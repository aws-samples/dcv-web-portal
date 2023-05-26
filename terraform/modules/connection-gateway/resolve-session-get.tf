# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_api_gateway_resource" "connection_gateway_api_resolve_session_resource" {
  rest_api_id = aws_api_gateway_rest_api.connection_gateway_api.id
  parent_id   = aws_api_gateway_rest_api.connection_gateway_api.root_resource_id
  path_part   = "resolveSession"
}

resource "aws_api_gateway_method" "resolve_session_get" {
  rest_api_id   = aws_api_gateway_rest_api.connection_gateway_api.id
  resource_id   = aws_api_gateway_resource.connection_gateway_api_resolve_session_resource.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }

}

resource "aws_api_gateway_method_response" "resolve_session_get_200" {
  rest_api_id = aws_api_gateway_rest_api.connection_gateway_api.id
  resource_id = aws_api_gateway_resource.connection_gateway_api_resolve_session_resource.id
  http_method = aws_api_gateway_method.resolve_session_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "resolve_session_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.connection_gateway_api.id
  resource_id             = aws_api_gateway_resource.connection_gateway_api_resolve_session_resource.id
  http_method             = aws_api_gateway_method.resolve_session_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.connection_gateway_resolve_session_function.invoke_arn
}
