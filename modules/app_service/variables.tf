
variable "prefix" {
  description = "The prefix to use for all resources."
  type        = string
}

variable "service_name" {
  description = "The name of the service (e.g., ui, api)."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "The IDs of the public subnets."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "The ID of the ALB security group."
  type        = string
}

variable "fargate_security_group_id" {
  description = "The ID of the Fargate security group."
  type        = string
}

variable "cluster_id" {
  description = "The ID of the ECS cluster."
  type        = string
}

variable "cluster_name" {
  description = "The name of the ECS cluster."
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  type        = string
}

variable "task_role_arn" {
  description = "The ARN of the ECS task role."
  type        = string
  default     = null
}

variable "container_image" {
  description = "The container image to deploy."
  type        = string
}

variable "container_port" {
  description = "The port the container listens on."
  type        = number
  default     = 80
}

variable "container_cpu" {
  description = "The CPU units to allocate to the container."
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "The memory to allocate to the container."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "The desired number of tasks to run."
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "The minimum number of tasks for auto-scaling."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "The maximum number of tasks for auto-scaling."
  type        = number
  default     = 4
}

variable "scaling_target_value" {
  description = "The target value for the scaling policy."
  type        = number
  default     = 75
}

variable "health_check_path" {
  description = "The path for the health check."
  type        = string
  default     = "/"
}

variable "certificate_arn" {
  description = "The ARN of the ACM certificate."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "secrets_arn" {
  description = "A list of maps, each containing 'name' and 'valueFrom' for secrets."
  type        = list(object({ name = string, valueFrom = string }))
  default     = []
}
