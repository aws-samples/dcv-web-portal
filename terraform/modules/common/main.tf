# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "build_image_function_role" {
  name               = "${var.project}-${var.environment}-build-image-function-role"
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

resource "aws_iam_policy" "build_image_function_policy" {
  name = "${var.project}-${var.environment}-build-image-function-policy"
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
        "imagebuilder:StartImagePipelineExecution"
     ],
     "Resource": "arn:aws:imagebuilder:${var.region}:${var.account_id}:image-pipeline/${var.project}-${var.environment}-*",
     "Effect": "Allow"
   },
   {
      "Action": [
        "iam:CreateServiceLinkedRole"
      ],
     "Resource": "arn:aws:iam::${var.account_id}:role/aws-service-role/imagebuilder.amazonaws.com/AWSServiceRoleForImageBuilder",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "build_image_function_policy_attachment" {
  role       = aws_iam_role.build_image_function_role.name
  policy_arn = aws_iam_policy.build_image_function_policy.arn
}

resource "random_uuid" "build_image_function_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("${path.module}/functions/build-image/src", "index.py")
    ) :
    filename => filemd5("${path.module}/functions/build-image/src/${filename}")
  }
}

data "archive_file" "build_image_function_code" {
  type        = "zip"
  source_dir  = "${path.module}/functions/build-image/src/"
  output_path = "${path.module}/functions/build-image/${random_uuid.build_image_function_src_hash.result}.zip"
}

# function that triggers the image builder pipeline after deployment
resource "aws_lambda_function" "build_image_function" {
  depends_on       = [aws_iam_role_policy_attachment.build_image_function_policy_attachment]
  filename         = data.archive_file.build_image_function_code.output_path
  source_code_hash = data.archive_file.build_image_function_code.output_base64sha256
  function_name    = "${var.project}-${var.environment}-build-image"
  role             = aws_iam_role.build_image_function_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  tracing_config {
    mode = "Active"
  }

  timeout = 30
}