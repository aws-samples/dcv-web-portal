# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.3.0, < 2.0.0"

  required_providers {
    aws = {
      version = "~> 4.14"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      "environment" = var.environment
    }
  }
}

# Helpers references
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

module "common" {
  source      = "./modules/common"
  region      = var.region
  project     = var.project
  environment = var.environment
  account_id  = data.aws_caller_identity.current.account_id
}

# Networking module: VPC, subnets, ...
module "networking" {
  source               = "./modules/networking"
  region               = var.region
  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  availability_zones   = var.availability_zones
  kms_key_arn          = aws_kms_key.key.arn
}

# Authentication module: Active Directory, Cognito user pool, ...
module "authentication" {
  source                       = "./modules/authentication"
  project                      = var.project
  environment                  = var.environment
  vpc_id                       = module.networking.vpc_id
  private_subnets_id           = module.networking.private_subnets.*.id
  kms_key_arn                  = aws_kms_key.key.arn
  active_directory_domain_name = "${var.project}-${var.environment}.com"
}

module "connection_gateway" {
  source                       = "./modules/connection-gateway"
  region                       = var.region
  project                      = var.project
  environment                  = var.environment
  account_id                   = data.aws_caller_identity.current.account_id
  kms_key_id                   = aws_kms_key.key.id
  kms_key_arn                  = aws_kms_key.key.arn
  vpc_id                       = module.networking.vpc_id
  vpc_cidr                     = module.networking.vpc_cidr
  private_subnets_id           = module.networking.private_subnets.*.id
  public_subnets_id            = module.networking.public_subnets.*.id
  active_directory_domain_name = "${var.project}-${var.environment}.com"
  user_pool_id                 = module.authentication.user_pool_id
  user_pool_client_id          = module.authentication.user_pool_client_id
  linux_base_image             = var.connection_gateway_base_image
  api_gateway_vpc_endpoint_id  = module.networking.api_gateway_vpc_endpoint_id
  instance_type                = var.connection_gateway_instance_type
  udp_port                     = var.udp_port
  tcp_port                     = var.tcp_port
  health_check_port            = var.health_check_port
  prefix_list_id               = aws_ec2_managed_prefix_list.allowed_ips.id
  build_image_function         = module.common.build_image_function
}

module "vdi" {
  source                       = "./modules/vdi"
  region                       = var.region
  project                      = var.project
  environment                  = var.environment
  account_id                   = data.aws_caller_identity.current.account_id
  kms_key_id                   = aws_kms_key.key.id
  kms_key_arn                  = aws_kms_key.key.arn
  vpc_id                       = module.networking.vpc_id
  vpc_cidr                     = module.networking.vpc_cidr
  private_subnets_id           = module.networking.private_subnets.*.id
  public_subnets_id            = module.networking.public_subnets.*.id
  active_directory_domain_name = "${var.project}-${var.environment}.com"
  user_pool_id                 = module.authentication.user_pool_id
  user_pool_client_id          = module.authentication.user_pool_client_id
  #  linux_base_image             = var.linux_workstation_base_image
  #  windows_base_image           = var.windows_workstation_base_image
  workstation_base_images     = var.workstation_base_images
  api_gateway_vpc_endpoint_id = module.networking.api_gateway_vpc_endpoint_id
  instance_type               = var.workstation_instance_type
  udp_port                    = var.udp_port
  tcp_port                    = var.tcp_port
  health_check_port           = var.health_check_port
  connection_gateway_api      = module.connection_gateway.api
  dcv_auth_endpoint           = "${module.connection_gateway.api}/auth"
  build_image_function        = module.common.build_image_function
}


module "frontend_api" {
  source                        = "./modules/frontend-api"
  project                       = var.project
  environment                   = var.environment
  region                        = var.region
  account_id                    = data.aws_caller_identity.current.account_id
  kms_key_arn                   = aws_kms_key.key.arn
  ip_allow_list                 = var.ip_allow_list
  application_table_arn         = module.vdi.application_table_arn
  application_table_name        = module.vdi.application_table_name
  aws_cognito_user_pool_arn     = module.authentication.user_pool_arn
  create_session_machine_arn    = module.vdi.create_session_machine_arn
  create_instance_machine_arn   = module.vdi.create_instance_machine_arn
  terminate_session_machine_arn = module.vdi.terminate_session_machine_arn
}


# Frontend module: React UI (S3 / CloudFront / WAF)
module "frontend" {
  source                  = "./modules/frontend"
  region                  = var.region
  account_id              = data.aws_caller_identity.current.account_id
  project                 = var.project
  environment             = var.environment
  ip_allow_list           = var.ip_allow_list
  kms_key_arn             = aws_kms_key.key.arn
  user_pool_id            = module.authentication.user_pool_id
  user_pool_client_id     = module.authentication.user_pool_client_id
  identity_pool_id        = module.authentication.identity_pool_id

  connection_gateway_endpoint = module.connection_gateway.endpoint
  connection_gateway_tcp_port = var.tcp_port
  api_endpoint                = module.frontend_api.api
}
