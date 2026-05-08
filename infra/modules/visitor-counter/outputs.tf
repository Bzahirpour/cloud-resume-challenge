output "api_invoke_url" {
  value       = "${aws_apigatewayv2_api.visitor_count_api.api_endpoint}/visitor-count"
  description = "Full URL to POST to for incrementing the visitor counter"
}