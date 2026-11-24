resource "aws_s3_bucket" "demo" {
  bucket_prefix = "${local.name_prefix}-demo-"
}

resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "demo_marker" {
  bucket       = aws_s3_bucket.demo.id
  key          = "golden-path/README.txt"
  content      = "Demo object for EKS Pod Identity least-privilege validation.\n"
  content_type = "text/plain"
}
