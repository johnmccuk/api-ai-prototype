output "api_arn" {
  value       = module.api_gateway.apigatewayv2_api_api_endpoint
  description = "API Gateway Endpoint"
}
