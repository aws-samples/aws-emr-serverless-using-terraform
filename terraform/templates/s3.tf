## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_s3_bucket" "click_log_loggregator_source_s3_bucket" {
  bucket = "${data.aws_region.current.region}-${var.app_prefix}-${var.stage_name}-loggregator-source-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Loggregator Source S3 Delivery bucket"
  }
}


resource "aws_s3_object" "click_log_loggregator_source_s3_bucket_object" {
  bucket = aws_s3_bucket.click_log_loggregator_source_s3_bucket.bucket

  key    = var.loggregator_jar
  source = var.emr_source_zip_path
  etag   = filemd5(var.emr_source_zip_path)
}


resource "aws_s3_bucket" "click_log_loggregator_output_s3_bucket" {
  bucket = "${data.aws_region.current.region}-${var.app_prefix}-${var.stage_name}-loggregator-output-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Loggregator Output S3 Delivery bucket"
  }
}

resource "aws_s3_bucket" "click_log_loggregator_emr_serverless_logs_s3_bucket" {
  bucket = "${data.aws_region.current.region}-${var.app_prefix}-${var.stage_name}-emr-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Loggregator EMR Logs S3 Delivery bucket"
  }
}


resource "aws_s3_bucket" "click_logger_firehose_delivery_s3_bucket" {
  bucket = "${data.aws_region.current.region}-${var.app_prefix}-${var.stage_name}-firehose-delivery-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Firehose S3 Delivery bucket"
  }
}

output "S3FirehoseDeliveryBucket" {
  value = aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.id
}

output "S3EMRSourceBucket" {
  value = aws_s3_bucket.click_log_loggregator_source_s3_bucket.id
}

output "S3OutputBucket" {
  value = aws_s3_bucket.click_log_loggregator_output_s3_bucket.id
}
