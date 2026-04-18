variable "region" {
  description = "AWS region for the KijaniKiosk Wednesday lab deployment"
  type        = string
  default     = "af-south-1"
}

variable "availability_zone" {
  description = "Availability zone for the shared public subnet"
  type        = string
  default     = "af-south-1a"
}

variable "instance_type" {
  description = "EC2 instance type for the api and payments servers"
  type        = string
  default     = "t2.micro"
}

variable "logs_instance_type" {
  description = "EC2 instance type for the logs server"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "Existing AWS key pair name used to access the lab servers"
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "Single CIDR block allowed to connect over SSH"
  type        = string
}

variable "http_ingress_cidr" {
  description = "CIDR block allowed to access HTTP on the servers"
  type        = string
  default     = "0.0.0.0/0"
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "staging"
}

variable "owner" {
  description = "Owner tag for shared resources and servers"
  type        = string
  default     = "amina"
}

variable "name_prefix" {
  description = "Name prefix applied to all Wednesday lab resources"
  type        = string
  default     = "kijanikiosk"
}

variable "vpc_cidr" {
  description = "CIDR block for the Wednesday lab VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the shared public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "assign_public_ip" {
  description = "Whether instances should receive public IP addresses"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root volume size in GB for each instance"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "Root volume type for each instance"
  type        = string
  default     = "gp3"
}

variable "private_key_path" {
  description = "Local SSH private key path used to connect to the created servers"
  type        = string
  default     = "~/.ssh/kijani-admin-key.pem"
}
