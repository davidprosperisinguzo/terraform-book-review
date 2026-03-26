# Internal Application Load Balancer
resource "aws_lb" "internal_alb" {
  name               = var.name
  internal           = true
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = var.enable_http2
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  idle_timeout                     = var.idle_timeout

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

# Target Group for app VMs
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-app-tg"
  port        = var.target_port
  protocol    = var.target_protocol
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-app-tg"
    Environment = var.environment
  }
}

# ALB Listener - HTTP on port 3001
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = 3001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
