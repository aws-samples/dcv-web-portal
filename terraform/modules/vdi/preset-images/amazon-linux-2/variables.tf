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

variable "tcp_port" {
  type = string
}

variable "udp_port" {
  type = string
}

variable "health_check_port" {
  type    = string
  default = 8989
}


variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnets_id" {
}

variable "public_subnets_id" {
}

variable "instance_type" {
  type = string
}

variable "linux_base_image" {
  type = string
}

variable "launch_template_id" {
  type = string
}

variable "run_schedule" {
  type    = string
  default = "cron(0 2 ? * 1-5 *)"
}

variable "connection_gateway_api" {
  type = string
}

variable "build_image_function" {
  type = string
}
