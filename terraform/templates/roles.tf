## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  emr_app_arn = aws_emrserverless_application.click_log_loggregator_emr_serverless.arn

  glue_catalog_arn  = "arn:aws:glue:${local.region}:${local.account_id}:catalog"
  glue_database_arn = "arn:aws:glue:${local.region}:${local.account_id}:database/${aws_glue_catalog_database.aws_glue_click_logger_database.name}"
  glue_table_arn    = "arn:aws:glue:${local.region}:${local.account_id}:table/${aws_glue_catalog_database.aws_glue_click_logger_database.name}/*"
}

################################################################################
# Ingestion Lambda
################################################################################

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "click_logger_lambda_role" {
  name               = "${var.app_prefix}-${var.stage_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "click_logger_lambda_policy" {
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda_click_logger_log_group.arn}:*"]
  }

  statement {
    sid       = "PutRecordsToFirehose"
    actions   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
    resources = [aws_kinesis_firehose_delivery_stream.click_logger_firehose_delivery_stream.arn]
  }
}

resource "aws_iam_role_policy" "click_logger_lambda_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-lambda-policy"
  role   = aws_iam_role.click_logger_lambda_role.id
  policy = data.aws_iam_policy_document.click_logger_lambda_policy.json
}

################################################################################
# Amazon Data Firehose delivery role
################################################################################

data "aws_iam_policy_document" "firehose_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "click_logger_stream_consumer_firehose_role" {
  name               = "${var.app_prefix}-${var.stage_name}-stream-consumer-firehose-role"
  assume_role_policy = data.aws_iam_policy_document.firehose_trust.json
}

data "aws_iam_policy_document" "click_logger_firehose_policy" {
  statement {
    sid = "DeliverToS3"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.arn,
      "${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.arn}/*",
    ]
  }

  statement {
    sid       = "ReadGlueSchemaForParquetConversion"
    actions   = ["glue:GetTable", "glue:GetTableVersion", "glue:GetTableVersions"]
    resources = [local.glue_catalog_arn, local.glue_database_arn, local.glue_table_arn]
  }

  statement {
    sid       = "WriteDeliveryErrorLogs"
    actions   = ["logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.click_logger_firehose_delivery_stream_log_group.arn}:*"]
  }
}

resource "aws_iam_role_policy" "click_logger_stream_consumer_inline_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-stream-consumer-inline-policy"
  role   = aws_iam_role.click_logger_stream_consumer_firehose_role.id
  policy = data.aws_iam_policy_document.click_logger_firehose_policy.json
}

################################################################################
# EMR Serverless job execution role
################################################################################

data "aws_iam_policy_document" "emr_serverless_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["emr-serverless.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "click_logger_emr_serverless_role" {
  name               = "${var.app_prefix}-${var.stage_name}-emr-serverless-role"
  assume_role_policy = data.aws_iam_policy_document.emr_serverless_trust.json
}

data "aws_iam_policy_document" "click_logger_emr_serverless_policy" {
  statement {
    sid     = "ReadJobJarAndInputData"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.click_log_loggregator_source_s3_bucket.arn,
      "${aws_s3_bucket.click_log_loggregator_source_s3_bucket.arn}/*",
      aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.arn,
      "${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.arn}/*",
    ]
  }

  statement {
    sid     = "WriteOutputAndLogs"
    actions = ["s3:GetObject", "s3:ListBucket", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      aws_s3_bucket.click_log_loggregator_output_s3_bucket.arn,
      "${aws_s3_bucket.click_log_loggregator_output_s3_bucket.arn}/*",
      aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.arn,
      "${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.arn}/*",
    ]
  }

  # EMR Serverless uses the Glue Data Catalog as the Spark metastore by default and
  # looks up the "default" database when the Spark session starts.
  statement {
    sid     = "ReadGlueDataCatalog"
    actions = ["glue:GetDatabase", "glue:GetDatabases", "glue:GetTable", "glue:GetTables", "glue:GetPartition", "glue:GetPartitions"]
    resources = [
      local.glue_catalog_arn,
      local.glue_database_arn,
      local.glue_table_arn,
      "arn:aws:glue:${local.region}:${local.account_id}:database/default",
      "arn:aws:glue:${local.region}:${local.account_id}:table/default/*",
    ]
  }

  statement {
    sid       = "DescribeLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
  }

  statement {
    sid       = "WriteJobLogsToCloudWatch"
    actions   = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.click_logger_emr_serverless_log_group.arn}:*"]
  }
}

resource "aws_iam_role_policy" "click_logger_emr_serverless_inline_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-emr-serverless-policy"
  role   = aws_iam_role.click_logger_emr_serverless_role.id
  policy = data.aws_iam_policy_document.click_logger_emr_serverless_policy.json
}

################################################################################
# Step Functions execution role
################################################################################

data "aws_iam_policy_document" "sfn_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "click_logger_sfn_role" {
  name               = "${var.app_prefix}-${var.stage_name}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_trust.json
}

# Permissions for the optimized emr-serverless:startJobRun.sync integration, following
# https://docs.aws.amazon.com/step-functions/latest/dg/connect-emr-serverless.html
data "aws_iam_policy_document" "click_logger_sfn_policy" {
  statement {
    sid       = "StartJobRun"
    actions   = ["emr-serverless:StartJobRun"]
    resources = [local.emr_app_arn]
  }

  statement {
    sid       = "TrackAndCancelJobRun"
    actions   = ["emr-serverless:GetJobRun", "emr-serverless:CancelJobRun"]
    resources = ["${local.emr_app_arn}/jobruns/*"]
  }

  statement {
    sid       = "PassJobExecutionRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.click_logger_emr_serverless_role.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["emr-serverless.amazonaws.com"]
    }
  }

  statement {
    sid       = "ManagedRuleForSyncIntegration"
    actions   = ["events:PutTargets", "events:PutRule", "events:DescribeRule"]
    resources = ["arn:aws:events:${local.region}:${local.account_id}:rule/StepFunctionsGetEventsForEMRServerlessJobRule"]
  }

  # CloudWatch Logs delivery actions don't support resource-level permissions.
  statement {
    sid = "DeliverExecutionLogs"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "click_logger_sfn_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-sfn-policy"
  role   = aws_iam_role.click_logger_sfn_role.id
  policy = data.aws_iam_policy_document.click_logger_sfn_policy.json
}
