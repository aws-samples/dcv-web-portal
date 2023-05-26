# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Define the security group
resource "aws_security_group" "api_gateway_endpoint_sg" {
  name   = "${var.project}-${var.environment}-api-gw-vpc-endpoint"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow outbound to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gateway_endpoint_sg"
  }
}



# Create a VPC endpoint
resource "aws_vpc_endpoint" "api_gateway" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private_subnet.*.id
  security_group_ids = [aws_security_group.api_gateway_endpoint_sg.id]
}
