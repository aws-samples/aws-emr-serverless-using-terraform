## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_sfn_state_machine" "sfn_state_machine_emr_transient" {
  count    = var.use_emr_on_ec2 ? 1 : 0
  name     = "${var.app_prefix}-${var.stage_name}-emr-transient-state-machine"
  role_arn = aws_iam_role.lambda_clicklogger_emr_sfn_start_job_role.arn

  definition = <<EOF
{
  "Comment": "Create EMR cluster, run job, and terminate.",
  "StartAt": "CreateEMRCluster",
  "States": {
    "CreateEMRCluster": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:emr:runJobFlow",
      "Parameters": {
        "Name": "${var.app_prefix}-${var.stage_name}-transient-cluster",
        "ReleaseLabel": "emr-6.15.0",
        "Applications": [
          {"Name": "Spark"},
          {"Name": "Hadoop"}
        ],
        "ServiceRole": "${aws_iam_role.click_logger_emr_service_role[0].arn}",
        "JobFlowRole": "${aws_iam_instance_profile.click_logger_emr_ec2_instance_profile[0].name}",
        "LogUri": "s3://${aws_s3_bucket.click_log_loggregator_emr_serverless_logs_s3_bucket.id}/emr-logs/",
        "Instances": {
          "MasterInstanceType": "m4.large",
          "InstanceCount": 1,
          "Ec2SubnetId": "${aws_subnet.click_logger_emr_private_subnet1.id}",
          "EmrManagedMasterSecurityGroup": "${aws_security_group.click_logger_emr_security_group.id}",
          "EmrManagedSlaveSecurityGroup": "${aws_security_group.click_logger_emr_security_group.id}",
          "ServiceAccessSecurityGroup": "${aws_security_group.click_logger_emr_service_security_group[0].id}",
          "KeepJobFlowAliveWhenNoSteps": false
        },
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
      "Next": "WaitForCluster"
    },
    "WaitForCluster": {
      "Type": "Wait",
      "Seconds": 60,
      "Next": "CheckClusterStatus"
    },
    "CheckClusterStatus": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:emr:describeCluster",
      "Parameters": {
        "ClusterId.$": "$.JobFlowId"
      },
      "ResultPath": "$.ClusterStatus",
      "Next": "IsClusterComplete"
    },
    "IsClusterComplete": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.ClusterStatus.Cluster.Status.State",
          "StringEquals": "TERMINATED",
          "Next": "Success"
        },
        {
          "Variable": "$.ClusterStatus.Cluster.Status.State",
          "StringEquals": "TERMINATED_WITH_ERRORS",
          "Next": "Failure"
        },
        {
          "Variable": "$.ClusterStatus.Cluster.Status.State",
          "StringEquals": "WAITING",
          "Next": "Success"
        }
      ],
      "Default": "WaitForCluster"
    },
    "Success": {
      "Type": "Pass",
      "Result": "EMR job completed successfully!",
      "End": true
    },
    "Failure": {
      "Type": "Fail",
      "Cause": "EMR job failed!"
    }
  }
}
EOF
}