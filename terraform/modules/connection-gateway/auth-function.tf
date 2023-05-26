# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "connection_gateway_api_auth_function" {
  name               = "${var.project}-${var.environment}-connection-gateway-api-auth"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_policy" "connection_gateway_api_auth_function_policy" {
  name = "${var.project}-${var.environment}-connection-gateway-api-auth"
  path = "/"

  policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "connection_gateway_api_auth_function_policy_attachment" {
  role       = aws_iam_role.connection_gateway_api_auth_function.name
  policy_arn = aws_iam_policy.connection_gateway_api_auth_function_policy.arn
}

resource "aws_iam_role_policy_attachment" "connection_gateway_auth_function_vpc_access_execution" {
  role       = aws_iam_role.connection_gateway_api_auth_function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r ${path.module}/functions/auth/src/requirements.txt -t ${path.module}/functions/auth/src/"
  }

  triggers = {
    dependencies_versions = filemd5("${path.module}/functions/auth/src/requirements.txt")
    source_version1       = filemd5("${path.module}/functions/auth/src/index.py")
    source_version2       = filemd5("${path.module}/functions/auth/src/jwt_auth.py")
    #    dependencies_available = !fileexists("${path.module}/functions/auth/src/jose/__init__.py")
  }
}

resource "random_uuid" "connection_gateway_api_auth_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("${path.module}/functions/auth/src", "requirements.txt"),
      fileset("${path.module}/functions/auth/src", "{index,jwt_auth}.py")
    ) :
    filename => filemd5("${path.module}/functions/auth/src/${filename}")
  }
}

data "archive_file" "connection_gateway_api_auth_function_code" {
  depends_on = [
    null_resource.install_dependencies
  ]
  excludes = [
    "__pycache__",
    "venv",
    ".venv"
  ]
  type        = "zip"
  source_dir  = "${path.module}/functions/auth/src/"
  output_path = "${path.module}/functions/auth/${random_uuid.connection_gateway_api_auth_src_hash.result}.zip"
}

resource "aws_lambda_function" "connection_gateway_api_auth_function" {
  #checkov:skip=CKV_AWS_117:The Lambda function needs to access to cognito and there is no VPC endpoint for cognito, thus not in a VPC
  depends_on       = [aws_iam_role_policy_attachment.connection_gateway_api_auth_function_policy_attachment]
  filename         = data.archive_file.connection_gateway_api_auth_function_code.output_path
  source_code_hash = data.archive_file.connection_gateway_api_auth_function_code.output_base64sha256
  function_name    = "${var.project}-${var.environment}-connection-gateway-api-auth"
  role             = aws_iam_role.connection_gateway_api_auth_function.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  tracing_config {
    mode = "Active"
  }

  timeout = 30

  environment {
    variables = {
      COGNITO_USER_POOL_ID = var.user_pool_id
      APP_CLIENT_ID        = var.user_pool_client_id
      AD_DOMAIN_NAME       = var.active_directory_domain_name
    }
  }
}