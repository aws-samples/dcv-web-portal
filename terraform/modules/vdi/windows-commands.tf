# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_ssm_document" "prepare_windows_instance" {
  name            = "${var.project}-${var.environment}-prepare-windows-instance"
  document_type   = "Automation"
  document_format = "YAML"
  target_type     = "/AWS::EC2::Instance"
  content         = <<DOC
description: |
  ## Prepare instance DCV configuration on Windows
  Set of commands executed remotely in a instance(s) to setup Nice DCV Server.
  Will update the Registry with proper configuration:
  - https://docs.aws.amazon.com/dcv/latest/adminguide/config-param-ref-modify.html
  - https://docs.aws.amazon.com/dcv/latest/adminguide/config-param-ref.html
  Restart the instance in the end.

  ### Parameters

  Name | Type | Description | Default Value
  ------------- | ------------- | ------------- | -------------
  InstanceIds | List<AWS::EC2::Instance::Id> | list of instances where to apply this ddocument | -
  dcvExternalAuthEndpoint | String | The Authentication endpoint for Nice DCV login | ${var.dcv_auth_endpoint}
  dcvWebPort | String | The Web port (TCP) for DCV | ${var.tcp_port}
  dcvQuicPort | Number | The QUIC port (UDP) for DCV | ${var.udp_port}
  dcvNoTLSStrict | Number | Disable TLS strict | 1

schemaVersion: '0.3'
parameters:
  InstanceIds:
    type: 'List<AWS::EC2::Instance::Id>'
    description: (Required) Provide the Instance Id. (e.g. i-07330aca1eb7fecc6 )
    allowedPattern: '^[i]{0,1}-[a-z0-9]{8,17}$'
  dcvExternalAuthEndpoint:
    type: String
    description: (Required) [DCV] The Authentication endpoint for Nice DCV login
    default: '${var.dcv_auth_endpoint}'
  dcvWebPort:
    type: String
    description: (Required) [DCV] The Web port (TCP) for DCV
    default: '${var.tcp_port}'
  dcvQuicEnabled:
    type: String
    description: (Required) [DCV] If QUIC UDP should be enabled
    default: 'true'
  dcvQuicPort:
    type: String
    description: (Required) [DCV] The Quic port (UDP) for DCV
    default: '${var.udp_port}'
  dcvNoTLSStrict:
    type: String
    description: (Required) [DCV] Disable TLS strict
    default: 'true'
mainSteps:
  - name: DCV_SetDCVExternalAuthEndpoint
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPowerShellScript
      Targets:
        - Key: InstanceIds
          Values: '{{InstanceIds}}'
      Parameters:
        commands:
            - 'New-ItemProperty -Path "Microsoft.PowerShell.Core\Registry::HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\security" -Name auth-token-verifier -Value {{ dcvExternalAuthEndpoint }} -force'
  - name: DCV_SetWebPort
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPowerShellScript
      Targets:
        - Key: InstanceIds
          Values: '{{InstanceIds}}'
      Parameters:
        commands:
            - 'New-ItemProperty -Path "Microsoft.PowerShell.Core\Registry::HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" -Name web-port -PropertyType DWORD -Value {{ dcvWebPort }} -force'
  - name: DCV_SetQuicPort
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPowerShellScript
      Targets:
        - Key: InstanceIds
          Values: '{{InstanceIds}}'
      Parameters:
        commands:
            - 'New-ItemProperty -Path "Microsoft.PowerShell.Core\Registry::HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\connectivity" -Name quic-port -PropertyType DWORD -Value {{ dcvQuicPort }} -force'
  - name: DCV_SetNoTLSStrict
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPowerShellScript
      Targets:
        - Key: InstanceIds
          Values: '{{InstanceIds}}'
      Parameters:
        commands:
            - 'New-ItemProperty -Path "Microsoft.PowerShell.Core\Registry::HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\security" -Name no-tls-strict -PropertyType DWORD -Value {{ dcvNoTLSStrict }} -force'
  - name: DCV_RestartDCVServer
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPowerShellScript
      Targets:
        - Key: InstanceIds
          Values: '{{InstanceIds}}'
      Parameters:
        commands:
            - 'Restart-Service -Name dcvserver'
DOC
}


resource "aws_ssm_document" "assign_windows_instance" {
  name            = "${var.project}-${var.environment}-assign-windows-instance"
  document_type   = "Automation"
  document_format = "YAML"
  target_type     = "/AWS::EC2::Instance"
  content         = <<DOC
description: |
  ## Assign instance to a user
   - Create a user/pwd combination to assign the instance to a user
   - Create a DCV session and associate it to the user

  ### Parameters

  Name | Type | Description | Default Value
  ------------- | ------------- | ------------- | -------------
  InstanceIds | AWS::EC2::Instance::Id | Instance to associate to a user | -
  username | String | Username | -
  dcvSessionType | String | Type of DCV Session | console
  dcvSessionName | String | Name of the DCV Session | console
schemaVersion: '0.3'
parameters:
  InstanceId:
    type: 'AWS::EC2::Instance::Id'
    description: (Required) Provide the Instance Id. (e.g. i-07330aca1eb7fecc6 )
    allowedPattern: '^[i]{0,1}-[a-z0-9]{8,17}$'
  username:
    type: String
    description: (Required) Username
    allowedPattern: '^[a-z_][a-z0-9_-]{3,32}$'
  dcvSessionType:
    type: String
    description: '(Required) [DCV] Session Type'
    allowedValues:
      - console
      - virtual
    default: console
  dcvSessionName:
    type: String
    description: '(Required) [DCV] Session Name'
    allowedPattern: '^[A-Za-z0-9_-]{1,256}$'
    default: console
mainSteps:
  - name: Secret_GetCredentials
    action: 'aws:executeAwsApi'
    onFailure: Abort
    inputs:
      Api: GetSecretValue
      Service: secretsmanager
      SecretId: 'dcv-{{ username }}-credentials'
    outputs:
      - Name: password
        Selector: $.SecretString
        Type: String
  - name: OS_CreateUser
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPowerShellScript
      Targets:
        - Key: InstanceIds
          Values:
            - '{{InstanceId}}'
      Parameters:
        commands:
          - 'Net User "{{ username }}" "{{ Secret_GetCredentials.password }}" /add /expires:never /comment:"Account for {{ username }}" /fullname:"{{ username }}"'
          - 'Set-ItemProperty -Path "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\UserSwitch" -Name Enabled -Value 1'
          - 'New-ItemProperty -Path "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" -PropertyType DWORD -Name EnumerateLocalUsers -Value 1 -Force'
  - name: DCV_CreateSession
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPowerShellScript
      Targets:
        - Key: InstanceIds
          Values:
            - '{{InstanceId}}'
      Parameters:
        commands:
            - 'Set-Location -Path "C:\Program Files\NICE\DCV\Server\bin\"'
            - '.\dcv.exe close-session {{ dcvSessionName }}'
            - '.\dcv.exe create-session --type={{ dcvSessionType }} --owner {{ username }} {{ dcvSessionName }}'
DOC
}
