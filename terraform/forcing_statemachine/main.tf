terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"      
    }
  }
}
provider "aws" {
  region  = var.aws_region
}
module "ecr_mod" {
  source = "../ecr_lynker"
}

#lambdas
resource "aws_lambda_function" "forcing_processor_function" {
  for_each      = var.unique_env_vars
  function_name = "${var.function_name}_${each.value}"
  timeout       = 900
  image_uri     = "${module.ecr_mod.repository_url}:${var.image_tag}"
  package_type  = "Image"
  memory_size   = var.memory_size
  role          = aws_iam_role.forcing_processor_function_role.arn
  depends_on    = [
    aws_iam_role_policy_attachment.lambda_logs,
  ]
  environment {
    variables   = {
      VPU = each.value
    }
  }
}
resource "aws_iam_role" "forcing_processor_function_role" {
  name               = "ForcingLambdaRole"
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# s3 buckets
resource "aws_s3_bucket" "out_bucket" {
  bucket = var.out_bucket
}
resource "aws_s3_bucket" "trigger_bucket" {
  bucket = var.trigger_bucket  
}

# s3 -> eventbridge event
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = aws_s3_bucket.trigger_bucket.id
  eventbridge = true
}
resource "aws_cloudwatch_event_rule" "sns_to_stepfcn_rule" {
  name          = "DetectNWMForcingUploadRule"
  event_pattern = <<EOF
  { 
    "source": ["aws.s3" ],
    "detail-type": [
        "Object Created"
    ],    
    "object": {
      "key": [ { "prefix": "${var.trigger_file_prefix}" } ]
    },
    "detail": {
      "bucket": {
        "name": [ "${var.trigger_bucket}" ]
      }
    }
  }
  EOF
}
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.sns_to_stepfcn_rule.name
  role_arn  = aws_iam_role.eventbridge_to_stepfunctions_role.arn
  target_id = "execute-stepfunctions-target"
  arn       = aws_sfn_state_machine.sfn_state_machine.arn
}
resource "aws_iam_policy_attachment" "eventbridge_execute_state" {
  name       = "ExecuteState"
  policy_arn = aws_iam_policy.invoke_statemachine_policy.arn
  roles      = [aws_iam_role.eventbridge_to_stepfunctions_role.name]
}
resource "aws_iam_role" "eventbridge_to_stepfunctions_role" {
  name               = "InvokeStateMachineRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}
resource "aws_iam_policy" "invoke_statemachine_policy" {
  name        = "InvokeStateMachinePolicy"
  description = "IAM policy to allow invoking a Step Functions state machine"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["states:StartExecution"],
        Resource = [aws_sfn_state_machine.sfn_state_machine.arn],
      },
    ],
  })
}

# # Step Function
# resource "aws_sfn_state_machine" "sfn_state_machine" {
#   name     = "ngenforcing"
#   role_arn = aws_iam_role.iam_for_sfn.arn

#   definition = jsonencode({
#     Comment   = "Triggered by EventBridgeRule",
#     StartAt   = "ParallelState",
#     States    = {
#       ParallelState = {
#         Type      = "Parallel",
#         Branches  = [
#           for key, value in var.unique_env_vars :
#           {
#             StartAt = "${value}"
#             States  = {
#               "${value}": {
#                 Type     = "Task",
#                 Resource = "arn:aws:states:::lambda:invoke",
#                 Parameters = {
#                   FunctionName = aws_lambda_function.forcing_processor_function[key].function_name
#                 }
#                 End      = true
#               }
#             }
#           }
#         ],
#         End       = true
#       }
#     }
#   })
# }
locals {
  state_machine_definition = {
    Comment   = "Triggered by EventBridgeRule",
    StartAt   = "FirstLambda",
    States    = {
      FirstLambda = {
        Type     = "Task",
        Resource = "arn:aws:states:::lambda:invoke",
        Parameters = {
          FunctionName = aws_lambda_function.forcing_processor_function[var.unique_env_vars[0]].function_name
        },
        Next     = "ChoiceState"
      },
      ChoiceState = {
        Type    = "Choice",
        Choices = [ // Create choices for each Lambda function except the last one
          for index, value in var.unique_env_vars :
          {
            Variable     = "$.index",
            NumericEquals = index,
            Next         = "Lambda${index + 1}"
          }
        ],
        Default = "EndState"
      },
      // Create a state for each Lambda function
      for index, value in var.unique_env_vars :
      "Lambda${index}" = {
        Type     = "Task",
        Resource = "arn:aws:states:::lambda:invoke",
        Parameters = {
          FunctionName = aws_lambda_function.forcing_processor_function[value].function_name
        },
        Next     = "${index == length(var.unique_env_vars) - 1 ? "EndState" : "ChoiceState"}"
      },
      EndState = {
        Type  = "Pass",
        Result = "All Lambdas Executed",
        End   = true
      }
    }
  }
}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "ngenforcing"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = jsonencode(local.state_machine_definition)
}
resource "aws_iam_role" "iam_for_sfn" {
  name = "forcingprocessorSFNRole4"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "states.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_policy" "lambda_invoke_policy" {
  name        = "LambdaInvokePolicy2"
  description = "Allows invoking Lambda functions"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["lambda:InvokeFunction"],
        Effect = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
resource "aws_iam_policy_attachment" "lambda_invoke_attachment" {
  name       = "LambdaInvokeAttachment"
  policy_arn = aws_iam_policy.lambda_invoke_policy.arn
  roles      = [aws_iam_role.iam_for_sfn.name]
}

# Logging
resource "aws_iam_policy" "forcingprocessor_logging_policy" {
  name   = "ForcingLoggingPolicy2"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  policy_arn = aws_iam_policy.forcingprocessor_logging_policy.arn
  role       = aws_iam_role.iam_for_sfn.name
}
data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.forcing_processor_function_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# Secrets
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "secrets_manager_access_policy"
  description = "Allows access to Secrets Manager"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSecretsManagerAccess"
        Effect    = "Allow"
        Action    = ["secretsmanager:GetSecretValue"]
        Resource  = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "secrets_manager_attachment" {
  role       = aws_iam_role.forcing_processor_function_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}
