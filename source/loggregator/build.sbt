name := "loggregator"

version := "0.1"

// Matches the Scala version of Apache Spark 3.5.x on Amazon EMR 7.x
scalaVersion := "2.12.18"

// Spark 3.5.8 ships with EMR Serverless emr-7.14.0. Spark and Hadoop are supplied by
// the EMR runtime, so they are "provided" and not bundled into the job jar.
val sparkVersion = "3.5.8"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql"  % sparkVersion % "provided"
)

Compile / mainClass := Some("com.examples.clicklogger.Loggregator")
