# ─────────────────────────────────────────
# Security Groups (no rules inside — avoids cycle)
# ─────────────────────────────────────────

resource "aws_security_group" "public_alb" {
  name        = "${var.project_name}-public-alb-sg"
  description = "Security group for public ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-public-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "web_tier" {
  name        = "${var.project_name}-web-tier-sg"
  description = "Security group for public web VMs"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-web-tier-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "internal_alb" {
  name        = "${var.project_name}-internal-alb-sg"
  description = "Security group for internal ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-internal-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "app_tier" {
  name        = "${var.project_name}-app-tier-sg"
  description = "Security group for private app VMs"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-app-tier-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds_db" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }
}


# ─────────────────────────────────────────
# Public ALB Rules
# ─────────────────────────────────────────

resource "aws_security_group_rule" "public_alb_ingress_http" {
  type              = "ingress"
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_alb.id
}

resource "aws_security_group_rule" "public_alb_ingress_https" {
  type              = "ingress"
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_alb.id
}

resource "aws_security_group_rule" "public_alb_egress_to_web" {
  type                     = "egress"
  description              = "HTTP to web tier"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.public_alb.id
  source_security_group_id = aws_security_group.web_tier.id
}


# ─────────────────────────────────────────
# Web Tier Rules
# ─────────────────────────────────────────

resource "aws_security_group_rule" "web_tier_ingress_from_public_alb" {
  type                     = "ingress"
  description              = "HTTP from public ALB"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_tier.id
  source_security_group_id = aws_security_group.public_alb.id
}

resource "aws_security_group_rule" "web_tier_ingress_ssh" {
  type              = "ingress"
  description       = "SSH access"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidr
  security_group_id = aws_security_group.web_tier.id
}

resource "aws_security_group_rule" "web_tier_egress_to_internal_alb" {
  type                     = "egress"
  description              = "To internal ALB"
  from_port                = 80
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_tier.id
  source_security_group_id = aws_security_group.internal_alb.id
}


# ─────────────────────────────────────────
# Internal ALB Rules
# ─────────────────────────────────────────

resource "aws_security_group_rule" "internal_alb_ingress_from_web" {
  type                     = "ingress"
  description              = "From web tier"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.internal_alb.id
  source_security_group_id = aws_security_group.web_tier.id
}

resource "aws_security_group_rule" "internal_alb_egress_to_app" {
  type                     = "egress"
  description              = "To app tier"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.internal_alb.id
  source_security_group_id = aws_security_group.app_tier.id
}


# ─────────────────────────────────────────
# App Tier Rules
# ─────────────────────────────────────────

resource "aws_security_group_rule" "app_tier_ingress_from_internal_alb" {
  type                     = "ingress"
  description              = "From internal ALB"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_tier.id
  source_security_group_id = aws_security_group.internal_alb.id
}

resource "aws_security_group_rule" "app_tier_ingress_ssh" {
  type                     = "ingress"
  description              = "SSH from web tier for debugging"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_tier.id
  source_security_group_id = aws_security_group.web_tier.id
}

resource "aws_security_group_rule" "app_tier_egress_to_rds" {
  type                     = "egress"
  description              = "MySQL to RDS"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_tier.id
  source_security_group_id = aws_security_group.rds_db.id
}


# ─────────────────────────────────────────
# RDS Rules
# ─────────────────────────────────────────

resource "aws_security_group_rule" "rds_ingress_from_app" {
  type                     = "ingress"
  description              = "MySQL from app tier"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_db.id
  source_security_group_id = aws_security_group.app_tier.id
}
