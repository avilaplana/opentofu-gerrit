# Application Load Balancer (ALB)  
resource "aws_lb" "python_alb" {
  name               = "python-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "python_tg" {
  name        = "python-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = var.container_port
    interval            = 30  # Interval in seconds between health checks
    timeout             = 5   # Timeout for each health check
    healthy_threshold   = 3   # The number of successful health checks before considering it healthy
    unhealthy_threshold = 3   # The number of failed health checks before considering it unhealthy
  }  
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.python_alb.arn
  port              = var.from_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.python_tg.arn
  }
}
