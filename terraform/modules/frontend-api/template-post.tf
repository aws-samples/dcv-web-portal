# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_api_gateway_method" "template_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.template.id
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_authorizer.id
  http_method   = "POST"
}

resource "aws_api_gateway_method_response" "template_post_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.template.id
  http_method = aws_api_gateway_method.template_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "template_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.template.id
  http_method             = aws_api_gateway_method.template_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.templates_function.invoke_arn
  credentials             = aws_iam_role.api.arn
}

resource "aws_api_gateway_integration_response" "template_integration_post_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_integration.template_post_integration.resource_id
  http_method = aws_api_gateway_integration.template_post_integration.http_method
  status_code = aws_api_gateway_method_response.template_post_200.status_code

  response_templates = {
    "application/json" = "$input.json('$')"
  }
}