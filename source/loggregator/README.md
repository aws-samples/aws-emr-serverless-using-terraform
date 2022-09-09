$ sbt reload

$ sbt compile

$ sbt package

$ java -jar target/scala-2.13/loggregator-assembly-0.1.jar  com.examples.clicklogger "2020-06-15"  "clicklogger-dev-firehose-delivery-bucket-<your-account-number>" "clicklogger-dev-loggregator-output-bucket-<your-account-number>"

$ emr console

- command-runner.jar
- spark-submit --deploy-mode client --class com.examples.clicklogger.Loggregator s3://clicklogger-emr-source/loggregator-assembly-0.1.jar 2022-07-18 clicklogger-dev-firehose-delivery-bucket-<your-account-number> clicklogger-dev-loggregator-output-bucket-<your-account-number>
