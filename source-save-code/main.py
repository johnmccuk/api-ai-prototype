#!/usr/bin/env python
import json
import os
import boto3

s3 = boto3.resource('s3')


def lambda_handler(event, context):
    "Save the passed data to an S3 bucket"

    filename = context.aws_request_id + ".tf"
    filepath = "/tmp/" + filename

    fp = open(filepath, 'w')
    fp.write(event['choices'][0]['text'])
    fp.close()

    s3.Bucket(os.environ["BUCKET"]).upload_file(filepath, filename)

    return filepath
