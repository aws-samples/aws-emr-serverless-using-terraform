package com.clicklogs.Handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.clicklogs.model.JobStatusRequest;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.services.emrserverless.EmrServerlessClient;
import software.amazon.awssdk.services.emrserverless.model.*;
import com.clicklogs.model.ClickLogResponse;
import com.clicklogs.model.ResponseBuilder;
import com.clicklogs.model.ClickLoggerException;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import org.apache.commons.lang3.StringUtils;

import java.lang.Thread;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */

public class ClickLoggerEMRJobHandler implements RequestHandler<JobStatusRequest, ClickLogResponse> {

    Gson gson = new GsonBuilder().setPrettyPrinting().create();
    LambdaLogger logger = null;
    private String applicationId = "";
    private String logsOutputPath = "";
    private Integer emrJobTimout = 5000;

    @Override
    public ClickLogResponse handleRequest(final JobStatusRequest jobStatusRequest, final Context context) {
        logger = context.getLogger();
        final String success_response = new String("200 OK");
        final String fail_response = new String("400 ERROR");

        ResponseBuilder responseBuilder = new ResponseBuilder();
        ClickLogResponse response = responseBuilder.badRequest(fail_response).build();

        logger.log("Incoming request - " + gson.toJson(jobStatusRequest));

        String envAppId = System.getenv("APPLICATION_ID");
        if (!StringUtils.isBlank(envAppId)) {
            applicationId = envAppId;
        }

        String envLogsOutputBucket = System.getenv("LOGS_OUTPUT_PATH");
        if (!StringUtils.isBlank(envLogsOutputBucket)) {
            logsOutputPath = envLogsOutputBucket;
        }

        emrJobTimout = Integer.parseInt(System.getenv("EMR_GET_SLEEP_TIME"));

        String jobRunId = "";
        if (!StringUtils.isBlank(jobStatusRequest.getJobRunId())) {
            jobRunId = jobStatusRequest.getJobRunId();
        }

        logger.log("Checking EMR Serverless job status for Job Run ID: " + jobRunId);

        try {
            CheckEMRJobStatus(applicationId, emrJobTimout, jobRunId);
        } catch (InterruptedException e) {
            logger.log("Error occurred checking EMR Job status.");
            throw new ClickLoggerException("Error occurred checking EMR Job status.");
        }
        logger.log("Stopping application");
        stopApplication(applicationId);
        logger.log(success_response);
        responseBuilder = new ResponseBuilder();
        responseBuilder.ok();
        response = responseBuilder.originHeader("*").build();
        logger.log("Returning response " + gson.toJson(response));
        return response;
    }

    private void CheckEMRJobStatus(String applicationId, Integer emrJobTimout, String jobRunId) throws InterruptedException {
        EmrServerlessClient client = getClient();
        GetJobRunRequest getJobRunRequest = GetJobRunRequest.builder()
                .applicationId(applicationId)
                .jobRunId(jobRunId)
                .build();
        GetJobRunResponse jobRunResponse = client.getJobRun(getJobRunRequest);

        while (true) {
            Thread.sleep(emrJobTimout);
            jobRunResponse = client.getJobRun(getJobRunRequest);

            if (jobRunResponse != null) {
                JobRunState jobState = jobRunResponse.jobRun().state();
                if (jobState.name().equals("SUCCESS") || jobState.name().equals("FAILED") ||
                        jobState.name().equals("CANCELLING") || jobState.name().equals("CANCELLED")) {
                    logger.log("Job Completed!!");
                    break;
                }
            }
        }
    }

    private StopApplicationResponse stopApplication(String applicationId) {
        EmrServerlessClient client = getClient();
        StopApplicationRequest stopApp = StopApplicationRequest.builder().applicationId(applicationId).build();
        return client.stopApplication(stopApp);
    }

    private EmrServerlessClient getClient() {
        return EmrServerlessClient.builder()
                .credentialsProvider(DefaultCredentialsProvider.create())
                .httpClient(UrlConnectionHttpClient.builder().build())
                .build();
    }
}