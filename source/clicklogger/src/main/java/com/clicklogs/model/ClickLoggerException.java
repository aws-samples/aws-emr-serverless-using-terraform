package com.clicklogs.model;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */

public class ClickLoggerException extends RuntimeException {
    public ClickLoggerException(String errorMessage) {
        super(errorMessage);
    }

    public ClickLoggerException(String errorMessage, Throwable cause) {
        super(errorMessage, cause);
    }
}
