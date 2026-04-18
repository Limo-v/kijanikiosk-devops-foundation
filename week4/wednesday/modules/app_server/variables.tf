variable "name" {
  description = "Full instance name for the server created by this module"
  type        = string
}

variable "service" {
  description = "Service label used in tags for the server"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type to launch for this server"
  type        = string
  default     = "t2.micro"
}

variable "environment" {
  description = "Environment label applied to the server and security group"
  type        = string
}

variable "ami_id" {
  description = "AMI ID used to boot the server"
  type        = string
}

variable "key_name" {
  description = "AWS key pair name used to enable SSH access"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the server will be created"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the module security group will be created"
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
  description = "Owner tag applied to resources created by the module"
  type        = string
}

variable "assign_public_ip" {
  description = "Whether the launched server should receive a public IP address"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root volume size in GB for the launched server"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "Root volume type for the launched server"
  type        = string
  default     = "gp3"
}
