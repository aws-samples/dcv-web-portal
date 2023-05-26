# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# REFERENCE
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-wininstall.html
resource "aws_imagebuilder_component" "nice_dcv_component" {
  name        = "${var.project}-${var.environment}-nice-dcv-${local.os}-${local.os_version}"
  platform    = "Windows"
  version     = "1.0.0"
  description = "[${local.os}-${local.os_version}] Install NICE DCV Server"
  kms_key_id  = var.kms_key_arn

  data = yamlencode({
    schemaVersion = 1.0

    phases = [{
      name = "build"
      steps = [
        {
          name           = "DownloadInstallDCVServer"
          action         = "ExecutePowerShell"
          onFailure      = "Abort"
          maxAttempts    = 3
          timeoutSeconds = -1
          inputs = {
            commands = [<<EOF
$token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} -Method PUT -Uri http://169.254.169.254/latest/api/token
$instanceType = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-type
if(($InstanceType[0] -ne 'g') -or ($InstanceType[0] -ne 'p')){
    Start-Job -Name WebReq -ScriptBlock { Invoke-WebRequest -uri https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-virtual-display-x64-Release.msi -OutFile C:\Windows\Temp\DCVDisplayDriver.msi ; Invoke-WebRequest -uri https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi -OutFile C:\Windows\Temp\DCVServer.msi }
}else{
    Start-Job -Name WebReq -ScriptBlock { Invoke-WebRequest -uri https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi -OutFile C:\Windows\Temp\DCVServer.msi }
}
Wait-Job -Name WebReq
if(($InstanceType[0] -ne 'g') -or ($InstanceType[0] -ne 'p')){
    Invoke-Command -ScriptBlock {Start-Process "msiexec.exe" -ArgumentList "/I C:\Windows\Temp\DCVDisplayDriver.msi /quiet /norestart" -Wait}
}
Invoke-Command -ScriptBlock {Start-Process "msiexec.exe" -ArgumentList "/I C:\Windows\Temp\DCVServer.msi ADDLOCAL=ALL /quiet /norestart /l*v dcv_install_msi.log " -Wait}
while (-not(Get-Service dcvserver -ErrorAction SilentlyContinue)) { Start-Sleep -Milliseconds 250 }
New-ItemProperty -Path "Microsoft.PowerShell.Core\Registry::HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" -Name enable-quic-frontend -PropertyType DWORD -Value 1 -force
Restart-Service -Name dcvserver
            EOF
            ]
          }
        }
      ]
    }]
  })
}
