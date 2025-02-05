resource "aws_ecs_cluster" "python_cluster" {
  name = "python-ecs-cluster"
}

resource "aws_ecs_task_definition" "python_task" {
  family                   = "python-http-server"
  requires_compatibilities = ["EC2"] # Change from "FARGATE" to "EC2"
  network_mode             = "bridge"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "python-server"
      image     = "python:3"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
      }]
      command = ["python", "-m", "http.server", tostring(var.container_port)]
    }
  ])
}

resource "aws_ecs_service" "python_service" {
  name            = "python-http-service"
  cluster         = aws_ecs_cluster.python_cluster.id
  task_definition = aws_ecs_task_definition.python_task.arn
  launch_type     = "EC2" # Change from "FARGATE" to "EC2"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.python_tg.arn
    container_name   = "python-server"
    container_port   = var.container_port
  }
}