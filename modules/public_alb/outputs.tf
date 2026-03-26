output "alb_id" {
  description = "Public ALB ID"
  value       = aws_lb.public_alb.id
}

output "alb_arn" {
  description = "Public ALB ARN"
  value       = aws_lb.public_alb.arn
}

output "alb_dns_name" {
  description = "Public ALB DNS name"
  value       = aws_lb.public_alb.dns_name
}

output "alb_zone_id" {
  description = "Public ALB hosted zone ID"
  value       = aws_lb.public_alb.zone_id
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.web.arn
}

output "target_group_name" {
  description = "Target group name"
  value       = aws_lb_target_group.web.name
}

output "listener_arn" {
  description = "HTTP Listener ARN"
  value       = aws_lb_listener.http.arn
}
