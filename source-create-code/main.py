#!/usr/bin/env python
import json
import os
from urllib import request, parse


def lambda_handler(event, context):
    "Call the open AI endpoint to generate psuedo code"
    """
    temp = {
        "id": "cmpl-6rOy2uJSOZQgauiarQqXCaslpRZZE",
        "object": "text_completion",
        "created": 1678185378,
        "model": "text-davinci-003",
        "choices": [
            {
                "text": "\n\nresource \"aws_lambda_function\" \"hello_world\" {\n  filename         = \"lambda_function_payload.zip\"\n  function_name    = \"hello_world\"\n  role             = aws_iam_role.iam_for_lambda.arn\n  handler          = \"index.handler\"\n  source_code_hash = filebase64sha256(\"lambda_function_payload.zip\")\n  runtime          = \"nodejs12.x\"\n  timeout          = 15\n  environment {\n    variables = {\n      message = \"Hello World!\"\n    }\n  }\n}\n\nresource \"aws_iam_role\" \"iam_for_lambda\" {\n  name = \"iam_for_lambda\"\n\n  assume_role_policy = <<EOF\n{\n  \"Version\": \"2012-10-17\",\n  \"Statement\": [\n    {\n      \"Action\": \"sts:AssumeRole\",\n      \"Principal\": {\n        \"Service\": \"lambda.amazonaws.com\"\n      },\n      \"Effect\": \"Allow\",\n      \"Sid\": \"\"\n    }\n  ]\n}\nEOF\n}\n\nresource \"aws_iam_role_policy\" \"lambda\" {\n  name = \"lambda\"\n  role = aws_iam_role.iam_for_lambda.id\n\n  policy = <<EOF\n{\n    \"Version\": \"2012-10-17\",\n    \"Statement\": [\n        {\n            \"Effect\": \"Allow\",\n            \"Action\": [\n                \"logs:CreateLogGroup\",\n                \"logs:CreateLogStream\",\n                \"logs:PutLogEvents\"\n            ],\n            \"Resource\": \"arn:aws:logs:*:*:*\"\n        }\n    ]\n}\nEOF\n}",
                "index": 0,
                "logprobs": '',
                "finish_reason": "stop"
            }
        ],
        "usage": {
            "prompt_tokens": 14,
            "completion_tokens": 412,
            "total_tokens": 426
        }
    }
    return temp
    """

    url = "https://api.openai.com/v1/completions"
    key = os.environ["OPEN_AI_KEY"]
    org = os.environ["OPEN_AI_ORG"]
    model = os.environ["OPEN_AI_TEXT_MODEL"]

    psuedoCode = "create a terraform file to create a " + event['description']

    body = {
        "model": model,
        "prompt": psuedoCode,
        "temperature": 0,
        "max_tokens": 4000 - len(psuedoCode)
    }

    print(body)
    data = json.dumps(body)
    data = data.encode()
    # data = parse.urlencode(body).encode()
    print(data)
    req = request.Request(url, method="POST", data=data)
    req.add_header("OpenAI-Organization", org)
    req.add_header("Authorization", "Bearer " + key)
    req.add_header("Content-Type", "application/json")
    res = json.load(request.urlopen(req))

    print(res)
    return res
