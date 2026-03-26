# RDS MySQL Database Instance
resource "aws_db_instance" "main" {
  identifier            = "${var.project_name}-db"
  allocated_storage     = var.allocated_storage
  storage_type          = var.storage_type
  engine                = var.engine
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  db_name               = var.db_name
  username              = var.username
  password              = var.password
  port                  = var.port
  db_subnet_group_name  = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids

  multi_az            = var.multi_az
  publicly_accessible = var.publicly_accessible

  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.final_snapshot_identifier

  deletion_protection            = var.deletion_protection
  iam_database_authentication_enabled = var.enable_iam_database_authentication

  tags = {
    Name        = "${var.project_name}-db"
    Environment = var.environment
  }
}
