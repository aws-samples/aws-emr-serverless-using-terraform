package com.clicklogs.Handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.clicklogs.model.ClickLogRequest;
import com.clicklogs.model.ClickLogResponse;
import com.clicklogs.model.ClickLoggerException;
import com.clicklogs.model.ResponseBuilder;
import com.google.gson.Gson;
import org.apache.commons.lang3.StringUtils;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.services.firehose.FirehoseClient;
import software.amazon.awssdk.services.firehose.model.PutRecordRequest;
import software.amazon.awssdk.services.firehose.model.PutRecordResponse;
import software.amazon.awssdk.services.firehose.model.Record;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */

public class ClickLoggerHandler implements RequestHandler<ClickLogRequest, ClickLogResponse> {

    private static final String DEFAULT_STREAM_NAME = "click-logger-firehose-delivery-stream";
    // Must stay MM-dd-yyyy: the Spark job groups on the first 10 characters of createdtime.
    private static final DateTimeFormatter CREATED_TIME_FORMAT = DateTimeFormatter.ofPattern("MM-dd-yyyy HH:mm:ss");
    private static final Gson GSON = new Gson();

    private final FirehoseClient firehoseClient;
    private final String streamName;

    /** Used by the Lambda runtime. The client is created once per execution environment and reused. */
    public ClickLoggerHandler() {
        this(FirehoseClient.builder()
                        .httpClient(UrlConnectionHttpClient.create())
                        .build(),
                StringUtils.defaultIfBlank(System.getenv("STREAM_NAME"), DEFAULT_STREAM_NAME));
    }

    /** Allows tests to inject a client. */
    public ClickLoggerHandler(FirehoseClient firehoseClient, String streamName) {
        this.firehoseClient = firehoseClient;
        this.streamName = streamName;
    }

    @Override
    public ClickLogResponse handleRequest(final ClickLogRequest clickLogRequest, final Context context) {
        final LambdaLogger logger = context.getLogger();

        String validationError = validateRequest(clickLogRequest);
        if (validationError != null) {
            logger.log("Rejected request: " + validationError);
            return new ResponseBuilder().badRequest(validationError).build();
        }
        applyDefaults(clickLogRequest);

        String messageJson = GSON.toJson(clickLogRequest);
        try {
            PutRecordResponse result = firehoseClient.putRecord(PutRecordRequest.builder()
                    .deliveryStreamName(streamName)
                    .record(Record.builder()
                            .data(SdkBytes.fromString(messageJson, StandardCharsets.UTF_8))
                            .build())
                    .build());
            logger.log("Delivered record " + result.recordId() + " for request " + clickLogRequest.getRequestid());
        } catch (SdkException e) {
            // Fail the invocation so the caller (or Lambda retry/DLQ settings) sees the error.
            throw new ClickLoggerException("Failed to write click log to Firehose: " + e.getMessage(), e);
        }

        return new ResponseBuilder().ok().originHeader("*").build();
    }

    static String validateRequest(ClickLogRequest request) {
        if (request == null) return "request body missing";
        if (StringUtils.isBlank(request.getRequestid())) return "requestid missing";
        if (StringUtils.isBlank(request.getContextid())) return "contextid missing";
        if (StringUtils.isBlank(request.getCallerid())) return "callerid missing";
        if (StringUtils.isBlank(request.getType())) return "type missing";
        if (StringUtils.isBlank(request.getAction())) return "action missing";
        if (StringUtils.isBlank(request.getComponent())) return "component missing";
        return null;
    }

    private static void applyDefaults(ClickLogRequest request) {
        if (StringUtils.isBlank(request.getUser())) {
            request.setUser("GUEST");
        }
        if (StringUtils.isBlank(request.getClientip())) {
            request.setClientip("APIGWY");
        }
        if (StringUtils.isBlank(request.getCreatedtime())) {
            request.setCreatedtime(LocalDateTime.now().format(CREATED_TIME_FORMAT));
        }
    }
}
