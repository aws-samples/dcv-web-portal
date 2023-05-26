# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_s3_bucket" "connection_gateway_lb_logs_bucket" {
  bucket_prefix = "${var.project}-${var.environment}-dcv-gw-lb-logs"
  force_destroy = true
}

# Define versioning so we can keep track of different logs files
resource "aws_s3_bucket_versioning" "connection_gateway_lb_logs_bucket_versioning" {
  bucket = aws_s3_bucket.connection_gateway_lb_logs_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Define encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "connection_gateway_lb_logs_bucket_encryption_configuration" {
  bucket = aws_s3_bucket.connection_gateway_lb_logs_bucket.bucket

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Public access block
resource "aws_s3_bucket_public_access_block" "connection_gateway_lb_logs_bucket_public_access_block" {
  bucket = aws_s3_bucket.connection_gateway_lb_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# Define bucket policy to allow Load Balancer to write access logs
resource "aws_s3_bucket_policy" "allow_write_access_to_load_balancer" {
  bucket = aws_s3_bucket.connection_gateway_lb_logs_bucket.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Id": "AWSConsole-AccessLogs-Policy-1649630547097",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
              "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": [
              "${aws_s3_bucket.connection_gateway_lb_logs_bucket.arn}/AWSLogs/${var.account_id}/*"
            ]
        },
        {
            "Sid": "AWSLogDeliveryWrite",
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": [
              "${aws_s3_bucket.connection_gateway_lb_logs_bucket.arn}/AWSLogs/${var.account_id}/*"
            ],
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        },
        {
            "Sid": "AWSLogDeliveryAclCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.connection_gateway_lb_logs_bucket.arn}"
        }
    ]
}
EOF
}

resource "aws_lb" "connection_gateway_lb" {
  depends_on                       = [aws_autoscaling_group.connection_gateway_asg, aws_s3_bucket_policy.allow_write_access_to_load_balancer]
  name                             = "${var.project}-${var.environment}-gateway"
  load_balancer_type               = "network"
  ip_address_type                  = "ipv4"
  internal                         = false
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = true
  desync_mitigation_mode           = "strictest"

  subnets = var.public_subnets_id

  access_logs {
    bucket  = aws_s3_bucket.connection_gateway_lb_logs_bucket.id
    enabled = true
  }
}

resource "aws_lb_target_group" "connection_gateway_target_group_tcp" {
  count                  = (var.udp_port != var.tcp_port) ? 1 : 0
  name                   = "${var.project}-${var.environment}-gateway-tcp"
  port                   = var.tcp_port
  protocol               = "TCP"
  vpc_id                 = var.vpc_id
  preserve_client_ip     = true
  connection_termination = true

  stickiness {
    type    = "source_ip"
    enabled = true
  }

  health_check {
    port                = var.health_check_port
    protocol            = "TCP"
    healthy_threshold   = 10
    unhealthy_threshold = 10
  }
}

resource "aws_lb_target_group" "connection_gateway_target_group_udp" {
  count                  = (var.udp_port != var.tcp_port) ? 1 : 0
  name                   = "${var.project}-${var.environment}-gateway-udp"
  port                   = var.udp_port
  protocol               = "UDP"
  vpc_id                 = var.vpc_id
  preserve_client_ip     = true
  connection_termination = true

  stickiness {
    type    = "source_ip"
    enabled = true
  }

  health_check {
    port                = var.health_check_port
    protocol            = "TCP"
    healthy_threshold   = 10
    unhealthy_threshold = 10
  }
}

# if udp port is the same as tcp port, use TCP_UDP protocol instead of 2 target groups
resource "aws_lb_target_group" "connection_gateway_target_group_tcp_udp" {
  count                  = (var.udp_port == var.tcp_port) ? 1 : 0
  name                   = "${var.project}-${var.environment}-gateway-tcp-udp"
  port                   = var.udp_port
  protocol               = "TCP_UDP"
  vpc_id                 = var.vpc_id
  preserve_client_ip     = true
  connection_termination = true

  stickiness {
    type    = "source_ip"
    enabled = true
  }

  health_check {
    port                = var.health_check_port
    protocol            = "TCP"
    healthy_threshold   = 10
    unhealthy_threshold = 10
  }
}

resource "aws_lb_listener" "connection_gateway_listener_tcp" {
  count             = (var.udp_port != var.tcp_port) ? 1 : 0
  load_balancer_arn = aws_lb.connection_gateway_lb.arn
  port              = var.tcp_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.connection_gateway_target_group_tcp[0].arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "connection_gateway_listener_udp" {
  count             = (var.udp_port != var.tcp_port) ? 1 : 0
  load_balancer_arn = aws_lb.connection_gateway_lb.arn
  port              = var.udp_port
  protocol          = "UDP"

  default_action {
    target_group_arn = aws_lb_target_group.connection_gateway_target_group_udp[0].arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "connection_gateway_listener_tcp_udp" {
  count             = (var.udp_port == var.tcp_port) ? 1 : 0
  load_balancer_arn = aws_lb.connection_gateway_lb.arn
  port              = var.udp_port
  protocol          = "TCP_UDP"

  default_action {
    target_group_arn = aws_lb_target_group.connection_gateway_target_group_tcp_udp[0].arn
    type             = "forward"
  }
}