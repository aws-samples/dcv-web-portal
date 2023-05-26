# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

module "image_builder" {
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
  instance_type          = var.instance_type
  linux_base_image       = var.linux_base_image
  launch_template_id     = aws_launch_template.connection_gateway_launch_template.id
  private_subnets_id     = var.private_subnets_id
  public_subnets_id      = var.public_subnets_id
  connection_gateway_api = aws_api_gateway_stage.connection_gateway_api_stage.invoke_url
  build_image_function   = var.build_image_function
}
