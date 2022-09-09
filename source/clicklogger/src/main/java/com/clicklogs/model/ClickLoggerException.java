package com.clicklogs.model;

import java.lang.RuntimeException;

public class ClickLoggerException extends RuntimeException { 
    public ClickLoggerException(String errorMessage) {
        super(errorMessage);
    }
}