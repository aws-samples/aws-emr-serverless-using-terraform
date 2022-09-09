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
  default = "..//..//..//source//clicklogger//target//clicklogger-1.0-SNAPSHOT.jar"
}

variable "emr_source_zip_path" {
  description = "EMR lambda zip"
  default = "..//..//..//source//loggregator//target//scala-2.12//loggregator_2.12-0.1.jar"
}

variable "loggregator_jar" {
  default = "loggregator-0-0.1.jar"
}


