# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_api_gateway_account" "api_account" {
  cloudwatch_role_arn = aws_iam_role.api_cloudwatch.arn
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project}-${var.environment}-session-api"
  description = "Session API"
  depends_on  = [aws_api_gateway_account.api_account]

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    create_before_destroy = true
  }

  # Only allow some IPs to access the API
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "execute-api:/*/*/*"
    },
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "execute-api:/*/*/*",
      "Condition": {
        "NotIpAddress": {
          "aws:SourceIp": ["${join("\", \"", var.ip_allow_list)}"]
        }
      }
    }
  ]
}
EOF
}

resource "aws_api_gateway_authorizer" "api_authorizer" {
  name          = "${var.project}-${var.environment}-authorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  provider_arns = [var.aws_cognito_user_pool_arn]
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  stage_description = "Deployed at ${timestamp()}"

  depends_on = [
    aws_api_gateway_integration.sessions_options_integration,
    aws_api_gateway_integration.session_options_integration,
    aws_api_gateway_integration.instances_options_integration,
    aws_api_gateway_integration.templates_options_integration,
    aws_api_gateway_integration.template_options_integration,
    aws_api_gateway_integration.instances_put_integration,
    aws_api_gateway_integration.instances_get_integration,
    aws_api_gateway_integration.sessions_get_integration,
    aws_api_gateway_integration.sessions_put_integration,
    aws_api_gateway_integration.session_delete_integration,
    aws_api_gateway_integration.templates_get_integration,
    aws_api_gateway_integration.template_get_integration,
    aws_api_gateway_integration.template_post_integration,
  ]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api.body))
  }
}

resource "aws_api_gateway_stage" "api_prod" {
  deployment_id        = aws_api_gateway_deployment.api_deployment.id
  rest_api_id          = aws_api_gateway_rest_api.api.id
  stage_name           = "prod"
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access_logs.arn
    format = jsonencode({
      requestId         = "$context.requestId"
      extendedRequestId = "$context.extendedRequestId"
      ip                = "$context.identity.sourceIp"
      caller            = "$context.identity.caller"
      user              = "$context.identity.user"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      resourcePath      = "$context.resourcePath"
      status            = "$context.status"
      protocol          = "$context.protocol"
      responseLength    = "$context.responseLength"
    })
  }
}

resource "aws_api_gateway_method_settings" "general_settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_prod.stage_name
  method_path = "*/*"

  depends_on = [aws_api_gateway_account.api_account]

  settings {
    # Enable CloudWatch logging and metrics
    metrics_enabled    = true
    data_trace_enabled = false # set to true for development only
    logging_level      = "INFO"

    # Limit the rate of calls to prevent abuse and unwanted charges
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
  }
}

resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "${var.project}-${var.environment}-frontend-api-access-logs"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}