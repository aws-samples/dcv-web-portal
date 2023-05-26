# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_imagebuilder_image_recipe" "vdi_image_builder_recipe" {
  depends_on   = [aws_imagebuilder_component.vdi_component, aws_imagebuilder_component.nice_dcv_component]
  name         = "${var.project}-${var.environment}-${local.os}-${local.os_version}-vdi"
  parent_image = var.windows_base_image
  version      = "1.0.0"

  block_device_mapping {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.kms_key_arn
    }
  }

  # Update windows
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/update-windows/x.x.x"
  }

  # CloudWatch agent component
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/amazon-cloudwatch-agent-windows/x.x.x"
  }

  # Powershell
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/powershell-windows/x.x.x"
  }

  # Nice DCV custom component (defined in nice-dcv-component.tf)
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:${var.account_id}:component/${var.project}-${var.environment}-nice-dcv-${local.os}-${local.os_version}/x.x.x"
  }

  # custom component (defined in vdi-component.tf)
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:${var.account_id}:component/${var.project}-${var.environment}-${local.os}-${local.os_version}/x.x.x"
  }
}
