output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_1_id" {
  description = "The ID of the first public subnet"
  value       = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  description = "The ID of the second public subnet"
  value       = aws_subnet.public_2.id
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.ecs_cluster.name
}

output "ecs_instance_id_1" {
  description = "The ID of the ECS EC2 instance 1"
  value       = aws_instance.ecs_instance_1.id
}

output "ecs_instance_public_ip_1" {
  description = "The public IP address of the ECS EC2 instance 1"
  value       = aws_instance.ecs_instance_1.public_ip
}

output "ecs_instance_id_2" {
  description = "The ID of the ECS EC2 instance 2"
  value       = aws_instance.ecs_instance_2.id
}

output "ecs_instance_public_ip_2" {
  description = "The public IP address of the ECS EC2 instance 2"
  value       = aws_instance.ecs_instance_2.public_ip
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.ecs_alb.dns_name
}
