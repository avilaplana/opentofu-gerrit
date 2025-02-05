# Input variables  
variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "Public subnets CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "ecs_task_cpu" {
  description = "ECS Task CPU units"
  default     = "256"
}

variable "ecs_task_memory" {
  description = "ECS Task Memory in MB"
  default     = "512"
}

variable "from_port" {
  description = "External port to the ALB"
  default     = 80
}

variable "container_port" {
  description = "Port for the Python HTTP server"
  default     = 8080
}

variable "profile" {
  description = "AWS profile to use"
  type        = string
}

