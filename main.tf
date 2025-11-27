# Terraform Configuration for AWS Apache Web Server with Load Balancer
# Region: us-east-1

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2"

  # Terraform Cloud Backend
  cloud {
    organization = "terraform-workshop3"  

    workspaces {
      name = "aws-loadbalancer"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 5
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# Data source for available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create a VPC
resource "aws_vpc" "terraform_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "terraform-vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "terraform_igw" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "terraform-igw"
  }
}

# Create a custom Route Table
resource "aws_route_table" "terraform_route_table" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_igw.id
  }

  tags = {
    Name = "terraform-route-table"
  }
}

# Create multiple Subnets in different AZs (required for ALB)
resource "aws_subnet" "terraform_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.terraform_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-subnet-${count.index + 1}"
  }
}

# Associate Subnets with Route Table
resource "aws_route_table_association" "main_association" {
  count          = 2
  subnet_id      = aws_subnet.terraform_subnet[count.index].id
  route_table_id = aws_route_table.terraform_route_table.id
}

# Create a Security Group for EC2 instances
resource "aws_security_group" "instance_sg" {
  name        = "terraform-instance-sg"
  description = "Security group for web server instances"
  vpc_id      = aws_vpc.terraform_vpc.id

  # Allow HTTP from ALB Security Group
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Egress: Allow everything
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-instance-sg"
  }
}

# Create a Security Group for the ALB
resource "aws_security_group" "alb_sg" {
  name        = "terraform-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.terraform_vpc.id

  # Allow HTTP from anywhere
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Allow everything
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-alb-sg"
  }
}

# Create EC2 Instances
resource "aws_instance" "web_server" {
  count                  = var.instance_count
  ami                    = "ami-0866a3c8686eaeeba" # Ubuntu 22.04 LTS in us-east-1
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.terraform_subnet[count.index % 2].id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # Apache web server with instance identifier
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
              echo "<h1>Hello World from Instance: $INSTANCE_ID</h1><p>Server ${count.index + 1}</p>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "web-server-${count.index + 1}"
  }
}

# Create Application Load Balancer
resource "aws_lb" "web_alb" {
  name               = "terraform-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.terraform_subnet[*].id

  enable_deletion_protection = false

  tags = {
    Name = "terraform-web-alb"
  }
}

# Create Target Group
resource "aws_lb_target_group" "web_tg" {
  name     = "terraform-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "terraform-web-tg"
  }
}

# Attach instances to Target Group
resource "aws_lb_target_group_attachment" "web_tg_attachment" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_server[count.index].id
  port             = 80
}

# Create ALB Listener
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Outputs
output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = aws_instance.web_server[*].id
}

output "instance_private_ips" {
  description = "Private IP addresses of the EC2 instances"
  value       = aws_instance.web_server[*].private_ip
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web_alb.dns_name
}

output "load_balancer_url" {
  description = "URL to access the web server via Load Balancer"
  value       = "http://${aws_lb.web_alb.dns_name}"
}

output "check_reachability" {
  description = "Command to check if Load Balancer is reachable"
  value       = "curl http://${aws_lb.web_alb.dns_name}"
}
