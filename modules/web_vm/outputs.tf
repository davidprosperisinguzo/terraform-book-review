output "instance_ids" {
  description = "Web VM instance IDs"
  value       = aws_instance.web[*].id
}

output "instance_private_ips" {
  description = "Web VM private IP addresses"
  value       = aws_instance.web[*].private_ip
}

output "instance_public_ips" {
  description = "Web VM public IP addresses"
  value       = aws_instance.web[*].public_ip
}

output "ami_id" {
  description = "AMI ID used"
  value       = data.aws_ami.ubuntu.id
}
