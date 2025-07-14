#!/bin/bash

# EMR Cluster Management Script
# Usage: ./create-emr-cluster.sh [create|get-active|run-job]

set -e

# Configuration
APP_PREFIX="clicklogger"
STAGE_NAME="dev"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# EMR Configuration
CLUSTER_NAME="${APP_PREFIX}-${STAGE_NAME}-emr-cluster"
LOG_URI="s3://${REGION}-${APP_PREFIX}-${STAGE_NAME}-emr-logs-${ACCOUNT_ID}/emr-logs/"
SERVICE_ROLE="EMR_DefaultRole"
EC2_PROFILE="EMR_EC2_DefaultRole"

create_cluster() {
    echo "Creating EMR cluster: $CLUSTER_NAME"
    
    CLUSTER_ID=$(aws emr create-cluster \
        --name "$CLUSTER_NAME" \
        --release-label "emr-6.9.0" \
        --applications Name=Spark \
        --instance-groups \
            InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m5.xlarge \
            InstanceGroupType=CORE,InstanceCount=2,InstanceType=m5.xlarge \
        --service-role "$SERVICE_ROLE" \
        --ec2-attributes InstanceProfile="$EC2_PROFILE" \
        --log-uri "$LOG_URI" \
        --auto-scaling-role EMR_AutoScaling_DefaultRole \
        --query 'ClusterId' --output text)
    
    echo "Cluster created with ID: $CLUSTER_ID"
    echo "Waiting for cluster to be ready..."
    
    aws emr wait cluster-running --cluster-id "$CLUSTER_ID"
    echo "Cluster $CLUSTER_ID is now RUNNING"
    echo "$CLUSTER_ID"
}

get_active_cluster() {
    ACTIVE_CLUSTER=$(aws emr list-clusters \
        --cluster-states RUNNING WAITING \
        --query "Clusters[?Name=='$CLUSTER_NAME'].Id" \
        --output text)
    
    if [ -n "$ACTIVE_CLUSTER" ] && [ "$ACTIVE_CLUSTER" != "None" ]; then
        echo "$ACTIVE_CLUSTER"
    else
        echo ""
    fi
}

run_job() {
    INPUT_DATE=${1:-$(date +%Y-%m-%d)}
    
    # Check for active cluster
    CLUSTER_ID=$(get_active_cluster)
    
    if [ -z "$CLUSTER_ID" ]; then
        echo "No active cluster found. Creating new cluster..."
        CLUSTER_ID=$(create_cluster)
    else
        echo "Using existing cluster: $CLUSTER_ID"
    fi
    
    # Trigger Step Function
    echo "Triggering Step Function with cluster ID: $CLUSTER_ID"
    
    EXECUTION_ARN=$(aws stepfunctions start-execution \
        --state-machine-arn "arn:aws:states:${REGION}:${ACCOUNT_ID}:stateMachine:${APP_PREFIX}-${STAGE_NAME}-emr-ec2-state-machine" \
        --name "emr-job-$(date +%s)" \
        --input "{\"InputDate\": \"$INPUT_DATE\", \"ClusterId\": \"$CLUSTER_ID\"}" \
        --query 'executionArn' --output text)
    
    echo "Step Function execution started: $EXECUTION_ARN"
    echo "Monitor execution: https://console.aws.amazon.com/states/home?region=${REGION}#/executions/details/${EXECUTION_ARN}"
}

# Main script logic
case "${1:-run-job}" in
    "create")
        create_cluster
        ;;
    "get-active")
        CLUSTER_ID=$(get_active_cluster)
        if [ -n "$CLUSTER_ID" ]; then
            echo "Active cluster: $CLUSTER_ID"
        else
            echo "No active cluster found"
        fi
        ;;
    "run-job")
        run_job "$2"
        ;;
    *)
        echo "Usage: $0 [create|get-active|run-job] [date]"
        echo "  create     - Create new EMR cluster"
        echo "  get-active - Get active cluster ID"
        echo "  run-job    - Create cluster if needed and run job (default)"
        echo "  date       - Input date for job (default: today)"
        exit 1
        ;;
esac