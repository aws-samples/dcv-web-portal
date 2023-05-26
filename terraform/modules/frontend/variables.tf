# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "project" {
  type        = string
  description = "The project name"
}

variable "environment" {
  type        = string
  description = "The Deployment environment"
}

variable "kms_key_arn" {
  type = string
}

variable "account_id" {
  type        = string
  description = "The Deployment account"
}

variable "region" {
  type        = string
  description = "The Deployment region"
}

variable "user_pool_id" {
  type        = string
  description = "The Cognito User Pool ID"
}

variable "user_pool_client_id" {
  type        = string
  description = "The Cognito User Pool Client ID"
}

variable "identity_pool_id" {
  type        = string
  description = "The Cognito Identity Pool ID"
}

variable "connection_gateway_endpoint" {
  type        = string
  description = "The NICE DCV Connection Gateway Endpoint"
}

variable "connection_gateway_tcp_port" {
  type = string
  description = "TCP Port to connect to Connection Gateway"
}

variable "api_endpoint" {
  type        = string
  description = "The API Endpoint"
}

variable "ip_allow_list" {
  type        = list(string)
  description = "The allowed IP CIDR allowed to access the portal (a.b.c.d/x)"
}
