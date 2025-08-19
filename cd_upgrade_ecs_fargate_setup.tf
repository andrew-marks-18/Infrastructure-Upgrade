terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
  vpc_id       = data.aws_vpc.default.id
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
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

resource "aws_security_group" "fargate_sg" {
  name        = "${local.prefix}-fargate-sg"
  description = "Allow traffic from the ALBs to the Fargate containers"
  vpc_id      = local.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [
      aws_security_group.alb_ui_sg.id,
      aws_security_group.alb_api_sg.id
    ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- SHARED INFRASTRUCTURE (ECS CLUSTER & IAM) ---
resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.prefix}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- UI WORKFLOW RESOURCES ---
resource "aws_security_group" "alb_ui_sg" {
  name        = "${local.prefix}-ui-alb-sg"
  description = "Allow HTTP/HTTPS traffic from the internet to the UI ALB"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "ui" {
  name               = "${local.prefix}-ui-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_ui_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "ui" {
  name        = "${local.prefix}-ui-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"
  health_check { path = "/" }
}

resource "aws_lb_listener" "ui_http" {
  load_balancer_arn = aws_lb.ui.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "ui_https" {
  load_balancer_arn = aws_lb.ui.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }
}

resource "aws_cloudwatch_log_group" "ui" {
  name = "/ecs/${local.prefix}/ui"
}

resource "aws_ecs_task_definition" "ui" {
  family                   = "${local.prefix}-ui"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([{
    name  = "${local.prefix}-ui-container"
    image = var.ui_container_image
    portMappings = [{ containerPort = 80 }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ui.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "ui" {
  name            = "${local.prefix}-ui-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ui.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Initial count
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ui.arn
    container_name   = "${local.prefix}-ui-container"
    container_port   = 80
  }
}

resource "aws_appautoscaling_target" "ui" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.ui.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ui_cpu" {
  name               = "${local.prefix}-ui-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ui.resource_id
  scalable_dimension = aws_appautoscaling_target.ui.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ui.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 75
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# --- API WORKFLOW RESOURCES ---
resource "aws_security_group" "alb_api_sg" {
  name        = "${local.prefix}-api-alb-sg"
  description = "Allow HTTP/HTTPS traffic from the internet to the API ALB"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "api" {
  name               = "${local.prefix}-api-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_api_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "api" {
  name        = "${local.prefix}-api-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"
  health_check { path = "/health" }
}

resource "aws_lb_listener" "api_http" {
  load_balancer_arn = aws_lb.api.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "api_https" {
  load_balancer_arn = aws_lb.api.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name = "/ecs/${local.prefix}/api"
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.prefix}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([{
    name  = "${local.prefix}-api-container"
    image = var.api_container_image
    portMappings = [{ containerPort = 80 }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.api.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "${local.prefix}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Initial count
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "${local.prefix}-api-container"
    container_port   = 80
  }
}

resource "aws_appautoscaling_target" "api" {
  max_capacity       = 6
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "${local.prefix}-api-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# --- OUTPUTS ---
output "ui_load_balancer_dns" {
  description = "The DNS name of the UI Load Balancer. Use this for your CNAME record."
  value       = aws_lb.ui.dns_name
}

output "api_load_balancer_dns" {
  description = "The DNS name of the API Load Balancer. Use this for your CNAME record."
  value       = aws_lb.api.dns_name
}
