output "instance_id" {
  description = "Instance ID of the server created by this module"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the server created by this module"
  value       = aws_instance.this.public_ip
}
