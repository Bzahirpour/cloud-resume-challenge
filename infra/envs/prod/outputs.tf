output "pipeline_test_parameter" {
  description = "Name of the validation parameter"
  value       = aws_ssm_parameter.pipeline_test.name
}
