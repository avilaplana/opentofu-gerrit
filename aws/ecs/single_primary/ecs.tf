# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.ecs_cluster_name
}

# EC2 Instance for ECS
data "aws_ssm_parameter" "ecs_ami" {
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_instance" "ecs_instance" {
  ami           = data.aws_ssm_parameter.ecs_ami.value 
  instance_type = var.ecs_instance_type
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
