# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#Parameters for CloudWatch Agent
resource "aws_ssm_parameter" "cloudwatch_dcv_connection_gateway_config" {
  name   = "AmazonCloudWatch-dcv-connection-gateway-config"
  value  = file("${path.module}/ConnectionGatewayCloudWatchConfig.json")
  type   = "String"
  key_id = var.kms_key_arn
}