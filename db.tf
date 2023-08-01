### DB Configuration Subnets,RT, Secgroup and Instance with Random Password ###

resource "aws_subnet" "private_db_a" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.db_subnets.private_db_a
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "private_db_a"
  }
}

resource "aws_subnet" "private_db_b" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.db_subnets.private_db_b
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "private_db_b"
  }
}

resource "aws_subnet" "private_db_c" {
  vpc_id     = aws_vpc.cloudx.id
  cidr_block = var.db_subnets.private_db_c
  availability_zone = data.aws_availability_zones.available.names[2]
  tags = {
    Name = "private_db_c"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.cloudx.id
  
  tags = {
    Name = "private_rt"
  }
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.private_db_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.private_db_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "db_c" {
  subnet_id      = aws_subnet.private_db_c.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "mysql" {
  name        = "mysql"
  description = "defines access to ghost db"
  vpc_id = aws_vpc.cloudx.id

  ingress {
    description = "ssh access"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_pool.id, aws_security_group.fargate_pool.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "db_group" {
  name       = "ghost"
  description = "ghost database subnet group"
  subnet_ids = [aws_subnet.private_db_a.id, aws_subnet.private_db_b.id, aws_subnet.private_db_c.id]

  tags = {
    Name = "ghost"
  }
}

resource "aws_db_instance" "ghost" {
  allocated_storage             = 20
  storage_type                  = "gp2"
  db_name                       = "ghost"
  engine                        = "mysql"
  engine_version                = "8.0"
  instance_class                = "db.t2.micro"
  username                      = var.db_user
  password                      = aws_ssm_parameter.db_password.value
  db_subnet_group_name          = aws_db_subnet_group.db_group.name
  vpc_security_group_ids        = [aws_security_group.mysql.id]
  skip_final_snapshot           = true
  iam_database_authentication_enabled = true
  monitoring_interval                 = 60
  monitoring_role_arn                 = aws_iam_role.rds_monitoring_role.arn
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "db_password" {
  name      = "/ghost/dbpassw"
  type      = "SecureString"
  value     = random_password.db_password.result
}

