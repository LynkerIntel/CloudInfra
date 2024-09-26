terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "ecr_mod" {
  source = "../ecr"
}

# Create function and set role
resource "aws_lambda_function" "forcing_processor_function" {
  function_name = "${var.function_name}"
  timeout       = 900 # 900 is max
  image_uri     = "${module.ecr_mod.repository_url}:${var.image_tag}"
  package_type  = "Image"

  memory_size = var.memory_size


  role = aws_iam_role.forcing_processor_function_role.arn

}

resource "aws_iam_role" "forcing_processor_function_role" {
  name = "forcing-processor"

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

# Output bucket 
resource "aws_s3_bucket" "out_bucket" {
  bucket = var.out_bucket
}

# Set up the trigger
resource "aws_s3_bucket" "trigger_bucket" {
  bucket = var.trigger_bucket
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.trigger_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.forcing_processor_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.trigger_file_prefix
    filter_suffix       = var.trigger_file_suffix
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forcing_processor_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.trigger_bucket.arn
}

resource "aws_iam_policy" "forcingprocessor_logging_policy" {
  name   = "forcingprocessor"
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
  role = aws_iam_role.forcing_processor_function_role.id
  policy_arn = aws_iam_policy.forcingprocessor_logging_policy.arn
}

# Add secret access to lambda function
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
