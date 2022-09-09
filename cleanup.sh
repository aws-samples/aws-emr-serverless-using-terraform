#! /bin/bash

echo 'Cleaning up Deployed Infrastructure..'
echo $PWD
APP_DIR=$PWD
APP_PREFIX=clicklogger
STAGE_NAME=dev
REGION=us-east-1

ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
echo $ACCOUNT_ID

aws s3 rb s3://$REGION-$APP_PREFIX-$STAGE_NAME-emr-logs-$ACCOUNT_ID --force
aws s3 rb s3://$REGION-$APP_PREFIX-$STAGE_NAME-firehose-delivery-$ACCOUNT_ID --force
aws s3 rb s3://$REGION-$APP_PREFIX-$STAGE_NAME-loggregator-output-$ACCOUNT_ID --force
aws s3 rb s3://$REGION-$APP_PREFIX-$STAGE_NAME-loggregator-source-$ACCOUNT_ID --force
aws s3 rb s3://$REGION-$APP_PREFIX-$STAGE_NAME-emr-studio-$ACCOUNT_ID --force
echo 'Deleted S3 contents'

echo 'Terraform Destroy Resources'
cd $APP_DIR/terraform/workspaces/$REGION
terraform destroy --auto-approve

cd $APP_DIR

echo 'Completed Successfully!'
