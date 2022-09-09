## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

variable "app_prefix" {
  description = "Application prefix for the AWS services that are built"
  default = "clicklogger"
}

variable "stage_name" {
  default = "dev"
}

variable "lambda_source_zip_path" {
  description = "Java lambda zip"
}

variable "emr_source_zip_path" {
  description = "EMR lambda zip"
}

variable "loggregator_jar" {
  default = "loggregator-0-0.1.jar"
}


