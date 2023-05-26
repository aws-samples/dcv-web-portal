# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Define the EC2 image builder instance role (instance used to rebuild the image for new updates or at defined cadence)
# https://docs.aws.amazon.com/imagebuilder/latest/userguide/image-builder-setting-up.html#image-builder-IAM-prereq
resource "aws_iam_role" "connection_gateway_image_builder_instance_role" {
  name = "${var.project}-${var.environment}-connection-gateway-image-builder"
  path = "/"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
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
}

# Needed to allow to write to KMS encrypted bucket
resource "aws_iam_role_policy" "connection_gateway_image_builder_instance_role_kms_policy" {
  name = "${var.project}-${var.environment}-connection-gateway-image-builder-instance-role-policy"
  role = aws_iam_role.connection_gateway_image_builder_instance_role.id

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

# Define the instance profile applied to EC2 builder instance
resource "aws_iam_instance_profile" "connection_gateway_image_builder_instance_profile" {
  name_prefix = "${var.project}-${var.environment}-connection-gateway-image-builder"
  role        = aws_iam_role.connection_gateway_image_builder_instance_role.name
}

# Define the security group applied to EC2 builder instance
resource "aws_security_group" "connection_gateway_builder_sg" {
  name        = "${var.project}-${var.environment}-connection-gateway-image-builder-sg"
  vpc_id      = var.vpc_id
  description = "Connection gateway EC2 image builder SG"


  egress {
    description      = "Allow outbound to anywhere"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Define the connection gateway image pipeline infrastructure
resource "aws_imagebuilder_infrastructure_configuration" "connection_gateway_image_builder_infrastructure_configuration" {
  name                          = "${var.project}-${var.environment}-connection-gateway"
  instance_profile_name         = aws_iam_instance_profile.connection_gateway_image_builder_instance_profile.name
  instance_types                = [var.instance_type]
  terminate_instance_on_failure = true


  subnet_id          = var.public_subnets_id[0]
  security_group_ids = [aws_security_group.connection_gateway_builder_sg.id]

  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.software_bucket.id
      s3_key_prefix  = "pipeline-logs"
    }
  }
}

# Define distribution settings
resource "aws_imagebuilder_distribution_configuration" "connection_gateway_image_builder_distribution_configuration" {
  name        = "${var.project}-${var.environment}-connection-gateway"
  description = "AMI to launch connection gateway instances"

  distribution {
    region = var.region

    ami_distribution_configuration {
      name       = "${var.project}-${var.environment}-connection-gateway-{{ imagebuilder:buildDate }}"
      kms_key_id = var.kms_key_id
    }

    launch_template_configuration {
      launch_template_id = var.launch_template_id
      default            = true
    }
  }
}

# Define the pipeline
resource "aws_imagebuilder_image_pipeline" "connection_gateway_image_builder_pipeline" {
  name        = "${var.project}-${var.environment}-connection-gateway"
  description = "[Connection Gateway Server Image Pipline] Handles Licensing System installation, patching and automatic Security Updates"

  image_recipe_arn                 = aws_imagebuilder_image_recipe.connection_gateway_image_builder_recipe.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.connection_gateway_image_builder_distribution_configuration.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.connection_gateway_image_builder_infrastructure_configuration.arn

  enhanced_image_metadata_enabled = false

  image_tests_configuration {
    image_tests_enabled = false
  }

  schedule {
    pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
    schedule_expression                = var.run_schedule
  }
}

#  Define the instance role for connection gateway running instance
resource "aws_iam_role" "connection_gateway_instance_role" {
  name_prefix = "${var.project}-${var.environment}-connection-gateway"
  path        = "/"
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
}

# Needed to allow to builder instance read/write to KMS encrypted bucket
resource "aws_iam_role_policy" "connection_gateway_instance_role_kms_policy" {
  name = "${var.project}-${var.environment}-connection-gateway-instance-role-policy"
  role = aws_iam_role.connection_gateway_instance_role.id

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
resource "aws_iam_instance_profile" "connection_gateway_instance_profile" {
  name_prefix = "${var.project}-${var.environment}-connection-gateway"
  role        = aws_iam_role.connection_gateway_instance_role.name
}

data "aws_lambda_invocation" "build_image_connection_gateway" {
  function_name = var.build_image_function

  input = <<JSON
{
  "apply_date": "${timestamp()}",
  "image_pipeline_arn": "${aws_imagebuilder_image_pipeline.connection_gateway_image_builder_pipeline.arn}"
}
JSON
}
