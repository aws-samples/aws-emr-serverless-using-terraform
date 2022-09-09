package com.clicklogs.model;

import java.util.HashMap;
import java.util.Map;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */
 
public class ResponseBuilder {
    private static final String ACCESS_CONTROL_ALLOW_HEADERS = "Access-Control-Allow-Headers";

    private static final String ACCESS_CONTROL_ALLOW_ORIGIN = "Access-Control-Allow-Origin";

    private int statusCode;

    private Map<String, String> headers = new HashMap<>();

    private String body;

    public ResponseBuilder headers(Map<String, String> headers) {
        this.headers = headers;
        return this;
    }

    public ResponseBuilder body(String body) {
        this.body = body;
        return this;
    }

    public ResponseBuilder ok() {
        this.statusCode = 200;
        return this;
    }

    public ResponseBuilder badRequest(String body) {
        this.body = buildErrorMsg(body);
        this.statusCode = 400;
        return this;
    }

    private String buildErrorMsg(String body) {
        return "{\"message\": \"" + body + "\"}";
    }

    public ResponseBuilder originHeader(String domain) {
        headers.put(ACCESS_CONTROL_ALLOW_ORIGIN, domain);
        return this;
    }

    private void initDefaultHeaders() {
        headers.put(ACCESS_CONTROL_ALLOW_HEADERS, "Origin, Access-Control-Allow-Headers, X-Requested-With, Content-Type, Accept");
    }

    public ClickLogResponse build() {
        this.initDefaultHeaders();
        return new ClickLogResponse(statusCode, headers, body);
    }  
}