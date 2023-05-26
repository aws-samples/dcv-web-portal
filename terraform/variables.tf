# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "project" {
  description = "Project identifier (default: dcv-portal)"
  type        = string
  default     = "dcv-portal"
}

variable "environment" {
  description = "Environment identifier (default: dev)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS deployment region (default: eu-west-1)"
  type        = string
  default     = "eu-west-1"
}

variable "availability_zones" {
  type        = list(string)
  description = "The AZ where the resources will be deployed (default: [\"eu-west-1a\", \"eu-west-1b\"])"
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "vpc_cidr" {
  description = "AWS VPC CIDR (default: 192.168.0.0/16)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "public_subnets_cidr" {
  type        = list(string)
  description = "The CIDR blocks for the public subnet (default: [\"192.168.0.0/25\", \"192.168.2.0/25\"])"
  default     = ["192.168.0.0/25", "192.168.2.0/25"]
}

variable "private_subnets_cidr" {
  type        = list(string)
  description = "The CIDR blocks for the private subnets (default: [\"192.168.0.128/25\", \"192.168.2.128/25\"])"
  default     = ["192.168.0.128/25", "192.168.2.128/25"]
}

variable "ip_allow_list" {
  type        = list(string)
  description = "The list of IP CIDR allowed to access the portal (a.b.c.d/x)"
  default     = ["0.0.0.0/0"]
}

variable "connection_gateway_instance_type" {
  type        = string
  description = "The type of instance used of the connection gateway"
  default     = "t3.small"
}

variable "workstation_instance_type" {
  type        = string
  description = "The type of instance used of the workstations"
  default     = "t3.small"
}

variable "workstation_base_images" {
  type        = map(string)
  description = "The image (AMI) to use for the workstations"
  default = {
    "amazon-linux-2"      = "ami-0ab040d0c6b04cf83" # amzn2-ami-kernel-5.10-hvm-2.0.20230504.1-x86_64-gp2 in eu-west-1 # ami-06a0cd9728546d178 for us-east-1
    "windows-server-2022" = "ami-0274fd9e256dea7b1" # Windows_Server-2022-English-Full-Base-2023.05.10 in eu-west-1 # ami-0d86c69530d0a048e for us-east-1
  }
}

variable "connection_gateway_base_image" {
  type        = string
  description = "The image (AMI) to use for the connection gateway"
  default     = "ami-0ab040d0c6b04cf83" # amzn2-ami-kernel-5.10-hvm-2.0.20230504.1-x86_64-gp2 in eu-west-1 # ami-06a0cd9728546d178 for us-east-1
}

variable "udp_port" {
  type    = string
  default = "8443"
}

variable "tcp_port" {
  type    = string
  default = "8443"
}

variable "health_check_port" {
  type    = string
  default = "8989"
}