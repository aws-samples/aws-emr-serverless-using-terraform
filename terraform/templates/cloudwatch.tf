## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_cloudwatch_log_group" "lambda_click_logger_log_group" {
  name              = "/aws/lambda/${var.app_prefix}/${aws_lambda_function.lambda_clicklogger_ingest.function_name}"
  retention_in_days = 3
  depends_on = [aws_lambda_function.lambda_clicklogger_ingest]
}

resource "aws_cloudwatch_log_group" "click_logger_firehose_delivery_stream_log_group" {
  name              = "/aws/kinesis_firehose_delivery_stream/${var.app_prefix}/${var.stage_name}/click_logger_firehose_delivery_stream"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_stream" "click_logger_firehose_delivery_stream" {
  name           = "${var.app_prefix}-${var.stage_name}-firehose-delivery-stream"
  log_group_name = aws_cloudwatch_log_group.click_logger_firehose_delivery_stream_log_group.name
}


resource "aws_cloudwatch_log_group" "lambda_clicklogger_emr_sfn_start_job_log_group" {
  name              = "/aws/state-machines/${var.app_prefix}/${var.stage_name}"
  retention_in_days = 3
}