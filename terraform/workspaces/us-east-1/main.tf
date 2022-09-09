## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

module "clicklogger" {
  source = "../../templates"
  app_prefix = var.app_prefix
  stage_name = var.stage_name
  lambda_source_zip_path = var.lambda_source_zip_path
  emr_source_zip_path = var.emr_source_zip_path
  loggregator_jar = var.loggregator_jar
}
