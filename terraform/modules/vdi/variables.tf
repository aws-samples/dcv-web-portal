# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "account_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "kms_key_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "user_pool_id" {
  type = string
}

variable "user_pool_client_id" {
  type = string
}

variable "active_directory_domain_name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "workstation_base_images" {
  type = map(string)
}

variable "tcp_port" {
  type = string
}

variable "udp_port" {
  type = string
}

variable "health_check_port" {
  type = string
}

variable "private_subnets_id" {
}

variable "public_subnets_id" {
}

variable "api_gateway_vpc_endpoint_id" {
  type = string
}

variable "connection_gateway_api" {
  type = string
}

variable "dcv_auth_endpoint" {
  type = string
}

variable "build_image_function" {
  type = string
}