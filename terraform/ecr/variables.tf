variable "aws_region" {
  description = "Preferred region in which to launch EC2 instances. Defaults to us-east-1"
  type        = string
  default     = "us-east-2"
}

variable "ecr_repo" {
  description = "AWS ECR repo name to hold the ngen research stream images"
  type        = string
  default     = "ngenresearchstream"
}