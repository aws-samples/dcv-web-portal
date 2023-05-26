# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_api_gateway_method" "instances_put" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.instances.id
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_authorizer.id
  http_method   = "PUT"
}

resource "aws_api_gateway_method_response" "instances_put_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.instances.id
  http_method = aws_api_gateway_method.instances_put.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "instances_put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.instances.id
  http_method             = aws_api_gateway_method.instances_put.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  passthrough_behavior    = "NEVER"
  uri                     = "arn:aws:apigateway:${var.region}:states:action/StartExecution"
  credentials             = aws_iam_role.api.arn

  request_templates = {
    "application/json" = <<EOT
      #if($context.authorizer.claims['cognito:groups'].contains('admin'))
      {"stateMachineArn":"${var.create_instance_machine_arn}", "input":"{ \"count\":1, \"launchTemplateName\":$util.escapeJavaScript($input.json('$.launchTemplateName')), \"launchTemplateVersion\":$util.escapeJavaScript($input.json('$.launchTemplateVersion')), \"type\":\"preallocate\"}"}
      #end
    EOT
  }
}

resource "aws_api_gateway_integration_response" "instances_integration_put_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_integration.instances_put_integration.resource_id
  http_method = aws_api_gateway_integration.instances_put_integration.http_method
  status_code = aws_api_gateway_method_response.instances_put_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "$input.json('$')"
  }
}