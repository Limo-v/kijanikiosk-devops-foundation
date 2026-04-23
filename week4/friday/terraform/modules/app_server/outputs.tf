output "instance_id" {
  description = "Instance ID of the created server"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the created server"
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  description = "Security group ID attached to the server"
  value       = aws_security_group.app.id
}
