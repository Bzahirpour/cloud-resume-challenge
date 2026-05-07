# Bootstrap

One-time setup that creates the resources required before the CI/CD pipeline can function:

- S3 bucket for Terraform remote state (with versioning + encryption)
- IAM OIDC provider for GitHub Actions
- IAM role that GitHub Actions assumes via OIDC

This config uses **local state** (gitignored). It is intentionally not managed by CI to avoid the chicken-and-egg problem of CI managing the resources CI depends on.

## Apply

(Instructions added in next step.)
