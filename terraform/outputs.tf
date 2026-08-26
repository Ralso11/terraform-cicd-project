output "cloudfront_domain_name" {
  description = "The public URL of the deployed website"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing the website files"
  value       = aws_s3_bucket.website.id
}

