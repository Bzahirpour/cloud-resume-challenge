variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "cors_allow_origins" {
  description = "CloudFront distribution URL allowed to call the API"
  type        = string
}
