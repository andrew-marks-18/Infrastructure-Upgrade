
variable "prefix" {
  description = "The prefix to use for all resources."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  description = "The CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "aws_region" {
  description = "The AWS region."
  type        = string
}

variable "availability_zones" {
  description = "The availability zones to use for the subnets."
  type        = list(string)
  default     = ["${var.aws_region}a", "${var.aws_region}b"]
}


