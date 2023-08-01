resource "aws_subnet" "private_a" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.private_subnets.private_a
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "private_a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.private_subnets.private_b
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "private_b"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.private_subnets.private_c
  availability_zone = data.aws_availability_zones.available.names[2]
  tags = {
    Name = "private_c"
  }
}

resource "aws_route_table_association" "ecs_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "ecs_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "ecs_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "fargate_pool" {
  name        = "fargate_pool"
  description = "allow access for fargate instances"
  vpc_id = aws_vpc.cloudx.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow-access-fargate-efs" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  source_security_group_id = aws_security_group.efs.id
  security_group_id = aws_security_group.fargate_pool.id
}

resource "aws_security_group_rule" "allow-endpoints" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks = [var.vpc_cidr_block]
  security_group_id = aws_security_group.fargate_pool.id
}

resource "aws_security_group_rule" "allow-access-fargate-alb" {
  type              = "ingress"
  from_port         = 2368
  to_port           = 2368
  protocol          = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id = aws_security_group.fargate_pool.id
}

#resource "aws_ecr_repository" "ghost" {
#  name                 = "ghost"
#  image_tag_mutability = "MUTABLE"
#  image_scanning_configuration {
#    scan_on_push = false
#  }
#  encryption_configuration {
#    encryption_type = "AES256"
#  }
#}

resource "aws_iam_role" "ghost_ecs" {
  name = "ghost_ecs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com",

        }
      },
    ]
  })
}

resource "aws_iam_policy" "ghost_ecs_policy" {
  name        = "ghost_ecs_policy"
  description = "allow ec2 instance efs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
            "ecr:*",
            "elasticfilesystem:*",
            "ssm:*",
            "logs:*",
            "s3:*",
            "secretsmanager:*",
            "kms:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ghost-fargate-attach" {
  role       = aws_iam_role.ghost_ecs.name
  policy_arn = aws_iam_policy.ghost_ecs_policy.arn
}


resource "aws_ecs_cluster" "ghost" {
  name = "ghost"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "task_def_ghost" {
  family                   = "task_def_ghost"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ghost_ecs.arn
  task_role_arn            = aws_iam_role.ghost_ecs.arn
  container_definitions    = templatefile("service.json", {
    DB_URL = aws_db_instance.ghost.address
    DB_USER = var.db_user
    PASS = aws_ssm_parameter.db_password.value
    DB_NAME = aws_db_instance.ghost.db_name
    ECR_IMAGE = var.ECR_IMAGE
  })

  volume {
    name = "ghost_volume"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.ghost_content.id
    }
  }
  depends_on = [aws_iam_role.ghost_ecs]
}

resource "aws_ecs_service" "ghost" {
  name            = "ghost"
  cluster         = aws_ecs_cluster.ghost.id
  task_definition = aws_ecs_task_definition.task_def_ghost.arn
  desired_count   = 3
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
    security_groups = [aws_security_group.fargate_pool.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ghost-fargate.arn
    container_name   = "ghost_container"
    container_port   = 2368
  }
}

resource "aws_vpc_endpoint" "efs" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.${var.aws_region}.elasticfilesystem"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.efs.id]
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
}

resource "aws_vpc_endpoint" "ecr" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.for-endpoints.id]
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
}

resource "aws_vpc_endpoint" "ecr-api" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.for-endpoints.id]
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.for-endpoints.id]
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type  = "Gateway"
  route_table_ids    = [aws_route_table.private_rt.id]
}

resource "aws_vpc_endpoint_route_table_association" "s3_gateway_rt_association" {
  vpc_endpoint_id    = aws_vpc_endpoint.s3_gateway.id
  route_table_id     = aws_route_table.private_rt.id 
}

resource "aws_vpc_endpoint" "cloudwatch" {
  vpc_id             = aws_vpc.cloudx.id
  service_name       = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.for-endpoints.id]
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
}

resource "aws_security_group" "for-endpoints" {
  name        = "ecr"
  description = "defines access to efs mount points"
  vpc_id      = aws_vpc.cloudx.id

  ingress {
    description = "all in vpc"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    #security_groups  = [aws_security_group.fargate_pool.id]
  }

  egress {
    description = "allow outbound traffic on port 443 (tcp)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }
}

