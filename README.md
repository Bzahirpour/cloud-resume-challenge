# Cloud Resume Challenge

A production-style implementation of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/) on AWS. The focus of this project is the CI/CD pipeline and Infrastructure as Code quality — the same patterns used in professional cloud engineering teams.

## Architecture

- Static frontend (HTML/CSS/JS) hosted in S3, served via CloudFront with Origin Access Control
- Visitor counter: Python Lambda behind API Gateway HTTP API, backed by DynamoDB
- All infrastructure managed by Terraform with remote state in S3 (native locking, no DynamoDB)
- All deployments via GitHub Actions authenticating to AWS through OIDC — no long-lived keys

---

## Repository Layout

```
cloud-resume-challenge/
├── .github/
│   └── workflows/
│       ├── terraform.yml        # IaC pipeline: lint → plan → apply dev → gate → apply prod
│       └── frontend.yml         # Frontend pipeline: validate → deploy dev → gate → deploy prod
│
├── bootstrap/                   # One-time local setup (local state, not managed by CI)
│   ├── main.tf                  # S3 state bucket + GitHub OIDC provider + CI IAM role
│   └── README.md
│
├── infra/
│   ├── modules/                 # Reusable resource definitions — no backend, no provider
│   │   ├── static-site/         # S3 bucket, CloudFront distribution, OAC, bucket policy
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── visitor-counter/     # DynamoDB, Lambda, IAM, API Gateway HTTP API
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   └── envs/                    # Environment entry points — backend + provider + module calls
│       ├── dev/
│       │   ├── backend.tf       # S3 backend config (key: envs/dev/terraform.tfstate)
│       │   ├── main.tf          # Module composition for dev
│       │   ├── variables.tf
│       │   ├── terraform.tfvars # Committed env config (project_name, environment, region)
│       │   └── outputs.tf
│       └── prod/                # Identical structure, different tfvars + state key
│
├── frontend/                    # Static site assets synced to S3 by frontend.yml
│   ├── index.html
│   ├── styles.css
│   ├── script.js                # Calls visitor counter API; URL injected at deploy time
│   └── headshot.png
│
└── lambda/
    └── db_update_fn.py          # Visitor counter handler: atomic DynamoDB increment
```

---

## Terraform Design

### Modules + Envs Pattern

Resources live exclusively in `infra/modules/`. Environment directories (`infra/envs/dev/`, `infra/envs/prod/`) are thin composition layers — they call modules with environment-specific values and nothing else. This enforces a clean separation between *what* gets built (modules) and *where* it gets built (envs).

```hcl
# infra/envs/dev/main.tf
module "static_site" {
  source       = "../../modules/static-site"
  project_name = var.project_name
  environment  = var.environment
}

module "visitor_counter" {
  source             = "../../modules/visitor-counter"
  project_name       = var.project_name
  environment        = var.environment
  cors_allow_origins = module.static_site.website_url
}
```

### State Management

- Remote state stored in S3: `cloud-resume-challenge-tfstate-{account_id}`
- State keys scoped per environment: `envs/dev/terraform.tfstate`, `envs/prod/terraform.tfstate`
- Native S3 locking (`use_lockfile = true`) — no DynamoDB lock table required
- Lock timeout set to 120s in CI to handle concurrent runs

### OIDC Authentication

GitHub Actions authenticates to AWS via OIDC federation — no IAM users, no access keys stored in secrets. The trust policy scopes permissions to specific workflow contexts:

| GitHub Actions context | OIDC subject claim |
|---|---|
| Pull request plan jobs | `repo:...:pull_request` |
| Apply dev | `repo:...:environment:dev` |
| Apply prod | `repo:...:environment:prod` |

### Naming and Tagging Conventions

- Resources: `${var.project_name}-${var.environment}-{purpose}`
- Default tags applied via provider `default_tags`: `Project`, `Environment`, `ManagedBy=Terraform`
- Provider lock files (`.terraform.lock.hcl`) committed for reproducible provider versions

### Runtime Configuration via SSM

Terraform writes infrastructure outputs (bucket name, CloudFront distribution ID, API endpoint) to SSM Parameter Store on apply. Downstream consumers (the frontend workflow) read from SSM at deploy time rather than hardcoding values.

```
/cloud-resume-challenge/{env}/static-site/bucket-name
/cloud-resume-challenge/{env}/static-site/distribution-id
/cloud-resume-challenge/{env}/visitor-counter/api-endpoint
```

---

## CI/CD Pipeline

### Terraform Pipeline (`terraform.yml`)

Triggers on changes to `infra/**` or the workflow file itself.

```
Pull Request
└── lint & security scan (terraform fmt, tflint, tfsec)
    └── plan: dev  ──┐
    └── plan: prod ──┘  (both posted as PR comments)

Merge to main
└── lint & security scan
    └── apply: dev  (automatic — environment: dev OIDC sub)
        └── apply: prod  (held for manual reviewer approval — environment: prod OIDC sub)
```

Plan output for both environments is posted as a collapsible comment on every PR. Reviewers are expected to read both plans before approving — especially prod, where a destroy is a red flag.

### Frontend Pipeline (`frontend.yml`)

Triggers on changes to `frontend/**`. Completely independent from the Terraform pipeline.

```
Pull Request
└── validate (htmlhint, node --check)

Merge to main
└── validate
    └── deploy: dev  (automatic — reads SSM, injects API URL into script.js, s3 sync, CF invalidation)
        └── deploy: prod  (held for manual reviewer approval)
```

The API Gateway endpoint URL is injected into `script.js` at deploy time using `sed`, replacing the placeholder `VISITOR_COUNTER_API_URL` with the environment-specific value read from SSM. This keeps the source file environment-agnostic.

The dev deploy includes a retry loop on the SSM read (30s intervals, up to 10 minutes) to handle the race condition where the frontend workflow starts before the Terraform apply has finished writing SSM parameters.

---

## Key Design Decisions

**Trunk-based development over GitFlow** — `main` is the single source of truth. Environments are apply targets, not branches. This eliminates long-lived environment branches and the merge conflicts that come with them.

**OIDC over static IAM keys** — No credentials stored in GitHub Secrets. The trust policy is scoped to specific workflow environments, so a compromised PR can only plan, never apply.

**Native S3 locking over DynamoDB** — Terraform 1.10+ supports `use_lockfile = true` in S3 backends. Eliminates a dependency on a separate DynamoDB table for a locking mechanism that rarely matters on a single-developer project.

**SSM Parameter Store for runtime config** — Infrastructure outputs (bucket names, distribution IDs, API endpoints) flow from Terraform to downstream workflows through SSM rather than hardcoding. Decouples the two pipelines and survives infrastructure rebuilds automatically.

**Modules own infrastructure, workflows own content** — The static-site module creates the S3 bucket and CloudFront distribution but never touches file content. The frontend workflow owns all file uploads via `aws s3 sync`. This keeps infrastructure changes and deployment changes on independent triggers and prevents Terraform state from tracking individual HTML files.

---

## Bootstrap

The state backend and OIDC trust were provisioned once from a local machine using `bootstrap/`. This directory has its own local state and is not managed by CI. See [`bootstrap/README.md`](bootstrap/README.md).
