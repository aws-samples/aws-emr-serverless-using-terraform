package com.clicklogs;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.clicklogs.Handlers.ClickLoggerHandler;
import com.clicklogs.model.ClickLogRequest;
import com.clicklogs.model.ClickLogResponse;
import com.clicklogs.model.ClickLoggerException;
import com.google.gson.Gson;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import software.amazon.awssdk.services.firehose.FirehoseClient;
import software.amazon.awssdk.services.firehose.model.FirehoseException;
import software.amazon.awssdk.services.firehose.model.PutRecordRequest;
import software.amazon.awssdk.services.firehose.model.PutRecordResponse;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */

class ClickLoggerHandlerTest {

    private static final String STREAM = "delivery-stream";

    private FirehoseClient firehose;
    private Context context;
    private ClickLoggerHandler handler;

    @BeforeEach
    void setup() {
        firehose = mock(FirehoseClient.class);
        context = mock(Context.class);
        when(context.getLogger()).thenReturn(mock(LambdaLogger.class));
        handler = new ClickLoggerHandler(firehose, STREAM);
    }

    private static ClickLogRequest validRequest() {
        ClickLogRequest request = new ClickLogRequest();
        request.setRequestid("REQUESTID");
        request.setContextid("CONTEXTID");
        request.setCallerid("CALLERID");
        request.setComponent("COMPONENT");
        request.setAction("ACTION");
        request.setType("TYPE");
        return request;
    }

    @Test
    void validRequestIsWrittenToFirehoseWithDefaults() {
        when(firehose.putRecord(any(PutRecordRequest.class)))
                .thenReturn(PutRecordResponse.builder().recordId("SUCCESS_RECORD_ID").build());

        ClickLogResponse response = handler.handleRequest(validRequest(), context);

        assertEquals(200, response.getStatusCode());
        ArgumentCaptor<PutRecordRequest> captor = ArgumentCaptor.forClass(PutRecordRequest.class);
        verify(firehose).putRecord(captor.capture());
        assertEquals(STREAM, captor.getValue().deliveryStreamName());

        ClickLogRequest sent = new Gson().fromJson(
                captor.getValue().record().data().asString(StandardCharsets.UTF_8), ClickLogRequest.class);
        assertEquals("REQUESTID", sent.getRequestid());
        assertEquals("GUEST", sent.getUser());
        assertEquals("APIGWY", sent.getClientip());
        assertNotNull(sent.getCreatedtime());
        // Spark job groups on substring(createdtime, 0, 10), which must be the MM-dd-yyyy date.
        assertEquals(19, sent.getCreatedtime().length());
    }

    @Test
    void missingRequiredFieldReturns400AndDoesNotCallFirehose() {
        ClickLogRequest request = validRequest();
        request.setCallerid(" ");

        ClickLogResponse response = handler.handleRequest(request, context);

        assertEquals(400, response.getStatusCode());
        verify(firehose, never()).putRecord(any(PutRecordRequest.class));
    }

    @Test
    void firehoseFailureFailsTheInvocation() {
        when(firehose.putRecord(any(PutRecordRequest.class)))
                .thenThrow(FirehoseException.builder().message("throttled").build());

        assertThrows(ClickLoggerException.class, () -> handler.handleRequest(validRequest(), context));
    }
}
