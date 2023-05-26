# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "post_confirmation_function_role" {
  name               = "${var.project}-${var.environment}-post-confirm-function-role"
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

resource "aws_iam_policy" "post_confirmation_function_policy" {
  name = "${var.project}-${var.environment}-post-confirm-function-policy"
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
        "secretsmanager:CreateSecret"
     ],
     "Resource": "*",
     "Effect": "Allow"
   },
   {
     "Action": [
       "kms:GenerateDataKey",
       "kms:Decrypt"
     ],
     "Resource": "${var.kms_key_arn}",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "post_confirmation_function_policy_attachment" {
  role       = aws_iam_role.post_confirmation_function_role.name
  policy_arn = aws_iam_policy.post_confirmation_function_policy.arn
}

resource "random_uuid" "post_confirmation_function_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("${path.module}/functions/post-confirmation/src", "index.py")
    ) :
    filename => filemd5("${path.module}/functions/post-confirmation/src/${filename}")
  }
}

data "archive_file" "post_confirmation_function_code" {
  type        = "zip"
  source_dir  = "${path.module}/functions/post-confirmation/src/"
  output_path = "${path.module}/functions/post-confirmation/${random_uuid.post_confirmation_function_src_hash.result}.zip"
}

# function triggered after user creation confirmed to create a secret in secrets manager
resource "aws_lambda_function" "post_confirmation_function" {
  depends_on       = [aws_iam_role_policy_attachment.post_confirmation_function_policy_attachment]
  filename         = data.archive_file.post_confirmation_function_code.output_path
  source_code_hash = data.archive_file.post_confirmation_function_code.output_base64sha256
  function_name    = "${var.project}-${var.environment}-auth-post-confirmation"
  role             = aws_iam_role.post_confirmation_function_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  environment {
    variables = {
      KMS_KEY_ID = var.kms_key_arn
    }
  }
}

resource "aws_lambda_permission" "post_confirmation_function_allow_cognito" {
  statement_id  = "allow-cognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation_function.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pool.arn
}