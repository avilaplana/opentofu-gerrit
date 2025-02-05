# Output values  
output "alb_dns_name" {
  value = aws_lb.python_alb.dns_name
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}
