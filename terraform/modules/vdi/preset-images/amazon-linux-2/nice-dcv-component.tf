# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# REFERENCE
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-server.html
resource "aws_imagebuilder_component" "nice_dcv_component" {
  name        = "${var.project}-${var.environment}-nice-dcv-${local.os}-${local.os_version}"
  platform    = "Linux"
  version     = "1.0.0"
  description = "[${local.os}-${local.os_version}] Install NICE DCV Server"
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
        # If you prefer to download from an S3 bucket, you must download and push the RPM in this bucket by yourself
        # https://download.nice-dcv.com/latest.html
        # {
        #   name   = "DownloadNiceDCVCServer"
        #   action = "S3Download"
        #   inputs = [{
        #     source      = "s3://${aws_s3_bucket.software_bucket.id}/nice-dcv-server.rpm"
        #     destination = "{{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-server.rpm"
        #   }]
        # },
        {
          name           = "DownloadNiceDCVCServer"
          action         = "WebDownload"
          maxAttempts    = 3
          onFailure      = "Abort"
          timeoutSeconds = -1
          inputs = [{
            source      = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-el7-x86_64.tgz"
            destination = "{{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-el7-x86_64.tgz"
            # Uncomment to verify checksum
            #checksum    = "63422528f24008ede5334d5cae310107c5b5ac9a6ca615f5b4c3b165435b6c44"
            #algorithm   = "SHA256"
          }]
        },
        # Uncompress Nice DCV tgz
        {
          name      = "UncompressNiceDCVServer"
          action    = "ExecuteBash"
          onFailure = "Abort"
          inputs = {
            commands = [
              "tar zxvf {{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-el7-x86_64.tgz -C {{ build.CreateWorkingDirectory.inputs[0].path }} --overwrite",
              "\\cp -rf {{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-*-el7-x86_64/nice-dcv-server-*.rpm {{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-server.rpm"
            ]
          }
        },
        # Install NiceDCVServer
        {
          name           = "InstallNiceDCVServer"
          action         = "ExecuteBash"
          onFailure      = "Abort"
          maxAttempts    = 3
          timeoutSeconds = -1
          inputs = {
            commands = [
              "yum -y update",
              "yum install -y {{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-server.rpm"
            ]
          }
        },
        {
          name           = "SetNiceDCVConfigurationFile"
          action         = "ExecuteBash"
          onFailure      = "Abort"
          maxAttempts    = 3
          timeoutSeconds = -1
          inputs = {
            commands = [
              "pip3 install crudini",
              "systemctl stop dcvserver"
            ]
          }
        }
      ]
    }]
  })
}
