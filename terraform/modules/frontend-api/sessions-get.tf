# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_api_gateway_method" "sessions_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.sessions.id
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_authorizer.id
  http_method   = "GET"
}

resource "aws_api_gateway_method_response" "sessions_get_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.sessions.id
  http_method = aws_api_gateway_method.sessions_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "sessions_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.sessions.id
  http_method             = aws_api_gateway_method.sessions_get.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:dynamodb:action/Query"
  credentials             = aws_iam_role.api.arn

  request_templates = {
    "application/json" = <<TEMPLATE
#if($context.authorizer.claims['cognito:groups'].contains('admin'))
{"TableName": "${var.application_table_name}", "IndexName": "${var.project}-${var.environment}-inverted-idx", "KeyConditionExpression": "sk = :sessionstr and begins_with(pk, :userstr)", "ExpressionAttributeValues": {":sessionstr": {"S": "SESSION#console"}, ":userstr":{"S": "USER#"}}}
#else
{"TableName": "${var.application_table_name}", "KeyConditionExpression": "pk = :userstr and begins_with(sk, :sessionstr)", "ExpressionAttributeValues": {":userstr":{"S":"USER#$context.authorizer.claims['cognito:username']"}, ":sessionstr":{"S": "SESSION#"}}}
#end
TEMPLATE
  }
}


resource "aws_api_gateway_integration_response" "sessions_integration_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_integration.sessions_get_integration.resource_id
  http_method = aws_api_gateway_integration.sessions_get_integration.http_method
  status_code = aws_api_gateway_method_response.sessions_get_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = <<EOT
    #set($inputRoot = $input.path('$')) {
      "sessions": [
        #foreach($elem in $inputRoot.Items) {
          "sessionId": "$elem.sk.S.split('#')[1]",
          "userId": "$elem.pk.S.split('#')[1]",
          "instanceId": "$elem.instanceId.S",
          "status": "$elem.status.S",
          "launchTemplateVersion": "$elem.launchTemplateVersion.S",
          "launchTemplateName": "$elem.launchTemplateName.S",
          "ami": "$elem.ami.S"
        }#if($foreach.hasNext),#end
      #end
      ]
    }
EOT
  }
}