# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "application_table_arn" {
  type = string
}

variable "application_table_name" {
  type = string
}

variable "aws_cognito_user_pool_arn" {
  type = string
}

variable "terminate_session_machine_arn" {
  type = string
}

variable "create_session_machine_arn" {
  type = string
}

variable "create_instance_machine_arn" {
  type = string
}

variable "ip_allow_list" {
  type        = list(string)
  description = "The allowed IP CIDR allowed to access the portal (a.b.c.d/x)"
}