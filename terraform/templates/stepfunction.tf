## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "${var.app_prefix}-${var.stage_name}-state-machine"
  role_arn = aws_iam_role.click_logger_sfn_role.arn

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.click_logger_sfn_log_group.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  # The optimized EMR Serverless integration (startJobRun.sync) submits the job and waits
  # for it to finish. The task fails if the job run ends in FAILED or CANCELLED, and the
  # job run is cancelled if the execution is stopped. No polling Lambda is required.
  definition = jsonencode({
    Comment       = "Run the Loggregator Spark job on EMR Serverless and wait for it to complete."
    QueryLanguage = "JSONata"
    StartAt       = "RunLoggregatorJob"
    States = {
      RunLoggregatorJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::emr-serverless:startJobRun.sync"
        Arguments = {
          ApplicationId           = aws_emrserverless_application.click_log_loggregator_emr_serverless.id
          ClientToken             = "{% $uuid() %}"
          Name                    = "{% 'loggregator-' & $states.input.InputDate %}"
          ExecutionRoleArn        = aws_iam_role.click_logger_emr_serverless_role.arn
          ExecutionTimeoutMinutes = var.emr_job_timeout_minutes
          JobDriver = {
            SparkSubmit = {
              EntryPoint            = "s3://${aws_s3_bucket.click_log_loggregator_source_s3_bucket.id}/${var.loggregator_jar}"
              EntryPointArguments   = "{% [$states.input.InputDate, '${aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.id}', '${aws_s3_bucket.click_log_loggregator_output_s3_bucket.id}'] %}"
              SparkSubmitParameters = "--class com.examples.clicklogger.Loggregator"
            }
          }
          ConfigurationOverrides = {
            MonitoringConfiguration = {
              S3MonitoringConfiguration = {
                LogUri = "s3://${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/logs/"
              }
              CloudWatchLoggingConfiguration = {
                Enabled      = true
                LogGroupName = aws_cloudwatch_log_group.click_logger_emr_serverless_log_group.name
              }
            }
          }
        }
        Output = {
          JobRunId   = "{% $states.result.JobRunId %}"
          InputDate  = "{% $states.input.InputDate %}"
          OutputPath = "{% 's3://${aws_s3_bucket.click_log_loggregator_output_s3_bucket.id}/' & $replace($states.input.InputDate, '-', '/') & '/response.md' %}"
        }
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "JobFailed"
            Output      = "{% $states.errorOutput %}"
          }
        ]
        Next = "JobSucceeded"
      }
      JobSucceeded = {
        Type = "Succeed"
      }
      JobFailed = {
        Type  = "Fail"
        Error = "{% $states.input.Error %}"
        Cause = "{% $states.input.Cause %}"
      }
    }
  })
}

output "StateMachineArn" {
  value = aws_sfn_state_machine.sfn_state_machine.arn
}
