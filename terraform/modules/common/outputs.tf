# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "build_image_function" {
  value = aws_lambda_function.build_image_function.function_name
}
