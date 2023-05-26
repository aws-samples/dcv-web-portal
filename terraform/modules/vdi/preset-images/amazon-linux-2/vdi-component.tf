# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_imagebuilder_component" "vdi_component" {
  name        = "${var.project}-${var.environment}-${local.os}-${local.os_version}"
  platform    = "Linux"
  version     = "1.0.0"
  description = "${local.os} ${local.os_version} VDI Component"
  kms_key_id  = var.kms_key_arn

  data = yamlencode({
    schemaVersion = 1.0

    phases = [{
      name = "build"
      steps = [
        {
          name   = "CreateWorkingDirectory"
          action = "CreateFolder"
          inputs = [{
            path      = "/AWS-VDI-AUTOMATION/BUILD-IMAGE/VDI-COMPONENT"
            overwrite = true
          }]
        },
        #https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html#linux-prereq-gui
        {
          action         = "ExecuteBash"
          name           = "InstallDesktopEnvironmentAndDesktopManager"
          onFailure      = "Abort"
          maxAttempts    = 3
          timeoutSeconds = -1
          inputs = {
            commands = [
              "yum install -y gdm gnome-session gnome-classic-session gnome-session-xsession",
              "yum install -y xorg-x11-server-Xorg xorg-x11-fonts-Type1 xorg-x11-drivers",
              "yum install -y gnome-terminal gnu-free-fonts-common",
              "yum install -y gnu-free-mono-fonts gnu-free-sans-fonts gnu-free-serif-fonts"
            ]
          }
        },
        {
          name   = "InstallBrowser" # You can replace this with all the applications you need to install or have your base AMI with the correct tools already installed
          action = "ExecuteBash"
          inputs = {
            commands = [
              "wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm",
              "yum install -y ./google-chrome-stable_current_x86_64.rpm",
              "ln -s /usr/bin/google-chrome-stable /usr/bin/chromium"
            ]
          }
        },
        {
          action         = "Reboot"
          name           = "Reboot"
          onFailure      = "Abort"
          maxAttempts    = 3
          timeoutSeconds = -1
        }
      ]
    }]
  })
}