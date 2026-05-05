variable "aws_profile" {
  description = "AWS CLI profile name used by Terraform for authentication"
  type        = string
  default     = "default"
}

variable "region" {
  description = "AWS region where the staging infrastructure will be created"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone used for the public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type used for the api and payments servers"
  type        = string
  default     = "t2.micro"
}

variable "logs_instance_type" {
  description = "EC2 instance type used for the logs server"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "Existing AWS key pair name used for SSH access"
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "CIDR block allowed to connect to the servers over SSH"
  type        = string
}

variable "http_ingress_cidr" {
  description = "CIDR block allowed to reach the servers over HTTP"
  type        = string
  default     = "0.0.0.0/0"
}

variable "environment" {
  description = "Deployment environment tag"
  type        = string
  default     = "staging"
}

variable "owner" {
  description = "Owner tag applied to all resources"
  type        = string
  default     = "amina"
}

variable "name_prefix" {
  description = "Name prefix used for all KijaniKiosk resources"
  type        = string
  default     = "kijanikiosk"
}

variable "vpc_cidr" {
  description = "CIDR block used for the project VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block used for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "assign_public_ip" {
  description = "Whether instances should receive public IP addresses"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root disk size in GB for each server"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "Root disk volume type for each server"
  type        = string
  default     = "gp3"
}

variable "private_key_path" {
  description = "Local SSH private key path used by Ansible and SSH outputs"
  type        = string
  default     = "~/.ssh/kijani-admin-key.pem"
}
