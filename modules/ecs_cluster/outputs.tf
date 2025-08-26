
output "cluster_id" {
  description = "The ID of the ECS cluster."
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "The ARN of the ECS task role."
  value       = aws_iam_role.ecs_task_role.arn
}
