## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_lambda_function" "lambda_clicklogger_ingest" {
  description   = "Lambda to ingest click logs into Amazon Data Firehose."
  filename      = var.lambda_source_zip_path
  function_name = "${var.app_prefix}-${var.stage_name}-ingestion-lambda"
  role          = aws_iam_role.click_logger_lambda_role.arn
  handler       = "com.clicklogs.Handlers.ClickLoggerHandler::handleRequest"
  runtime       = "java21"
  architectures = ["arm64"]
  memory_size   = 1024
  timeout       = 30

  source_code_hash = filebase64sha256(var.lambda_source_zip_path)

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.lambda_click_logger_log_group.name
  }

  environment {
    variables = {
      STREAM_NAME = aws_kinesis_firehose_delivery_stream.click_logger_firehose_delivery_stream.name
    }
  }
}

output "lambda-clicklogger-ingest" {
  value = aws_lambda_function.lambda_clicklogger_ingest.function_name
}
