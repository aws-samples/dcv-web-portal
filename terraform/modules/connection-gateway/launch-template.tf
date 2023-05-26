# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


# Define the launch template that will be used to launch ALS instance based on the images generated from the pipeline
resource "aws_launch_template" "connection_gateway_launch_template" {
  name = "connection-gateway"

  # IMPORTANT:THIS IMAGE ID is just to avoid the first deployment to fail the very first time (i.e. empty account).
  # the real image id for this launch template will be updated automatically when the image builder pipeline runs
  update_default_version = false
  image_id               = var.linux_base_image

  iam_instance_profile {
    name = aws_iam_instance_profile.connection_gateway_instance_profile.id
  }

  instance_type = var.instance_type

  # root volume
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted   = true
      kms_key_id  = var.kms_key_arn
      volume_size = 8
    }
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      encrypted   = true
      kms_key_id  = var.kms_key_arn
      volume_size = 30
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
    http_put_response_hop_limit = 1
  }

  network_interfaces {
    security_groups       = [aws_security_group.connection_gateway_sg.id]
    subnet_id             = var.private_subnets_id[0]
    delete_on_termination = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "[NICE DCV] Connection Gateway"
    }
  }
}