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

resource "aws_ecr_repository" "ngen_image_repo" {
  name = var.ecr_repo
}

resource "aws_ecr_repository_policy" "my_ecr_repo_policy" {

  repository = "${aws_ecr_repository.ngen_image_repo.name }"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal: "*",
        Action = [
          "ecr:BatchGetImage",
          "ecr:DeleteRepositoryPolicy",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy",
        ],
      },
    ],
  })
}

output "repository_url" {
  value = aws_ecr_repository.ngen_image_repo.repository_url
}


