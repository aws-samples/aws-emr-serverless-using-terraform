# Running a Data Processing Job on EMR Serverless with AWS Step Functions and AWS Lambda using Terraform (By HashiCorp)

*Update Feb 2023* – AWS Step Functions adds direct integration for 35 services including Amazon EMR Serverless. In the current version of this blog, we are able to submit an EMR Serverless job by invoking the APIs directly from a Step Functions workflow. We are using the Lambda only for polling the status of the job in EMR. Read more about this feature enhancement [here](https://aws.amazon.com/about-aws/whats-new/2023/02/aws-step-functions-integration-35-services-emr-serverless/).

In this blog we showcase how to build and orchestrate a [Scala](https://www.scala-lang.org/) Spark Application using [Amazon EMR Serverless](https://aws.amazon.com/emr/serverless/) , AWS Step Functions and [Terraform By HashiCorp](https://www.terraform.io/). In this end to end solution we execute a Spark job on EMR Serverless which processes sample click-stream data in Amazon S3 bucket and stores the aggregation results in Amazon S3. 
 
With EMR Serverless, customers don’t have to configure, optimize, secure, or operate clusters to run applications. You will continue to get the benefits of [Amazon EMR](https://aws.amazon.com/emr/), such as open source compatibility, concurrency, and optimized runtime performance for popular data frameworks. EMR Serverless is suitable for customers who want ease in operating applications using open-source frameworks. It offers quick job startup, automatic capacity management, and straightforward cost controls.
 
There are several ‘infrastructure as code’ frameworks available today, to help customers define their infrastructure, such as the AWS CDK or Terraform. Terraform, an AWS Partner Network (APN) Advanced Technology Partner and member of the AWS DevOps Competency, is an infrastructure as code tool similar to AWS CloudFormation that allows you to create, update, and version your AWS infrastructure. Terraform provides friendly syntax (similar to [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html)) along with other features like planning (visibility to see the changes before they actually happen), graphing, ability to create templates to break infra configurations into smaller chunks which allows better  maintenance and reusability. We will leverage the capabilities and features of Terraform to build an API based ingestion process into AWS. Let’s get started!
 
We will provide the Terraform infrastructure definition and the source code for an AWS Lambda using which sample customer user clicks for online website inputs are ingested into an [Amazon Kinesis Data Firehose](https://aws.amazon.com/kinesis/data-firehose/). The solution leverages Firehose’s capability to convert the incoming data into a Parquet file (an open-source file format for Hadoop) before pushing it to [Amazon S3](https://aws.amazon.com/s3/) using [AWS Glue](https://aws.amazon.com/glue/) catalog. The generated output S3 Parquet file logs are then processed by an EMR Serverless process and outputs a report detailing aggregate click stream statistics in S3 bucket. The EMR serverless operation is triggered using [AWS Step Functions](https://aws.amazon.com/step-functions). The sample architecture and code will be spun up as below.
 
Provided samples have the source code for building the infrastructure using Terraform for running the Amazon EMR Application. Setup scripts are provided to create the sample ingestion using AWS Lambda for incoming application logs.  Similar ingestion pattern sample was terraformed in an earlier [blog](https://aws.amazon.com/blogs/developer/provision-aws-infrastructure-using-terraform-by-hashicorp-an-example-of-web-application-logging-customer-data/). 
 
Overview of the steps and the AWS Services used in this solution:

* Java source build – Provided application code is packaged & built using Apache Maven
* Terraform commands are used to deploy the infrastructure in AWS.
* [Amazon EMR Serverless](https://aws.amazon.com/emr/serverless/) Application - provides the option to submit a Spark job.
* [AWS Lambda](https://aws.amazon.com/lambda/):
    * Ingestion Lambda – This lambda processes the incoming request and pushes the data into Firehose stream.
    * EMR Job Status Check Lambda - This lambda does a polling mechanism to check the status of the job that was submitted to EMR Serverless.
* [AWS Step Functions](https://aws.amazon.com/step-functions)  Submits the data processing job to an EMR Serverless application and triggers a Lambda which polls to check the status of the submitted job.
* [Amazon Simple Storage Service](https://aws.amazon.com/s3/) (Amazon S3)  
    * Firehose Delivery Bucket - Stores the ingested application logs in parquet file format
    * Loggregator Source Bucket - Stores the scala code/jar for EMR job execution
    * Loggregator Output Bucket - EMR processed output is stored in this bucket
    * EMR Serverless logs Bucket - Stores EMR process application logs
* Sample AWS Invoke commands (run as part of initial set up process) inserts the data using the Ingestion Lambda and Firehose stream converts the incoming stream into a Parquet file and stored in an S3 bucket

 
![Alt text](assets/emr-serverless-click-logs-from-web-application.drawio.png?raw=true "Title")
### Prerequisites

* [AWS Cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) - At the time of writing this article version 2.7.18 was used. This will be required to query aws emr-serverless cli commands from your local machine. Optionally all the AWS Services used in this blog can be viewed/operated from AWS Console also.
* Make sure to have [Java](https://www.java.com/en/download/) installed, JDK/JRE 8 is set in the environment path of your machine. For instructions, see [Java Development Kit](https://www.java.com/en/download/)
* [Apache Maven](https://maven.apache.org/download.cgi) – Java Lambdas are built using mvn packages and are deployed using Terraform into AWS
* [Scala Build Tool](https://www.scala-sbt.org/download.html) (sbt) - Version 1.4.7 is used at the time of this article. Make sure to download and install based on your operating system needs.
* Set up [Terraform](https://www.terraform.io/downloads). For steps, see Terraform downloads. Version 1.2.5 is used at the time of this article.
* An [AWS Account](https://aws.amazon.com/free/)

### Design Decisions

* We use AWS Step Functions  and its support for SDK Integrations with EMR Serverless to submit the data processing job to the EMR Serverless Application.
* AWS Lambda Code & EMR Serverless Log Aggregation code are developed using Java & Scala respectively.
* AWS CLI V2 is required for querying Amazon EMR Serverless applications from command line. These can be viewed from AWS Console also. A sample CLI command provided below in the “Testing” section below.

### Steps


 Clone [this repository](https://github.com/aws-samples/aws-emr-serverless-using-terraform) and execute the below command to spin up the infrastructure and the application
Provided “exec.sh” shell script builds the Java application jar (For the Lambda Ingestion), the Scala application Jar (For the EMR Processing) and deploys the AWS Infrastructure that is needed for this use case.
 
Execute the below commands
 

```
$ chmod +x exec.sh
$ ./exec.sh
```

 
To run the commands individually
 
Set the application deployment region and account number. An example below. Modify as needed. 

```
 $ APP_DIR=$PWD
 $ APP_PREFIX=clicklogger
 $ STAGE_NAME=dev
 $ REGION=us-east-1
 $ ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
```

Maven build AWS Lambda Application Jar & Scala Application package

```
 $ cd $APP_DIR/source/clicklogger
 $ mvn clean package
 $ cd $APP_DIR/source/loggregator
 $ sbt reload
 $ sbt compile
 $ sbt package
```

 
Deploy the AWS Infrastructure using Terraform

```
 $ terraform init
 $ terraform plan
 $ terraform apply --auto-approve
```

### Testing


 Once the application is built and deployed, you can also insert sample data for the EMR processing. An example as below. Note exec.sh has multiple sample insertions for AWS Lambda. The ingested logs will be used by the EMR Serverless Application job
 
Below sample AWS CLI Invoke command inserts sample data for the application logs

```
aws lambda invoke --function-name clicklogger-dev-ingestion-lambda —cli-binary-format raw-in-base64-out —payload '{"requestid":"OAP-guid-001","contextid":"OAP-ctxt-001","callerid":"OrderingApplication","component":"login","action":"load","type":"webpage"}' out
```

Validate the Deployments

* Output – Once the Lambda is successfully executed, you should see the output in S3 buckets as shown below 
* Validate the saved ingested data as below
    * Navigate to the bucket created as part of the stack.
    * Select the file and view the file from “Select From” sub tab.  
    * You should see something ingested stream got converted into parquet file. * 
    * Select the file and view the data. A sample is shown below

![Alt text](assets/s3_source_parquet_files.png?raw=true "Title")

* Run AWS Step Function to validate the Serverless application
  * Open AWS Console > AWS Step Function > Open "clicklogger-dev-state-machine".
  * The step function will show the steps that ran to trigger the AWS Lambda and Job submission to EMR Serverless Application
  * Start a new StepFunctions execution to trigger the workflow with the sample input below:
  ```
  {
    "InputDate": "2023-02-08"
  }
  ```
  * Once the AWS Step Function is successful, navigate to Amazon S3 > <your-region>-clicklogger-dev-loggregator-output-<your-Account-Number> to see the output files.
  * These will be partitioned by year/month/date/response.md. A sample is shown below
 
![Alt text](assets/s3_output_response_file.png?raw=true "Title")


AWS CLI can be used to check the deployed AWS Serverless Application

```
$ aws emr-serverless list-applications \
      | jq -r '.applications[] | select(.name=="clicklogger-dev-loggregrator-emr-<Your-Account-Number>").id'

```

![Alt text](assets/step_function_success.png?raw=true "Title")

EMR Studio

* Open AWS Console, Navigate to “EMR” > “Serverless” tab on the left pane.
* Select “clicklogger-dev-studio” and click “Manage Applications”

 
  
![Alt text](assets/EMRStudioApplications.png?raw=true "Title")

![Alt text](assets/EMRServerlessApplication.png?raw=true "Title")

Reviewing the Serverless Application Output:
 

* Open AWS Console, Navigate to Amazon S3
* Open the outputs S3 bucket. This will be like - us-east-1-clicklogger-dev-loggregator-output-<YOUR-ACCOUNT-NUMBER>
* The EMR Serverless application writes the output based on the date partition as below
    * 2022/07/28/response.md
    * Output of the file will be like below

```

 |*createdTime*|*callerid*|*component*|*count*
 |------------|-----------|-----------|-------
 *07-28-2022*|OrderingApplication|checkout|2
 *07-28-2022*|OrderingApplication|login|2
 *07-28-2022*|OrderingApplication|products|2
```

## Cleanup


Provided "./cleanup.sh" has the required steps to delete all the files from Amazon S3 buckets that were created as part of this blog. terraform destroy command will clean up the AWS infrastructure those were spun up as mentioned above
 

```
$ chmod +x cleanup.sh
$ ./cleanup.sh
```

* To do the steps manually,

S3 and created services can be deleted using CLI also. Execute the below commands (an example below, modify as needed):

```


# CLI Commands to delete the S3  

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


To recap, in this post we built, deployed & ran a data processing spark job in Amazon EMR Serverless that interacts with various AWS Services. The post walked through deploying a lambda packaged with Java using maven, a Scala application code for EMR Serverless Application triggered with AWS Step Functions with infrastructure as code. You may use any combination of applicable programming languages to build your lambda functions, EMR Job application. EMR Serverless can be triggered manually, automated or can be orchestrated using AWS Services like AWS Step Function, Amazon Managed Apache airflow, etc., 
 
We encourage you to test this example and see for yourself how this overall application design works within AWS. Then, it will be just the matter of replacing your individual code base, package them and let the Amazon EMR Serverless handle the process efficiently.
 
If you implement this example and run into any issues, or have any questions or feedback about this blog please provide your comments below!

## References

* [Terraform: Beyond the basics with AWS](https://aws.amazon.com/blogs/apn/terraform-beyond-the-basics-with-aws/) 
* [Amazon EMR Serverless General Availability](https://aws.amazon.com/about-aws/whats-new/2022/06/amazon-emr-serverless-generally-available/)
* [Amazon EMR Serverless Now Generally Available – Run Big Data Applications without Managing Servers](https://aws.amazon.com/blogs/aws/amazon-emr-serverless-now-generally-available-run-big-data-applications-without-managing-servers/)
* [Provision AWS infrastructure using Terraform (By HashiCorp): an example of web application logging customer data](https://aws.amazon.com/blogs/developer/provision-aws-infrastructure-using-terraform-by-hashicorp-an-example-of-web-application-logging-customer-data/)

 
