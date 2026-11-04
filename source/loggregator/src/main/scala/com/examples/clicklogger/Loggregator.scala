package com.examples.clicklogger

import java.nio.charset.StandardCharsets
import java.time.LocalDate

import org.apache.hadoop.fs.Path
import org.apache.spark.sql.{DataFrame, SparkSession}

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */

/**
 * Aggregates a day of click logs (Parquet, written by Amazon Data Firehose) into a
 * Markdown report.
 *
 * Arguments: <yyyy-MM-dd | ALL> <firehose-delivery-bucket> <output-bucket>
 *
 * S3 access uses the EMR S3 file system (s3://) provided by the EMR Serverless runtime,
 * so the job doesn't bundle an AWS SDK and needs no S3 endpoint or credentials setup.
 * Any failure raises an exception, which fails the job run and the Step Functions task.
 */
object Loggregator {

  def main(args: Array[String]): Unit = {
    require(args.length == 3, "Usage: Loggregator <yyyy-MM-dd|ALL> <source-bucket> <output-bucket>")
    val Array(date, sourceBucket, outputBucket) = args

    val spark = SparkSession.builder().appName("Loggregator").getOrCreate()
    try {
      val aggregated = aggregate(spark, inputPath(date, sourceBucket))
      aggregated.show(truncate = false)

      val report = toMarkdown(aggregated)
      val outputKey = s"${outputPrefix(date)}response.md"
      writeText(spark, new Path(s"s3://$outputBucket/$outputKey"), report)
      println(s"Wrote report to s3://$outputBucket/$outputKey")
    } finally {
      spark.stop()
    }
  }

  private def inputPath(date: String, bucket: String): String =
    if (date.equalsIgnoreCase("ALL")) s"s3://$bucket/clicklog/"
    else s"s3://$bucket/clicklog/data=$date/"

  /** yyyy/MM/dd/ for a specific date, or ALL/yyyy/MM/dd/ (today) for a full run. */
  private def outputPrefix(date: String): String = {
    if (date.equalsIgnoreCase("ALL")) {
      val today = LocalDate.now()
      f"ALL/${today.getYear}%04d/${today.getMonthValue}%02d/${today.getDayOfMonth}%02d/"
    } else {
      val d = LocalDate.parse(date)
      f"${d.getYear}%04d/${d.getMonthValue}%02d/${d.getDayOfMonth}%02d/"
    }
  }

  def aggregate(spark: SparkSession, path: String): DataFrame = {
    spark.read.parquet(path).createOrReplaceTempView("ClickLoggerTable")
    spark.sql(
      """SELECT substring(createdtime, 0, 10) AS createdTime, callerid, component, count(*) AS count
        |FROM ClickLoggerTable
        |GROUP BY 1, 2, 3
        |ORDER BY 1, 2, 3""".stripMargin)
  }

  def toMarkdown(df: DataFrame): String = {
    val header = "|*createdTime*|*callerid*|*component*|*count*\n" +
      "|------------|-----------------------|-----------|-------\n"
    val rows = df.collect().map { r =>
      s"*${r.getString(0)}*|${r.getString(1)}|${r.getString(2)}|${r.getLong(3)}\n"
    }
    header + rows.mkString
  }

  private def writeText(spark: SparkSession, path: Path, content: String): Unit = {
    val fs = path.getFileSystem(spark.sparkContext.hadoopConfiguration)
    val out = fs.create(path, true)
    try out.write(content.getBytes(StandardCharsets.UTF_8))
    finally out.close()
  }
}
