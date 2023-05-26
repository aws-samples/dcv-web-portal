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

variable "region" {
  type        = string
  description = "The Deployment region"
}

variable "account_id" {
  type        = string
  description = "The AWS account where resources are deployed"
}