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
/*
resource "aws_apigatewayv2_stage" "dev" {
  api_id = module.api_gateway.apigatewayv2_api_id
  name   = "dev"
}

resource "aws_apigatewayv2_integration" "get" {
  api_id           = module.api_gateway.apigatewayv2_api_id
  integration_type = "MOCK"
}

resource "aws_apigatewayv2_route" "example" {
  api_id    = module.api_gateway.apigatewayv2_api_id
  route_key = "GET /pets"
  target    = "integrations/${aws_apigatewayv2_integration.get.id}"
}
*/
resource "aws_cloudwatch_log_group" "logs" {
  name = local.name
}


####################
# AWS Step Function
####################

module "step_function" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "~> 2.0"

  name = "${random_pet.this.id}-step"

  definition = <<EOF
{
  "Comment": "A Hello World example of the Amazon States Language using Pass states",
  "StartAt": "Hello",
  "States": {
    "Hello": {
      "Type": "Pass",
      "Result": "Hello",
      "Next": "World"
    },
    "World": {
      "Type": "Pass",
      "Result": "World",
      "End": true
    }
  }
}
EOF
}

####################
# Lambda
####################

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.0"

  function_name = "${random_pet.this.id}-lambda"
  description   = "My awesome lambda function"
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
      //source_arn = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
    }
  }

  attach_policy_statements = true
  policy_statements = {
    # Allow failures to be sent to SQS queue
    ssm = {
      effect = "Allow",
      actions = [
        "states:StartExecution",
        //"states:ListStateMachines",
        //"states:ListActivities",
        //"states:DescribeStateMachine",
        //"states:DescribeStateMachineForExecution",
        // "states:ListExecutions",
        // "states:DescribeExecution",
        // "states:GetExecutionHistory",
        //"states:DescribeActivity"
      ],
      resources = [module.step_function.state_machine_arn]
    }
  }

  #add xray policy
  attach_tracing_policy = true
  tags                  = local.tags
}
