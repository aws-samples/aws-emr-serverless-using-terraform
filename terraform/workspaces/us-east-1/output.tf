## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

output "S3FirehoseDeliveryBucket" {
  value = module.clicklogger.S3FirehoseDeliveryBucket
}

output "S3EMRSourceBucket" {
  value = module.clicklogger.S3EMRSourceBucket
}

output "S3OutputBucket" {
  value = module.clicklogger.S3OutputBucket
}

output "IngestionLambdaName" {
  value = module.clicklogger.lambda-clicklogger-ingest
}

output "EMRServerlessApplicationId" {
  value = module.clicklogger.EMRServerlessApplicationId
}

output "StateMachineArn" {
  value = module.clicklogger.StateMachineArn
}
