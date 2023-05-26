# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0



#  Define the instance role for connection gateway running instance
resource "aws_iam_role" "vdi_instance_role" {
  name = "${var.project}-${var.environment}-vdi"
  path = "/"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, tags_all e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags, tags_all
    ]
  }
}

# Needed to allow to builder instance read/write to KMS encrypted bucket
resource "aws_iam_role_policy" "vdi_instance_role_kms_policy" {
  name = "${var.project}-${var.environment}-vdi-instance-role-policy"
  role = aws_iam_role.vdi_instance_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = [var.kms_key_arn]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.region}:*:log-group:/aws/imagebuilder/*"
      }
    ]
  })
}

# Define the instance profile applied to ALS running instance
resource "aws_iam_instance_profile" "vdi_instance_profile" {
  name = "${var.project}-${var.environment}-vdi"
  role = aws_iam_role.vdi_instance_role.name
}

# Define the security group applied to running instance
resource "aws_security_group" "vdi_sg" {
  name        = "${var.project}-${var.environment}-vdi"
  description = "Workstations SG"
  vpc_id      = var.vpc_id

  ingress {
    description = "Inbound NICE TCP from VPC via NLB"
    from_port   = var.tcp_port
    to_port     = var.tcp_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Inbound NICE UDP from VPC via NLB"
    from_port   = var.udp_port
    to_port     = var.udp_port
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Inbound Healthcheck from VPC via NLB"
    from_port   = var.health_check_port
    to_port     = var.health_check_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description      = "Allow outbound to anywhere"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
