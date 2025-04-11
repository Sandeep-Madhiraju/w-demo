output "s3_bucket_name" {
  value = aws_s3_bucket.hashicat_bucket.bucket
}

output "wiz_role_arn" {
  value = aws_iam_role.wiz_integration_role.arn
}
