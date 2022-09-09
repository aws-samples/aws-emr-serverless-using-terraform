package com.examples.clicklogger

import org.apache.spark.{SparkConf, SparkContext, sql}
import org.apache.spark.sql.{DataFrameReader, SQLContext, SparkSession}
import java.lang.Boolean
import java.util
import java.io.IOException
import java.text.Format
import java.text.SimpleDateFormat
import java.util.Date

import com.amazonaws.AmazonServiceException
import com.amazonaws.SdkClientException
import com.amazonaws.services.s3.AmazonS3
import com.amazonaws.services.s3.AmazonS3ClientBuilder
import org.apache.commons.lang3.StringUtils


/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */
 
object Loggregator {

  private var sourceBucketName = ""
  private var outputBucketName = ""
  private var region = ""

  private var configMap = new util.HashMap[String, String]

  def main(args: Array[String]): Unit = {

    if (args.length != 3) {
      System.out.println("Invalid no of Arguments!!!")
      System.exit(-1)
    }

    val date = args(0)
    sourceBucketName = args(1)
    outputBucketName = args(2)

    System.out.println("Input Date " + date)
    region = scala.util.Properties.envOrElse("REGION", "us-east-1")

    System.out.format("values receive bucket_name %s, output_bucket_name %s \n", sourceBucketName, outputBucketName)

    val dataFrame = processFiles(date, sourceBucketName)
    System.out.println("")
    writeOutputToS3(date, dataFrame, outputBucketName)

    System.out.println("Completed successfully!")
  }

  private def writeOutputToS3(date: String, dataFrame: sql.DataFrame, outputBucketName: String): String = {
    var outputResponse: String = "|*createdTime*|*callerid*|*component*|*count*\n"

    if (dataFrame != null) {
      outputResponse = outputResponse + "|------------|-----------------------|-----------|-------\n"
      for (row <- dataFrame.rdd.collect) {
        val createdTime = row.mkString(",").split(",")(0)
        val callerid = row.mkString(",").split(",")(1)
        val component = row.mkString(",").split(",")(2)
        val count = row.mkString(",").split(",")(3)
        outputResponse = outputResponse + "*" + createdTime + "*|" + callerid + "|" + component + "|" + count + "\n"
      }
    }
    System.out.println("printing output schema from data frame")
    System.out.println(outputResponse)

    var f = new SimpleDateFormat("yyyy")
    var year = f.format(new Date())
    f = new SimpleDateFormat("MM")
    var month = f.format(new Date())
    f = new SimpleDateFormat("dd")
    var onlydate = f.format(new Date())

    // 2020-07-18
    if (date.length == 10) {
      val dateArr = date.split("-")
      year = dateArr(0)
      month = dateArr(1)
      onlydate = dateArr(2)
    }

    var fileObjKeyName = year + "/" + month + "/" + onlydate + "/"
    if (date.equalsIgnoreCase("ALL")) {
      fileObjKeyName = "ALL/" + year + "/" + month + "/" + onlydate + "/"
    }
    val fileName = "response.md"

    System.out.println("fileObjKeyName  " + fileObjKeyName + "   fileName  " + fileName)
    try {
      val s3Client = AmazonS3ClientBuilder.standard.build
      s3Client.putObject(outputBucketName, fileObjKeyName + fileName, outputResponse)
    } catch {
      case e: AmazonServiceException =>
        System.out.println(e.getMessage)
      case e: SdkClientException =>
        System.out.println(e.getMessage)
    }

    return outputResponse
  }


  def processFiles(date: String, bucket: String): sql.DataFrame = {
    System.out.println("processing a date - " + date + " from bucket - " + bucket)
    var s3Path = String.format("s3a://%s/clicklog/data=%s/", bucket, date)
    var spark = getSparkSession()
    val s3FolderDF = spark.read.parquet(s3Path)
    s3FolderDF.createOrReplaceTempView("ClickLoggerTable")
    return getClickLoggerDataFrame(spark)
  }

  def getClickLoggerDataFrame(spark: SparkSession): sql.DataFrame = {
    val sql = "select substring(createdTime,0, 10) as createdTime, callerid, component from ClickLoggerTable"

    val clickLoggerDF = spark.sql(sql)
    clickLoggerDF.groupBy("createdTime", "callerid", "component").count()
      .orderBy("createdTime", "callerid", "component")
      .show()

    // DO not printSchema in production
    clickLoggerDF.printSchema()

    System.out.println("DataFrame for date completed successfully ---------")
    return clickLoggerDF.groupBy("createdTime", "callerid", "component").count()
      .orderBy("createdTime", "callerid", "component")
  }

  def getSparkSession(): SparkSession = {
    System.out.println("starting spark session -------------")

    val sparkConfig = new SparkConf()
    //.setMaster("local[*]")
    //.setAppName("ClickLogger")
    val spark: SparkSession = SparkSession.builder()
      .config(conf = sparkConfig)
      .getOrCreate()
    val sparkContext: SparkContext = spark.sparkContext
    val hadoopConf = sparkContext.hadoopConfiguration
    hadoopConf.set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
    hadoopConf.set("fs.s3a.path.style.access", "true")
    hadoopConf.set("fs.s3a.endpoint", "s3." + region + ".amazonaws.com")
    return spark;
  }
}
