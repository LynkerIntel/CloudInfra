# Variable declarations
variable "aws_region" {
  description = "Preferred region in which to launch EC2 instances. Defaults to us-east-1"
  type        = string
  default     = "us-west-2"  
}

variable "ecr_repo" {
  description = "AWS ECR repo name to hold the ngen research stream images"
  type        = string
  default     = "ngenimages"
}

variable "trigger_bucket" {
  description = "Event from this bucket triggers the lambda function"
  type        = string
  default     = "ngenforcingresources"
}

variable "out_bucket" {
  description = "Output folder for ngen forcing files"
  type        = string
  default     = "ngenforcingdev1"
}

variable "function_name" {
  description = "lamda function name"
  type = string
  default = "forcingprocessor"
}

variable "unique_env_vars" {
  type = map(string)
  default = {
    function01 = "01",
    function02 = "02",
    function03W = "03W",
    function03S = "03S",
    function03N = "03N",
    function04 = "04",
    function05 = "05",
    function06 = "06",
    function07 = "07",
    function08 = "08",
    function09 = "09",
    function10U = "10U",
    function10L = "10L",
    function11 = "11",
    function12 = "12",
    function13 = "13",
    function14 = "14",
    function15 = "15",
    function16 = "16",
    function17 = "17",
    function18 = "18"
  }
}

variable "trigger_file_prefix" {
  description = "The prefix to the file that will trigger the lambda function"
  type = string
  default = ""
}

variable "trigger_file_suffix" {
  description = "The suffix to the file that will trigger the lambda function"
  type = string
  default = ""
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

