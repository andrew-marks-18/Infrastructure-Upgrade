variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-2"
}

variable "ui_container_image" {
  description = "The UI container image to deploy (e.g., from ECR)."
  type        = string
  default     = "nginx:1.27.0"
}

variable "api_container_image" {
  description = "The API container image to deploy (e.g., from ECR)."
  type        = string
  default     = "nginx:1.27.0"
}

variable "domain_name" {
  description = "The root domain name for your application (e.g., example.com)."
  type        = string
  default     = "customdonations.com"
}

variable "ui_subdomain" {
  description = "The subdomain for the UI service (e.g., upgrade-ui)."
  type        = string
  default     = "upgrade-ui"
}

variable "api_subdomain" {
  description = "The subdomain for the API service (e.g., upgrade-api)."
  type        = string
  default     = "upgrade-api"
}
