resource "aws_s3_bucket" "kubernetes" {
  bucket        = var.bucket
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "kubernetes" {
  bucket = aws_s3_bucket.kubernetes.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "kubernetes" {
  bucket = aws_s3_bucket.kubernetes.id
  versioning_configuration {
    status = "Enabled"
  }
}
