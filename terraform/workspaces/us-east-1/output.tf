## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

output "S3FirehoseDeliveryBucket" {
  value = module.clicklogger.S3FirehoseDeliveryBucket
}

output "S3EMRSourceBucket" {
  value = module.clicklogger.S3EMRSourceBucket
}

output "lambda-clicklogger-ingest" {
  value = module.clicklogger.lambda-clicklogger-ingest
}

output "lambda-clicklogger-emr-job" {
  value = module.clicklogger.lambda-clicklogger-emr-job
}