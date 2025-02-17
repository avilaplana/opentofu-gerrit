terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
  profile = "aws-personal"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Add an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-1a"
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-1b"
}

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

resource "aws_security_group" "private_alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.private_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "public_alb" {
  name               = "public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb" "private_alb_1" {
  name               = "private-alb-1"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.private_alb_sg.id]
  subnets            = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

resource "aws_lb" "private_alb_2" {
  name               = "private-alb-2"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.private_alb_sg.id]
  subnets            = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

resource "aws_lb_target_group" "internal_tg_1" {
  name     = "internal-tg-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group" "internal_tg_2" {
  name     = "internal-tg-2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "public_alb_listener" {
  load_balancer_arn = aws_lb.public_alb.arn
  port             = 80
  protocol        = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Default action"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "public_alb_rule_1" {
  listener_arn = aws_lb_listener.public_alb_listener.arn
  priority     = 1

  action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.private_alb_1_tg.arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/path1/*"]
    }
  }
}

resource "aws_lb_listener_rule" "public_alb_rule_2" {
  listener_arn = aws_lb_listener.public_alb_listener.arn
  priority     = 2

  action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.private_alb_2_tg.arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/path2/*"]
    }
  }
}

resource "aws_lb_target_group" "private_alb_1_tg" {
  name     = "private-alb-1-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip" # Since ALBs don’t register as "instance", use "ip"
}

resource "aws_lb_target_group_attachment" "internal_alb_1_attach" {
  target_group_arn = aws_lb_target_group.private_alb_1_tg.arn
  target_id        = aws_lb.private_alb_1.dns_name # Use the ALB's DNS/IP
  port            = 80
}

resource "aws_lb_target_group" "private_alb_2_tg" {
  name     = "private-alb-2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip" # Since ALBs don’t register as "instance", use "ip"  
}

resource "aws_lb_target_group_attachment" "internal_alb_2_attach" {
  target_group_arn = aws_lb_target_group.private_alb_2_tg.arn
  target_id        = aws_lb.private_alb_2.dns_name # Use the ALB's DNS/IP
  port            = 80
}

resource "aws_lb_listener" "private_alb_1_listener" {
  load_balancer_arn = aws_lb.private_alb_1.arn
  port             = 80
  protocol        = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_tg_1.arn
  }
}

resource "aws_lb_listener" "private_alb_2_listener" {
  load_balancer_arn = aws_lb.private_alb_2.arn
  port             = 80
  protocol        = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_tg_2.arn
  }
}

resource "aws_instance" "nginx_1" {
  ami           = "ami-08a28be5eae6c1d68"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_1.id
  security_groups = [aws_security_group.ec2_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              yum install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF
}

resource "aws_instance" "nginx_2" {
  ami           = "ami-08a28be5eae6c1d68"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_2.id
  security_groups = [aws_security_group.ec2_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              yum install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF
}

resource "aws_lb_target_group_attachment" "nginx_1_attach" {
  target_group_arn = aws_lb_target_group.internal_tg_1.arn
  target_id        = aws_instance.nginx_1.id
  port            = 80
}

resource "aws_lb_target_group_attachment" "nginx_2_attach" {
  target_group_arn = aws_lb_target_group.internal_tg_2.arn
  target_id        = aws_instance.nginx_2.id
  port            = 80
}
