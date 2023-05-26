# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "api_cloudwatch" {
  name_prefix = "${var.project}-${var.environment}-api-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.project}-${var.environment}-logs"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:PutLogEvents",
            "logs:GetLogEvents",
            "logs:FilterLogEvents"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:logs:*:*:*",
        },
      ]
    })
  }
}

resource "aws_iam_role" "api" {
  name_prefix = "${var.project}-${var.environment}-api"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.project}-${var.environment}-kms"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "kms:Decrypt",
          ]
          Effect   = "Allow"
          Resource = var.kms_key_arn
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-dynamodb"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "dynamodb:Query",
          ]
          Effect   = "Allow"
          Resource = [var.application_table_arn, "${var.application_table_arn}/index/*"]
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-states"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "states:StartExecution",
          ]
          Effect = "Allow"
          Resource = [
            var.create_session_machine_arn,
            var.terminate_session_machine_arn,
            var.create_instance_machine_arn
          ]
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-lambda"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "lambda:InvokeFunction",
          ]
          Effect = "Allow"
          Resource = [
            aws_lambda_function.templates_function.arn
          ]
        },
      ]
    })
  }
}

resource "aws_iam_role" "templates_function" {
  name = "${var.project}-${var.environment}-templates-function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.project}-${var.environment}-logs"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*",
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-ec2"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeLaunchTemplateVersions",
            "ec2:ModifyLaunchTemplate"
          ]
          Effect   = "Allow"
          Resource = "*",
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-vpc-execution"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:AssignPrivateIpAddresses",
            "ec2:UnassignPrivateIpAddresses"
          ]
          Effect   = "Allow"
          Resource = "*",
        },
      ]
    })
  }
}
