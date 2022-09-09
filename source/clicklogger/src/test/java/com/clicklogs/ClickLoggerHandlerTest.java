package com.clicklogs;

import com.amazonaws.services.kinesisfirehose.AmazonKinesisFirehose;
import com.amazonaws.services.kinesisfirehose.model.PutRecordRequest;
import com.amazonaws.services.kinesisfirehose.model.PutRecordResult;
import com.amazonaws.services.kinesisfirehose.model.Record;
import com.amazonaws.services.lambda.runtime.Context;
import com.clicklogs.Handlers.ClickLoggerHandler;
import com.clicklogs.model.ClickLogRequest;

import org.junit.Assert;
import java.nio.ByteBuffer;
import com.google.gson.Gson;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mockito;
import org.mockito.junit.MockitoJUnitRunner;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */
 
@RunWith(MockitoJUnitRunner.class)
public class ClickLoggerHandlerTest {
  
  private static String deliveryStreamName = "delivery-stream";
  Gson gson = new Gson();
  ClickLogRequest clickLogRequest = new ClickLogRequest();
  PutRecordRequest putRecordRequest = new PutRecordRequest();
  Record record = new Record();
  PutRecordResult putRecordResult = new PutRecordResult();

  Context context =  Mockito.mock(Context.class);
  
  protected AmazonKinesisFirehose amazonKinesisFirehoseClient = Mockito.mock(AmazonKinesisFirehose.class);
  ClickLoggerHandler clickLoggerHandler = Mockito.mock(ClickLoggerHandler.class);

  @Before
  public void setup() {
    clickLogRequest = new ClickLogRequest();
    clickLogRequest.setAction("ACTION");
    clickLogRequest.setCallerid("CALLERID");
    clickLogRequest.setClientip("CLIENTIP");
    clickLogRequest.setComponent("COMPONENT");
    clickLogRequest.setContextid("CONTEXTID");
    clickLogRequest.setCreatedtime("CREATEDTIME");
    clickLogRequest.setRequestid("REQUESTID");
    clickLogRequest.setType("TYPE");
    clickLogRequest.setUser("USER");

    when(clickLogRequest).thenReturn(this.clickLogRequest);

    amazonKinesisFirehoseClient = Mockito.mock(AmazonKinesisFirehose.class);
    when(amazonKinesisFirehoseClient).thenReturn(amazonKinesisFirehoseClient);

    putRecordResult = new PutRecordResult();
    putRecordResult.setRecordId("SUCCESS_RECORD_ID");
    when(any(PutRecordResult.class)).thenReturn(putRecordResult);
  }

  @Test
  void invokeTest() {
      clickLoggerHandler.handleRequest(clickLogRequest, context);
      
      putRecordRequest.setDeliveryStreamName(deliveryStreamName);

      Gson gson = new Gson();
      String messageJson = gson.toJson(clickLogRequest);
      System.out.println("gson - " + messageJson);
      record = new Record().withData(ByteBuffer.wrap(messageJson.toString().getBytes()));
      putRecordRequest.setRecord(record);
      
      amazonKinesisFirehoseClient = Mockito.mock(AmazonKinesisFirehose.class);
      PutRecordResult result = amazonKinesisFirehoseClient.putRecord( putRecordRequest );
      Assert.assertEquals(result.getRecordId(), "SUCCESS_RECORD_ID");
    
  }

}