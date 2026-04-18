terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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

resource "aws_vpc" "kk_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name_tag}-vpc"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_internet_gateway" "kk_igw" {
  vpc_id = aws_vpc.kk_vpc.id

  tags = {
    Name        = "${var.name_tag}-igw"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_subnet" "kk_public_subnet" {
  vpc_id                  = aws_vpc.kk_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.name_tag}-public-subnet"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_route_table" "kk_public_rt" {
  vpc_id = aws_vpc.kk_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kk_igw.id
  }

  tags = {
    Name        = "${var.name_tag}-public-rt"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_route_table_association" "kk_public_assoc" {
  subnet_id      = aws_subnet.kk_public_subnet.id
  route_table_id = aws_route_table.kk_public_rt.id
}

resource "aws_security_group" "kk_api_sg" {
  name        = "${var.name_tag}-sg"
  description = "Security group for the KijaniKiosk staging API server"
  vpc_id      = aws_vpc.kk_vpc.id

  ingress {
    description = "SSH from my public IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_tag}-sg"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_instance" "kk_api" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  key_name                    = var.ssh_key_name
  subnet_id                   = aws_subnet.kk_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.kk_api_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name        = var.name_tag
    Environment = var.environment
    Owner       = var.owner
  }
}
