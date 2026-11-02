output "api_endpoint" {
  description = "Base URL of the HTTP API"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "table_name" {
  value = aws_dynamodb_table.links.name
}

output "create_link_function" {
  value = aws_lambda_function.create_link.function_name
}

output "redirect_function" {
  value = aws_lambda_function.redirect.function_name
}