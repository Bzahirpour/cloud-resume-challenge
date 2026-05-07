terraform {
  required_version = "~> 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # No backend block — bootstrap uses local state by design.
  # See bootstrap/README.md for rationale.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

data "aws_caller_identity" "current" {}

# ----------------------------------------------------------------------------
# Terraform remote state backend (S3 with native locking, no DynamoDB needed)
# ----------------------------------------------------------------------------

resource "aws_s3_bucket" "tf_state" {
  bucket        = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"
  force_destroy = false # explicit; prevents accidental destruction of state history
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------------------------------------------------------------------
# GitHub Actions OIDC provider
# ----------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's known thumbprints. AWS no longer validates thumbprints for
  # well-known IdPs like GitHub, but the field is still required by the provider.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# ----------------------------------------------------------------------------
# IAM role assumed by GitHub Actions via OIDC
# ----------------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # The audience claim must be sts.amazonaws.com — this is what the
    # configure-aws-credentials action sets when requesting an OIDC token.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scope assumption to specific events from this repo only:
    #   - PRs (for terraform plan)
    #   - Pushes to main (for non-environment-scoped workflow steps)
    #   - Jobs running with environment: dev
    #   - Jobs running with environment: prod
    #
    # NOTE: When a workflow job specifies `environment: <name>`, the OIDC
    # token's `sub` claim becomes `repo:OWNER/REPO:environment:<name>`,
    # overriding any ref-based sub. This is what enables the prod approval
    # gate: GitHub holds the workflow until reviewers approve, then issues
    # a token with the prod environment claim, then the job can assume.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:pull_request",
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_org}/${var.github_repo}:environment:dev",
        "repo:${var.github_org}/${var.github_repo}:environment:prod",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "${var.project_name}-github-actions"
  description          = "Assumed by GitHub Actions via OIDC to deploy ${var.project_name}"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume.json
  max_session_duration = 3600
}

# Broad permissions for development velocity.
# TODO (production-grade improvement): Replace with three separate roles:
#   - <project>-github-actions-plan: read-only, scoped to PR events
#   - <project>-github-actions-dev:  write access to dev resources only
#   - <project>-github-actions-prod: write access to prod resources only
# Each role's trust policy would scope its `sub` claim to the relevant event
# type. This is the production pattern; using a single admin role here is a
# deliberate tradeoff for development speed on a personal project.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
