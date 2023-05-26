# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "private_subnets" {
  value = aws_subnet.private_subnet.*
}

output "public_subnets" {
  value = aws_subnet.public_subnet.*
}


output "private_subnets_ids" {
  value = aws_subnet.private_subnet.*.id
}

output "public_subnets_ids" {
  value = aws_subnet.public_subnet.*.id
}


output "api_gateway_vpc_endpoint_id" {
  value = aws_vpc_endpoint.api_gateway.id
}