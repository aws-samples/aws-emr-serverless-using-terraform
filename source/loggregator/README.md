# Loggregator Spark job

Build (requires sbt 1.11+ and a JDK 17 or 21):

```
sbt clean package
# -> target/scala-2.12/loggregator_2.12-0.1.jar
```

Run on EMR Serverless (the Step Functions workflow does this for you):

```
aws emr-serverless start-job-run \
  --application-id <application-id> \
  --execution-role-arn <job-execution-role-arn> \
  --job-driver '{"sparkSubmit": {
      "entryPoint": "s3://<source-bucket>/loggregator-0-0.1.jar",
      "entryPointArguments": ["2026-11-04", "<firehose-delivery-bucket>", "<output-bucket>"],
      "sparkSubmitParameters": "--class com.examples.clicklogger.Loggregator"}}'
```
