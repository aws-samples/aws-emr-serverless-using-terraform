#! /bin/bash

# Configuration
# Note When set this flag, a long running EMR cluster is created by default
USE_EMR_ON_EC2=${USE_EMR_ON_EC2:-false}
EC2_KEY_NAME=${EC2_KEY_NAME:-""}

echo $PWD
APP_DIR=$PWD
APP_PREFIX=clicklogger
STAGE_NAME=dev
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')

echo "Using EMR on EC2: $USE_EMR_ON_EC2"

echo 'Building Source Lambda Jar'
cd $APP_DIR/source/clicklogger
mvn clean package
echo 'Building Source EMR Jar'
cd $APP_DIR/source/loggregator
# Build Scala JAR with Java 11
sbt clean
sbt compile
sbt package 

echo 'Deploying Terraform Resources'
cd $APP_DIR/terraform/workspaces/$REGION

terraform init
terraform plan -var="use_emr_on_ec2=$USE_EMR_ON_EC2" -var="ec2_key_name=$EC2_KEY_NAME"
terraform apply -var="use_emr_on_ec2=$USE_EMR_ON_EC2" -var="ec2_key_name=$EC2_KEY_NAME" --auto-approve
# shellcheck disable=SC2103

cd $APP_DIR
echo 'Deployed Successfully!'

echo 'Inserting Sample Data'
aws lambda invoke --function-name $APP_PREFIX-$STAGE_NAME-ingestion-lambda --cli-binary-format raw-in-base64-out --payload '{"requestid":"OAP-guid-001","contextid":"OAP-ctxt-001","callerid":"OrderingApplication","component":"login","action":"load","type":"webpage"}' out
aws lambda invoke --function-name $APP_PREFIX-$STAGE_NAME-ingestion-lambda --cli-binary-format raw-in-base64-out --payload '{"requestid":"OAP-guid-002","contextid":"OAP-ctxt-002","callerid":"OrderingApplication","component":"login","action":"load","type":"webpage"}' out
aws lambda invoke --function-name $APP_PREFIX-$STAGE_NAME-ingestion-lambda --cli-binary-format raw-in-base64-out --payload '{"requestid":"OAP-guid-003","contextid":"OAP-ctxt-003","callerid":"OrderingApplication","component":"products","action":"show","type":"webpage"}' out
aws lambda invoke --function-name $APP_PREFIX-$STAGE_NAME-ingestion-lambda --cli-binary-format raw-in-base64-out --payload '{"requestid":"OAP-guid-004","contextid":"OAP-ctxt-004","callerid":"OrderingApplication","component":"products","action":"show","type":"webpage"}' out
aws lambda invoke --function-name $APP_PREFIX-$STAGE_NAME-ingestion-lambda --cli-binary-format raw-in-base64-out --payload '{"requestid":"OAP-guid-005","contextid":"OAP-ctxt-005","callerid":"OrderingApplication","component":"checkout","action":"show","type":"webpage"}' out
aws lambda invoke --function-name $APP_PREFIX-$STAGE_NAME-ingestion-lambda --cli-binary-format raw-in-base64-out --payload '{"requestid":"OAP-guid-006","contextid":"OAP-ctxt-006","callerid":"OrderingApplication","component":"checkout","action":"show","type":"webpage"}' out
aws lambda invoke --function-name $APP_PREFIX-$STAGE_NAME-ingestion-lambda --cli-binary-format raw-in-base64-out --payload '{"requestid":"OAP-guid-007","contextid":"OAP-ctxt-007","callerid":"OrderingApplication","component":"submitorder","action":"backend","type":"process"}' out
aws lambda invoke --function-name $APP_PREFIX-$STAGE_NAME-ingestion-lambda --cli-binary-format raw-in-base64-out --payload '{"requestid":"OAP-guid-008","contextid":"OAP-ctxt-008","callerid":"OrderingApplication","component":"submitorder","action":"backend","type":"process"}' out


echo 'All process completed successfully!!'
