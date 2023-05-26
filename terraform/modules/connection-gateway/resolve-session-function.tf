# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "connection_gateway_resolve_session_function" {
  name               = "${var.project}-${var.environment}-connection-gateway-api-resolve-session"
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

resource "aws_iam_role_policy_attachment" "connection_gateway_resolve_session_function_vpc_access_execution" {
  role       = aws_iam_role.connection_gateway_resolve_session_function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "connection_gateway_resolve_session_function_policy" {
  name = "${var.project}-${var.environment}-connection-gateway-api-resolve-session"
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
   },
   {
     "Action": [
       "ec2:DescribeInstances"
     ],
     "Resource": "*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "connection_gateway_resolve_session_function_policy_attachment" {
  role       = aws_iam_role.connection_gateway_resolve_session_function.name
  policy_arn = aws_iam_policy.connection_gateway_resolve_session_function_policy.arn
}

resource "random_uuid" "connection_gateway_resolve_session_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("${path.module}/functions/resolve-session/src", "index.py")
    ) :
    filename => filemd5("${path.module}/functions/resolve-session/src/${filename}")
  }
}

data "archive_file" "connection_gateway_resolve_session_function_code" {
  type        = "zip"
  source_dir  = "${path.module}/functions/resolve-session/src"
  output_path = "${path.module}/functions/resolve-session/${random_uuid.connection_gateway_resolve_session_src_hash.result}.zip"
}

resource "aws_lambda_function" "connection_gateway_resolve_session_function" {
  depends_on = [aws_iam_role_policy_attachment.connection_gateway_resolve_session_function_policy_attachment]

  filename         = data.archive_file.connection_gateway_resolve_session_function_code.output_path
  source_code_hash = data.archive_file.connection_gateway_resolve_session_function_code.output_base64sha256
  function_name    = "${var.project}-${var.environment}-connection-gateway-api-resolve-session"
  role             = aws_iam_role.connection_gateway_resolve_session_function.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnets_id
    security_group_ids = [aws_security_group.connection_gateway_functions_sg.id]
  }

  environment {
    variables = {
      TCP_PORT = var.tcp_port
      UDP_PORT = var.udp_port
    }
  }

}
