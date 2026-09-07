# ============================================================
# Thanos Object Storage
# ============================================================

resource "aws_s3_bucket" "thanos" {
  bucket = "${var.cluster_name}-thanos-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${var.prefix}-thanos"
    Project = var.cluster_name
    Purpose = "thanos-long-term-metrics"
  }
}

# ============================================================
# Block Public Access
# ============================================================

resource "aws_s3_bucket_public_access_block" "thanos" {
  bucket = aws_s3_bucket.thanos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# Server-side Encryption
# ============================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "thanos" {
  bucket = aws_s3_bucket.thanos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================
# Versioning
# ============================================================

resource "aws_s3_bucket_versioning" "thanos" {
  bucket = aws_s3_bucket.thanos.id

  versioning_configuration {
    status = "Enabled"
  }
}