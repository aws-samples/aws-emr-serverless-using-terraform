## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_emr_studio" "clicklog_dev_studio" {
  auth_mode                   = "IAM"
  default_s3_location         = "s3://${aws_s3_bucket.click_logger_emr_studio_bucket.bucket}/clicklogger"
  engine_security_group_id    = aws_security_group.click_logger_emr_security_group.id
  name                        = "${var.app_prefix}-${var.stage_name}-studio"
  service_role                = aws_iam_role.emr_studio_role.arn
  subnet_ids                  = [aws_subnet.click_logger_emr_public_subnet1.id]
  vpc_id                      = aws_vpc.click_logger_emr_vpc.id
  workspace_security_group_id = aws_security_group.click_logger_emr_security_group.id
}


resource "aws_emrserverless_application" "click_log_loggregator_emr_serverless" {
  name          = "${var.app_prefix}-${var.stage_name}-loggregrator-emr-${data.aws_caller_identity.current.account_id}"
  release_label = "emr-6.6.0"
  type          = "spark"

  initial_capacity {
    initial_capacity_type = "Driver"

    initial_capacity_config {
      worker_count = 5
      worker_configuration {
        cpu    = "4 vCPU"
        memory = "20 GB"
      }
    }
  }

  initial_capacity {
    initial_capacity_type = "Executor"

    initial_capacity_config {
      worker_count = 5
      worker_configuration {
        cpu    = "4 vCPU"
        memory = "20 GB"
      }
    }
  }

  maximum_capacity {
    cpu    = "150 vCPU"
    memory = "1000 GB"
  }

  tags = {
    Name        = "EMR Serverless for ClickLogs Aggregation"
    Environment = var.stage_name
  }
}