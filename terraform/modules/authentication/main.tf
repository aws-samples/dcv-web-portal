# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_cognito_user_pool" "pool" {
  name = "${var.project}-${var.environment}-user-pool"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # MFA configuration
  mfa_configuration = "OPTIONAL"
  software_token_mfa_configuration {
    enabled = true
  }

  # only the administrator is allowed to create user profiles
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  lambda_config {
    pre_sign_up = aws_lambda_function.post_confirmation_function.arn
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_pool_client" "user_pool_client_web" {
  name                = "${var.project}-${var.environment}-pool-client-web"
  user_pool_id        = aws_cognito_user_pool.pool.id
  explicit_auth_flows = ["ADMIN_NO_SRP_AUTH"]

  refresh_token_validity = 12
  token_validity_units {
    refresh_token = "hours"
  }
}

resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = "${var.project}-${var.environment}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.user_pool_client_web.id
    provider_name           = aws_cognito_user_pool.pool.endpoint
    server_side_token_check = true
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id

  roles = {
    authenticated   = aws_iam_role.web_identity_pool_authenticated.arn
    unauthenticated = aws_iam_role.web_identity_pool_unauthenticated.arn
  }
}

# https://www.terraform.io/docs/providers/aws/r/cognito_identity_pool_roles_attachment.html
resource "aws_iam_role" "web_identity_pool_authenticated" {
  name_prefix = "${var.project}-${var.environment}-idpool-authenticated"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.identity_pool.id}"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "web_identity_pool_unauthenticated" {
  name_prefix = "${var.project}-${var.environment}-idpool-unauthenticated"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
EOF
}

# we can then attach additional policies to each identity pool role
resource "aws_iam_role_policy" "web_identity_pool_authenticated" {
  name = "${var.project}-${var.environment}-identitypool-authenticated-policy"
  role = aws_iam_role.web_identity_pool_authenticated.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cognito-sync:*",
        "cognito-identity:*"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": [
        "${var.kms_key_arn}"
      ]
    }
  ]
}
EOF
}

# we don't allow unauthenticated access, so just set all actions to be denied
resource "aws_iam_role_policy" "apps_identity_pool_unauthenticated" {
  name = "${var.project}-${var.environment}-identitypool-unauthenticated-policy"
  role = aws_iam_role.web_identity_pool_unauthenticated.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}
