#!/bin/bash

# Smart EMR Job Runner - Creates cluster if needed, runs job
set -e

DATE=${1:-$(date +%Y-%m-%d)}
APP_PREFIX="clicklogger"
STAGE_NAME="dev"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Running EMR job for date: $DATE"

# Function to check if cluster exists and is running
check_existing_cluster() {
    local cluster_name="${APP_PREFIX}-${STAGE_NAME}-emr-cluster"
    
    # Find running clusters with our naming pattern
    EXISTING_CLUSTER=$(aws emr list-clusters \
        --active \
        --query "Clusters[?starts_with(Name, '$cluster_name') && (Status.State=='RUNNING' || Status.State=='WAITING')].Id" \
        --output text | head -1)
    
    if [ -n "$EXISTING_CLUSTER" ] && [ "$EXISTING_CLUSTER" != "None" ]; then
        echo "Found existing cluster: $EXISTING_CLUSTER"
        echo "$EXISTING_CLUSTER"
        return 0
    else
        echo "No running cluster found"
        return 1
    fi
}

# Function to create new cluster
create_cluster() {
    echo "Creating new EMR cluster..."
    
    # Get infrastructure details from Terraform
    cd terraform/workspaces/us-east-1
    SUBNET_ID=$(terraform output -raw private_subnet_id 2>/dev/null || echo "")
    EMR_SERVICE_ROLE_ARN=$(terraform output -raw emr_service_role_arn 2>/dev/null || echo "")
    EMR_INSTANCE_PROFILE=$(terraform output -raw emr_instance_profile_name 2>/dev/null || echo "")
    EMR_SECURITY_GROUP=$(terraform output -raw emr_security_group_id 2>/dev/null || echo "")
    SERVICE_SECURITY_GROUP=$(terraform output -raw emr_service_security_group_id 2>/dev/null || echo "")
    LOGS_BUCKET=$(terraform output -raw emr_logs_bucket 2>/dev/null || echo "")
    cd - > /dev/null
    
    if [ -z "$SUBNET_ID" ] || [ -z "$EMR_SERVICE_ROLE_ARN" ]; then
        echo "Infrastructure not found. Please run terraform apply first."
        exit 1
    fi
    
    # Create cluster
    CLUSTER_ID=$(aws emr create-cluster \
        --name "${APP_PREFIX}-${STAGE_NAME}-emr-cluster-$(date +%s)" \
        --release-label "emr-6.15.0" \
        --applications Name=Spark Name=Hadoop \
        --service-role "$EMR_SERVICE_ROLE_ARN" \
        --log-uri "s3://${LOGS_BUCKET}/emr-logs/" \
        --auto-termination-policy IdleTimeout=3600 \
        --ec2-attributes "{\
            \"InstanceProfile\":\"$EMR_INSTANCE_PROFILE\",\
            \"SubnetId\":\"$SUBNET_ID\",\
            \"EmrManagedMasterSecurityGroup\":\"$EMR_SECURITY_GROUP\",\
            \"EmrManagedSlaveSecurityGroup\":\"$EMR_SECURITY_GROUP\",\
            \"ServiceAccessSecurityGroup\":\"$SERVICE_SECURITY_GROUP\"\
        }" \
        --instance-groups "[\
            {\
                \"Name\":\"Master\",\
                \"Market\":\"ON_DEMAND\",\
                \"InstanceRole\":\"MASTER\",\
                \"InstanceType\":\"m4.large\",\
                \"InstanceCount\":1\
            }\
        ]" \
        --configurations '[
            {
                "Classification": "spark-defaults",
                "Properties": {
                    "spark.eventLog.enabled": "true",
                    "spark.eventLog.dir": "s3://'$LOGS_BUCKET'/spark-logs/",
                    "spark.history.fs.logDirectory": "s3://'$LOGS_BUCKET'/spark-logs/"
                }
            }
        ]' \
        --query 'ClusterId' --output text)
    
    echo "Created cluster: $CLUSTER_ID"
    
    # Wait for cluster to be ready
    echo "Waiting for cluster to be ready..."
    aws emr wait cluster-running --cluster-id $CLUSTER_ID
    echo "Cluster is ready!"
    
    echo "$CLUSTER_ID"
}

# Main logic
if CLUSTER_ID=$(check_existing_cluster); then
    echo "Using existing cluster: $CLUSTER_ID"
else
    CLUSTER_ID=$(create_cluster)
fi

# Trigger Step Function
echo "Triggering Step Function with cluster: $CLUSTER_ID"
EXECUTION_ARN=$(aws stepfunctions start-execution \
    --state-machine-arn "arn:aws:states:${REGION}:${ACCOUNT_ID}:stateMachine:${APP_PREFIX}-${STAGE_NAME}-emr-ec2-state-machine" \
    --input "{\"InputDate\": \"$DATE\", \"ClusterId\": \"$CLUSTER_ID\"}" \
    --query 'executionArn' --output text)

echo "✅ Job submitted successfully!"
echo "Execution ARN: $EXECUTION_ARN"
echo "Monitor at: https://console.aws.amazon.com/states/home?region=${REGION}#/executions/details/$EXECUTION_ARN"

# Optional: Wait for completion
if [ "$2" = "--wait" ]; then
    echo "Waiting for job completion..."
    aws stepfunctions describe-execution --execution-arn $EXECUTION_ARN --query 'status' --output text
    
    while true; do
        STATUS=$(aws stepfunctions describe-execution --execution-arn $EXECUTION_ARN --query 'status' --output text)
        if [ "$STATUS" = "SUCCEEDED" ]; then
            echo "✅ Job completed successfully!"
            break
        elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "ABORTED" ]; then
            echo "❌ Job failed with status: $STATUS"
            exit 1
        else
            echo "Job status: $STATUS"
            sleep 30
        fi
    done
fi