## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_emrserverless_application" "click_log_loggregator_emr_serverless" {
  name          = "${var.app_prefix}-${var.stage_name}-loggregrator-emr-${data.aws_caller_identity.current.account_id}"
  release_label = var.emr_release_label
  type          = "spark"

  # Graviton (arm64) workers offer better price-performance than x86_64 for JVM workloads.
  architecture = "ARM64"

  # The application starts automatically when a job is submitted and stops after it has
  # been idle, so no Lambda or workflow step is needed to start or stop it.
  auto_start_configuration {
    enabled = true
  }

  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = 5
  }

  # No pre-initialized capacity: workers are provisioned on demand and you pay only while
  # the job runs. Add an initial_capacity block if you need sub-second job start times.

  maximum_capacity {
    cpu    = "32 vCPU"
    memory = "128 GB"
    disk   = "1000 GB"
  }

  tags = {
    Name = "EMR Serverless for ClickLogs Aggregation"
  }
}

output "EMRServerlessApplicationId" {
  value = aws_emrserverless_application.click_log_loggregator_emr_serverless.id
}
