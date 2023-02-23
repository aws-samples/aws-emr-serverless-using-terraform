## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_lambda_function" "lambda_clicklogger_ingest" {
  description   = "Lambda to ingest data."
  filename      = var.lambda_source_zip_path
  function_name = "${var.app_prefix}-${var.stage_name}-ingestion-lambda"
  role          = aws_iam_role.click_logger_lambda_role.arn
  handler       = "com.clicklogs.Handlers.ClickLoggerHandler::handleRequest"
  runtime       = "java8"
  memory_size   = 2048
  timeout       = 300

  source_code_hash = filebase64sha256(var.lambda_source_zip_path)
  depends_on       = [
    aws_iam_role.click_logger_lambda_role, aws_kinesis_firehose_delivery_stream.click_logger_firehose_delivery_stream
  ]

  environment {
    variables = {
      STREAM_NAME = aws_kinesis_firehose_delivery_stream.click_logger_firehose_delivery_stream.name
      REGION      = data.aws_region.current.name
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.click_logger_emr_private_subnet1.id]
    security_group_ids = [aws_security_group.click_logger_emr_security_group.id]
  }
}

resource "aws_lambda_function" "lambda_clicklogger_emr_job_status" {
  description   = "Lambda to check status of job on EMR Serverless cluster."
  filename      = var.lambda_source_zip_path
  function_name = "${var.app_prefix}-${var.stage_name}-emr-job-status-lambda"
  role          = aws_iam_role.click_logger_emr_lambda_role.arn
  handler       = "com.clicklogs.Handlers.ClickLoggerEMRJobHandler::handleRequest"
  runtime       = "java8"
  memory_size   = 2048
  timeout       = 600

  source_code_hash = filebase64sha256(var.lambda_source_zip_path)
  depends_on       = [aws_iam_role.click_logger_emr_lambda_role]

  environment {
    variables = {
      APPLICATION_ID     = aws_emrserverless_application.click_log_loggregator_emr_serverless.id
      LOGS_OUTPUT_PATH   = "s3://${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}"
      REGION             = data.aws_region.current.name
      EMR_GET_SLEEP_TIME = 5000
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.click_logger_emr_private_subnet1.id]
    security_group_ids = [aws_security_group.click_logger_emr_security_group.id]
  }
}

output "lambda-clicklogger-ingest" {
  value = aws_lambda_function.lambda_clicklogger_ingest
}

output "lambda-clicklogger-emr-job" {
  value = aws_lambda_function.lambda_clicklogger_emr_job_status
}