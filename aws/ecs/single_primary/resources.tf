terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.4.0"
}

provider "aws" {
  region = "eu-west-1"
  profile = "aws-personal"
}

# Generate SSH Key Pair
resource "aws_key_pair" "ecs_key" {
  key_name   = "ecs-key"
  public_key = file("my-ecs-key.pub") # Ensure you have this file generated
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ecs-vpc"
  }
}

# Public Subnet 1 (AZ: eu-west-1a)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"  
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1a" 

  tags = {
    Name = "ecs-public-subnet-1"
  }
}

# Public Subnet 2 (AZ: eu-west-1b) - 🔹 Change CIDR to avoid conflict
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"  
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1b"  

  tags = {
    Name = "ecs-public-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ecs-igw"
  }
}

# Route Table & Association
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for ECS
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Limit this to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for ECS EC2
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"
}

# Application Load Balancer (ALB)
resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# ALB Target Group
resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
}

# ALB Listener
resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

# EC2 Instance for ECS
data "aws_ssm_parameter" "ecs_ami" {
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_instance" "ecs_instance" {
  ami           = data.aws_ssm_parameter.ecs_ami.value 
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_1.id
  security_groups = [aws_security_group.ecs_sg.id]
  key_name      = aws_key_pair.ecs_key.key_name
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name}" >> /etc/ecs/ecs.config
              EOF

  tags = {
    Name = "ecs-ec2-instance"
  }
}

# Register EC2 Instance in ALB Target Group
resource "aws_lb_target_group_attachment" "ecs_tg_attachment" {
  target_group_arn = aws_lb_target_group.ecs_tg.arn
  target_id        = aws_instance.ecs_instance.id
  port            = 80
}

# ECS Task Definition
resource "aws_ecs_task_definition" "web" {
  family                   = "web"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = "nginx"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "web_service" {
  name            = "web-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  launch_type     = "EC2"

  depends_on = [aws_lb.ecs_alb, aws_instance.ecs_instance]
}

# Output ALB DNS Name
output "alb_dns_name" {
  value = aws_lb.ecs_alb.dns_name
}
