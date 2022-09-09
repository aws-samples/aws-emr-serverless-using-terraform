## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_glue_catalog_database" "aws_glue_click_logger_database" {
  name = "${var.app_prefix}${var.stage_name}database"
  description = "Click logger Glue database"
}

resource "aws_glue_catalog_table" "aws_glue_click_logger_catalog_table" {
  name          = "${var.app_prefix}${var.stage_name}-table"
  database_name = "${var.app_prefix}${var.stage_name}database"
  depends_on    = [aws_glue_catalog_database.aws_glue_click_logger_database, aws_s3_bucket.click_logger_firehose_delivery_s3_bucket]

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  retention = 0
  
  storage_descriptor {
    location = aws_s3_bucket.click_logger_firehose_delivery_s3_bucket.arn
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    compressed    = false
    parameters = {
        "crawler_schema_serializer_version" = "1.0"
        "crawler_schema_deserializer_version" = "1.0"
        "compression_type" = "none"
        "classification" = "json"
        "type_of_data" = "file"
    }
    ser_de_info {
      name                  = "${var.app_prefix}table"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"

      parameters = {
        "serialization.format" = 1
      }
    }

    columns {
      name = "requestid"
      type = "string"
    }

    columns {
      name = "contextid"
      type = "string"
    }

    columns {
      name    = "callerid"
      type    = "string"
      comment = ""
    }

    columns {
      name    = "component"
      type    = "string"
      comment = ""
    }

    columns {
      name    = "action"
      type    = "string"
      comment = ""
    }
    
    columns {
      name    = "type"
      type    = "string"
      comment = ""
    }

    columns {
      name    = "clientip"
      type    = "string"
      comment = ""
    }

    columns {
      name    = "createdtime"
      type    = "string"
      comment = ""
    }
  }
}