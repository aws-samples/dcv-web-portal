# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_api_gateway_method" "instances_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.instances.id
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_authorizer.id
  http_method   = "GET"
}

resource "aws_api_gateway_method_response" "instances_get_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.instances.id
  http_method = aws_api_gateway_method.instances_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "instances_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.instances.id
  http_method             = aws_api_gateway_method.instances_get.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:dynamodb:action/Query"
  credentials             = aws_iam_role.api.arn

  request_templates = {
    "application/json" = jsonencode({
      TableName              = var.application_table_name,
      Select                 = "COUNT"
      KeyConditionExpression = "pk = :val",
      ExpressionAttributeValues = {
        ":val" = {
          "S" = "INSTANCE#preallocate"
        }
      },
    })
  }
}


resource "aws_api_gateway_integration_response" "instances_integration_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_integration.instances_get_integration.resource_id
  http_method = aws_api_gateway_integration.instances_get_integration.http_method
  status_code = aws_api_gateway_method_response.instances_get_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = <<EOT
            #set($inputRoot = $input.path('$')) {
              "count": $inputRoot.Count
            }
EOT
  }
}