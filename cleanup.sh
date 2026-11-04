#!/usr/bin/env bash
# Empties the sample's S3 buckets and destroys all resources created by exec.sh.
set -euo pipefail

APP_DIR=$PWD
APP_PREFIX=clicklogger
STAGE_NAME=dev
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "This deletes all objects in the $APP_PREFIX-$STAGE_NAME buckets and destroys the stack in account $ACCOUNT_ID ($REGION)."
read -r -p "Type 'yes' to continue: " CONFIRM
[ "$CONFIRM" = "yes" ] || { echo "Aborted."; exit 1; }

for b in emr-logs firehose-delivery loggregator-output loggregator-source; do
  aws s3 rb "s3://$REGION-$APP_PREFIX-$STAGE_NAME-$b-$ACCOUNT_ID" --force || true
done
echo 'Deleted S3 contents'

echo 'Destroying Terraform resources'
cd "$APP_DIR/terraform/workspaces/$REGION"
terraform destroy -input=false

cd "$APP_DIR"
echo 'Completed successfully!'
