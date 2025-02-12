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
  region  = var.aws_region
  profile = var.aws_profile
}

# Generate SSH Key Pair
resource "aws_key_pair" "ecs_key" {
  key_name   = "ecs-key"
  public_key = file("my-ecs-key.pub") # Ensure you have this file generated
}