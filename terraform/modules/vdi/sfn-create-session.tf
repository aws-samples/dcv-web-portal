# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "sfn_create_session_role" {
  name_prefix = "${var.project}-${var.environment}-create-session-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.project}-${var.environment}-ec2"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ec2:CreateTags",
            "ec2:TerminateInstances",
            "ec2:DescribeInstances",
            "ec2:DescribeLaunchTemplateVersions"
          ]
          Effect   = "Allow"
          Resource = ["*"]
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-ssm"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ssm:StartAutomationExecution",
            "ssm:DescribeInstanceInformation",
            "ssm:GetAutomationExecution",
            "ssm:SendCommand",
            "ssm:ListCommands",
            "ssm:ListCommandInvocations"
          ]
          Effect   = "Allow"
          Resource = ["*"]
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-states"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "states:StartExecution.sync",
            "states:StartExecution",
          ]
          Effect   = "Allow"
          Resource = aws_sfn_state_machine.preallocate_instance.arn
        },
        {
          Action = [
            "states:DescribeExecution",
            "states:StopExecution"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:states:${var.region}:${var.account_id}:execution:${aws_sfn_state_machine.preallocate_instance.name}:*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "events:PutTargets",
            "events:PutRule",
            "events:DescribeRule"
          ],
          "Resource" : [
            "arn:aws:events:${var.region}:${var.account_id}:rule/StepFunctionsGetEventsForStepFunctionsExecutionRule"
          ]
        }
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-secrets"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:dcv-*-credentials-*"
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-dynamodb"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:transactWriteItems"
          ]
          Effect   = "Allow"
          Resource = [aws_dynamodb_table.application_table.arn, "${aws_dynamodb_table.application_table.arn}/index/*"]
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-kms"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "kms:CreateGrant",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:Encrypt",
            "kms:Describe*",
            "kms:Decrypt"
          ]
          Effect   = "Allow"
          Resource = var.kms_key_arn
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-x-ray"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords",
            "xray:GetSamplingRules",
            "xray:GetSamplingTargets"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-logs"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "logs:CreateLogDelivery",
            "logs:GetLogDelivery",
            "logs:UpdateLogDelivery",
            "logs:DeleteLogDelivery",
            "logs:ListLogDeliveries",
            "logs:PutResourcePolicy",
            "logs:PutLogEvents",
            "logs:PutDestination",
            "logs:DescribeResourcePolicies",
            "logs:DescribeLogGroups",
            "logs:DescribeDestinations"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}

