name := "loggregator"

version := "0.1"


scalaVersion := "2.12.1"

lazy val root = (project in file(".")).
  settings(
    name := "loggregator",
    version := "0.1",
    maintainer := "shiva.ramani@live.com",
    mainClass in Compile := Some("com.examples.clicklogger.Loggregator")
  )

val sparkVersion = "3.2.0"
val hadoopVersion = "3.2.0"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion,
  "org.apache.spark" %% "spark-sql" % sparkVersion,
  "org.apache.hadoop" % "hadoop-client" % hadoopVersion,
  "org.apache.hadoop" % "hadoop-aws" % hadoopVersion,
  "org.apache.commons" % "commons-lang3" % "3.10",
  "com.amazonaws" % "aws-java-sdk-s3" % "1.12.262",
  "io.netty" % "netty-buffer" % "4.1.17.Final"

)

val meta = """META.INF(.)*""".r
assemblyMergeStrategy in assembly := {
  case PathList("javax", "servlet", xs @ _*) => MergeStrategy.first
  case PathList(ps @ _*) if ps.last endsWith ".html" => MergeStrategy.first
  case n if n.contains("services") => MergeStrategy.concat
  case n if n.startsWith("reference.conf") => MergeStrategy.concat
  case n if n.endsWith(".conf") => MergeStrategy.concat
  case meta(_) => MergeStrategy.discard
  case x => MergeStrategy.first
  /*case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first*/
}

enablePlugins(JavaAppPackaging)