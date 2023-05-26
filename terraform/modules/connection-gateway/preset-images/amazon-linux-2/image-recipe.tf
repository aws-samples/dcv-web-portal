# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Define the connection-gateway image recipe
resource "aws_imagebuilder_image_recipe" "connection_gateway_image_builder_recipe" {
  depends_on   = [aws_imagebuilder_component.connection_gateway_component]
  name         = "${var.project}-${var.environment}-connection-gateway"
  parent_image = var.linux_base_image #"arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2-x86/x.x.x"
  version      = "1.0.0"


  block_device_mapping {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.kms_key_arn
    }
  }

  # CloudWatch agent component
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/amazon-cloudwatch-agent-linux/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/update-linux/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/update-linux-kernel-5/x.x.x"
  }

  # Connection Gateway Component defined in connection-gateway-component.tf (x.x.x === always fetch latest version available)
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:${var.account_id}:component/${var.project}-${var.environment}-connection-gateway/x.x.x"
  }
}