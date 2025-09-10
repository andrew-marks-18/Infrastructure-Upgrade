
resource "aws_lb" "main" {
  name               = "${var.prefix}-${var.service_name}-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "main" {
  name        = "${var.prefix}-${var.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check { path = var.health_check_path }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name = "/ecs/${var.prefix}/${var.service_name}"
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.prefix}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["Fargate"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name         = "${var.prefix}-${var.service_name}-container"
    image        = var.container_image
    portMappings = [{ containerPort = var.container_port }]
    secrets = var.secrets_arn != null ? [
      for s in var.secrets_arn : {
        name      = s.name
        valueFrom = s.valueFrom
      }
    ] : null
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.main.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "main" {
  name            = "${var.prefix}-${var.service_name}-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count
  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.fargate_security_group_id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "${var.prefix}-${var.service_name}-container"
    container_port   = var.container_port
  }
}

resource "aws_appautoscaling_target" "main" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.prefix}-${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = var.scaling_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
