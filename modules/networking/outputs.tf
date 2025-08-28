
output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group."
  value       = aws_security_group.alb.id
}

output "fargate_security_group_id" {
  description = "The ID of the Fargate security group."
  value       = aws_security_group.fargate.id
}
