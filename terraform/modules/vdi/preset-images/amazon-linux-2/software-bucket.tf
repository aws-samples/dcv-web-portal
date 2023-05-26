# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_s3_bucket" "software_bucket" {
  bucket_prefix = "${var.project}-${var.environment}-${local.os}-${local.os_version}"
  force_destroy = true
}

# Define encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "software_bucket_encryption_configuration" {
  bucket = aws_s3_bucket.software_bucket.bucket

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Define versioning so we can keep track of different software version uploaded
resource "aws_s3_bucket_versioning" "software_bucket_versioning" {
  bucket = aws_s3_bucket.software_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Public access block
resource "aws_s3_bucket_public_access_block" "software_bucket_public_access_block" {
  bucket = aws_s3_bucket.software_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true

}