resource "aws_cloudwatch_log_group" "sfn_create_session_logs" {
  name              = "${var.project}-${var.environment}-sfn-create-session-logs"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_sfn_state_machine" "create_session" {
  name     = "${var.project}-${var.environment}-create-session"
  role_arn = aws_iam_role.sfn_create_session_role.arn

  logging_configuration {
    level                  = "ALL"
    include_execution_data = true
    log_destination        = "${aws_cloudwatch_log_group.sfn_create_session_logs.arn}:*"
  }

  tracing_configuration {
    enabled = true
  }

  definition = <<EOF
{
  "Comment": "Create Session",
  "StartAt": "Set current session status to PENDING",
  "States": {
    "Set current session status to PENDING": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:putItem",
      "Parameters": {
        "TableName": "${aws_dynamodb_table.application_table.id}",
        "Item": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$": "States.Format('SESSION#{}', $.sessionId)"
          },
          "status": {
            "S": "PENDING"
          },
          "sfnFunctionExecutionId": {
            "S.$": "$$.Execution.Id"
          },
          "lastUpdatedAt": {
            "S.$": "$$.State.EnteredTime"
          }
        }
      },
      "Next": "Default Version?",
      "ResultPath": null
    },
    "Default Version?": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.launchTemplateVersion",
          "StringEquals": "$Default",
          "Next": "Get exact version number"
        }
      ],
      "Default": "Are there available instances?"
    },
    "Get exact version number": {
      "Type": "Task",
      "Next": "Format LaunchTemplate Version",
      "Parameters": {
        "LaunchTemplateName.$": "$.launchTemplateName",
        "Versions.$": "States.Array($.launchTemplateVersion)"
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:describeLaunchTemplateVersions",
      "ResultSelector": {
        "launchTemplateVersion.$": "$.LaunchTemplateVersions[0].VersionNumber"
      },
      "ResultPath": "$.exactVersion"
    },
    "Format LaunchTemplate Version": {
      "Type": "Pass",
      "Next": "Are there available instances?",
      "Parameters": {
        "username.$": "$.username",
        "sessionId.$": "$.sessionId",
        "launchTemplateName.$": "$.launchTemplateName",
        "launchTemplateVersion.$": "States.Format('{}', $.exactVersion.launchTemplateVersion)"
      }
    },
    "Are there available instances?": {
      "Type": "Task",
      "Parameters": {
        "TableName": "${aws_dynamodb_table.application_table.id}",
        "IndexName": "${var.project}-${var.environment}-status-idx",
        "Limit": 1,
        "KeyConditionExpression": "#pk = :pk AND #status = :status",
        "FilterExpression": "#launchTemplateName = :launchTemplateName",
        "ExpressionAttributeNames": {
          "#pk": "pk",
          "#status": "status",
          "#launchTemplateName": "launchTemplateName"
        },
        "ExpressionAttributeValues": {
          ":pk": {
            "S": "INSTANCE#preallocate"
          },
          ":status": {
            "S": "READY"
          },
          ":launchTemplateName": {
            "S.$": "$.launchTemplateName"
          }
        },
        "ScanIndexForward": false
      },
      "Resource": "arn:aws:states:::aws-sdk:dynamodb:query",
      "Next": "Choice",
      "ResultPath": "$.preallocatedInstances"
    },
    "Choice": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.preallocatedInstances.Count",
          "NumericGreaterThan": 0,
          "Next": "Format instance id"
        }
      ],
      "Default": "Set current session status to LAUNCHING"
    },
    "Set current session status to LAUNCHING": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${aws_dynamodb_table.application_table.id}",
        "Key": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$": "States.Format('SESSION#{}', $.sessionId)"
          }
        },
        "UpdateExpression": "SET #status = :statusRef,  #lastUpdatedAt = :lastUpdatedAtRef",
        "ExpressionAttributeNames": {
          "#status": "status",
          "#lastUpdatedAt": "lastUpdatedAt"
        },
        "ExpressionAttributeValues": {
          ":statusRef": {
            "S": "LAUNCHING"
          },
          ":lastUpdatedAtRef": {
            "S.$": "$$.State.EnteredTime"
          }
        }
      },
      "Next": "Preallocate instance",
      "ResultPath": null
    },
    "Preallocate instance": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution.sync:2",
      "Parameters": {
        "StateMachineArn": "${aws_sfn_state_machine.preallocate_instance.arn}",
        "Input": {
          "count": 1,
          "type": "user",
          "launchTemplateName.$": "$.launchTemplateName",
          "launchTemplateVersion.$": "$.launchTemplateVersion",
          "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID.$": "$$.Execution.Id"
        }
      },
      "Next": "Add user type",
      "ResultSelector": {
        "instanceId.$": "$.Output[0].instance.instanceId"
      },
      "ResultPath": "$.instance",
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "Next": "Set current session status to FAILED",
          "ResultPath": "$.error"
        }
      ],
      "Retry": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "BackoffRate": 1,
          "IntervalSeconds": 1,
          "MaxAttempts": 2
        }
      ]
    },
    "Add user type": {
      "Type": "Pass",
      "Next": "Get Instance Info",
      "Parameters": {
        "instance.$": "$.instance",
        "username.$": "$.username",
        "sessionId.$": "$.sessionId",
        "launchTemplateName.$": "$.launchTemplateName",
        "launchTemplateVersion.$": "$.launchTemplateVersion",
        "type": "user"
      }
    },
    "Format instance id": {
      "Type": "Pass",
      "Next": "Get Instance Info",
      "Parameters": {
        "instance": {
          "instanceId.$": "$.preallocatedInstances.Items[0].instanceId.S"
        },
        "username.$": "$.username",
        "sessionId.$": "$.sessionId",
        "launchTemplateName.$": "$.launchTemplateName",
        "launchTemplateVersion.$": "$.launchTemplateVersion",
        "type": "preallocate"
      }
    },
    "Get Instance Info": {
      "Type": "Task",
      "Next": "Associate preallocated instance to user",
      "Parameters": {
        "InstanceIds.$": "States.Array($.instance.instanceId)"
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:describeInstances",
      "ResultSelector": {
        "data.$": "$.Reservations[0].Instances[0]"
      },
      "ResultPath": "$.instanceData"
    },
    "Associate preallocated instance to user": {
      "Type": "Task",
      "Next": "Update Instance name",
      "Parameters": {
        "TransactItems": [
          {
            "Delete": {
              "TableName": "${aws_dynamodb_table.application_table.id}",
              "Key": {
                "pk": {
                  "S.$": "States.Format('INSTANCE#{}', $.type)"
                },
                "sk": {
                  "S.$": "States.Format('ID#{}', $.instance.instanceId)"
                }
              }
            }
          },
          {
            "Update": {
              "TableName": "${aws_dynamodb_table.application_table.id}",
              "Key": {
                "pk": {
                  "S.$": "States.Format('USER#{}', $.username)"
                },
                "sk": {
                  "S.$": "States.Format('SESSION#{}', $.sessionId)"
                }
              },
              "UpdateExpression": "SET #instanceId = :instanceIdRef, #launchTemplateName = :launchTemplateNameRef, #launchTemplateVersion = :launchTemplateVersionRef, #privateDnsName = :privateDnsNameRef, #privateIpAddress = :privateIpAddressRef, #imageId = :imageIdRef, #lastUpdatedAt = :lastUpdatedAtRef",
              "ExpressionAttributeNames": {
                "#instanceId": "instanceId",
                "#privateDnsName": "privateDnsName",
                "#privateIpAddress": "privateIpAddress",
                "#launchTemplateVersion": "launchTemplateVersion",
                "#launchTemplateName": "launchTemplateName",
                "#imageId": "imageId",
                "#lastUpdatedAt": "lastUpdatedAt"
              },
              "ExpressionAttributeValues": {
                ":instanceIdRef": {
                  "S.$": "$.instance.instanceId"
                },
                ":privateDnsNameRef": {
                  "S.$": "$.instanceData.data.PrivateDnsName"
                },
                ":privateIpAddressRef": {
                  "S.$": "$.instanceData.data.PrivateIpAddress"
                },
                ":launchTemplateVersionRef": {
                  "S.$": "$.launchTemplateVersion"
                },
                ":launchTemplateNameRef": {
                  "S.$": "$.launchTemplateName"
                },
                ":imageIdRef": {
                  "S.$": "$.instanceData.data.ImageId"
                },
                ":lastUpdatedAtRef": {
                  "S.$": "$$.State.EnteredTime"
                }
              }
            }
          }
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:dynamodb:transactWriteItems",
      "ResultPath": null
    },
    "Update Instance name": {
      "Type": "Task",
      "Next": "Windows Or Linux",
      "Parameters": {
        "Resources.$": "States.Array($.instance.instanceId)",
        "Tags": [
          {
            "Key": "Name",
            "Value.$": "States.Format('[{}] {} instance', $.username, $.launchTemplateName)"
          },
          {
            "Key": "SessionUser",
            "Value.$": "$.username"
          }
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:createTags",
      "ResultPath": null
    },
    "Windows Or Linux": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.launchTemplateName",
          "StringMatches": "*windows*",
          "Next": "Run assign instance automation on Windows"
        }
      ],
      "Default": "Run assign instance automation on Linux"
    },
    "Run assign instance automation on Windows": {
      "Type": "Task",
      "Next": "Set current session status to FINALISING",
      "Parameters": {
        "DocumentName": "${var.project}-${var.environment}-assign-windows-instance",
        "DocumentVersion": "$DEFAULT",
        "Parameters": {
          "InstanceId.$": "States.Array($.instance.instanceId)",
          "username.$": "States.Array($.username)"
        }
      },
      "Resource": "arn:aws:states:::aws-sdk:ssm:startAutomationExecution",
      "ResultSelector": {
        "AutomationExecutionId.$": "$.AutomationExecutionId"
      },
      "ResultPath": "$.assignAutomation"
    },
    "Run assign instance automation on Linux": {
      "Type": "Task",
      "Next": "Set current session status to FINALISING",
      "Parameters": {
        "DocumentName": "${var.project}-${var.environment}-assign-linux-instance",
        "DocumentVersion": "$DEFAULT",
        "Parameters": {
          "InstanceId.$": "States.Array($.instance.instanceId)",
          "username.$": "States.Array($.username)"
        }
      },
      "Resource": "arn:aws:states:::aws-sdk:ssm:startAutomationExecution",
      "ResultSelector": {
        "AutomationExecutionId.$": "$.AutomationExecutionId"
      },
      "ResultPath": "$.assignAutomation"
    },
    "Set current session status to FINALISING": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${aws_dynamodb_table.application_table.id}",
        "Key": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$": "States.Format('SESSION#{}', $.sessionId)"
          }
        },
        "UpdateExpression": "SET #status = :statusRef, #ssmAutomationExecutionId=:ssmAutomationExecutionIdRef, #lastUpdatedAt = :lastUpdatedAtRef",
        "ExpressionAttributeNames": {
          "#status": "status",
          "#ssmAutomationExecutionId": "ssmAutomationExecutionId",
          "#lastUpdatedAt": "lastUpdatedAt"
        },
        "ExpressionAttributeValues": {
          ":statusRef": {
            "S": "FINALISING"
          },
          ":ssmAutomationExecutionIdRef": {
            "S.$": "$.assignAutomation.AutomationExecutionId"
          },
          ":lastUpdatedAtRef": {
            "S.$": "$$.State.EnteredTime"
          }
        }
      },
      "Next": "Get assign instance automation status",
      "ResultPath": null
    },
    "Get assign instance automation status": {
      "Type": "Task",
      "Next": "Is instance finalised",
      "Parameters": {
        "AutomationExecutionId.$": "$.assignAutomation.AutomationExecutionId"
      },
      "Resource": "arn:aws:states:::aws-sdk:ssm:getAutomationExecution",
      "ResultSelector": {
        "AutomationExecutionId.$": "$.AutomationExecution.AutomationExecutionId",
        "Status.$": "$.AutomationExecution.AutomationExecutionStatus"
      },
      "ResultPath": "$.assignAutomation"
    },
    "Is instance finalised": {
      "Type": "Choice",
      "Choices": [
        {
          "Or": [
            {
              "Variable": "$.assignAutomation.Status",
              "StringEquals": "Success"
            },
            {
              "Variable": "$.assignAutomation.Status",
              "StringEquals": "CompletedWithSuccess"
            }
          ],
          "Next": "Set current session status to AVAILABLE"
        },
        {
          "Or": [
            {
              "Variable": "$.assignAutomation.Status",
              "StringEquals": "Failed"
            },
            {
              "Variable": "$.assignAutomation.Status",
              "StringEquals": "TimedOut"
            },
            {
              "Variable": "$.assignAutomation.Status",
              "StringEquals": "Cancelling"
            },
            {
              "Variable": "$.assignAutomation.Status",
              "StringEquals": "Cancelled"
            },
            {
              "Variable": "$.assignAutomation.Status",
              "StringEquals": "CompletedWithFailure"
            }
          ],
          "Next": "TerminateInstances"
        }
      ],
      "Default": "Wait 5s"
    },
    "Wait 5s": {
      "Type": "Wait",
      "Seconds": 5,
      "Next": "Get assign instance automation status"
    },
    "Set current session status to AVAILABLE": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${aws_dynamodb_table.application_table.id}",
        "Key": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$": "States.Format('SESSION#{}', $.sessionId)"
          }
        },
        "UpdateExpression": "SET #status = :statusRef, #niceDcvSessionId = :niceDcvSessionIdRef, #lastUpdatedAt = :lastUpdatedAtRef",
        "ExpressionAttributeNames": {
          "#status": "status",
          "#niceDcvSessionId": "niceDcvSessionId",
          "#lastUpdatedAt": "lastUpdatedAt"
        },
        "ExpressionAttributeValues": {
          ":statusRef": {
            "S": "AVAILABLE"
          },
          ":niceDcvSessionIdRef": {
            "S.$": "$.sessionId"
          },
          ":lastUpdatedAtRef": {
            "S.$": "$$.State.EnteredTime"
          }
        }
      },
      "Next": "Success",
      "ResultPath": null
    },
    "Success": {
      "Type": "Succeed"
    },
    "TerminateInstances": {
      "Type": "Task",
      "Parameters": {
        "InstanceIds.$": "States.Array($.instance.instanceId)"
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:terminateInstances",
      "ResultPath": null,
      "Next": "Set current session status to FAILED"
    },
    "Set current session status to FAILED": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${aws_dynamodb_table.application_table.id}",
        "Key": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$": "States.Format('SESSION#{}', $.sessionId)"
          }
        },
        "UpdateExpression": "SET #status = :statusRef, #details = :detailsRef, #lastUpdatedAt = :lastUpdatedAtRef",
        "ExpressionAttributeNames": {
          "#status": "status",
          "#details": "details",
          "#lastUpdatedAt": "lastUpdatedAt"
        },
        "ExpressionAttributeValues": {
          ":statusRef": {
            "S": "FAILED"
          },
          ":detailsRef": {
            "S.$": "$.error.Cause"
          },
          ":lastUpdatedAtRef": {
            "S.$": "$$.State.EnteredTime"
          }
        }
      },
      "Next": "Fail",
      "ResultPath": null
    },
    "Fail": {
      "Type": "Fail"
    }
  }
}
EOF
}