output "instance_ids" {
  description = "Map of server names to EC2 instance IDs"
  value = {
    for name, server in module.app_servers : name => server.instance_id
  }
}

output "instance_public_ips" {
  description = "Map of server names to public IP addresses"
  value = {
    for name, server in module.app_servers : name => server.public_ip
  }
}

output "ssh_commands" {
  description = "Ready-to-copy SSH commands for all created servers"
  value = {
    for name, server in module.app_servers : name => "ssh -i ${var.private_key_path} ubuntu@${server.public_ip}"
  }
}
