terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "replace-with-your-terraform-state-bucket"
    key            = "week4/wednesday/terraform.tfstate"
    region         = "af-south-1"
    dynamodb_table = "replace-with-your-terraform-lock-table"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  servers = {
    api = {
      service       = "api"
      instance_type = var.instance_type
    }
    payments = {
      service       = "payments"
      instance_type = var.instance_type
    }
    logs = {
      service       = "logs"
      instance_type = var.logs_instance_type
    }
  }
}

resource "aws_vpc" "kk_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name_prefix}-vpc"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "kk_igw" {
  vpc_id = aws_vpc.kk_vpc.id

  tags = {
    Name        = "${var.name_prefix}-igw"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "kk_public_subnet" {
  vpc_id                  = aws_vpc.kk_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = var.assign_public_ip

  tags = {
    Name        = "${var.name_prefix}-public-subnet"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table" "kk_public_rt" {
  vpc_id = aws_vpc.kk_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kk_igw.id
  }

  tags = {
    Name        = "${var.name_prefix}-public-rt"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table_association" "kk_public_assoc" {
  subnet_id      = aws_subnet.kk_public_subnet.id
  route_table_id = aws_route_table.kk_public_rt.id
}

module "app_servers" {
  source   = "./modules/app_server"
  for_each = local.servers

  name              = "${var.name_prefix}-${each.key}"
  service           = each.value.service
  instance_type     = each.value.instance_type
  environment       = var.environment
  ami_id            = data.aws_ami.ubuntu_2204.id
  key_name          = var.ssh_key_name
  subnet_id         = aws_subnet.kk_public_subnet.id
  vpc_id            = aws_vpc.kk_vpc.id
  ssh_ingress_cidr  = var.ssh_ingress_cidr
  http_ingress_cidr = var.http_ingress_cidr
  owner             = var.owner
  assign_public_ip  = var.assign_public_ip
  root_volume_size  = var.root_volume_size
  root_volume_type  = var.root_volume_type
}

