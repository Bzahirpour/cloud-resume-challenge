output "tf_state_bucket" {
  description = "S3 bucket name for Terraform remote state (used in infra/envs/*/backend.tf)"
  value       = aws_s3_bucket.tf_state.id
}

output "github_actions_role_arn" {
  description = "IAM role ARN that GitHub Actions assumes via OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "aws_account_id" {
  description = "AWS account ID, for reference"
  value       = data.aws_caller_identity.current.account_id
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
