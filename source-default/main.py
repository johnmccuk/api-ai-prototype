#!/usr/bin/env python
# import sys
# import logging
import json

'''
Put any pip installs in the requirements.txt file
'''

# logging.info("Cached code goes here")


def lambda_handler(event, context):
    "Endpoint validator and starts Step Function"

    statusCode = 422
    body = json.loads(event["body"])

    if "phrase" not in body:
        returnBody = {"error": "phrase field missing"}

    elif type(body["phrase"]) != list:
        returnBody = {"error": "phrase field must be a list"}

    elif len(body["phrase"]) < 3:
        returnBody = {"error": "phrase field must contain at least 3 phrases"}
    else:
        statusCode = 202
        returnBody = {"message": "generation process started"}

    return {
        "statusCode": statusCode,
        "body": json.dumps(returnBody),
        "headers": {
            "Content-Type": "application/json"
        }
    }
