output "api_server_ip" {
  description = "Public IP address of the api server"
  value       = module.app_servers["api"].public_ip
}

output "payments_server_ip" {
  description = "Public IP address of the payments server"
  value       = module.app_servers["payments"].public_ip
}

output "logs_server_ip" {
  description = "Public IP address of the logs server"
  value       = module.app_servers["logs"].public_ip
}

output "server_public_ips" {
  description = "Map of server names to public IP addresses"
  value = {
    for name, server in module.app_servers : name => server.public_ip
  }
}

output "ssh_commands" {
  description = "Ready-to-copy SSH commands for all servers"
  value = {
    for name, server in module.app_servers : name => "ssh -i ${var.private_key_path} ubuntu@${server.public_ip}"
  }
}
