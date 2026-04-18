output "instance_public_ip" {
  description = "Public IP address assigned to the KijaniKiosk staging API server"
  value       = aws_instance.kk_api.public_ip
}

output "instance_id" {
  description = "EC2 instance ID for the KijaniKiosk staging API server"
  value       = aws_instance.kk_api.id
}

output "ssh_command" {
  description = "SSH command to connect to the API server"
  value       = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.kk_api.public_ip}"
}
