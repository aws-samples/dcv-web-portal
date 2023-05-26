# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "api" {
  value = aws_api_gateway_stage.api_prod.invoke_url
}