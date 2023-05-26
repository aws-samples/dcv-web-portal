# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "connection_gateway_api_cloudwatch" {
  name_prefix = "${var.project}-${var.environment}-con-gw-api-cw"

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
          Resource = "*"
        },
      ]
    })
  }
}

resource "aws_api_gateway_account" "connection_gateway_api_account" {
  cloudwatch_role_arn = aws_iam_role.connection_gateway_api_cloudwatch.arn
}

resource "aws_api_gateway_rest_api" "connection_gateway_api" {
  name                         = "${var.project}-${var.environment}-connection-gateway-api"
  description                  = "Connection Gateway API"
  disable_execute_api_endpoint = false

  endpoint_configuration {
    vpc_endpoint_ids = [var.api_gateway_vpc_endpoint_id]
    types            = ["PRIVATE"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_rest_api_policy" "connection_gateway_api_resource_policy" {
  rest_api_id = aws_api_gateway_rest_api.connection_gateway_api.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": "${aws_api_gateway_rest_api.connection_gateway_api.execution_arn}/*"
        },
        {
            "Effect": "Deny",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": "${aws_api_gateway_rest_api.connection_gateway_api.execution_arn}/*",
            "Condition": {
                "StringNotEquals": {
                    "aws:SourceVpc": "${var.vpc_id}"
                }
            }
        }
    ]
}
EOF
}

resource "aws_api_gateway_deployment" "connection_gateway_api_deployment" {
  rest_api_id       = aws_api_gateway_rest_api.connection_gateway_api.id
  stage_description = "Deployed at ${timestamp()}"

  depends_on = [
    aws_api_gateway_rest_api_policy.connection_gateway_api_resource_policy,
    aws_api_gateway_integration.resolve_session_get_integration,
    aws_api_gateway_integration.auth_get_integration,
  ]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.connection_gateway_api.body))
  }
}

resource "aws_api_gateway_stage" "connection_gateway_api_stage" {
  deployment_id        = aws_api_gateway_deployment.connection_gateway_api_deployment.id
  rest_api_id          = aws_api_gateway_rest_api.connection_gateway_api.id
  xray_tracing_enabled = true
  stage_name           = "prod"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.connection_gateway_api_stage_log.arn
    format          = "{ \"requestId\":\"$context.requestId\", \"ip\": \"$context.identity.sourceIp\", \"caller\":\"$context.identity.caller\", \"user\":\"$context.identity.user\",\"requestTime\":\"$context.requestTime\", \"httpMethod\":\"$context.httpMethod\",\"resourcePath\":\"$context.resourcePath\", \"status\":\"$context.status\",\"protocol\":\"$context.protocol\", \"responseLength\":\"$context.responseLength\" }"
  }
}

resource "aws_cloudwatch_log_group" "connection_gateway_api_stage_log" {
  name              = "/aws/apigateway/${var.project}-${var.environment}/connection-gateway-api"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 30
}

resource "aws_api_gateway_method_settings" "connection_gateway_api_general_settings" {
  rest_api_id = aws_api_gateway_rest_api.connection_gateway_api.id
  stage_name  = aws_api_gateway_stage.connection_gateway_api_stage.stage_name
  method_path = "*/*"

  depends_on = [aws_api_gateway_account.connection_gateway_api_account]

  settings {
    # Enable CloudWatch logging and metrics
    metrics_enabled    = true
    data_trace_enabled = false # set to true for development only
    logging_level      = "INFO"

    # Limit the rate of calls to prevent abuse and unwanted charges
    throttling_rate_limit  = 100
    throttling_burst_limit = 500
  }
}

resource "aws_lambda_permission" "connection_gateway_api_resolve_session_lambda_permission" {
  statement_id  = "AllowResolveSessionExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.connection_gateway_resolve_session_function.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.connection_gateway_api.id}/*/*"
}

resource "aws_lambda_permission" "connection_gateway_api_auth_lambda_permission" {
  statement_id  = "AllowAuthFunctionExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.connection_gateway_api_auth_function.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.connection_gateway_api.id}/*/*"
}

resource "aws_security_group" "connection_gateway_functions_sg" {
  name        = "${var.project}-${var.environment}-connection-gateway-functions-sg"
  description = "Security Group of the Lambda functions used by the dcv connection gateway"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound from anywhere within the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description      = "Allow outbound to anywhere"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
