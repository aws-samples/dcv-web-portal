# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "connection_gateway_instance_refresh_function" {
  name               = "${var.project}-${var.environment}-connection-gateway-instance-refresh"
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

resource "aws_iam_policy" "connection_gateway_instance_refresh_function_policy" {
  name = "${var.project}-${var.environment}-connection-gateway-instance_refresh"
  path = "/"

  policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*"
   },
   {
     "Effect": "Allow",
     "Action": [
        "autoscaling:StartInstanceRefresh"
     ],
     "Resource": "${aws_autoscaling_group.connection_gateway_asg.arn}"
   },
   {
     "Effect": "Allow",
     "Action" : [
        "iam:PassRole"
     ],
     "Resource": "${aws_iam_role.connection_gateway_instance_role.arn}"
   },
   {
     "Effect": "Allow",
     "Action" : [
       "ec2:RunInstances",
       "ec2:CreateTags",
       "autoscaling:Describe*"
     ],
     "Resource": [
       "*"
     ]
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "connection_gateway_instance_refresh_function_policy_attachment" {
  role       = aws_iam_role.connection_gateway_instance_refresh_function.name
  policy_arn = aws_iam_policy.connection_gateway_instance_refresh_function_policy.arn
}

resource "random_uuid" "connection_gateway_instance_refresh_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("${path.module}/functions/instance-refresh/src", "index.py")
    ) :
    filename => filemd5("${path.module}/functions/instance-refresh/src/${filename}")
  }
}

data "archive_file" "connection_gateway_instance_refresh_function_code" {
  type        = "zip"
  source_dir  = "${path.module}/functions/instance-refresh/src/"
  output_path = "${path.module}/functions/instance-refresh/${random_uuid.connection_gateway_instance_refresh_src_hash.result}.zip"
}

resource "aws_lambda_function" "connection_gateway_instance_refresh_function" {
  depends_on       = [aws_iam_role_policy_attachment.connection_gateway_instance_refresh_function_policy_attachment]
  filename         = data.archive_file.connection_gateway_instance_refresh_function_code.output_path
  source_code_hash = data.archive_file.connection_gateway_instance_refresh_function_code.output_base64sha256
  function_name    = "${var.project}-${var.environment}-connection-gateway-instance-refresh"
  role             = aws_iam_role.connection_gateway_instance_refresh_function.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  tracing_config {
    mode = "Active"
  }

  timeout = 30

  environment {
    variables = {
      AUTOSCALING_GROUP_NAME = aws_autoscaling_group.connection_gateway_asg.name
      LAUNCH_TEMPLATE_ID     = aws_launch_template.connection_gateway_launch_template.id
    }
  }
}

resource "aws_lambda_permission" "instance_refresh_function_invocation" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.connection_gateway_instance_refresh_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.connection_gateway_image_builder_pipeline_success_rule.arn
}