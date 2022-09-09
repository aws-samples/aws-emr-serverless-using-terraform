## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

data "aws_iam_policy_document" "AWSLambdaTrustPolicy" {
  statement {
    actions    = ["sts:AssumeRole"]
    effect     = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "click_logger_emr_lambda_role" {
  name = "${var.app_prefix}-${var.stage_name}-lambda-emr-role"
  assume_role_policy = data.aws_iam_policy_document.AWSLambdaTrustPolicy.json
}

resource "aws_iam_role_policy_attachment" "click_logger_emr_lambda_policy" {
  role       = aws_iam_role.click_logger_emr_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "click_logger_emr_lambda_iam_role_policy_attachment_vpc_access_execution" {
  role       = aws_iam_role.click_logger_emr_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "click_logger_emr_lambda_inline_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-emr-lambda-inline_policy"
  role   = aws_iam_role.click_logger_emr_lambda_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:PassRole"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "emr-serverless:CreateApplication",
        "emr-serverless:StopApplication",
        "emr-serverless:GetApplication",
        "emr-serverless:GetJobRun",
        "emr-serverless:StartJobRun",
        "emr-serverless:StartApplication"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "click_logger_lambda_role" {
  name = "${var.app_prefix}-${var.stage_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.AWSLambdaTrustPolicy.json
}

# resource "aws_iam_role_policy_attachment" "click_loggerlambda_policy" {
#   role       = aws_iam_role.click_logger_lambda_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }

resource "aws_iam_role_policy_attachment" "click_logger_lambda_iam_role_policy_attachment_vpc_access_execution" {
  role       = aws_iam_role.click_logger_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "click_logger_stream_consumer_firehose_role" {
  name = "${var.app_prefix}-${var.stage_name}-stream-consumer-firehose-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "click_logger_stream_consumer_inline_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-stream-consumer-inline_policy"
  role   = aws_iam_role.click_logger_stream_consumer_firehose_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadAccessForEMRSamples",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::*.elasticmapreduce",
                "arn:aws:s3:::*.elasticmapreduce/*"
            ]
        },
        {
            "Sid": "FullAccessToOutputBucket",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_source_s3_bucket.id}",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_source_s3_bucket.id}/*",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_output_s3_bucket.id}",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_output_s3_bucket.id}/*",
                "arn:aws:s3:::${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.id}",
                "arn:aws:s3:::${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.id}/*",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/*"
            ]
        },
        {
            "Sid": "GlueCreateAndReadDataCatalog",
            "Effect": "Allow",
            "Action": [
                "glue:GetDatabase",
                "glue:CreateDatabase",
                "glue:GetDataBases",
                "glue:CreateTable",
                "glue:GetTable",
                "glue:UpdateTable",
                "glue:DeleteTable",
                "glue:GetTables",
                "glue:GetPartition",
                "glue:GetPartitions",
                "glue:CreatePartition",
                "glue:BatchCreatePartition",
                "glue:GetUserDefinedFunctions"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
}

data "aws_iam_policy_document" "click_logger_emr_s3_and_glue_inline_policy" {
  statement {
    actions    = ["sts:AssumeRole"]
    effect     = "Allow"
    principals {
      type        = "Service"
      identifiers = ["emr-serverless.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "click_logger_emr_serverless_role" {
  name = "${var.app_prefix}-${var.stage_name}-emr-serverless-role"
  assume_role_policy = data.aws_iam_policy_document.click_logger_emr_s3_and_glue_inline_policy.json
}

resource "aws_iam_role_policy" "click_logger_emr_serverless_inline_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-emr-s3-glue-inline_policy"
  role   = aws_iam_role.click_logger_emr_serverless_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadAccessForEMRSamples",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::*.elasticmapreduce",
                "arn:aws:s3:::*.elasticmapreduce/*"
            ]
        },
        {
            "Sid": "FullAccessToOutputBucket",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_source_s3_bucket.id}",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_source_s3_bucket.id}/*",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_output_s3_bucket.id}",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_output_s3_bucket.id}/*",
                "arn:aws:s3:::${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.id}",
                "arn:aws:s3:::${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.id}/*",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}",
                "arn:aws:s3:::${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/*"
            ]
        },
        {
            "Sid": "GlueCreateAndReadDataCatalog",
            "Effect": "Allow",
            "Action": [
                "glue:GetDatabase",
                "glue:CreateDatabase",
                "glue:GetDataBases",
                "glue:CreateTable",
                "glue:GetTable",
                "glue:UpdateTable",
                "glue:DeleteTable",
                "glue:GetTables",
                "glue:GetPartition",
                "glue:GetPartitions",
                "glue:CreatePartition",
                "glue:BatchCreatePartition",
                "glue:GetUserDefinedFunctions"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
}


data "aws_iam_policy_document" "lambda_clicklogger_emr_sfn_start_job_policy" {
  statement {
    actions    = ["sts:AssumeRole"]
    effect     = "Allow"
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "lambda_clicklogger_emr_sfn_start_job_role" {
  name = "${var.app_prefix}-${var.stage_name}-sfn-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_clicklogger_emr_sfn_start_job_policy.json
}

resource "aws_iam_role_policy_attachment" "click_logger_emr_sfn_lambda_iam_role_policy_attachment_vpc_access_execution" {
  role       = aws_iam_role.lambda_clicklogger_emr_sfn_start_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_clicklogger_emr_sfn_start_job_inline_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-emr-lambda-inline_policy"
  role   = aws_iam_role.lambda_clicklogger_emr_sfn_start_job_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
          "Action": [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": "arn:aws:logs:*:*:*",
          "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "${aws_lambda_function.lambda_clicklogger_emr_start_job.arn}"
            ]
        }
    ]
}
EOF
}

// Role for EMR Studio
data "aws_iam_policy_document" "emr_studio_policy_doc" {
  statement {
    actions    = ["sts:AssumeRole"]
    effect     = "Allow"
    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "emr_studio_role" {
  name = "${var.app_prefix}-${var.stage_name}-emr-studio-role"
  assume_role_policy = data.aws_iam_policy_document.emr_studio_policy_doc.json
}

resource "aws_iam_role_policy" "emr_studio_policy" {
  name   = "${var.app_prefix}-${var.stage_name}-emr-studio-policy"
  role   = aws_iam_role.emr_studio_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CancelSpotInstanceRequests",
                "ec2:CreateFleet",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateNetworkInterface",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:DeleteLaunchTemplate",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteTags",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeDhcpOptions",
                "ec2:DescribeImages",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeInstances",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeNetworkAcls",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribePrefixLists",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSpotInstanceRequests",
                "ec2:DescribeSpotPriceHistory",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeVpcEndpointServices",
                "ec2:DescribeVpcs",
                "ec2:DetachNetworkInterface",
                "ec2:ModifyImageAttribute",
                "ec2:ModifyInstanceAttribute",
                "ec2:RequestSpotInstances",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:RunInstances",
                "ec2:TerminateInstances",
                "ec2:DeleteVolume",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "iam:GetRole",
                "iam:GetRolePolicy",
                "iam:ListInstanceProfiles",
                "iam:ListRolePolicies",
                "iam:PassRole",
                "s3:CreateBucket",
                "s3:Get*",
                "s3:List*",
                "s3:Put*",
                "sdb:BatchPutAttributes",
                "sdb:Select",
                "sqs:CreateQueue",
                "sqs:Delete*",
                "sqs:GetQueue*",
                "sqs:PurgeQueue",
                "sqs:ReceiveMessage",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:DeleteAlarms",
                "application-autoscaling:RegisterScalableTarget",
                "application-autoscaling:DeregisterScalableTarget",
                "application-autoscaling:PutScalingPolicy",
                "application-autoscaling:DeleteScalingPolicy",
                "application-autoscaling:Describe*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot*",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": "spot.amazonaws.com"
                }
            }
        }
    ]
}
EOF
}

