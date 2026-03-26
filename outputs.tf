# VPC and Network Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.networking.vpc_cidr
}

output "public_web_subnet_ids" {
  description = "Public web tier subnet IDs"
  value       = module.networking.public_web_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private app tier subnet IDs"
  value       = module.networking.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Private database tier subnet IDs"
  value       = module.networking.private_db_subnet_ids
}

output "availability_zones" {
  description = "Availability zones used"
  value       = module.networking.availability_zones
}

# Security Groups Outputs
output "public_alb_security_group_id" {
  description = "Public ALB security group ID"
  value       = module.security.public_alb_security_group_id
}

output "web_tier_security_group_id" {
  description = "Web tier security group ID"
  value       = module.security.web_tier_security_group_id
}

output "internal_alb_security_group_id" {
  description = "Internal ALB security group ID"
  value       = module.security.internal_alb_security_group_id
}

output "app_tier_security_group_id" {
  description = "App tier security group ID"
  value       = module.security.app_tier_security_group_id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.security.rds_security_group_id
}

# Public ALB Outputs
output "public_alb_dns_name" {
  description = "Public ALB DNS name"
  value       = module.public_alb.alb_dns_name
}

output "public_alb_arn" {
  description = "Public ALB ARN"
  value       = module.public_alb.alb_arn
}

# Web Tier Outputs
output "web_instance_ids" {
  description = "Web tier instance IDs"
  value       = module.web_vm.instance_ids
}

output "web_instance_private_ips" {
  description = "Web tier private IP addresses"
  value       = module.web_vm.instance_private_ips
}

output "web_instance_public_ips" {
  description = "Web tier public IP addresses"
  value       = module.web_vm.instance_public_ips
}

# Internal ALB Outputs
output "internal_alb_dns_name" {
  description = "Internal ALB DNS name"
  value       = module.internal_alb.alb_dns_name
}

output "internal_alb_arn" {
  description = "Internal ALB ARN"
  value       = module.internal_alb.alb_arn
}

# App Tier Outputs
output "app_instance_ids" {
  description = "App tier instance IDs"
  value       = module.app_vm.instance_ids
}

output "app_instance_private_ips" {
  description = "App tier private IP addresses"
  value       = module.app_vm.instance_private_ips
}

# RDS Database Outputs
output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_address" {
  description = "RDS database address"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "RDS database port"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_instance_name
}

output "rds_master_username" {
  description = "RDS master username"
  value       = module.rds.db_instance_username
  sensitive = true
}

# Connection information for application
output "app_tier_endpoint" {
  description = "Internal ALB endpoint for app tier"
  value       = "http://${module.internal_alb.alb_dns_name}:3001"
}

output "database_connection_string" {
  description = "Database connection string template"
  value       = "mysql://<username>:<password>@${module.rds.db_instance_address}:${module.rds.db_instance_port}/${module.rds.db_instance_name}"
  sensitive   = true
}
