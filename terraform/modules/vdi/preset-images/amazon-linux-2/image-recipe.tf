# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_imagebuilder_image_recipe" "vdi_image_builder_recipe" {
  depends_on   = [aws_imagebuilder_component.vdi_component, aws_imagebuilder_component.nice_dcv_component]
  name         = "${var.project}-${var.environment}-${local.os}-${local.os_version}-vdi"
  parent_image = var.linux_base_image # "arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2-x86/x.x.x"
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

  # Nice DCV custom component (defined in nice-dcv-component.tf)
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:${var.account_id}:component/${var.project}-${var.environment}-nice-dcv-${local.os}-${local.os_version}/x.x.x"
  }

  # custom component (defined in vdi-component.tf)
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:${var.account_id}:component/${var.project}-${var.environment}-${local.os}-${local.os_version}/x.x.x"
  }
}
