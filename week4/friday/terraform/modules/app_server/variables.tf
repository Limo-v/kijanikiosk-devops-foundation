variable "name" {
  description = "Full instance name for the application server"
  type        = string
}

variable "service" {
  description = "Service label for the instance tags"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the server"
  type        = string
}

variable "environment" {
  description = "Environment label applied to the server"
  type        = string
}

variable "ami_id" {
  description = "AMI ID used for the Ubuntu 22.04 server"
  type        = string
}

variable "key_name" {
  description = "AWS key pair name used for SSH access"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be launched"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID used to create the service security group"
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "CIDR block allowed to access the server over SSH"
  type        = string
}

variable "http_ingress_cidr" {
  description = "CIDR block allowed to access the server over HTTP"
  type        = string
}

variable "owner" {
  description = "Owner tag applied to resources created by this module"
  type        = string
}

variable "assign_public_ip" {
  description = "Whether to associate a public IP address with the instance"
  type        = bool
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
}

variable "root_volume_type" {
  description = "Root EBS volume type for the instance"
  type        = string
}
