package com.clicklogs.Handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.clicklogs.model.StartJobRequest;
import software.amazon.awssdk.regions.Region;
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
import java.text.Format;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;

/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT-0
 */
 
public class ClickLoggerEMRJobHandler implements RequestHandler<StartJobRequest, ClickLogResponse>{

  private String applicationName = "clicklogger-dev-emr-serverless-application";
  private String applicationId = "";
  private String executionRoleArn = "";
  private String entrypoint = "";
  private String mainClass = "";
  private String outputBucket = "";
  private String sourceBucket = "";
  private String logsOutputPath = "";
  private Integer emrJobTimout = 5000;

  Gson gson = new GsonBuilder().setPrettyPrinting().create();

  LambdaLogger logger = null;
  @Override
  public ClickLogResponse handleRequest(final StartJobRequest startJobRequest, final Context context) {
    logger = context.getLogger();
    final String success_response = new String("200 OK");
    final String fail_response = new String("400 ERROR");

    ResponseBuilder responseBuilder = new ResponseBuilder();
    ClickLogResponse response = responseBuilder.badRequest(fail_response).build();


    logger.log("Incoming request - " + gson.toJson(startJobRequest));

    String envAppName = System.getenv("APPLICATION_NAME");
    if(!StringUtils.isBlank(envAppName))
    {
      applicationName = envAppName;
    }

    String envAppId = System.getenv("APPLICATION_ID");
    if(!StringUtils.isBlank(envAppId))
    {
      applicationId = envAppId;
    }

    String envExecRole = System.getenv("EXECUTION_ROLE_ARN");
    if(!StringUtils.isBlank(envExecRole))
    {
      executionRoleArn = envExecRole;
    }

    String envEntryPoint = System.getenv("ENTRY_POINT");
    if(!StringUtils.isBlank(envEntryPoint))
    {
      entrypoint = envEntryPoint;
    }

    String envMainClass = System.getenv("MAIN_CLASS");
    if(!StringUtils.isBlank(envMainClass))
    {
      mainClass = envMainClass;
    }

    String envOutputBucket = System.getenv("OUTPUT_BUCKET");
    if(!StringUtils.isBlank(envOutputBucket))
    {
      outputBucket = envOutputBucket;
    }

    String envSourceBucket = System.getenv("SOURCE_BUCKET");
    if(!StringUtils.isBlank(envSourceBucket))
    {
      sourceBucket = envSourceBucket;
    }

    String envLogsOutputBucket = System.getenv("LOGS_OUTPUT_PATH");
    if(!StringUtils.isBlank(envLogsOutputBucket))
    {
      logsOutputPath = envLogsOutputBucket;
    }

    emrJobTimout = Integer.parseInt(System.getenv("EMR_GET_SLEEP_TIME"));
    
    String datetime = "";
    if (startJobRequest == null ||
            (startJobRequest != null && StringUtils.isBlank(startJobRequest.getDate()))) {
      logger.log("setting default createdtime");
      Format f = new SimpleDateFormat("yyyy-MM-dd");
      datetime = f.format(new Date());
    }
    else{
      datetime = startJobRequest.getDate();
    }

    logger.log("Starting EMR Serverless job for the date - "+ datetime);

    try {
      startEMRJobRun(datetime, applicationId, applicationName,
                      executionRoleArn, mainClass,
                      entrypoint, sourceBucket, outputBucket, emrJobTimout);
    } catch (InterruptedException e) {
      logger.log("Error occurred starting EMR Job");      
      throw new ClickLoggerException("Error occurred starting EMR Job");
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

  private void startEMRJobRun(String inputDate,
                              String applicationId, String applicationName, String executionRoleArn,
                              String mainClass, String entrypoint, String sourceBucket,
                              String outputBucket, Integer emrJobTimout) throws InterruptedException {
    EmrServerlessClient client = getClient();

    S3MonitoringConfiguration s3MonitoringConfiguration = S3MonitoringConfiguration.builder().logUri(logsOutputPath).build();
    StartJobRunRequest jobRunRequest = StartJobRunRequest.builder()
            .name(applicationName)
            .applicationId(applicationId)
            .executionRoleArn(executionRoleArn)
            .jobDriver(
                    JobDriver.fromSparkSubmit(SparkSubmit.builder()
                            .entryPoint(entrypoint)
                            .entryPointArguments(Arrays.asList(inputDate, sourceBucket, outputBucket))
                            .sparkSubmitParameters(mainClass)
                            .build())
            )
            .configurationOverrides(ConfigurationOverrides.builder()
                    .monitoringConfiguration(MonitoringConfiguration.builder()
                            .s3MonitoringConfiguration(s3MonitoringConfiguration)
                            .build()).build()
                    .toBuilder().build()).build();

    logger.log("Starting job run");
    StartJobRunResponse  response = client.startJobRun(jobRunRequest);

    String jobRunId = response.jobRunId();
    GetJobRunRequest getJobRunRequest = GetJobRunRequest.builder()
            .applicationId(applicationId)
            .jobRunId(jobRunId)
            .build();
    GetJobRunResponse jobRunResponse  = client.getJobRun(getJobRunRequest);

    while(true){
      Thread.sleep(emrJobTimout);
      jobRunResponse  = client.getJobRun(getJobRunRequest);

      if(jobRunResponse != null){
        JobRunState jobState = jobRunResponse.jobRun().state();
        if(jobState.name().equals("SUCCESS") || jobState.name().equals("FAILED") ||
                jobState.name().equals("CANCELLING") || jobState.name().equals("CANCELLED")){
          logger.log("Job Completed Successfully!");
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