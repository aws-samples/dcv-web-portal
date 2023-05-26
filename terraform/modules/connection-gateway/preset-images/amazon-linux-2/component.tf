# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Connection Gateway Component
resource "aws_imagebuilder_component" "connection_gateway_component" {
  name        = "${var.project}-${var.environment}-connection-gateway"
  platform    = "Linux"
  version     = "1.0.3"
  description = "[Linux] Install NICE DCV Connection Gateway"
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
            path      = "/AWS-VDI-AUTOMATION/BUILD-IMAGE/CONNECTION-GATEWAY-COMPONENT"
            overwrite = true
          }]
        },
        # If you prefer to download from an S3 bucket, you must download and push the RPM in this bucket by yourself
        # https://download.nice-dcv.com/latest.html
        # {
        #   name   = "DownloadNiceDCVConnectionGateway"
        #   action = "S3Download"
        #   inputs = [{
        #     source      = "s3://${aws_s3_bucket.software_bucket.id}/nice-dcv-connection-gateway.rpm"
        #     destination = "{{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-connection-gateway.rpm"
        #   }]
        # },
        {
          name        = "DownloadNiceDCVConnectionGateway"
          action      = "WebDownload"
          maxAttempts = 3
          inputs = [{
            source      = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-connection-gateway-el7.x86_64.rpm"
            destination = "{{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-connection-gateway.rpm"
            # Uncomment to verify checksum
            # checksum    = "e7a37aa48cf37ab2761a6b7f4e5baeb1996b3571e2904ad0d563bdf83b746a32"
            # algorithm   = "SHA256"
          }]
        },
        # Install NiceDCVConnectionGateway
        {
          action         = "ExecuteBash"
          name           = "InstallNiceDCVConnectionGateway"
          onFailure      = "Abort"
          maxAttempts    = 3
          timeoutSeconds = -1
          inputs = {
            commands = [
              "sudo yum -y update",
              "yum install -y {{ build.CreateWorkingDirectory.inputs[0].path }}/nice-dcv-connection-gateway.rpm",
              "systemctl stop dcv-connection-gateway"
            ]
          }
        },
        # Create connection gateway conf file
        {
          action         = "CreateFile"
          name           = "CreateNiceDCVConfigurationFile"
          onFailure      = "Abort"
          maxAttempts    = 3
          timeoutSeconds = -1
          inputs = [{
            path    = "/etc/dcv-connection-gateway/dcv-connection-gateway.conf"
            content = <<EOF
[gateway]
web-listen-endpoints = ["0.0.0.0:${var.tcp_port}"]
quic-listen-endpoints = ["0.0.0.0:${var.udp_port}"]

[health-check]
bind-addr = "::"
port = ${var.health_check_port}

[dcv]
tls-strict = false

[resolver]
tls-strict = false
url = "${var.connection_gateway_api}"

[web-resources]
tls-strict = false
url = "http://localhost:8081/static"
EOF
          }]
        },
        {
          action         = "ExecuteBash"
          name           = "StartDCVConnectionGatewayService"
          onFailure      = "Abort"
          maxAttempts    = 3
          timeoutSeconds = -1
          inputs = {
            commands = [
              "systemctl restart dcv-connection-gateway",
              "systemctl enable dcv-connection-gateway"
            ]
          }
        }
      ]
    }]
  })
}
