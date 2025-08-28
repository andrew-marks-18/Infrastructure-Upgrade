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

# --- SECRETS ---
data "aws_secretsmanager_secret" "app_credentials" {
  name = "${local.prefix}-app-secrets"
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
  aws_region = var.aws_region
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
  task_role_arn           = module.ecs_cluster.ecs_task_role_arn
  container_image         = var.ui_container_image
  health_check_path       = "/"
  certificate_arn         = data.aws_acm_certificate.wildcard.arn
  aws_region              = var.aws_region
  min_capacity            = 2
  max_capacity            = 6
  scaling_target_value    = 60
  secrets_arn = [
    {
      name      = "APP_SECRETS" # This will be the environment variable name in the container
      valueFrom = data.aws_secretsmanager_secret.app_credentials.arn
    }
  ]
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
  task_role_arn           = module.ecs_cluster.ecs_task_role_arn
  container_image         = var.api_container_image
  container_port          = 80
  health_check_path       = "/health"
  certificate_arn         = data.aws_acm_certificate.wildcard.arn
  aws_region              = var.aws_region
  min_capacity            = 2
  max_capacity            = 6
  scaling_target_value    = 60
  secrets_arn = [
    {
      name      = "APP_SECRETS" # This will be the environment variable name in the container
      valueFrom = data.aws_secretsmanager_secret.app_credentials.arn
    }
  ]
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