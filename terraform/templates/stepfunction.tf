## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "${var.app_prefix}-${var.stage_name}-state-machine"
  role_arn = aws_iam_role.lambda_clicklogger_emr_sfn_start_job_role.arn

  definition = <<EOF
{
  "Comment": "Submit job to EMR Serverless.",
  "StartAt": "StartEMRServerlessJob",
  "States": {
    "StartEMRServerlessJob": {
     "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:emrserverless:startJobRun",
      "Next": "CheckStatus",
      "Parameters": {
        "ApplicationId": "${aws_emrserverless_application.click_log_loggregator_emr_serverless.id}",
        "ClientToken.$": "States.UUID()",
        "Name": "${aws_emrserverless_application.click_log_loggregator_emr_serverless.name}",
        "ExecutionRoleArn": "${aws_iam_role.click_logger_emr_serverless_role.arn}",
        "JobDriver": {
          "SparkSubmit": {
            "EntryPoint": "s3://${aws_s3_bucket.click_log_loggregator_source_s3_bucket.id}/${var.loggregator_jar}",
            "EntryPointArguments.$": "States.Array($.InputDate, '${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.id}', '${aws_s3_bucket.click_log_loggregator_output_s3_bucket.id}')",
            "SparkSubmitParameters": "--class com.examples.clicklogger.Loggregator"
          }
        }
     }
    },
    "CheckStatus": {
      "Comment": "Lambda to check status of job submitted to EMR Serverless.",
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lambda_clicklogger_emr_job_status.arn}",
        "Payload": {
          "jobRunId.$": "$.JobRunId"
        }
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
