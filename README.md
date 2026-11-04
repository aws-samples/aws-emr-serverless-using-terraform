# Running a Data Processing Job on EMR Serverless with AWS Step Functions using Terraform (By HashiCorp)

*Update November 2026* – This sample has been refreshed for current AWS services:

* The Step Functions workflow now uses the optimized **`emr-serverless:startJobRun.sync`** integration. Step Functions submits the job, waits for it to finish, and fails the execution if the job fails or is cancelled. The Lambda function that polled for job status has been removed.
* The EMR Serverless application uses release **`emr-7.14.0`** (Apache Spark 3.5.8) on **Graviton (arm64)** workers, with auto-start and auto-stop and no pre-initialized capacity, so you pay only while a job runs.
* The ingestion Lambda function runs on the **`java21`** runtime and uses the **AWS SDK for Java 2.x** (SDK v1 reached end of support on December 31, 2025).
* IAM policies are scoped to the resources this sample creates, and the VPC, NAT gateway, and EMR Studio that the earlier version required have been removed.
* Amazon Kinesis Data Firehose is now named **Amazon Data Firehose**.

In this post we show how to build and orchestrate a [Scala](https://www.scala-lang.org/) Spark application using [Amazon EMR Serverless](https://aws.amazon.com/emr/serverless/), [AWS Step Functions](https://aws.amazon.com/step-functions), and [Terraform by HashiCorp](https://www.terraform.io/). In this end-to-end solution we run a Spark job on EMR Serverless that processes sample clickstream data in an Amazon S3 bucket and stores the aggregation results in Amazon S3.

With EMR Serverless, you don't have to configure, optimize, secure, or operate clusters to run applications. You still get the benefits of [Amazon EMR](https://aws.amazon.com/emr/), such as open-source compatibility, concurrency, and optimized runtime performance for popular data frameworks. EMR Serverless offers quick job startup, automatic capacity management, and straightforward cost controls.

Several infrastructure as code frameworks help you define AWS infrastructure, such as the AWS CDK and Terraform. Terraform, an AWS Partner Network (APN) Advanced Technology Partner and member of the AWS DevOps Competency, is an infrastructure as code tool similar to AWS CloudFormation that lets you create, update, and version your AWS infrastructure. Terraform offers a friendly syntax, planning (see changes before they happen), graphing, and modules that break infrastructure into smaller, reusable pieces.

We provide the Terraform infrastructure definition and the source code for an AWS Lambda function that ingests sample website click events into [Amazon Data Firehose](https://aws.amazon.com/firehose/). Firehose converts the incoming JSON into Apache Parquet using a schema in the [AWS Glue](https://aws.amazon.com/glue/) Data Catalog and writes it to [Amazon S3](https://aws.amazon.com/s3/). An EMR Serverless Spark job, orchestrated by AWS Step Functions, then processes the Parquet files and writes a report of aggregate clickstream statistics to S3. A similar ingestion pattern was covered in an earlier [blog post](https://aws.amazon.com/blogs/developer/provision-aws-infrastructure-using-terraform-by-hashicorp-an-example-of-web-application-logging-customer-data/).

Overview of the steps and the AWS services used in this solution:

* Java and Scala builds – The Lambda function is built with Apache Maven and the Spark job with sbt.
* Terraform deploys the infrastructure to AWS.
* [Amazon EMR Serverless](https://aws.amazon.com/emr/serverless/) application – runs the Spark job. It starts automatically when a job is submitted and stops after 5 idle minutes.
* [AWS Lambda](https://aws.amazon.com/lambda/) ingestion function – validates incoming click events and writes them to the Firehose stream.
* [Amazon Data Firehose](https://aws.amazon.com/firehose/) – buffers the events, converts them to Parquet, and writes them to S3, partitioned by date.
* [AWS Step Functions](https://aws.amazon.com/step-functions) – submits the Spark job to EMR Serverless with the `startJobRun.sync` integration and waits for it to complete. No custom polling code is needed.
* [Amazon S3](https://aws.amazon.com/s3/)
    * Firehose delivery bucket – stores the ingested click logs as Parquet
    * Loggregator source bucket – stores the Spark job jar
    * Loggregator output bucket – stores the job's report
    * EMR Serverless logs bucket – stores Spark driver and executor logs
* [Amazon CloudWatch Logs](https://aws.amazon.com/cloudwatch/) – collects Lambda, Firehose, EMR Serverless job, and Step Functions execution logs.

![Architecture](assets/emr-serverless-click-logs-from-web-application.drawio.png?raw=true "Architecture")

### Prerequisites

* An [AWS account](https://aws.amazon.com/free/) and credentials with permission to create the resources in this sample.
* [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
* A Java Development Kit, version 21 (for example, [Amazon Corretto 21](https://aws.amazon.com/corretto/)).
* [Apache Maven](https://maven.apache.org/download.cgi) 3.9 or later.
* [sbt](https://www.scala-sbt.org/download/) 1.11 or later.
* [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or later. The configuration uses the AWS provider version 6.x.

### Design decisions

* **Step Functions optimized integration for EMR Serverless.** `arn:aws:states:::emr-serverless:startJobRun.sync` submits the job and waits for a terminal state. A job that ends in `FAILED` or `CANCELLED` fails the task, and stopping the execution cancels the job run. This replaces the earlier pattern of an SDK integration plus a polling Lambda function, which was limited by Lambda's 15-minute maximum timeout and could report success for a failed job.
* **JSONata in the state machine.** The workflow uses `QueryLanguage: JSONata` to build the job name and arguments from the execution input, and it returns the job run ID and report location as output.
* **On-demand capacity.** The application has no pre-initialized workers. Auto-start and auto-stop handle the application lifecycle, so the workflow doesn't need start or stop steps. Add `initial_capacity` in `terraform/templates/emr.tf` if you need faster job start times.
* **Graviton.** Both the EMR Serverless application and the Lambda function run on arm64 for better price-performance.
* **Least-privilege IAM.** Each role is limited to the specific buckets, Glue tables, log groups, EMR Serverless application, and Firehose stream it uses.
* **No VPC required.** None of the components need private network access, so the sample no longer creates a VPC or NAT gateway. If your Spark job needs to reach resources in a VPC, add a `network_configuration` block to the EMR Serverless application.

### Steps

Clone [this repository](https://github.com/aws-samples/aws-emr-serverless-using-terraform). The provided `exec.sh` script builds the Lambda jar and the Spark job jar, deploys the infrastructure, and sends sample click events.

```
$ chmod +x exec.sh
$ ./exec.sh
```

To run the commands individually:

```
APP_DIR=$PWD
REGION=us-east-1

# Build the ingestion Lambda and the Spark job
cd $APP_DIR/source/clicklogger && mvn clean package
cd $APP_DIR/source/loggregator && sbt clean package

# Deploy the infrastructure
cd $APP_DIR/terraform/workspaces/$REGION
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Testing

After deployment, send sample click events. `exec.sh` sends several. For example:

```
aws lambda invoke --function-name clicklogger-dev-ingestion-lambda \
  --cli-binary-format raw-in-base64-out \
  --payload '{"requestid":"OAP-guid-001","contextid":"OAP-ctxt-001","callerid":"OrderingApplication","component":"login","action":"load","type":"webpage"}' out
```

Firehose buffers records for up to 60 seconds, then writes Parquet files under `clicklog/data=YYYY-MM-DD/` in the Firehose delivery bucket. You can query the files with Amazon Athena by using the `clickloggerdev-table` table in the `clickloggerdevdatabase` Glue database.

![Parquet files in S3](assets/s3_source_parquet_files.png?raw=true "Parquet files in S3")

Run the Step Functions workflow with the date that the sample data was ingested (UTC):

```
aws stepfunctions start-execution \
  --state-machine-arn "$(terraform -chdir=terraform/workspaces/us-east-1 output -raw StateMachineArn)" \
  --name "loggregator-$(date +%s)" \
  --input "{\"InputDate\": \"$(date -u +%Y-%m-%d)\"}"
```

You can also start the execution from the Step Functions console by opening `clicklogger-dev-state-machine` and choosing **Start execution**. When the job completes, the execution output contains the job run ID and the report location:

```
{
  "JobRunId": "00f...",
  "InputDate": "2026-11-04",
  "OutputPath": "s3://us-east-1-clicklogger-dev-loggregator-output-<account-id>/2026/11/04/response.md"
}
```

![Step Functions execution](assets/step_function_success.png?raw=true "Step Functions execution")

If the Spark job fails, the execution fails with the error and cause returned by EMR Serverless. You can find the Spark driver logs in the `/aws/emr-serverless/clicklogger-dev` CloudWatch log group or in the EMR Serverless logs bucket.

To view the EMR Serverless application and its job runs, open the Amazon EMR console and choose **EMR Serverless** > **Applications**, or use the CLI:

```
aws emr-serverless get-application \
  --application-id "$(terraform -chdir=terraform/workspaces/us-east-1 output -raw EMRServerlessApplicationId)"
```

![EMR Serverless application](assets/EMRServerlessApplication.png?raw=true "EMR Serverless application")

### Reviewing the output

The job writes its report to the output bucket under a `yyyy/MM/dd/response.md` key:

```
aws s3 cp "s3://$(terraform -chdir=terraform/workspaces/us-east-1 output -raw S3OutputBucket)/2026/11/04/response.md" -
```

```
|*createdTime*|*callerid*|*component*|*count*
|------------|-----------------------|-----------|-------
*11-04-2026*|OrderingApplication|checkout|2
*11-04-2026*|OrderingApplication|login|2
*11-04-2026*|OrderingApplication|products|2
*11-04-2026*|OrderingApplication|submitorder|2
```

![Output report in S3](assets/s3_output_response_file.png?raw=true "Output report in S3")

## Cleanup

`cleanup.sh` empties the S3 buckets created by this sample and runs `terraform destroy`. It asks for confirmation before deleting anything, and Terraform shows the resources it will destroy before you approve.

```
$ chmod +x cleanup.sh
$ ./cleanup.sh
```

To clean up manually:

```
APP_PREFIX=clicklogger
STAGE_NAME=dev
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

for b in emr-logs firehose-delivery loggregator-output loggregator-source; do
  aws s3 rb s3://$REGION-$APP_PREFIX-$STAGE_NAME-$b-$ACCOUNT_ID --force
done

cd terraform/workspaces/$REGION
terraform destroy
```

## Conclusion

In this post we built, deployed, and ran a Spark data processing job on Amazon EMR Serverless, orchestrated by AWS Step Functions and deployed with Terraform. The Step Functions optimized integration for EMR Serverless lets the workflow submit a job and wait for its result without any custom polling code, and EMR Serverless auto-start and auto-stop mean you pay only for the capacity the job uses. You can use any supported language for your Lambda functions and Spark jobs, and you can trigger EMR Serverless jobs manually, on a schedule with Amazon EventBridge Scheduler, or from orchestrators such as AWS Step Functions and Amazon Managed Workflows for Apache Airflow.

We encourage you to try this example, then replace the sample code with your own and let Amazon EMR Serverless run it for you. If you have questions or feedback about this post, please leave a comment.

## References

* [Create and manage Amazon EMR Serverless applications with Step Functions](https://docs.aws.amazon.com/step-functions/latest/dg/connect-emr-serverless.html)
* [Amazon EMR Serverless release versions](https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/release-versions.html)
* [Transforming data with JSONata in Step Functions](https://docs.aws.amazon.com/step-functions/latest/dg/transforming-data.html)
* [Lambda runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)
* [Terraform: Beyond the basics with AWS](https://aws.amazon.com/blogs/apn/terraform-beyond-the-basics-with-aws/)
* [Provision AWS infrastructure using Terraform (By HashiCorp): an example of web application logging customer data](https://aws.amazon.com/blogs/developer/provision-aws-infrastructure-using-terraform-by-hashicorp-an-example-of-web-application-logging-customer-data/)
