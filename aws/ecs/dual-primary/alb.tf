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
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.tg_app1.arn
        weight = 50
      }
      target_group {
        arn    = aws_lb_target_group.tg_app2.arn
        weight = 50
      }
    }
  }
}

# Internal ALB for App1 (alb-int-1)
resource "aws_lb" "alb_int_1" {
  name               = "alb-int-1"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
}

# Target Group for App1 (handled by alb-int-1)
resource "aws_lb_target_group" "tg_app1" {
  name        = "tg-app1"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
}

# Listener for alb-int-2 (Routes traffic to App2)
resource "aws_lb_listener" "listener_int_1" {
  load_balancer_arn = aws_lb.alb_int_1.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_app1.arn
  }
}


# Internal ALB for App2 (alb-int-2)
resource "aws_lb" "alb_int_2" {
  name               = "alb-int-2"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
}

# Target Group for App2 (handled by alb-int-2)
resource "aws_lb_target_group" "tg_app2" {
  name        = "tg-app2"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
}

# Listener for alb-int-2 (Routes traffic to App2)
resource "aws_lb_listener" "listener_int_2" {
  load_balancer_arn = aws_lb.alb_int_2.arn
  port              = 9090
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_app2.arn
  }
}


