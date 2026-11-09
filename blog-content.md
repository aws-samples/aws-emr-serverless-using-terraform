**Source references** (for editors — automatically removed before publishing): Blog post: https://aws.amazon.com/blogs/big-data/run-a-data-processing-job-on-amazon-emr-serverless-with-aws-step-functions/ · SIM ticket: https://sim.amazon.com/issues/REVBLOG-1381

# Run a data processing job on Amazon EMR Serverless with AWS Step Functions

***Update Feb 2023: AWS Step Functions adds direct integration for 35 services including Amazon EMR Serverless. In the current version of this blog, we are able to submit an EMR Serverless job by invoking the APIs directly from a Step Functions workflow. We are using the Lambda only for polling the status of the job in EMR. Read more about the Step Functions enhancement [here](/about-aws/whats-new/2023/02/aws-step-functions-integration-35-services-emr-serverless/).***

***February 9, 2024:** Amazon Kinesis Data Firehose has been renamed to Amazon Data Firehose. Read the [AWS What's New post](/about-aws/whats-new/2024/02/amazon-data-firehose-formerly-kinesis-data-firehose/) to learn more.*

There are several infrastructure as code (IaC) frameworks available today, to help you define your infrastructure, such as the [AWS Cloud Development Kit](/cdk/) (AWS CDK) or [Terraform by HashiCorp](https://www.terraform.io/). Terraform, an AWS Partner Network (APN) Advanced Technology Partner and member of the AWS DevOps Competency, is an IaC tool similar to [AWS CloudFormation](/cloudformation) that allows you to create, update, and version your AWS infrastructure. Terraform provides friendly syntax (similar to AWS CloudFormation) along with other features like planning (visibility to see the changes before they actually happen), graphing, and the ability to create templates to break infrastructure configurations into smaller chunks, which allows better maintenance and reusability. We use the capabilities and features of Terraform to build an API-based ingestion process into AWS. Let's get started!

In this post, we showcase how to build and orchestrate a [Scala](https://www.scala-lang.org/) Spark application using [Amazon EMR Serverless](/emr/serverless/), [AWS Step Functions](/step-functions), and Terraform. In this end-to-end solution, we run a Spark job on EMR Serverless that processes sample clickstream data in an [Amazon Simple Storage Service](/s3) (Amazon S3) bucket and stores the aggregation results in Amazon S3.

With EMR Serverless, you don't have to configure, optimize, secure, or operate clusters to run applications. You will continue to get the benefits of [Amazon EMR](/emr/), such as open source compatibility, concurrency, and optimized runtime performance for popular data frameworks. EMR Serverless is suitable for customers who want ease in operating applications using open-source frameworks. It offers quick job startup, automatic capacity management, and straightforward cost controls.

## Solution overview

We provide the Terraform infrastructure definition and the source code for an [AWS Lambda](/lambda) function using sample customer user clicks for online website inputs, which are ingested into an [Amazon Kinesis Data Firehose](/kinesis/data-firehose/) delivery stream. The solution uses Kinesis Data Firehose to convert the incoming data into a Parquet file (an open-source file format for Hadoop) before pushing it to Amazon S3 using the [AWS Glue](/glue/) Data Catalog. The generated output S3 Parquet file logs are then processed by an EMR Serverless process, which outputs a report detailing aggregate clickstream statistics in an S3 bucket. The EMR Serverless operation is triggered using Step Functions. The sample architecture and code are spun up as shown in the following diagram.

![reblog-198-archdiag.png](/api/documents/b4dw49wc4GUKX/media/4AFDxU)

The provided samples have the source code for building the infrastructure using Terraform for running the Amazon EMR application. Setup scripts are provided to create the sample ingestion using Lambda for the incoming application logs. For a similar ingestion pattern sample, refer to [Provision AWS infrastructure using Terraform (By HashiCorp): an example of web application logging customer data](/blogs/developer/provision-aws-infrastructure-using-terraform-by-hashicorp-an-example-of-web-application-logging-customer-data/).

The following are the high-level steps and AWS services used in this solution:

- The provided application code is packaged and built using Apache Maven.
- Terraform commands are used to deploy the infrastructure in AWS.
- The EMR Serverless application provides the option to submit a Spark job.
- The solution uses two Lambda functions:
  - **Ingestion** – This function processes the incoming request and pushes the data into the Kinesis Data Firehose delivery stream.
  - **EMR Job Status Check Lambda** – This Lambda does a polling mechanism to check the status of the job that was submitted to EMR Serverless Application.
- Step Functions starts the data processing job on the EMR Serverless application and then triggers a Lambda which polls to check the status of the submitted job.
- The solution uses four S3 buckets:
  - **Kinesis Data Firehose delivery bucket** – Stores the ingested application logs in Parquet file format.
  - **Loggregator source bucket** – Stores the Scala code and JAR for running the EMR job.
  - **Loggregator output bucket** – Stores the EMR processed output.
  - **EMR Serverless logs bucket** – Stores the EMR process application logs.
- Sample invoke commands (run as part of the initial setup process) insert the data using the ingestion Lambda function. The Kinesis Data Firehose delivery stream converts the incoming stream into a Parquet file and stores it in an S3 bucket.

For this solution, we made the following design decisions:

- We use AWS Step Functions and its support for SDK Integrations with EMR Serverless to start a data processing job on the EMR Serverless Application.
- The Lambda code (used for polling the status of the EMR job) and EMR Serverless log aggregation code are developed using Java and Scala, respectively. You can use any supported languages in these use cases.
- The [AWS Command Line Interface](/cli) (AWS CLI) V2 is required for querying EMR Serverless applications from the command line. You can also view these from the [AWS Management Console](/console). We provide a sample AWS CLI command to test the solution later in this post.

## Prerequisites

To use this solution, you must complete the following prerequisites:

- [Install the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). For this post, we used version 2.7.18. This is required in order to query the `aws emr-serverless` AWS CLI commands from your local machine. Optionally, all the AWS services used in this post can be viewed and operated via the console.
- Make sure to have [Java](https://www.java.com/en/download/) installed, and JDK/JRE 8 is set in the environment path of your machine. For instructions, see the [Java Development Kit](https://www.java.com/en/download/).
- Install [Apache Maven](https://maven.apache.org/download.cgi). The Java Lambda functions are built using mvn packages and are deployed using Terraform into AWS.
- Install the [Scala Build Tool](https://www.scala-sbt.org/download.html). For this post, we used version 1.4.7. Make sure to download and install based on your operating system needs.
- Set up [Terraform](https://www.terraform.io/downloads). For steps, see [Terraform downloads](https://www.terraform.io/downloads). We use version 1.2.5 for this post.
- Have an [AWS account](/free/).

## Configure the solution

To spin up the infrastructure and the application, complete the following steps:

1. Clone the following [GitHub repository](https://github.com/aws-samples/aws-emr-serverless-using-terraform).\
    The provided `exec.sh` shell script builds the Java application JAR (for the Lambda ingestion function) and the Scala application JAR (for the EMR processing) and deploys the AWS infrastructure that is needed for this use case.

1. Run the following commands:

```bash
$ chmod +x exec.sh
$ ./exec.sh
```

To run the commands individually, set the application deployment Region and account number, as shown in the following example:

```bash
$ APP_DIR=$PWD
$ APP_PREFIX=clicklogger
$ STAGE_NAME=dev
$ REGION=us-east-1
$ ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
```

The following is the Maven build Lambda application JAR and Scala application package:

```bash
$ cd $APP_DIR/source/clicklogger
$ mvn clean package
$ cd $APP_DIR/source/loggregator
$ sbt reload
$ sbt compile
$ sbt package
```

1. Deploy the AWS infrastructure using Terraform:

```bash
$ terraform init
$ terraform plan
$ terraform apply --auto-approve
```

## Test the solution

After you build and deploy the application, you can insert sample data for Amazon EMR processing. We use the following code as an example. The `exec.sh` script has multiple sample insertions for Lambda. The ingested logs are used by the EMR Serverless application job.

The sample AWS CLI invoke command inserts sample data for the application logs:

```bash
aws lambda invoke --function-name clicklogger-dev-ingestion-lambda —cli-binary-format raw-in-base64-out —payload '{"requestid":"OAP-guid-001","contextid":"OAP-ctxt-001","callerid":"OrderingApplication","component":"login","action":"load","type":"webpage"}' out
```

To validate the deployments, complete the following steps:

1. On the Amazon S3 console, navigate to the bucket created as part of the infrastructure setup.

2. Choose the bucket to view the files.\
    You should see that data from the ingested stream was converted into a Parquet file.

1. Choose the file to view the data.\

The following screenshot shows an example of our bucket contents.

![s3_source_parquet_files.png](/api/documents/b4dw49wc4GUKX/media/tAi2ZA)

\

    Now you can run Step Functions to validate the EMR Serverless application.
4. On the Step Functions console, open c`licklogger-dev-state-machine`. You can review the definition section to understand the steps configured in the state machine.
5. Start a new run (with the below sample input) to trigger the state machine. Enter the date value equal to the date when sample data was ingested to S3 with the ingest lambda.

```code
{
"InputDate": "2023-02-08"
}
```

1. Once completed, below is how a successful state machine run looks on the Step Functions console.\

![reblog-198-img1.png](/api/documents/b4dw49wc4GUKX/media/os18Yx)

1. After the state machine runs successfully, navigate to the `<your-region>``-clicklogger-dev-loggregator-output-``<your-account-number>` on the Amazon S3 console to see the output files.\

![reblog-198-img2.png](/api/documents/b4dw49wc4GUKX/media/Aueui8)

1. Use the AWS CLI to check the deployed EMR Serverless application:

```bash
$ aws emr-serverless list-applications \
      | jq -r '.applications[] | select(.name=="clicklogger-dev-loggregrator-emr-<Your-Account-Number>").id'
```

1. On the Amazon EMR console, choose **Serverless** in the navigation pane.
2. Select `clicklogger-dev-studio` and choose **Manage applications**.
3. The Application created by the stack will be as shown below `clicklogger-dev-loggregator-emr-``<Your-Account-Number>`\

![EMRStudioApplications-1024x481.png](/api/documents/b4dw49wc4GUKX/media/AWpgEK)

![EMRServerlessApplication-1024x343.png](/api/documents/b4dw49wc4GUKX/media/w6qFcu)

Now you can review the EMR Serverless application output.

12. On the Amazon S3 console, open the output bucket (`<your-region>``-clicklogger-dev-loggregator-output-``<your-account-number>`).\
    The EMR Serverless application writes the output based on the date partition, such as `2022/07/28/response.md`. The following code shows an example of the file output:

```code
|*createdTime*|*callerid*|*component*|*count*
|------------|-----------|-----------|-------
*07-28-2022*|OrderingApplication|checkout|2
*07-28-2022*|OrderingApplication|login|2
*07-28-2022*|OrderingApplication|products|2
```

## Clean up

The provided `./cleanup.sh` script has the required steps to delete all the files from the S3 buckets that were created as part of this post. The `terraform destroy` command cleans up the AWS infrastructure that you created earlier. See the following code:

```bash
$ chmod +x cleanup.sh
$ ./cleanup.sh
```

To do the steps manually, you can also delete the resources via the AWS CLI:

```bash
# CLI Commands to delete the Amazon S3  

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

# Destroy the AWS Infrastructure 
terraform destroy --auto-approve
```

## Conclusion

In this post, we built, deployed, and ran a data processing Spark job in EMR Serverless that interacts with various AWS services. We walked through deploying a Lambda function packaged with Java using Maven, and a Scala application code for the EMR Serverless application triggered with Step Functions with infrastructure as code. You can use any combination of applicable programming languages to build your Lambda functions and EMR job application. EMR Serverless can be triggered manually, automated, or orchestrated using AWS services like Step Functions and Amazon MWAA.

We encourage you to test this example and see for yourself how this overall application design works within AWS. Then, it's just the matter of replacing your individual code base, packaging it, and letting EMR Serverless handle the process efficiently.

If you implement this example and run into any issues, or have any questions or feedback about this post, please leave a comment!

## References

- [AWS Step Functions adds integration for 35 services including EMR Serverless](/about-aws/whats-new/2023/02/aws-step-functions-integration-35-services-emr-serverless/)
- [Terraform: Beyond the Basics with AWS](/blogs/apn/terraform-beyond-the-basics-with-aws/)
- [Amazon EMR Serverless is now generally available](/about-aws/whats-new/2022/06/amazon-emr-serverless-generally-available/)
- [Amazon EMR Serverless Now Generally Available – Run Big Data Applications without Managing Servers](/blogs/aws/amazon-emr-serverless-now-generally-available-run-big-data-applications-without-managing-servers/)
- [Provision AWS infrastructure using Terraform (By HashiCorp): an example of web application logging customer data](/blogs/developer/provision-aws-infrastructure-using-terraform-by-hashicorp-an-example-of-web-application-logging-customer-data/)

------------------------------------------------------------------------

## **About the Authors**

![ramani.png](/api/documents/b4dw49wc4GUKX/media/SNobKK)

### Sivasubramanian Ramani (Siva Ramani)

Sivasubramanian is a Sr Cloud Application Architect at Amazon Web Services. His expertise is in application optimization & modernization, serverless solutions and using Microsoft application workloads with AWS.

![nbbalara.jpg](/api/documents/b4dw49wc4GUKX/media/f0nwGl)

### Naveen Balaraman

Naveen is a Sr Cloud Application Architect at Amazon Web Services. He is passionate about Containers, serverless Applications, Architecting Microservices and helping customers leverage the power of AWS cloud.