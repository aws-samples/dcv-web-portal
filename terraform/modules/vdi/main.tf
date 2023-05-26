# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

module "amazon_linux_2_image" {
  source                 = "./preset-images/amazon-linux-2"
  region                 = var.region
  project                = var.project
  environment            = var.environment
  account_id             = var.account_id
  kms_key_arn            = var.kms_key_arn
  kms_key_id             = var.kms_key_id
  vpc_id                 = var.vpc_id
  vpc_cidr               = var.vpc_cidr
  udp_port               = var.udp_port
  tcp_port               = var.tcp_port
  launch_template_id     = aws_launch_template.vdi_launch_template["amazon-linux-2"].id
  instance_type          = var.instance_type
  private_subnets_id     = var.private_subnets_id
  public_subnets_id      = var.public_subnets_id
  connection_gateway_api = var.connection_gateway_api
  build_image_function   = var.build_image_function
  linux_base_image       = var.workstation_base_images["amazon-linux-2"]
}

module "windows_server_2022_image" {
  source                 = "./preset-images/windows-server-2022"
  region                 = var.region
  project                = var.project
  environment            = var.environment
  account_id             = var.account_id
  kms_key_arn            = var.kms_key_arn
  kms_key_id             = var.kms_key_id
  vpc_id                 = var.vpc_id
  vpc_cidr               = var.vpc_cidr
  udp_port               = var.udp_port
  tcp_port               = var.tcp_port
  launch_template_id     = aws_launch_template.vdi_launch_template["windows-server-2022"].id
  instance_type          = var.instance_type
  private_subnets_id     = var.private_subnets_id
  public_subnets_id      = var.public_subnets_id
  connection_gateway_api = var.connection_gateway_api
  build_image_function   = var.build_image_function
  windows_base_image     = var.workstation_base_images["windows-server-2022"]
}