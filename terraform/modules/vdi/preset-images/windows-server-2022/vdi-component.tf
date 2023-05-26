# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_imagebuilder_component" "vdi_component" {
  name        = "${var.project}-${var.environment}-${local.os}-${local.os_version}"
  platform    = "Windows"
  version     = "1.0.0"
  description = "${local.os} ${local.os_version} VDI Component"
  kms_key_id  = var.kms_key_arn

  data = yamlencode({
    schemaVersion = 1.0

    phases = [{
      name = "build"
      steps = [
        {
          name   = "InstallBrowser" # You can replace this with all the applications you need to install or have your base AMI with the correct tools already installed
          action = "ExecutePowerShell"
          inputs = {
            commands = [<<EOF
$LocalTempDir = $env:TEMP; $ChromeInstaller = "ChromeInstaller.exe"; (new-object System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller"); & "$LocalTempDir\$ChromeInstaller" /silent /install; $Process2Monitor =  "ChromeInstaller"; Do { $ProcessesFound = Get-Process | ?{$Process2Monitor -contains $_.Name} | Select-Object -ExpandProperty Name; If ($ProcessesFound) { "Still running: $($ProcessesFound -join ', ')" | Write-Host; Start-Sleep -Seconds 2 } else { rm "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose } } Until (!$ProcessesFound)
EOF
            ]
          }
        }
      ]
    }]
  })
}