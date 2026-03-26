# Web Tier EC2 Instances
resource "aws_instance" "web" {
  count                       = var.instance_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.key_name != "" ? var.key_name : null
  user_data                   = var.user_data != "" ? base64encode(var.user_data) : null

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project_name}-web-vm-${count.index + 1}"
    Environment = var.environment
    Tier        = "Web"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Register instances with ALB target group
resource "aws_lb_target_group_attachment" "web" {
  count            = var.instance_count
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
