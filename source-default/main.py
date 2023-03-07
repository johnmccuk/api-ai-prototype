#!/usr/bin/env python
# import sys
# import logging
import json
import os
import boto3

'''
Put any pip installs in the requirements.txt file
'''

# logging.info("Cached code goes here")

client = boto3.client('stepfunctions')

description_length = 100


def lambda_handler(event, context):
    "Endpoint validator and starts Step Function"

    statusCode = 422
    body = json.loads(event["body"])

    if "description" not in body:
        returnBody = {"error": "description field missing"}

    elif len(body["description"]) > description_length:
        returnBody = {"error": "phrase field must less than " +
                      str(description_length) + " chars"}

    else:
        statusCode = 202
        returnBody = {"message": "generation process started"}
        response = client.start_execution(
            stateMachineArn=os.environ["STEP_ARN"],
            name=context.aws_request_id,
            input=event["body"]
        )

    return {
        "statusCode": statusCode,
        "body": json.dumps(returnBody),
        "headers": {
            "Content-Type": "application/json"
        }
    }
