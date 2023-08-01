provider "aws" {
    region = "eu-central-1"
}

### NETWORKING ###
resource "aws_vpc" "cloudx" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "cloudx"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnet_a" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.subnets.public_a
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_a"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.subnets.public_b
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_b"
  }
}

resource "aws_subnet" "subnet_c" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.subnets.public_c
  availability_zone = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_c"
  }
}

resource "aws_internet_gateway" "cloudx-igw" {
  vpc_id = aws_vpc.cloudx.id
  tags = {
    Name = "cloudx-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cloudx.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloudx-igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.subnet_c.id
  route_table_id = aws_route_table.public_rt.id
}

### SECURITY ###

resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "allows access to bastion"
  vpc_id = aws_vpc.cloudx.id

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_pool" {
  name        = "ec2_pool"
  description = "allows access to ec2 instances"
  vpc_id      = aws_vpc.cloudx.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    from_port = 2368
    to_port = 2368
    protocol = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name        = "alb"
  description = "allows access to alb"
  vpc_id      = aws_vpc.cloudx.id
}

resource "aws_security_group_rule" "http-access-for-alb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks = [var.my_ip]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "allow-access-ec2-pool" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  source_security_group_id = aws_security_group.ec2_pool.id
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "allow-access-fargate-pool" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  source_security_group_id = aws_security_group.fargate_pool.id
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group" "efs" {
  name        = "efs"
  description = "defines access to efs mount points"
  vpc_id      = aws_vpc.cloudx.id

  ingress {
    description = "NFS access"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_pool.id, aws_security_group.fargate_pool.id]
  }

  egress {
    description = "all access to vpc"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }
}

### Policies ###

resource "aws_iam_role" "ghost_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "ghost_policy" {
  name        = "ec2_policy"
  description = "allow ec2 instance efs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "ssm:GetParameter*",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ghost-attach" {
  role       = aws_iam_role.ghost_role.name
  policy_arn = aws_iam_policy.ghost_policy.arn
}

resource "aws_iam_instance_profile" "ghost-app" {
  name = "ghost_app"
  role = aws_iam_role.ghost_role.name
}

### EFS with mount target ###

resource "aws_efs_file_system" "ghost_content" {
  creation_token = "ghost_content"
  tags = {
    Name = "ghost_content"
  }
}

resource "aws_efs_mount_target" "mount-a" {
  file_system_id = aws_efs_file_system.ghost_content.id
  subnet_id      = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "mount-b" {
  file_system_id = aws_efs_file_system.ghost_content.id
  subnet_id      = aws_subnet.subnet_b.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "mount-c" {
  file_system_id = aws_efs_file_system.ghost_content.id
  subnet_id      = aws_subnet.subnet_c.id
  security_groups = [aws_security_group.efs.id]
}

### LoadBalancer ###

resource "aws_lb_target_group" "ghost-ec2" {
  name     = "ghost-ec2"
  port     = 2368
  protocol = "HTTP"
  vpc_id   = aws_vpc.cloudx.id
}

resource "aws_lb_target_group" "ghost-fargate" {
  name     = "ghost-fargate"
  port     = 2368
  protocol = "HTTP"
  vpc_id   = aws_vpc.cloudx.id

  target_type = "ip"
}

resource "aws_lb" "ghost-alb" {
  name               = "ghost-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id, aws_subnet.subnet_c.id]

  enable_deletion_protection = false

  tags = {
    Name = "ghost-alb"
  }
}

resource "aws_lb_listener" "ghost-listener" {
  load_balancer_arn = aws_lb.ghost-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.ghost-ec2.arn
      }
      target_group {
        arn = aws_lb_target_group.ghost-fargate.arn
      }
    }
  }
}

### Launch Template ASG and attach to Target Group ###

data "aws_ami" "latest-amazon-linux-image" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["amzn2-ami-kernel-*-x86_64-gp2"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_key_pair" "ssh-key" {
    key_name = "ghost-ec2-pool"
    public_key = file(var.public_key_location)
}

data "template_file" "user_data" {
  template = file("script.sh")

  vars = {
    LB_DNS_NAME = aws_lb.ghost-alb.dns_name
    DB_URL = aws_db_instance.ghost.address
    DB_USER = var.db_user
    DB_NAME = aws_db_instance.ghost.db_name
    DB_PASSWORD = aws_ssm_parameter.db_password.value
    EFS_FILE_SYSTEM = aws_efs_file_system.ghost_content.dns_name
  }
}

resource "aws_launch_template" "ghost_template" {
  name = "ghost"
  iam_instance_profile {
    name = "ghost_app"
  }
  image_id = data.aws_ami.latest-amazon-linux-image.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.ssh-key.key_name
  user_data = base64encode(data.template_file.user_data.rendered)
  network_interfaces {
    security_groups = [aws_security_group.ec2_pool.id]
    associate_public_ip_address = true
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ghost"
    }
  }
}

resource "aws_autoscaling_group" "ghost_ec2_pool" {
  name = "ghost_ec2_pool"
  vpc_zone_identifier = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id, aws_subnet.subnet_c.id]
  desired_capacity   = 3
  max_size           = 3
  min_size           = 3

  launch_template {
    id      = aws_launch_template.ghost_template.id
    version = "$Latest"
  }

  tag {
    key = "name"
    value = "ghost_ec2_pool"
    propagate_at_launch = false
  }

  depends_on = [aws_internet_gateway.cloudx-igw]
}

resource "aws_autoscaling_attachment" "asg-attach" {
  autoscaling_group_name = aws_autoscaling_group.ghost_ec2_pool.id
  lb_target_group_arn    = aws_lb_target_group.ghost-ec2.arn
}

### Bastion Instance ###

resource "aws_instance" "bastion" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.subnet_a.id
    vpc_security_group_ids = [aws_security_group.bastion.id]
    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name
    tags = {
        Name = "Bastion"
    }
}

#### Output

output "alb-dns" {
  value = aws_lb.ghost-alb.arn
}

output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "efs-dns" {
  value = aws_efs_file_system.ghost_content.id
}

