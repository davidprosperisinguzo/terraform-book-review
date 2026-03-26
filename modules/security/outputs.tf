output "public_alb_security_group_id" {
  description = "Public ALB Security Group ID"
  value       = aws_security_group.public_alb.id
}

output "web_tier_security_group_id" {
  description = "Web Tier Security Group ID"
  value       = aws_security_group.web_tier.id
}

output "internal_alb_security_group_id" {
  description = "Internal ALB Security Group ID"
  value       = aws_security_group.internal_alb.id
}

output "app_tier_security_group_id" {
  description = "App Tier Security Group ID"
  value       = aws_security_group.app_tier.id
}

output "rds_security_group_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds_db.id
}
