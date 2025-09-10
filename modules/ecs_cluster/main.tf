
resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-cluster"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.prefix}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Condition = {
        StringEquals = { "aws:RequestedRegion": "us-east-2" }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_custom_policy.arn
}

resource "aws_iam_policy" "ecs_task_execution_custom_policy" {
  name        = "${var.prefix}-ecs-task-execution-custom-policy"
  description = "Custom policy for ECS task execution role restricted to us-east-2"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource  = "*",
        Condition = {
          StringEquals = { "aws:RequestedRegion": "us-east-2" }
        }
      },
    ],
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.prefix}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Condition = {
        StringEquals = { "aws:RequestedRegion": "us-east-2" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_role_secrets_policy" {
  name = "${var.prefix}-ecs-task-role-secrets-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ],
        Effect    = "Allow",
        Resource  = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.prefix}-app-secrets-*",
        Condition = {
          StringEquals = { "aws:RequestedRegion": "us-east-2" }
        }
      },
    ],
  })
}
