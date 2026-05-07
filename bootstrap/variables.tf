variable "aws_region" {
  description = "AWS region for the bootstrap resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used as a prefix for resource names"
  type        = string
  default     = "cloud-resume-challenge"
}

variable "github_org" {
  description = "GitHub username or organization that owns the repo"
  type        = string
  default     = "Bzahirpour"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "cloud-resume-challenge"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "cloud-resume-challenge"
    ManagedBy = "Terraform"
    Module    = "bootstrap"
  }
}
