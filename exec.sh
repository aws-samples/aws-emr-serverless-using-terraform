#!/usr/bin/env bash
# Builds the Lambda and Spark job, deploys the infrastructure, and ingests sample data.
set -euo pipefail

APP_DIR=$PWD
APP_PREFIX=clicklogger
STAGE_NAME=dev
REGION=us-east-1

echo 'Building ingestion Lambda jar (Java 21)'
cd "$APP_DIR/source/clicklogger"
mvn -B clean package

echo 'Building Loggregator Spark job jar (Scala 2.12 / Spark 3.5)'
cd "$APP_DIR/source/loggregator"
sbt clean package

echo 'Deploying Terraform resources'
cd "$APP_DIR/terraform/workspaces/$REGION"
terraform init -input=false
terraform plan -input=false -out=tfplan
terraform apply -input=false tfplan
rm -f tfplan

cd "$APP_DIR"
echo 'Deployed successfully!'

echo 'Inserting sample data'
send() {
  aws lambda invoke --region "$REGION" \
    --function-name "$APP_PREFIX-$STAGE_NAME-ingestion-lambda" \
    --cli-binary-format raw-in-base64-out \
    --payload "$1" out >/dev/null
}
send '{"requestid":"OAP-guid-001","contextid":"OAP-ctxt-001","callerid":"OrderingApplication","component":"login","action":"load","type":"webpage"}'
send '{"requestid":"OAP-guid-002","contextid":"OAP-ctxt-002","callerid":"OrderingApplication","component":"login","action":"load","type":"webpage"}'
send '{"requestid":"OAP-guid-003","contextid":"OAP-ctxt-003","callerid":"OrderingApplication","component":"products","action":"show","type":"webpage"}'
send '{"requestid":"OAP-guid-004","contextid":"OAP-ctxt-004","callerid":"OrderingApplication","component":"products","action":"show","type":"webpage"}'
send '{"requestid":"OAP-guid-005","contextid":"OAP-ctxt-005","callerid":"OrderingApplication","component":"checkout","action":"show","type":"webpage"}'
send '{"requestid":"OAP-guid-006","contextid":"OAP-ctxt-006","callerid":"OrderingApplication","component":"checkout","action":"show","type":"webpage"}'
send '{"requestid":"OAP-guid-007","contextid":"OAP-ctxt-007","callerid":"OrderingApplication","component":"submitorder","action":"backend","type":"process"}'
send '{"requestid":"OAP-guid-008","contextid":"OAP-ctxt-008","callerid":"OrderingApplication","component":"submitorder","action":"backend","type":"process"}'
rm -f out

echo "Sample data sent. Firehose buffers for up to 60 seconds before writing Parquet to S3."
echo "Then run the workflow, for example:"
echo "  aws stepfunctions start-execution --region $REGION \\"
echo "    --state-machine-arn \$(terraform -chdir=terraform/workspaces/$REGION output -raw StateMachineArn) \\"
echo "    --input '{\"InputDate\": \"$(date -u +%Y-%m-%d)\"}'"
