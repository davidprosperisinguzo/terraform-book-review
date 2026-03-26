output "instance_ids" {
  description = "App VM instance IDs"
  value       = aws_instance.app[*].id
}

output "instance_private_ips" {
  description = "App VM private IP addresses"
  value       = aws_instance.app[*].private_ip
}

output "ami_id" {
  description = "AMI ID used"
  value       = data.aws_ami.ubuntu.id
}
