# ECS and ECR setup to deploy Django (Learn_Urdu) using Terraform

provider "aws" {
  region = "ap-south-1"
}

# ECR Repository
resource "aws_ecr_repository" "learn_urdu" {
  name = "learn_urdu"

  lifecycle {
    prevent_destroy = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "learn_urdu_cluster" {
  name = "learn_urdu-cluster"

  # Ignore changes to the cluster name to avoid conflicts with existing clusters
  lifecycle {
    ignore_changes = [name]
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Definition
resource "aws_ecs_task_definition" "learn_urdu_task" {
  family                   = "learn_urdu-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "learn_urdu"
      image     = "${aws_ecr_repository.learn_urdu.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
    }
  ])

  # Ignore changes to the task definition family to avoid conflicts
  lifecycle {
    ignore_changes = [family]
  }
}

# VPC, Subnets and Security Group
# Using default VPC for simplicity

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "learn_urdu_sg" {
  name        = "learn_urdu_sg"
  description = "Allow inbound access on port 8000"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    # prevent_destroy = true
  }
}

# ECS Service
resource "aws_ecs_service" "learn_urdu_service" {
  name            = "learn_urdu-service"
  cluster         = aws_ecs_cluster.learn_urdu_cluster.id
  task_definition = aws_ecs_task_definition.learn_urdu_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.learn_urdu_sg.id]
    assign_public_ip = true
  }

  # Ignore changes to the service name to avoid conflicts
  lifecycle {
    ignore_changes = [name]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy
  ]
}
