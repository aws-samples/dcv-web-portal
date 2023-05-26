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

variable "vpc_id" {
  type        = string
  description = "The VPC ID"
}

variable "private_subnets_id" {
  type        = list(string)
  description = "The CIDR block for the private subnet"
}

variable "kms_key_arn" {
  type        = string
  description = "The KMS Key ARN to be used to encrypt resources"
}

variable "active_directory_domain_name" {
  description = "The Active Directory Domain Name"
}
