# Bootstrap

One-time setup that creates the foundational resources the CI/CD pipeline depends on:

- S3 bucket for Terraform remote state (versioning + encryption + public access blocked)
- GitHub Actions OIDC provider in IAM
- IAM role assumed by GitHub Actions via OIDC, scoped to this repo and specific events/environments

This config uses **local state** by design. It avoids the chicken-and-egg problem of CI managing the resources CI depends on, and keeps teardown simple — `terraform destroy` from this directory wipes everything cleanly with no state migration dance.

## Prerequisites

- AWS CLI configured with admin (or near-admin) credentials
- Terraform >= 1.14

## Apply

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

Capture the outputs — they feed into the rest of the project:

- `tf_state_bucket` — used in `infra/envs/*/backend.tf`
- `github_actions_role_arn` — used in the GitHub Actions workflows
- `aws_account_id` — handy reference

## OIDC trust scope

The role's trust policy permits assumption from this repo only, and only on these events:

| Event | OIDC `sub` claim |
|-------|------------------|
| Pull request | `repo:OWNER/REPO:pull_request` |
| Push to main | `repo:OWNER/REPO:ref:refs/heads/main` |
| Job with `environment: dev` | `repo:OWNER/REPO:environment:dev` |
| Job with `environment: prod` | `repo:OWNER/REPO:environment:prod` |

When a workflow job specifies an `environment`, the OIDC token's `sub` claim reflects that environment, overriding any ref-based sub. This is what enables the prod approval gate: GitHub holds the workflow until required reviewers approve, then issues a token with the prod environment claim, then the job can assume the role.

## Permissions

The role currently has `AdministratorAccess` attached. This is a **deliberate first-pass tradeoff** for development velocity. The production-grade pattern is three separate roles (plan, dev, prod) with resource-scoped policies — see the inline `TODO` in `main.tf`.

## Teardown

```bash
terraform destroy
```

Local state means no migration needed. State bucket has `force_destroy = false`, so if you want to remove it cleanly:

```bash
aws s3 rm s3://$(terraform output -raw tf_state_bucket) --recursive --include "*"
# Then handle versioned objects and delete markers if any:
# (use the AWS console "Empty bucket" button, or a versioned-delete script)
terraform destroy
```