# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#  Define the instance role for connection gateway running instance
resource "aws_iam_role" "connection_gateway_instance_role" {
  name = "${var.project}-${var.environment}-connection-gateway"
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
  name = "${var.project}-${var.environment}-connection-gateway"
  role = aws_iam_role.connection_gateway_instance_role.name
}

# Define the security group applied to running instance
resource "aws_security_group" "connection_gateway_sg" {
  name        = "${var.project}-${var.environment}-connection-gateway"
  description = "DCV connection gateway SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Inbound NICE TCP from VPC via NLB and Prefix List"
    from_port       = var.tcp_port
    to_port         = var.tcp_port
    protocol        = "tcp"
    cidr_blocks     = [var.vpc_cidr]
    prefix_list_ids = [var.prefix_list_id]
  }

  ingress {
    description     = "Inbound NICE UDP from VPC via NLB"
    from_port       = var.udp_port
    to_port         = var.udp_port
    protocol        = "udp"
    cidr_blocks     = [var.vpc_cidr]
    prefix_list_ids = [var.prefix_list_id]
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

## ASG version
resource "aws_autoscaling_group" "connection_gateway_asg" {
  depends_on        = [aws_launch_template.connection_gateway_launch_template, module.image_builder]
  name              = "${var.project}-${var.environment}-connection-gateway"
  max_size          = 4
  min_size          = 1
  health_check_type = "EC2"
  desired_capacity  = 1

  target_group_arns = (var.udp_port != var.tcp_port) ? [
    aws_lb_target_group.connection_gateway_target_group_tcp[0].arn, aws_lb_target_group.connection_gateway_target_group_udp[0].arn
  ] : [ aws_lb_target_group.connection_gateway_target_group_tcp_udp[0].arn ]
  vpc_zone_identifier = var.private_subnets_id

  launch_template {
    id      = aws_launch_template.connection_gateway_launch_template.id
    version = aws_launch_template.connection_gateway_launch_template.default_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      instance_warmup = 300
    }
  }

  wait_for_capacity_timeout = 0

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "[NICE DCV] Connection Gateway"
  }
}

# Define an EventBridge rule to refresh the instances in the ASG with the latest launch template / AMI
resource "aws_cloudwatch_event_rule" "connection_gateway_image_builder_pipeline_success_rule" {
  name          = "capture-connection-gateway-image-built"
  description   = "Rule triggered when a connection gateway AMI and Launch Template are successfully built by Image Builder"
  event_pattern = <<EOF
{
  "source": ["aws.ec2"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["ModifyLaunchTemplate"],
    "userAgent": ["imagebuilder.amazonaws.com"],
    "requestParameters": {
      "ModifyLaunchTemplateRequest": {
        "LaunchTemplateId": ["${aws_launch_template.connection_gateway_launch_template.id}"]
      }
    },
    "responseElements": {
      "ModifyLaunchTemplateResponse": {
        "launchTemplate": {
            "launchTemplateId": ["${aws_launch_template.connection_gateway_launch_template.id}"]
        }
      }
    }
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "connection_gateway_image_builder_pipeline_success_target" {
  rule = aws_cloudwatch_event_rule.connection_gateway_image_builder_pipeline_success_rule.name
  arn  = aws_lambda_function.connection_gateway_instance_refresh_function.arn
}

# Single Instance Version
#resource "aws_instance" "connection_gateway" {
#   depends_on                = [aws_launch_template.connection_gateway_launch_template, module.image_builder]
#   iam_instance_profile = aws_iam_instance_profile.connection_gateway_instance_profile.name
#   launch_template {
#     id      = aws_launch_template.connection_gateway_launch_template.id
#     version = aws_launch_template.connection_gateway_launch_template.default_version
#   }
#
#    tags = {
#      Name        = "[NICE DCV] Connection Gateway"
#    }
#}
#
#resource "aws_lb_target_group_attachment" "connection_gateway_tcp_attachment" {
#  target_group_arn = aws_lb_target_group.connection_gateway_target_group_tcp.arn
#  target_id        = aws_instance.connection_gateway.id
#  port             = var.tcp_port
#}
#
#resource "aws_lb_target_group_attachment" "connection_gateway_udp_attachment" {
#  target_group_arn = aws_lb_target_group.connection_gateway_target_group_udp.arn
#  target_id        = aws_instance.connection_gateway.id
#  port             = var.udp_port
#}