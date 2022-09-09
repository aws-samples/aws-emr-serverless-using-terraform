package com.clicklogs.model;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */
 
public class ClickLogRequest {

    public String requestid;
    public String contextid;
    public String callerid;
    public String type;
    public String component;
    public String action;
    public String user;
    public String clientip;
    public String createdtime;

    public String getRequestid() {
        return requestid;
    }

    public String getContextid() {
        return contextid;
    }

    public String getCallerid() {
        return callerid;
    }

    public String getType() {
        return type;
    }

    public String getComponent() {
        return component;
    }

    public String getAction() {
        return action;
    }

    public String getCreatedtime() {
        return createdtime;
    }

    public String getUser() {
        return user;
    }

    public String getClientip() {
        return clientip;
    }

    public void setRequestid(String requestid) {
        this.requestid = requestid;
    }

    public void setContextid(String contextid) {
        this.contextid = contextid;
    }

    public void setCallerid(String callerid) {
        this.callerid = callerid;
    }

    public void setType(String type) {
        this.type = type;
    }

    
    public void setComponent(String component) {
        this.component = component;
    }

    public void setAction(String action) {
        this.action = action;
    }

    public void setCreatedtime(String createdtime) {
        this.createdtime = createdtime;
    }

    public void setUser(String user) {
        this.user = user;
    }

    public void setClientip(String clientip) {
        this.clientip = clientip;
    }

}