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

####################
# API Gateway
####################
module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name                        = "api-ai-prototype"
  description                 = "API for prototyping AI"
  protocol_type               = "HTTP"
  domain_name                 = local.name
  create_api_domain_name      = false
  domain_name_certificate_arn = var.certificate_arn
  //disable_execute_api_endpoint             = true
  default_stage_access_log_destination_arn = aws_cloudwatch_log_group.logs.arn
  tags                                     = local.tags

  default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 10
    throttling_rate_limit    = 10
  }

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "Authorization", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }
  /*
  integrations = {
    "POST /" = {
      lambda_arn               = module.lambda-default.lambda_function_arn
      payload_format_version   = "2.0"
      timeout_milliseconds     = 3000
      detailed_metrics_enabled = true
    }

    "$default" = {
      lambda_arn = module.lambda-default.lambda_function_arn
      tls_config = jsonencode({
        server_name_to_verify = "api.mccracken.cloud"
      })

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
    }

  }
  */
}

resource "aws_cloudwatch_log_group" "logs" {
  name = local.name
}

####################
# Step Function
####################

####################
# Lambda
####################
