# Cloud Resume Challenge

A production-style implementation of the Cloud Resume Challenge on AWS, deployed via Terraform and GitHub Actions. Built to demonstrate Infrastructure as Code, CI/CD pipeline design, and AWS architecture practices.

## Architecture

- Static frontend hosted in S3, served via CloudFront with Origin Access Control
- Visitor counter API: Lambda (Python) behind API Gateway HTTP API, backed by DynamoDB
- All infrastructure managed by Terraform with remote state in S3 (native S3 locking)
- All deployments managed by GitHub Actions, authenticating to AWS via OIDC (no long-lived keys)

## Repository Layout

\`\`\`
.
├── .github/workflows/   # CI/CD pipeline definitions
├── bootstrap/           # One-time setup: state backend + GitHub OIDC role (local state)
├── infra/
│   ├── modules/         # Reusable Terraform modules
│   │   ├── static-site/
│   │   └── visitor-counter/
│   └── envs/            # Environment-specific compositions
│       ├── dev/
│       └── prod/
├── frontend/            # Static site assets
└── lambda/              # Lambda function source
\`\`\`

## Pipeline Flow

Trunk-based development with environment promotion:

1. Feature branch → PR → CI runs fmt, validate, tflint, tfsec, and `terraform plan` for both dev and prod (posted as PR comments)
2. Merge to `main` → automatic apply to **dev**
3. Manual approval gate via GitHub Environments → apply to **prod**
4. Post-deploy validation

## Setup

See [`bootstrap/README.md`](bootstrap/README.md) for first-time setup.

## Status

In active development.
