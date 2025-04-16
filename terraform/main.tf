# Specify the AWS provider and region
provider "aws" {
  region = var.region
}

# ECR Repository to store Docker images
resource "aws_ecr_repository" "learn_urdu_repo" {
  name = "${var.project_name}-repo"
}

# ECS Cluster to manage containers
resource "aws_ecs_cluster" "learn_urdu_cluster" {
  name = "${var.project_name}-cluster"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition for the Django app
resource "aws_ecs_task_definition" "learn_urdu_task" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # Minimal CPU to keep costs low
  memory                   = "512"  # Minimal memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container"
      image     = "${aws_ecr_repository.learn_urdu_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
    }
  ])
}

# Minimal VPC for ECS (cost-effective)
resource "aws_vpc" "learn_urdu_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "learn_urdu_subnet" {
  count             = 2
  vpc_id            = aws_vpc.learn_urdu_vpc.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_internet_gateway" "learn_urdu_igw" {
  vpc_id = aws_vpc.learn_urdu_vpc.id
}

resource "aws_route_table" "learn_urdu_rt" {
  vpc_id = aws_vpc.learn_urdu_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.learn_urdu_igw.id
  }
}

resource "aws_route_table_association" "learn_urdu_rta" {
  count          = 2
  subnet_id      = aws_subnet.learn_urdu_subnet[count.index].id
  route_table_id = aws_route_table.learn_urdu_rt.id
}

data "aws_availability_zones" "available" {}

# Security Group to allow HTTP traffic
resource "aws_security_group" "learn_urdu_sg" {
  vpc_id = aws_vpc.learn_urdu_vpc.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow public access (for learning)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Service to run the Django app
resource "aws_ecs_service" "learn_urdu_service" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.learn_urdu_cluster.id
  task_definition = aws_ecs_task_definition.learn_urdu_task.arn
  desired_count   = 1  # Single task to minimize costs
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.learn_urdu_subnet[*].id
    security_groups  = [aws_security_group.learn_urdu_sg.id]
    assign_public_ip = true  # Required for Fargate with public access
  }
}

# Outputs for easy reference
output "ecr_repository_url" {
  value = aws_ecr_repository.learn_urdu_repo.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.learn_urdu_cluster.name
}