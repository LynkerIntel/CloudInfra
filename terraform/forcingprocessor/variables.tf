# Variable declarations
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

variable "trigger_bucket" {
  description = "Event from this bucket triggers the lambda function"
  type        = string
  default     = "ngenresourcesdev"
}

variable "out_bucket" {
  description = "Output folder for ngen forcing files"
  type        = string
  default     = "ngenforcingdev"
}

variable "function_name" {
  description = "lamda function name"
  type = string
  default = "forcingprocessor"
}

variable "trigger_file_prefix" {
  description = "The prefix to the file that will trigger the lambda function"
  type = string
  default = ""
}

variable "trigger_file_suffix" {
  description = "The suffix to the file that will trigger the lambda function"
  type = string
  default = "02.conus.nc.txt"
}

variable "image_tag" {
  description = "The lambda function's image's tag"
  type = string
  default = "forcingprocessor"
}

variable "memory_size" {
  description = "Maximum allowed memory for the lambda function"
  type = number
  default = "4096"
}

