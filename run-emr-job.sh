#!/bin/bash

# Script to run EMR job on long-running cluster
set -e

DATE=${1:-$(date +%Y-%m-%d)}
echo "Running EMR job for date: $DATE"

cd terraform/workspaces/us-east-1

# Get cluster ID
CLUSTER_ID=$(terraform output -raw emr_cluster_id 2>/dev/null || echo "")

if [ -z "$CLUSTER_ID" ]; then
    echo "No cluster found. Creating new cluster..."
    terraform apply -var="use_emr_on_ec2=true" -var="ec2_key_name=" --auto-approve
    CLUSTER_ID=$(terraform output -raw emr_cluster_id)
fi

echo "Cluster ID: $CLUSTER_ID"

# Check cluster status
STATUS=$(aws emr describe-cluster --cluster-id $CLUSTER_ID --query 'Cluster.Status.State' --output text 2>/dev/null || echo "TERMINATED")
echo "Cluster status: $STATUS"

if [ "$STATUS" = "TERMINATED" ] || [ "$STATUS" = "TERMINATING" ]; then
    echo "Cluster terminated. Creating new cluster..."
    terraform apply -var="use_emr_on_ec2=true" -var="ec2_key_name=" --auto-approve
    CLUSTER_ID=$(terraform output -raw emr_cluster_id)
    echo "New Cluster ID: $CLUSTER_ID"
fi

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
aws emr wait cluster-running --cluster-id $CLUSTER_ID
echo "Cluster is ready!"

# Trigger Step Function
echo "Triggering Step Function..."
EXECUTION_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn "arn:aws:states:us-east-1:$(aws sts get-caller-identity --query Account --output text):stateMachine:clicklogger-dev-emr-ec2-state-machine" \
  --input "{\"InputDate\": \"$DATE\", \"ClusterId\": \"$CLUSTER_ID\"}" \
  --query 'executionArn' --output text)

echo "Step Function execution started: $EXECUTION_ARN"
echo "Monitor at: https://console.aws.amazon.com/states/home?region=us-east-1#/executions/details/$EXECUTION_ARN"