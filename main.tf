# Networking Module
module "networking" {
  source = "./modules/networking"

  vpc_cidr              = var.vpc_cidr
  aws_region            = var.aws_region
  environment           = var.environment
  project_name          = var.project_name
  enable_nat_gateway    = var.enable_nat_gateway
  enable_vpn_gateway    = var.enable_vpn_gateway
}

# Security Module
module "security" {
  source = "./modules/security"

  vpc_id              = module.networking.vpc_id
  environment         = var.environment
  project_name        = var.project_name
  allowed_ssh_cidr    = var.allowed_ssh_cidr
}

# Public ALB Module
module "public_alb" {
  source = "./modules/public_alb"

  name                   = "${var.project_name}-public-alb"
  environment            = var.environment
  project_name           = var.project_name
  security_group_ids     = [module.security.public_alb_security_group_id]
  subnet_ids             = module.networking.public_web_subnet_ids
  vpc_id                 = module.networking.vpc_id
  target_port            = 80
  health_check_path      = "/"
}

# Web Tier VMs Module
module "web_vm" {
  source = "./modules/web_vm"

  instance_type       = var.web_instance_type
  subnet_ids          = module.networking.public_web_subnet_ids
  security_group_ids  = [module.security.web_tier_security_group_id]
  target_group_arn    = module.public_alb.target_group_arn
  environment         = var.environment
  project_name        = var.project_name
  instance_count      = var.web_instance_count
  key_name            = var.ec2_key_pair_name
  depends_on = [module.public_alb]
}

# Internal ALB Module
module "internal_alb" {
  source = "./modules/internal_alb"

  name                   = "${var.project_name}-internal-alb"
  environment            = var.environment
  project_name           = var.project_name
  security_group_ids     = [module.security.internal_alb_security_group_id]
  subnet_ids             = module.networking.private_app_subnet_ids
  vpc_id                 = module.networking.vpc_id
  target_port            = 3001
  health_check_path      = "/"
}

# App Tier VMs Module
module "app_vm" {
  source = "./modules/app_vm"

  instance_type       = var.app_instance_type
  subnet_ids          = module.networking.private_app_subnet_ids
  security_group_ids  = [module.security.app_tier_security_group_id]
  target_group_arn    = module.internal_alb.target_group_arn
  environment         = var.environment
  project_name        = var.project_name
  instance_count      = var.app_instance_count
  key_name            = var.ec2_key_pair_name
  depends_on = [module.internal_alb]
}

# RDS Module - Create DB subnet group outside of module for proper dependency management
resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.networking.private_db_subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

module "rds" {
  source = "./modules/rds"

  allocated_storage     = var.db_allocated_storage
  storage_type          = var.db_storage_type
  engine                = var.db_engine
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  db_name               = var.db_name
  username              = var.db_username
  password              = var.db_password
  db_subnet_group_name  = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [module.security.rds_security_group_id]
  environment           = var.environment
  project_name          = var.project_name
  multi_az              = var.db_multi_az
  publicly_accessible   = var.db_publicly_accessible
  skip_final_snapshot   = var.db_skip_final_snapshot
  final_snapshot_identifier = "${var.project_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection   = var.db_deletion_protection
  enable_iam_database_authentication = var.db_enable_iam_authentication

  depends_on = [aws_db_subnet_group.rds]
}
