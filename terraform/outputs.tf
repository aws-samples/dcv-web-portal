# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "networking_vpc_id" {
  value = module.networking.vpc_id
}

output "network_load_balancer" {
  value = module.connection_gateway.nlb
}

output "networking_private_subnets_ids" {
  value = module.networking.private_subnets_ids
}

output "networking_public_subnets_ids" {
  value = module.networking.public_subnets_ids
}

output "authentication_user_pool_id" {
  value = module.authentication.user_pool_id
}

output "authentication_user_pool_client_id" {
  value = module.authentication.user_pool_client_id
}

output "authentication_identity_pool_id" {
  value = module.authentication.identity_pool_id
}

output "frontend_bucket" {
  value = module.frontend.frontend_bucket
}

output "frontend_distribution_id" {
  value = module.frontend.frontend_distribution_id
}

output "frontend_url" {
  value = module.frontend.frontend_distribution_endpoint
}

output "frontend_api" {
  value = module.frontend_api.api
}

output "connection_gateway" {
  value = module.connection_gateway.endpoint
}

output "connection_gateway_api" {
  value = module.connection_gateway.api
}
