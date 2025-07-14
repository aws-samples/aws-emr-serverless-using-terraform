## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_emr_cluster" "click_logger_emr_cluster" {
  count = var.use_emr_on_ec2 ? 1 : 0
  
  name          = "${var.app_prefix}-${var.stage_name}-emr-cluster"
  release_label = "emr-6.15.0"
  applications  = ["Spark", "Hadoop"]

  termination_protection            = false
  keep_job_flow_alive_when_no_steps = true
  auto_termination_policy {
    idle_timeout = 14400  # Terminate after 4 hours of inactivity
  }
  log_uri                          = "s3://${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/emr-logs/"

  ec2_attributes {
    subnet_id                         = aws_subnet.click_logger_emr_private_subnet1.id
    emr_managed_master_security_group = aws_security_group.click_logger_emr_security_group.id
    emr_managed_slave_security_group  = aws_security_group.click_logger_emr_security_group.id
    service_access_security_group     = aws_security_group.click_logger_emr_service_security_group[0].id
    instance_profile                  = aws_iam_instance_profile.click_logger_emr_ec2_instance_profile[0].name
    key_name                          = var.ec2_key_name != "" ? var.ec2_key_name : null
  }

  master_instance_group {
    instance_type = "m4.large"
  }

  # No core instances - single node cluster for testing

  configurations_json = <<EOF
[
  {
    "Classification": "hadoop-env",
    "Configurations": [
      {
        "Classification": "export",
        "Properties": {
          "JAVA_HOME": "/usr/lib/jvm/java-1.8.0"
        }
      }
    ],
    "Properties": {}
  },
  {
    "Classification": "spark-env",
    "Configurations": [
      {
        "Classification": "export",
        "Properties": {
          "JAVA_HOME": "/usr/lib/jvm/java-1.8.0"
        }
      }
    ],
    "Properties": {}
  },
  {
    "Classification": "spark-defaults",
    "Properties": {
      "spark.eventLog.enabled": "true",
      "spark.eventLog.dir": "s3://${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/spark-logs/",
      "spark.history.fs.logDirectory": "s3://${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/spark-logs/"
    }
  }
]
EOF

  service_role = aws_iam_role.click_logger_emr_service_role[0].arn

  tags = {
    Name = "${var.app_prefix}-${var.stage_name}-emr-cluster"
  }
}

# EMR Service Role
resource "aws_iam_role" "click_logger_emr_service_role" {
  count = var.use_emr_on_ec2 ? 1 : 0
  name  = "${var.app_prefix}-${var.stage_name}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "click_logger_emr_service_role_policy" {
  count      = var.use_emr_on_ec2 ? 1 : 0
  role       = aws_iam_role.click_logger_emr_service_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

# EMR EC2 Instance Profile
resource "aws_iam_instance_profile" "click_logger_emr_ec2_instance_profile" {
  count = var.use_emr_on_ec2 ? 1 : 0
  name  = "${var.app_prefix}-${var.stage_name}-emr-ec2-instance-profile"
  role  = aws_iam_role.click_logger_emr_ec2_role[0].name
}

resource "aws_iam_role" "click_logger_emr_ec2_role" {
  count = var.use_emr_on_ec2 ? 1 : 0
  name  = "${var.app_prefix}-${var.stage_name}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "click_logger_emr_ec2_role_policy" {
  count      = var.use_emr_on_ec2 ? 1 : 0
  role       = aws_iam_role.click_logger_emr_ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# S3 Access Policy for EMR EC2 instances
resource "aws_iam_role_policy" "click_logger_emr_ec2_s3_policy" {
  count = var.use_emr_on_ec2 ? 1 : 0
  name  = "${var.app_prefix}-${var.stage_name}-emr-ec2-s3-policy"
  role  = aws_iam_role.click_logger_emr_ec2_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.arn,
          "${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.arn}/*",
          aws_s3_bucket.click_log_loggregator_output_s3_bucket.arn,
          "${aws_s3_bucket.click_log_loggregator_output_s3_bucket.arn}/*",
          aws_s3_bucket.click_log_loggregator_source_s3_bucket.arn,
          "${aws_s3_bucket.click_log_loggregator_source_s3_bucket.arn}/*"
        ]
      }
    ]
  })
}

output "emr_cluster_id" {
  value = var.use_emr_on_ec2 ? aws_emr_cluster.click_logger_emr_cluster[0].id : null
}

output "emr_cluster_logs_uri" {
  value = var.use_emr_on_ec2 ? "s3://${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/emr-logs/" : null
}

# Service Access Security Group for EMR
resource "aws_security_group" "click_logger_emr_service_security_group" {
  count       = var.use_emr_on_ec2 ? 1 : 0
  name        = "${var.app_prefix}-${var.stage_name}-emr-service-sg"
  description = "EMR Service Access Security Group"
  vpc_id      = aws_vpc.click_logger_emr_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.click_logger_emr_security_group.id]
  }

  tags = {
    Name = "${var.app_prefix}-${var.stage_name}-emr-service-sg"
  }
}

output "emr_spark_logs_uri" {
  value = var.use_emr_on_ec2 ? "s3://${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/spark-logs/" : null
}