# modules/secure-bucket/outputs.tf
#
# These outputs let the caller reference things about the bucket
# the module created.

output "bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "The bucket's domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}