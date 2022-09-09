## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "${var.app_prefix}-${var.stage_name}-state-machine"
  role_arn = aws_iam_role.lambda_clicklogger_emr_sfn_start_job_role.arn

  definition = <<EOF
{
  "Comment": "Start EMR Serverless Job using an AWS Lambda Function",
  "StartAt": "StartEMRServerlessJob",
  "States": {
    "StartEMRServerlessJob": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lambda_clicklogger_emr_start_job.arn}",
        "Payload": {}
      },
      "Next": "Success",
      "Retry": [
          {
          "ErrorEquals": [
              "function.MaxDepthError",
              "function.MaxDepthError",
              "Lambda.TooManyRequestsException",
              "Lambda.ServiceException",
              "Lambda.Unknown"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 2
          }
      ],
      "Catch": [
            {
              "ErrorEquals": [
                  "com.clicklogs.model.ClickLoggerException"
                ],
                "Next": "CaughtException"
            },
            {
              "ErrorEquals": [
                  "States.ALL"
                ],
                "Next": "UncaughtException"
            }
        ],
        "Next": "Success"
      },
      "CaughtException": {
        "Type": "Pass",
        "Result": "The function returned an error.",
        "Next": "Failure"
      },
      "UncaughtException": {
        "Type": "Pass",
        "Result": "Invocation failed.",
        "Next": "Failure"
      },
      "Success": {
        "Type": "Pass",
        "Result": "Invocation succeeded!",
        "End": true
      },
      "Failure": {
        "Type": "Fail",
        "Cause": "Execution Failed!"
      }
    }
}
EOF
}