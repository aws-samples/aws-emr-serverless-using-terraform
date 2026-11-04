## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

variable "app_prefix" {
  description = "Application prefix for the AWS services that are built"
  default     = "clicklogger"
}

variable "stage_name" {
  default = "dev"
}

variable "lambda_source_zip_path" {
  description = "Path to the packaged ingestion Lambda jar"
}

variable "emr_source_zip_path" {
  description = "Path to the packaged Loggregator Spark job jar"
}

variable "loggregator_jar" {
  description = "S3 object key for the Loggregator Spark job jar"
  default     = "loggregator-0-0.1.jar"
}

variable "emr_release_label" {
  description = "Amazon EMR release label for the EMR Serverless application"
  default     = "emr-7.14.0"
}

variable "emr_job_timeout_minutes" {
  description = "Maximum run time for a single EMR Serverless job run"
  default     = 60
}

variable "log_retention_days" {
  description = "Retention for CloudWatch log groups created by this sample"
  default     = 7
}
