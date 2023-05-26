# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "random_uuid" "templates_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("${path.module}/functions/templates/src", "index.py")
    ) :
    filename => filemd5("${path.module}/functions/templates/src/${filename}")
  }
}

data "archive_file" "templates_function_code" {
  type        = "zip"
  source_dir  = "${path.module}/functions/templates/src"
  output_path = "${path.module}/functions/templates/${random_uuid.templates_src_hash.result}.zip"
}

resource "aws_lambda_function" "templates_function" {
  function_name    = "${var.project}-${var.environment}-frontend-api-templates"
  architectures    = ["arm64"]
  filename         = data.archive_file.templates_function_code.output_path
  source_code_hash = data.archive_file.templates_function_code.output_base64sha256
  role             = aws_iam_role.templates_function.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  tracing_config {
    mode = "Active"
  }
}
