# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

provider "aws" {
  alias  = "us"
  region = "us-east-1" # to deploy a WAF associated to cloudfront

  default_tags {
    tags = {
      "environment" = var.environment
    }
  }
}

# application config file
resource "local_file" "frontend_config_file" {
  filename = "${path.root}/../web-portal/src/config.js"
  content  = <<EOF
export const region = "${var.region}";
export const userPoolId = "${var.user_pool_id}";
export const userPoolWebClientId = "${var.user_pool_client_id}";
export const identityPoolId = "${var.identity_pool_id}";
export const apiEndpoint = "${var.api_endpoint}";
export const gatewayEndpoint = "${var.connection_gateway_endpoint}";
export const gatewayPort = ${var.connection_gateway_tcp_port};
EOF
}

# website S3 bucket
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "${var.project}-${var.environment}-frontend-${var.account_id}-${var.region}" // change this if you want a custom domain name
  force_destroy = true
}

resource "aws_s3_bucket_cors_configuration" "frontend_bucket_cors" {
  bucket = aws_s3_bucket.frontend_bucket.id
  cors_rule {
    allowed_methods = ["GET", "POST", "PUT"]
    allowed_origins = ["*"] // change if you have a custom domain
    allowed_headers = ["*"]
  }
}

resource "aws_s3_bucket_versioning" "frontend_bucket_versioning" {
  bucket = aws_s3_bucket.frontend_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_access_block" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# WAF
resource "aws_wafv2_ip_set" "frontend_waf_ip_allow_list" {
  provider           = aws.us
  name               = "${var.project}-${var.environment}-frontend-ip-allowed"
  addresses          = var.ip_allow_list
  ip_address_version = "IPV4"
  scope              = "CLOUDFRONT"
}

resource "aws_wafv2_web_acl" "frontend_waf_acl" {
  provider = aws.us
  name     = "${var.project}-${var.environment}-frontend-waf"
  scope    = "CLOUDFRONT"
  default_action {
    block {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-${var.environment}-frontend-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "ip-allow-list"
    priority = 1
    action {
      allow {}
    }
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.frontend_waf_ip_allow_list.arn
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowedIP"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "BadInputs"
      sampled_requests_enabled   = false
    }
  }
}

# Cloudfront distribution
resource "aws_s3_bucket" "frontend_distribution_logs_bucket" {
  bucket_prefix = "${var.project}-${var.environment}-cloudfront-logs"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "frontend_distribution_logs_bucket_versioning" {
  bucket = aws_s3_bucket.frontend_distribution_logs_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_distribution_logs_bucket_encryption" {
  bucket = aws_s3_bucket.frontend_distribution_logs_bucket.bucket

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "frontend_distribution_logs_bucket_ownership_controls" {
  bucket = aws_s3_bucket.frontend_distribution_logs_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "frontend_distribution_logs_bucket_acl" {
  bucket = aws_s3_bucket.frontend_distribution_logs_bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.frontend_distribution_logs_bucket_ownership_controls]
}

resource "aws_s3_bucket_public_access_block" "frontend_distribution_logs_bucket_public_access_block" {
  bucket = aws_s3_bucket.frontend_distribution_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_policy" "allow_s3_write_access_cloudfront" {
  bucket = aws_s3_bucket.frontend_distribution_logs_bucket.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Id": "AWSConsole-AccessLogs-Policy-1544636543097",
    "Statement": [
        {
            "Sid": "AWSLogDeliveryWrite",
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": ["s3:PutObject"],
            "Resource": [
              "${aws_s3_bucket.frontend_distribution_logs_bucket.arn}/*"
            ]
        },
        {
            "Sid": "AWSLogDeliveryAclCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": [
                "s3:GetBucketAcl",
                "s3:PutBucketAcl"
            ],
            "Resource": "${aws_s3_bucket.frontend_distribution_logs_bucket.arn}"
        }
    ]
}
EOF
}

locals {
  s3_origin_id  = "${var.project}-${var.environment}-frontend-${var.account_id}"
  api_origin_id = "${var.project}-${var.environment}-frontend-api-${var.account_id}"
}

resource "aws_cloudfront_origin_access_identity" "frontend_oai" {
  comment = "${var.project}-${var.environment}-frontend-${var.account_id}"
}

data "aws_cloudfront_cache_policy" "frontend_cache_policy_managed" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.frontend_waf_acl.arn

  logging_config {
    bucket          = aws_s3_bucket.frontend_distribution_logs_bucket.bucket_domain_name
    include_cookies = false
  }

  default_cache_behavior {
    cache_policy_id        = data.aws_cloudfront_cache_policy.frontend_cache_policy_managed.id
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.frontend_oai.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none" // specify some geo restriction if needed
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true // use ACM if needed
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }
}

data "aws_iam_policy_document" "frontend_oai_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.frontend_oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_s3_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.frontend_oai_policy.json
}

output "frontend_bucket" {
  value = aws_s3_bucket.frontend_bucket.bucket
}

output "frontend_distribution_id" {
  value = aws_cloudfront_distribution.frontend_distribution.id
}

output "frontend_distribution_endpoint" {
  value = "https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"
}