output "alb_id" {
  description = "Internal ALB ID"
  value       = aws_lb.internal_alb.id
}

output "alb_arn" {
  description = "Internal ALB ARN"
  value       = aws_lb.internal_alb.arn
}

output "alb_dns_name" {
  description = "Internal ALB DNS name"
  value       = aws_lb.internal_alb.dns_name
}

output "alb_zone_id" {
  description = "Internal ALB hosted zone ID"
  value       = aws_lb.internal_alb.zone_id
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.app.arn
}

output "target_group_name" {
  description = "Target group name"
  value       = aws_lb_target_group.app.name
}

output "listener_arn" {
  description = "App Listener ARN"
  value       = aws_lb_listener.app.arn
}
