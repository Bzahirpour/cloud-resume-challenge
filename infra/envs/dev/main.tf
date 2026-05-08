# Trivial resource used to validate the CI/CD pipeline end-to-end.
# Will be removed before adding real CRC infra modules.
resource "aws_ssm_parameter" "pipeline_test" {
  name        = "/${var.project_name}/${var.environment}/pipeline-test"
  description = "Pipeline validation parameter (will be removed before MVP)"
  type        = "String"
  value       = "pipeline-validated-v1"
}
