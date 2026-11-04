## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_cloudwatch_log_group" "lambda_click_logger_log_group" {
  name              = "/aws/lambda/${var.app_prefix}-${var.stage_name}-ingestion-lambda"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "click_logger_firehose_delivery_stream_log_group" {
  name              = "/aws/kinesisfirehose/${var.app_prefix}-${var.stage_name}-firehose-delivery-stream"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_stream" "click_logger_firehose_delivery_stream" {
  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.click_logger_firehose_delivery_stream_log_group.name
}

resource "aws_cloudwatch_log_group" "click_logger_emr_serverless_log_group" {
  name              = "/aws/emr-serverless/${var.app_prefix}-${var.stage_name}"
  retention_in_days = var.log_retention_days
}

# Step Functions log groups use the /aws/vendedlogs/ prefix so that CloudWatch Logs
# resource policies don't hit their size limit as more state machines are added.
resource "aws_cloudwatch_log_group" "click_logger_sfn_log_group" {
  name              = "/aws/vendedlogs/states/${var.app_prefix}-${var.stage_name}-state-machine"
  retention_in_days = var.log_retention_days
}
