terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------------------------------------------------
# PROVIDER
# ------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------
# VPC & NETWORKING
# ------------------------------------------------------------------

# Your private fenced area in AWS
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ecommerce-vpc"
  }
}

# Internet Gateway = the door to the internet for your public stuff
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ecommerce-igw"
  }
}

# Elastic IP for NAT Gateway (NAT needs a fixed public IP)
resource "aws_eip" "nat" {
  domain = "vpc"
}

# ------------------------------------------------------------------
# SUBNETS
# ------------------------------------------------------------------

# PUBLIC SUBNET 1 (us-east-1a) - for ALB and NAT Gateway
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true   # Any computer here gets a public IP

  tags = {
    Name = "public-subnet-1a"
  }
}

# PUBLIC SUBNET 2 (us-east-1b) - for ALB (needs 2 AZs to work)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.102.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1b"
  }
}

# PRIVATE SUBNET A (us-east-1a) - matches your PDF diagram
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "private-subnet-a"
  }
}

# PRIVATE SUBNET B (us-east-1b) - matches your PDF diagram
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "private-subnet-b"
  }
}

# ------------------------------------------------------------------
# NAT GATEWAY
# ------------------------------------------------------------------
# Allows private servers to download Docker/images from the internet
# but blocks strangers from coming in
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "ecommerce-nat"
  }
}

# ------------------------------------------------------------------
# ROUTE TABLES (The traffic signs of your network)
# ------------------------------------------------------------------

# Public Route Table: sends internet traffic through Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Private Route Table: sends internet traffic through NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Connect subnets to their route tables
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------
# SECURITY GROUPS (Firewalls)
# ------------------------------------------------------------------

# ALB Security Group - allows visitors to reach the load balancer
resource "aws_security_group" "alb" {
  name_prefix = "alb-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# EC2 Security Group - allows traffic only from ALB + SSH for Ansible
resource "aws_security_group" "ec2" {
  name_prefix = "ec2-sg-"
  vpc_id      = aws_vpc.main.id

  # Port 80 - ONLY from the Load Balancer (very secure)
  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Port 22 - SSH access so GitHub Actions/Ansible can log in
  # In production you would restrict this to your office IP
  ingress {
    description = "SSH from anywhere (needed for GitHub Actions)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (to download Docker, updates, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# ------------------------------------------------------------------
# APPLICATION LOAD BALANCER (The receptionist)
# ------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "ecommerce-alb"
  internal           = false          # Public-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "ecommerce-alb"
  }
}

# Target Group = the group of servers that receive traffic
resource "aws_lb_target_group" "web" {
  name     = "tg-webapps"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "tg-webapps"
  }
}

# Listener = "if someone visits port 80, send them to the target group"
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ------------------------------------------------------------------
# SSH KEY PAIR
# ------------------------------------------------------------------
# This reads your public key file and uploads it to AWS
# so you can SSH into servers using your private key
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# ------------------------------------------------------------------
# EC2 INSTANCES (The actual servers running your app)
# ------------------------------------------------------------------

# Automatically find the latest Amazon Linux 2 image
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create 2 web servers
resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"              # Free tier eligible
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # NOTE: For this student lab, we place instances in PUBLIC subnets
  # so GitHub Actions can SSH directly. In a real job, you'd use
  # private subnets + a bastion host (jump server).
  subnet_id                   = count.index == 0 ? aws_subnet.public_1.id : aws_subnet.public_2.id
  associate_public_ip_address = true

  tags = {
    Name = "EC2-Web-${count.index + 1}"
  }
}

# Connect each server to the Load Balancer
resource "aws_lb_target_group_attachment" "web" {
  count            = length(aws_instance.web)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# ------------------------------------------------------------------
# CLOUDWATCH ALARM (The CPU alarm from your diagram)
# ------------------------------------------------------------------

# SNS Topic = where alarm messages go (email notifications)
resource "aws_sns_topic" "alerts" {
  name = "cpu-alerts"
}

# Alarm for each EC2 instance
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = length(aws_instance.web)
  alarm_name          = "cpu-high-web-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"      # Check every 2 minutes
  statistic           = "Average"
  threshold           = "75"       # Fire if CPU > 75%
  alarm_description   = "Alarm when CPU exceeds 75% for 2 consecutive periods"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.web[count.index].id
  }
}

# ------------------------------------------------------------------
# OUTPUTS (These values are used by Ansible later!)
# ------------------------------------------------------------------

output "instance_public_ips" {
  description = "Public IP addresses of the web servers (for Ansible inventory)"
  value       = aws_instance.web[*].public_ip
}

output "alb_dns_name" {
  description = "The website address you paste in your browser"
  value       = aws_lb.main.dns_name
}
