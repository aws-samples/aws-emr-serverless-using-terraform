## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_iam_policy" "click_loggerlambda_logging_policy" {
  name = "${var.app_prefix}-${var.stage_name}-lambda-logging-policy"
  path = "/"
  description = "IAM policy for logging from a lambda"

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
      "Action": [
        "firehose:*"
      ],
      "Resource": "${aws_kinesis_firehose_delivery_stream.click_logger_firehose_delivery_stream.arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = aws_iam_role.click_logger_lambda_role.name
  policy_arn = aws_iam_policy.click_loggerlambda_logging_policy.arn
}
