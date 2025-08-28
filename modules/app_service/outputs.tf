
output "load_balancer_dns" {
  description = "The DNS name of the Load Balancer."
  value       = aws_lb.main.dns_name
}
