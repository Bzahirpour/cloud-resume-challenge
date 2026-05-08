output "website_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "bucket_name" {
  description = "S3 bucket name for frontend file sync"
  value       = aws_s3_bucket.crc_static_site.id
}

output "distribution_id" {
  description = "CloudFront distribution ID for cache invalidation"
  value       = aws_cloudfront_distribution.s3_distribution.id
}
