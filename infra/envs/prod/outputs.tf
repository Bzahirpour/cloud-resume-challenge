output "website_url" {
  description = "CloudFront distribution URL"
  value       = module.static_site.website_url
}

output "bucket_name" {
  description = "S3 bucket name for frontend file sync"
  value       = module.static_site.bucket_name
}

output "distribution_id" {
  description = "CloudFront distribution ID for cache invalidation"
  value       = module.static_site.distribution_id
}
