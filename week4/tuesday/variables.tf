variable "region" {
  description = "AWS region for the KijaniKiosk staging server"
  type        = string
  default     = "af-south-1"
}

variable "instance_type" {
  description = "EC2 instance size for the staging API server"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "Existing AWS key pair name for SSH access to the server"
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "Single public CIDR allowed to connect over SSH"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "owner" {
  description = "Resource owner tag"
  type        = string
  default     = "amina"
}

variable "name_tag" {
  description = "Name tag applied to the API server and related resources"
  type        = string
  default     = "kijanikiosk-api-staging"
}

variable "vpc_cidr" {
  description = "CIDR block for the staging VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet used by the API server"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_key_path" {
  description = "Local private key path used when connecting to the instance"
  type        = string
  default     = "~/.ssh/kijani-admin-key.pem"
}
