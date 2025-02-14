# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.ecs_cluster_name
}

# EC2 Instance for ECS
data "aws_ssm_parameter" "ecs_ami" {
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

######## app 1
resource "aws_instance" "ecs_instance_1" {
  ami           = data.aws_ssm_parameter.ecs_ami.value 
  instance_type = var.ecs_instance_type
  subnet_id     = aws_subnet.private_az1.id
  security_groups = [aws_security_group.ecs_sg.id] #???
  key_name      = aws_key_pair.ecs_key.key_name
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name}" >> /etc/ecs/ecs.config
              EOF

  tags = {
    Name = "ecs-ec2-instance-1"
  }
}

# do we need 2 of this and attache to the private ALB?
# Register EC2 Instance in ALB Target Group
resource "aws_lb_target_group_attachment" "ecs_tg_attachment_1" {
  target_group_arn = aws_lb_target_group.tg_app1.arn
  target_id        = aws_instance.ecs_instance_1.id
  port            = 80
}

# ECS Task Definition
resource "aws_ecs_task_definition" "web-1" {
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
resource "aws_ecs_service" "web_service-1" {
  name            = "web-service-1"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.web-1.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_app1.arn
    container_name   = "web"
    container_port   = 80
  }

  depends_on = [aws_lb.alb_int_1, aws_instance.ecs_instance_1]
}

######## app 2
resource "aws_instance" "ecs_instance_2" {
  ami           = data.aws_ssm_parameter.ecs_ami.value 
  instance_type = var.ecs_instance_type
  subnet_id     = aws_subnet.private_az2.id
  security_groups = [aws_security_group.ecs_sg.id] #???
  key_name      = aws_key_pair.ecs_key.key_name
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name}" >> /etc/ecs/ecs.config
              EOF

  tags = {
    Name = "ecs-ec2-instance-2"
  }
}

# Register EC2 Instance in ALB Target Group
resource "aws_lb_target_group_attachment" "ecs_tg_attachment_2" {
  target_group_arn = aws_lb_target_group.tg_app2.arn
  target_id        = aws_instance.ecs_instance_2.id
  port            = 80
}

# ECS Task Definition
resource "aws_ecs_task_definition" "web-2" {
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

resource "aws_ecs_service" "web_service-2" {
  name            = "web-service-2"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.web-2.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_app2.arn
    container_name   = "web"
    container_port   = 80
  }

  depends_on = [aws_lb.alb_int_2, aws_instance.ecs_instance_2]
}
