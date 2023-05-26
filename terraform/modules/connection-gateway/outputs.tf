# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "api" {
  value = aws_api_gateway_stage.connection_gateway_api_stage.invoke_url
}

output "endpoint" {
  value = aws_lb.connection_gateway_lb.dns_name
  # value = aws_route53_record.connection_gateway_record.fqdn
}

output "nlb" {
  value = aws_lb.connection_gateway_lb.arn
}
