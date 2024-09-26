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

output "repository_url" {
  value = aws_ecr_repository.ngen_image_repo.repository_url
}