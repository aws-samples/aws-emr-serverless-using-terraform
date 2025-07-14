## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_sfn_state_machine" "sfn_state_machine_emr_ec2" {
  count    = var.use_emr_on_ec2 ? 1 : 0
  name     = "${var.app_prefix}-${var.stage_name}-emr-ec2-state-machine"
  role_arn = aws_iam_role.lambda_clicklogger_emr_sfn_start_job_role.arn

  definition = <<EOF
{
  "Comment": "Submit job to EMR on EC2.",
  "StartAt": "StartEMRStep",
  "States": {
    "StartEMRStep": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:emr:addJobFlowSteps",
      "Parameters": {
        "JobFlowId.$": "$.ClusterId",
        "Steps": [
          {
            "Name": "ClickLogger Spark Job",
            "ActionOnFailure": "TERMINATE_JOB_FLOW",
            "HadoopJarStep": {
              "Jar": "command-runner.jar",
              "Args.$": "States.Array('spark-submit', '--class', 'com.examples.clicklogger.Loggregator', 's3://${aws_s3_bucket.click_log_loggregator_source_s3_bucket.id}/${var.loggregator_jar}', $.InputDate, '${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.id}', '${aws_s3_bucket.click_log_loggregator_output_s3_bucket.id}')"
            }
          }
        ]
      },
      "ResultPath": "$.StepResult",
      "Next": "WaitForStep"
    },
    "WaitForStep": {
      "Type": "Wait",
      "Seconds": 30,
      "Next": "CheckStepStatus"
    },
    "CheckStepStatus": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:emr:describeStep",
      "Parameters": {
        "ClusterId.$": "$.ClusterId",
        "StepId.$": "$.StepResult.StepIds[0]"
      },
      "Next": "IsStepComplete"
    },
    "IsStepComplete": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Step.Status.State",
          "StringEquals": "COMPLETED",
          "Next": "Success"
        },
        {
          "Variable": "$.Step.Status.State",
          "StringEquals": "FAILED",
          "Next": "Failure"
        },
        {
          "Variable": "$.Step.Status.State",
          "StringEquals": "CANCELLED",
          "Next": "Failure"
        }
      ],
      "Default": "WaitForStep"
    },
    "Success": {
      "Type": "Pass",
      "Result": "EMR Step completed successfully!",
      "End": true
    },
    "Failure": {
      "Type": "Fail",
      "Cause": "EMR Step failed!"
    }
  }
}
EOF
}