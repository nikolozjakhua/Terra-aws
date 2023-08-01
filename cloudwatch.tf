resource "aws_iam_role" "rds_monitoring_role" {
  name = "RDSMonitoringRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "rds_monitoring_policy" {
  name        = "RDSMonitoringPolicy"
  description = "Policy to allow RDS to publish monitoring data to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
            "logs:*",
            "cloudwatch:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


# Attach the IAM Policy to the RDS instance role
resource "aws_iam_role_policy_attachment" "rds_monitoring_attachment" {
  policy_arn = aws_iam_policy.rds_monitoring_policy.arn
  role       = aws_iam_role.rds_monitoring_role.name
}

resource "aws_cloudwatch_dashboard" "mydashboard" {
  dashboard_name = "MyCustomDashboard"

  dashboard_body = jsonencode({
    "widgets": [
      {
        "type": "metric",
        "x": 0,
        "y": 0,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${aws_autoscaling_group.ghost_ec2_pool.name}", { "stat": "Average", "period": 300 } ]
          ],
          "region": "${var.aws_region}",
          "title": "EC2 Instance CPU"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 7,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/ECS", "CPUUtilization", "ServiceName", "${aws_ecs_service.ghost.name}", "ClusterName", "${aws_ecs_service.ghost.name}", { "stat": "Average", "period": 300 } ]
          ],
          "region": "${var.aws_region}",
          "title": "ECS CPU Utilization"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 14,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "ECS/ContainerInsights", "RunningTaskCount", "ServiceName", "${aws_ecs_service.ghost.name}", "ClusterName", "${aws_ecs_service.ghost.name}",  { "stat": "Sum", "period": 60 } ]
          ],
          "region": "${var.aws_region}",
          "title": "ECS Running Task Count"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 21,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/EFS", "ClientConnections", "FileSystemId", "${aws_efs_file_system.ghost_content.id}", { "stat": "Sum", "period": 300 } ]
          ],
          "region": "${var.aws_region}",
          "title": "EFS Client Connections"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 28,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/EFS", "TotalIOBytes", "FileSystemId", "${aws_efs_file_system.ghost_content.id}", { "stat": "Average", "period": 300 } ]
          ],
          "region": "${var.aws_region}",
          "title": "EFS Volume Bytes Used"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 35,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${aws_db_instance.ghost.identifier}", { "stat": "Sum", "period": 300 } ]
          ],
          "region": "${var.aws_region}",
          "title": "RDS Database Connections"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 42,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${aws_db_instance.ghost.identifier}", { "stat": "Average", "period": 300 } ]
          ],
          "region": "${var.aws_region}",
          "title": "RDS CPU Utilization"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 49,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", "${aws_db_instance.ghost.identifier}", { "stat": "Average", "period": 300 } ]
          ],
          "region": "${var.aws_region}",
          "title": "RDS Read IOPS"
        }
      },
      {
        "type": "metric",
        "x": 0,
        "y": 56,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            [ "AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", "${aws_db_instance.ghost.identifier}", { "stat": "Average", "period": 300 } ]
          ],
          "region": "${var.aws_region}",
          "title": "RDS Write IOPS"
        }
      },
    ]
  })
}
