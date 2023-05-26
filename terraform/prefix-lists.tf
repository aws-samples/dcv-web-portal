# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Prefix lists will let us reduce the amount of traffic we see
resource "aws_ec2_managed_prefix_list" "allowed_ips" {
  name           = "Allowed traffic via the network load balancer"
  address_family = "IPv4"
  max_entries    = 20

  entry {
    cidr        = "0.0.0.0/0"
    description = "Everywhere"
  }
}