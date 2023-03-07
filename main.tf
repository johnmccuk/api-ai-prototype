terraform {

  backend "s3" {
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 4.16"
    }
  }
}

provider "aws" {
  profile = var.environment
  region  = "eu-west-1"
}

locals {
  name   = basename(path.cwd)
  region = "eu-west-1"
  tags = {
    TF-Name     = basename(path.cwd)
    Environment = var.environment
    Repo        = "https://github.com/johnmccuk/${basename(path.cwd)}.git"
  }
}

resource "random_pet" "this" {

}

####################
# API Gateway REST
####################
/*
resource "aws_api_gateway_rest_api" "main" {
  name = "${random_pet.this.id}-api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.tags
}

resource "aws_api_gateway_resource" "test" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "test"
}

resource "aws_api_gateway_method" "test_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.test.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.test.id
  http_method             = aws_api_gateway_method.test_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_function.lambda_function_invoke_arn
}
*/
####################
# API Gateway HTTP
####################

/*
resource "aws_apigatewayv2_api" "main" {
  name          = "${random_pet.this.id}-api"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_stage" "v1" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "v1"
  auto_deploy = true
}

resource "aws_apigatewayv2_stage" "v2" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "v2"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "default_post" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = module.lambda_function.lambda_function_invoke_arn
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.default_post.id}"
}
*/

####################
# API Gateway HTTP module
####################

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name                   = "${random_pet.this.id}-api"
  description            = "API for prototyping AI"
  protocol_type          = "HTTP"
  domain_name            = local.name
  create_api_domain_name = false
  tags                   = local.tags

  default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 10
    throttling_rate_limit    = 10
  }

  default_stage_access_log_destination_arn = aws_cloudwatch_log_group.logs.arn
  default_stage_access_log_format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "Authorization", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  integrations = {
    /*
    "POST /" = {
      lambda_arn               = module.lambda_function.lambda_function_arn
      payload_format_version   = "2.0"
      timeout_milliseconds     = 3000
      detailed_metrics_enabled = true
    }
    */

    "$default" = {
      lambda_arn = module.lambda_function.lambda_function_arn
      /*
      response_parameters = jsonencode([
        {
          status_code = 500
          mappings = {
            "append:header.header1" = "$context.requestId"
            "overwrite:statuscode"  = "403"
          }
        },
        {
          status_code = 404
          mappings = {
            "append:header.error" = "$stageVariables.environmentId"
          }
        }
      ])
      */
    }
  }
}

resource "aws_cloudwatch_log_group" "logs" {
  name              = local.name
  retention_in_days = 5
}


####################
# AWS Step Function
####################

locals {
  definition_template = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Create Code",
  "States": {
    "Create Code": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${module.lambda_create_code.lambda_function_arn}:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 2,
          "BackoffRate": 2
        }
      ],
      "Next": "Save Code"
    },
    "Save Code": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${module.lambda_save_code.lambda_function_arn}:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 2,
          "BackoffRate": 2
        }
      ],
      "Next": "Success"
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
EOF
}

module "step_function" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "~> 2.0"

  depends_on = [
    aws_cloudwatch_log_group.logs
  ]

  name = "${random_pet.this.id}-step"

  definition = local.definition_template

  logging_configuration = {
    include_execution_data = true
    level                  = "ALL"
  }
  tags = local.tags

  use_existing_cloudwatch_log_group = true
  cloudwatch_log_group_name         = aws_cloudwatch_log_group.logs.name
  //cloudwatch_log_group_retention_in_days = 5

  service_integrations = {

    lambda = {
      lambda = [
        module.lambda_create_code.lambda_function_arn,
        "${module.lambda_create_code.lambda_function_arn}:*",
        module.lambda_save_code.lambda_function_arn,
        "${module.lambda_save_code.lambda_function_arn}:*",
      ]
    }

    xray = {
      xray = true
    }

  }
  /*
  attach_policy_json = true
  policy_json        = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
*/
}

####################
# S3 Bucket
####################

module "s3_bucket_for_code" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${random_pet.this.id}-code-store"

  # Allow deletion of non-empty bucket
  force_destroy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}
/*
resource "aws_iam_role" "role" {
  name = "${random_pet.this.id}-s3-access"
  path = "/"

  assume_role_policy = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

#Created Policy for IAM Role
resource "aws_iam_policy" "policy" {
  name        = "${random_pet.this.id}-code-policy"
  description = "Policy for lambda access to S3"
  policy      = <<EOF
   {
"Version": "2012-10-17",
"Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "s3:ListBucket"
        ],
        "Resource": "${module.s3_bucket_for_code.s3_bucket_arn}"
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:PutObject"
        ],
        "Resource": "${module.s3_bucket_for_code.s3_bucket_arn}/*"
    },
]

} 
    EOF
}
*/

####################
# Lambda
####################

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.0"

  function_name = "${random_pet.this.id}-validate"
  description   = "Validates request before executing step function"
  handler       = "main.lambda_handler"
  source_path   = "./source-default/main.py"
  runtime       = "python3.8"
  timeout       = 15
  publish       = true

  environment_variables = {
    "STEP_ARN" : module.step_function.state_machine_arn
  }

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*"
    }
  }

  attach_policy_statements = true
  policy_statements = {
    # Allow failures to be sent to SQS queue
    ssm = {
      effect = "Allow",
      actions = [
        "states:StartExecution",
      ],
      resources = [module.step_function.state_machine_arn]
    }
  }

  #add xray policy
  attach_tracing_policy = true
  tags                  = local.tags
}

module "lambda_create_code" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.0"

  function_name = "${random_pet.this.id}-create-code"
  description   = "Calls Open AI and retrieves generated text content"
  handler       = "main.lambda_handler"
  source_path   = "./source-create-code/main.py"
  runtime       = "python3.8"
  timeout       = 60
  publish       = true

  environment_variables = {
    "OPEN_AI_KEY" : var.open_ai_key
    "OPEN_AI_ORG" : var.open_ai_org
    "OPEN_AI_TEXT_MODEL" : var.open_ai_text_model
  }

  #add xray policy
  attach_tracing_policy = true
  tags                  = local.tags
}

module "lambda_save_code" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.0"

  function_name = "${random_pet.this.id}-save-code"
  description   = "Save the passed data to an S3 bucket"
  handler       = "main.lambda_handler"
  source_path   = "./source-save-code/main.py"
  runtime       = "python3.8"
  timeout       = 60
  publish       = true

  environment_variables = {
    "BUCKET" : module.s3_bucket_for_code.s3_bucket_id
  }

  attach_policy_statements = true
  policy_statements = {
    s3 = {
      effect = "Allow",
      actions = [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      resources = [
        "arn:aws:s3:::${module.s3_bucket_for_code.s3_bucket_id}/*",
        "arn:aws:s3:::${module.s3_bucket_for_code.s3_bucket_id}"
      ]
    }
  }

  #add xray policy
  attach_tracing_policy = true
  tags                  = local.tags
}
