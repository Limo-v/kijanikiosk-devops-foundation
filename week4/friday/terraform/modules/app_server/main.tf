resource "aws_security_group" "app" {
  name        = "${var.name}-sg"
  description = "Security group for the ${var.service} server"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from current operator CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  ingress {
    description = "HTTP from approved internet CIDR"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.http_ingress_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-sg"
    Service     = var.service
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = var.assign_public_ip

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
  }

  tags = {
    Name        = var.name
    Service     = var.service
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}
