package com.clicklogs.Handlers;

import com.amazonaws.services.kinesisfirehose.model.Record;
import com.amazonaws.services.kinesisfirehose.AmazonKinesisFirehose;
import com.amazonaws.services.kinesisfirehose.AmazonKinesisFirehoseClientBuilder;
import com.amazonaws.services.kinesisfirehose.model.PutRecordRequest;
import com.amazonaws.services.kinesisfirehose.model.PutRecordResult;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.LambdaLogger;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import org.apache.commons.lang3.StringUtils;

import java.nio.ByteBuffer;
import java.text.Format;
import java.text.SimpleDateFormat;
import java.util.Date;

import com.clicklogs.model.ClickLogRequest;
import com.clicklogs.model.ClickLogResponse;
import com.clicklogs.model.ResponseBuilder;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */
 
public class ClickLoggerHandler implements RequestHandler<ClickLogRequest, ClickLogResponse> {

    private String stream_name = "click-logger-firehose-delivery-stream";
    private String region = "us-east-1";

    Gson gson = new GsonBuilder().setPrettyPrinting().create();

    @Override
    public ClickLogResponse handleRequest(final ClickLogRequest clickLogRequest, final Context context) {
        final LambdaLogger logger = context.getLogger();
        final String success_response = new String("200 OK");
        final String fail_response = new String("400 ERROR");

        ResponseBuilder responseBuilder = new ResponseBuilder();
        ClickLogResponse response = responseBuilder.badRequest(fail_response).build();


        String env_stream_name = System.getenv("STREAM_NAME");
        if (!StringUtils.isBlank(env_stream_name)) {
            stream_name = env_stream_name;
        }

        String env_region = System.getenv("REGION");
        logger.log("Environment region name - " + env_region);
        if (!StringUtils.isBlank(env_region)) {
            region = env_region;
        }
        if (clickLogRequest != null) {
            String req = clickLogRequest.getRequestid() + " - " + clickLogRequest.getCallerid() + "  - "
                    + clickLogRequest.getComponent() + " - " + clickLogRequest.getType() + " - " + clickLogRequest.getAction()
                    + " - " + clickLogRequest.getUser() + " - " + clickLogRequest.getClientip() + " - "
                    + clickLogRequest.getCreatedtime();
            logger.log("Incoming request variables - " + req);

            if (validateRequest(clickLogRequest, logger, response)) return response;
        }

        System.out.println("Calling updateclicklogs method for the received clicklogrequest");

        updateClickLogRequestToStream(clickLogRequest);
        logger.log(success_response);
        responseBuilder = new ResponseBuilder();
        responseBuilder.ok();
        response = responseBuilder.originHeader("*").build();
        return response;
    }

    private boolean validateRequest(ClickLogRequest clickLogRequest, LambdaLogger logger, ClickLogResponse response) {
        logger.log("Validating inputs");
        if (StringUtils.isBlank(clickLogRequest.getRequestid())) {
            logger.log("error occurred - requestid missing");
            return true;
        }
        if (StringUtils.isBlank(clickLogRequest.getContextid())) {
            logger.log("error occurred - contextid missing");
            return true;
        }
        if (StringUtils.isBlank(clickLogRequest.getCallerid())) {
            logger.log("error occurred - caller missing");
            return true;
        }
        if (StringUtils.isBlank(clickLogRequest.getType())) {
            logger.log("error occurred - type missing");
            return true;
        }
        if (StringUtils.isBlank(clickLogRequest.getAction())) {
            logger.log("error occurred - action missing");
            return true;
        }
        if (StringUtils.isBlank(clickLogRequest.getComponent())) {
            logger.log("error occurred - component missing");
            return true;
        }

        String user = "GUEST";
        if (StringUtils.isBlank(clickLogRequest.getUser())) {
            logger.log("setting default user");
            clickLogRequest.setUser(user);
        }

        String clientip = "APIGWY";
        if (StringUtils.isBlank(clickLogRequest.getClientip())) {
            logger.log("setting default clientip");
            clickLogRequest.setClientip(clientip);
        }

        String datetime = "";
        if (StringUtils.isBlank(clickLogRequest.getCreatedtime())) {
            logger.log("setting default createdtime");
            Format f = new SimpleDateFormat("MM-dd-yyyy hh:mm:ss");
            datetime = f.format(new Date());
            clickLogRequest.setCreatedtime(datetime);
        }
        logger.log("Validated inputs");
        return false;
    }

    private Boolean updateClickLogRequestToStream(ClickLogRequest clickLogRequest) {
        System.out.println("Inside updateClickLogRequestToStream method for the input");
        try {

            AmazonKinesisFirehose amazonKinesisFirehoseClient = AmazonKinesisFirehoseClientBuilder.standard().withRegion(region).build();

            PutRecordRequest putRecordRequest = new PutRecordRequest();
            putRecordRequest.setDeliveryStreamName(stream_name);
            Gson gson = new Gson();
            String messageJson = gson.toJson(clickLogRequest);
            System.out.println("gson - " + messageJson);
            Record record = new Record().withData(ByteBuffer.wrap(messageJson.toString().getBytes()));
            putRecordRequest.setRecord(record);
            PutRecordResult putRecordResult = amazonKinesisFirehoseClient.putRecord(putRecordRequest);
            System.out.println("updated the stream for recordid - " + putRecordResult.getRecordId());
            return true;
        } catch (Exception e) {
            System.out.println("Error occurred - " + e.getMessage());
        }
        return false;
    }

}