provider "aws" {
  region = "ap-south-1" 
}


resource "aws_ecs_cluster" "learn_urdu_cluster" {
  name = "learn_urdu-cluster"
}

# Add more resources like ECS task definitions, services, etc.
