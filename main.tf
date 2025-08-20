terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags = {
    ManagedBy = "Terraform"
    Project   = "Upgrade"
  }
}

# --- VARIABLES ---
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
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

# --- LOCALS ---
locals {
  prefix       = "upgrade"
  ui_hostname  = "${var.ui_subdomain}.${var.domain_name}"
  api_hostname = "${var.api_subdomain}.${var.domain_name}"
}

# --- DNS & CERTIFICATES ---
data "aws_acm_certificate" "wildcard" {
  domain      = "*.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

# --- NETWORKING ---
module "networking" {
  source = "./modules/networking"
  prefix = local.prefix
}

# --- SHARED INFRASTRUCTURE (ECS CLUSTER & IAM) ---
module "ecs_cluster" {
  source = "./modules/ecs_cluster"
  prefix = local.prefix
}

# --- UI WORKFLOW RESOURCES ---
module "ui_service" {
  source                  = "./modules/app_service"
  prefix                  = local.prefix
  service_name            = "ui"
  vpc_id                  = module.networking.vpc_id
  public_subnet_ids       = module.networking.public_subnet_ids
  alb_security_group_id   = module.networking.alb_security_group_id
  fargate_security_group_id = module.networking.fargate_security_group_id
  cluster_id              = module.ecs_cluster.cluster_id
  cluster_name            = module.ecs_cluster.cluster_name
  ecs_task_execution_role_arn = module.ecs_cluster.ecs_task_execution_role_arn
  container_image         = var.ui_container_image
  health_check_path       = "/"
  certificate_arn         = data.aws_acm_certificate.wildcard.arn
  aws_region              = var.aws_region
}

# --- API WORKFLOW RESOURCES ---
module "api_service" {
  source                  = "./modules/app_service"
  prefix                  = local.prefix
  service_name            = "api"
  vpc_id                  = module.networking.vpc_id
  public_subnet_ids       = module.networking.public_subnet_ids
  alb_security_group_id   = module.networking.alb_security_group_id
  fargate_security_group_id = module.networking.fargate_security_group_id
  cluster_id              = module.ecs_cluster.cluster_id
  cluster_name            = module.ecs_cluster.cluster_name
  ecs_task_execution_role_arn = module.ecs_cluster.ecs_task_execution_role_arn
  container_image         = var.api_container_image
  health_check_path       = "/health"
  certificate_arn         = data.aws_acm_certificate.wildcard.arn
  aws_region              = var.aws_region
  min_capacity            = 2
  max_capacity            = 6
  scaling_target_value    = 60
}

# --- OUTPUTS ---
output "ui_load_balancer_dns" {
  description = "The DNS name of the UI Load Balancer. Use this for your CNAME record."
  value       = module.ui_service.load_balancer_dns
}

output "api_load_balancer_dns" {
  description = "The DNS name of the API Load Balancer. Use this for your CNAME record."
  value       = module.api_service.load_balancer_dns
}