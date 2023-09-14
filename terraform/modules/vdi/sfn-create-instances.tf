# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "sfn_preallocate_instance_role" {
  name_prefix = "${var.project}-${var.environment}-preallocate-role"

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
            "ec2:RunInstances",
            "ec2:DescribeInstanceStatus",
            "ec2:TerminateInstances"
          ]
          Effect   = "Allow"
          Resource = ["*"]
        },
      ]
    })
  }

  inline_policy {
    name = "${var.project}-${var.environment}-iam"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "iam:PassRole"
          ]
          Effect   = "Allow"
          Resource = [aws_iam_role.vdi_instance_role.arn]
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
            "ssm:ListCommandInvocations",
          ]
          Effect   = "Allow"
          Resource = ["*"]
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
            "dynamodb:DeleteItem"
          ]
          Effect   = "Allow"
          Resource = aws_dynamodb_table.application_table.arn
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

resource "aws_cloudwatch_log_group" "sfn_preallocate_instance_logs" {
  name              = "${var.project}-${var.environment}-sfn-preallocate-instance-logs"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_sfn_state_machine" "preallocate_instance" {
  name     = "${var.project}-${var.environment}-preallocate-instance"
  role_arn = aws_iam_role.sfn_preallocate_instance_role.arn

  logging_configuration {
    level                  = "ALL"
    include_execution_data = true
    log_destination        = "${aws_cloudwatch_log_group.sfn_preallocate_instance_logs.arn}:*"
  }

  tracing_configuration {
    enabled = true
  }

  definition = <<EOF
{
  "Comment": "Create Instance",
  "StartAt": "Launch instances with launch template",
  "States": {
    "Launch instances with launch template": {
      "Type": "Task",
      "Parameters": {
        "MaxCount.$": "$.count",
        "MinCount": 1,
        "LaunchTemplate": {
          "LaunchTemplateName.$": "$.launchTemplateName",
          "Version.$": "$.launchTemplateVersion"
        },
        "TagSpecifications": [
          {
            "ResourceType": "instance",
            "Tags": [
              {
                "Key": "Project",
                "Value": "${var.project}"
              },
              {
                "Key": "Environment",
                "Value": "${var.environment}"
              },
              {
                "Key": "Name",
                "Value.$": "States.Format('[pre-allocated] {} instance', $.launchTemplateName)"
              },
              {
                "Key": "SessionType",
                "Value.$": "$.launchTemplateName"
              },
              {
                "Key": "SessionUser",
                "Value": "pre-allocated"
              },
              {
                "Key": "SessionLaunchTemplateVersion",
                "Value.$": "$.launchTemplateVersion"
              }
            ]
          }
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:runInstances",
      "Next": "For each instance",
      "ResultPath": "$.Instances"
    },
    "For each instance": {
      "Type": "Map",
      "Iterator": {
        "StartAt": "Set instance to LAUNCHING",
        "States": {
          "Set instance to LAUNCHING": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:putItem",
            "Parameters": {
              "TableName": "${aws_dynamodb_table.application_table.id}",
              "Item": {
                "pk": {
                  "S.$": "States.Format('INSTANCE#{}', $.type)"
                },
                "sk": {
                  "S.$": "States.Format('ID#{}', $.Instance.InstanceId)"
                },
                "launchTemplateName": {
                  "S.$": "$.launchTemplateName"
                },
                "launchTemplateVersion": {
                  "S.$": "$.launchTemplateVersion"
                },
                "status": {
                  "S": "LAUNCHING"
                },
                "instanceId": {
                  "S.$": "$.Instance.InstanceId"
                },
                "sfnFunctionExecutionId": {
                  "S.$": "$$.Execution.Id"
                },
                "lastUpdatedAt": {
                  "S.$": "$$.State.EnteredTime"
                }
              }
            },
            "Next": "Get Instance Status",
            "ResultPath": null,
            "Catch": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "Next": "Terminate Instance"
              }
            ]
          },
          "Get Instance Status": {
            "Type": "Task",
            "Parameters": {
              "InstanceIds.$": "States.Array($.Instance.InstanceId)",
              "IncludeAllInstances": true
            },
            "Resource": "arn:aws:states:::aws-sdk:ec2:describeInstanceStatus",
            "ResultSelector": {
              "instanceId.$": "$.InstanceStatuses[0].InstanceId",
              "instanceStatus.$": "$.InstanceStatuses[0].InstanceStatus.Status",
              "systemStatus.$": "$.InstanceStatuses[0].SystemStatus.Status"
            },
            "ResultPath": "$.instance",
            "Next": "Is instance running",
            "Retry": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "BackoffRate": 2.5,
                "IntervalSeconds": 3,
                "MaxAttempts": 10
              }
            ],
            "Catch": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "Next": "Terminate Instance"
              }
            ]
          },
          "Is instance running": {
            "Type": "Choice",
            "Choices": [
              {
                "And": [
                  {
                    "Variable": "$.instance.instanceStatus",
                    "StringEquals": "ok"
                  },
                  {
                    "Variable": "$.instance.systemStatus",
                    "StringEquals": "ok"
                  }
                ],
                "Next": "Get ping status"
              },
              {
                "Or": [
                  {
                    "Variable": "$.instance.instanceStatus",
                    "StringEquals": "impaired"
                  },
                  {
                    "Variable": "$.instance.systemStatus",
                    "StringEquals": "impaired"
                  }
                ],
                "Next": "Wait 45s"
              }
            ],
            "Default": "Wait 45s"
          },
          "Get ping status": {
            "Type": "Task",
            "Next": "Is online",
            "Parameters": {
              "Filters": [
                {
                  "Key": "InstanceIds",
                  "Values.$": "States.Array($.Instance.InstanceId)"
                }
              ]
            },
            "Resource": "arn:aws:states:::aws-sdk:ssm:describeInstanceInformation",
            "ResultPath": "$.pingStatus",
            "Retry": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "BackoffRate": 1.5,
                "IntervalSeconds": 3,
                "MaxAttempts": 10
              }
            ],
            "Catch": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "Next": "Terminate Instance"
              }
            ]
          },
          "Is online": {
          "Type": "Choice",
          "Choices": [
            {
              "And": [
                {
                  "Variable": "$.pingStatus.InstanceInformationList[0]",
                  "IsPresent": true
                },
                {
                  "And": [
                    {
                      "Variable": "$.pingStatus.InstanceInformationList[0].PingStatus",
                      "StringEquals": "Online"
                    }
                  ]
                }
              ],
              "Next": "Windows Or Linux"
            }
          ],
          "Default": "Wait 5s"
        },
        "Windows Or Linux": {
          "Type": "Choice",
          "Choices": [
            {
              "Variable": "$.launchTemplateName",
              "StringMatches": "*windows*",
              "Next": "Run prepare instance automation on Windows"
            }
          ],
          "Default": "Run prepare instance automation on Linux"
        },
          "Wait 5s": {
            "Type": "Wait",
            "Seconds": 5,
            "Next": "Get ping status"
          },
          "Run prepare instance automation on Windows": {
            "Type": "Task",
            "Next": "Set instance to FINALISING",
            "Parameters": {
              "DocumentName": "${var.project}-${var.environment}-prepare-windows-instance",
              "DocumentVersion": "$DEFAULT",
              "Parameters": {
                "InstanceIds.$": "States.Array($.Instance.InstanceId)"
              }
            },
            "Resource": "arn:aws:states:::aws-sdk:ssm:startAutomationExecution",
            "ResultSelector": {
              "AutomationExecutionId.$": "$.AutomationExecutionId"
            },
            "ResultPath": "$.prepareAutomation",
            "Retry": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "BackoffRate": 1.5,
                "IntervalSeconds": 3,
                "MaxAttempts": 10
              }
            ],
            "Catch": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "Next": "Terminate Instance"
              }
            ]
          },
          "Run prepare instance automation on Linux": {
            "Type": "Task",
            "Next": "Set instance to FINALISING",
            "Parameters": {
              "DocumentName": "${var.project}-${var.environment}-prepare-linux-instance",
              "DocumentVersion": "$DEFAULT",
              "Parameters": {
                "InstanceIds.$": "States.Array($.Instance.InstanceId)"
              }
            },
            "Resource": "arn:aws:states:::aws-sdk:ssm:startAutomationExecution",
            "ResultSelector": {
              "AutomationExecutionId.$": "$.AutomationExecutionId"
            },
            "ResultPath": "$.prepareAutomation",
            "Retry": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "BackoffRate": 1.5,
                "IntervalSeconds": 3,
                "MaxAttempts": 10
              }
            ],
            "Catch": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "Next": "Terminate Instance"
              }
            ]
          },
          "Set instance to FINALISING": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:updateItem",
            "Parameters": {
              "TableName": "${aws_dynamodb_table.application_table.id}",
              "Key": {
                "pk": {
                  "S.$": "States.Format('INSTANCE#{}', $.type)"
                },
                "sk": {
                  "S.$": "States.Format('ID#{}', $.Instance.InstanceId)"
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
                  "S.$": "$.prepareAutomation.AutomationExecutionId"
                },
                ":lastUpdatedAtRef": {
                  "S.$": "$$.State.EnteredTime"
                }
              }
            },
            "Next": "Get prepare instance automation status",
            "ResultPath": null,
            "Catch": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "Next": "Terminate Instance"
              }
            ]
          },
          "Get prepare instance automation status": {
            "Type": "Task",
            "Next": "Is instance finalised",
            "Parameters": {
              "AutomationExecutionId.$": "$.prepareAutomation.AutomationExecutionId"
            },
            "Resource": "arn:aws:states:::aws-sdk:ssm:getAutomationExecution",
            "ResultSelector": {
              "AutomationExecutionId.$": "$.AutomationExecution.AutomationExecutionId",
              "Status.$": "$.AutomationExecution.AutomationExecutionStatus"
            },
            "ResultPath": "$.prepareAutomation",
            "Retry": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "BackoffRate": 1.5,
                "IntervalSeconds": 3,
                "MaxAttempts": 5
              }
            ]
          },
          "Is instance finalised": {
            "Type": "Choice",
            "Choices": [
              {
                "Or": [
                  {
                    "Variable": "$.prepareAutomation.Status",
                    "StringEquals": "Success"
                  },
                  {
                    "Variable": "$.prepareAutomation.Status",
                    "StringEquals": "CompletedWithSuccess"
                  }
                ],
                "Next": "Set instance to READY"
              },
              {
                "Or": [
                  {
                    "Variable": "$.prepareAutomation.Status",
                    "StringEquals": "Failed"
                  },
                  {
                    "Variable": "$.prepareAutomation.Status",
                    "StringEquals": "TimedOut"
                  },
                  {
                    "Variable": "$.prepareAutomation.Status",
                    "StringEquals": "Cancelling"
                  },
                  {
                    "Variable": "$.prepareAutomation.Status",
                    "StringEquals": "Cancelled"
                  },
                  {
                    "Variable": "$.prepareAutomation.Status",
                    "StringEquals": "CompletedWithFailure"
                  }
                ],
                "Next": "Terminate Instance"
              }
            ],
            "Default": "Wait 45ss"
          },
          "Set instance to READY": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:updateItem",
            "Parameters": {
              "TableName": "${aws_dynamodb_table.application_table.id}",
              "Key": {
                "pk": {
                  "S.$": "States.Format('INSTANCE#{}', $.type)"
                },
                "sk": {
                  "S.$": "States.Format('ID#{}', $.Instance.InstanceId)"
                }
              },
              "UpdateExpression": "SET #status = :statusRef, #lastUpdatedAt = :lastUpdatedAtRef",
              "ExpressionAttributeNames": {
                "#status": "status",
                "#lastUpdatedAt": "lastUpdatedAt"
              },
              "ExpressionAttributeValues": {
                ":statusRef": {
                  "S": "READY"
                },
                ":lastUpdatedAtRef": {
                  "S.$": "$$.State.EnteredTime"
                }
              }
            },
            "End": true,
            "Catch": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "Next": "Terminate Instance"
              }
            ],
            "ResultPath": null
          },
          "Wait 45ss": {
            "Type": "Wait",
            "Seconds": 45,
            "Next": "Get prepare instance automation status"
          },
          "Wait 45s": {
            "Type": "Wait",
            "Seconds": 45,
            "Next": "Get Instance Status"
          },
          "Terminate Instance": {
            "Type": "Task",
            "Parameters": {
              "InstanceIds.$": "States.Array($.Instance.InstanceId)"
            },
            "Resource": "arn:aws:states:::aws-sdk:ec2:terminateInstances",
            "Next": "Remove pre-allocated instance from DB",
            "ResultPath": null,
            "Retry": [
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "BackoffRate": 1.5,
                "IntervalSeconds": 1,
                "MaxAttempts": 5
              }
            ]
          },
          "Remove pre-allocated instance from DB": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:deleteItem",
            "Parameters": {
              "TableName": "${aws_dynamodb_table.application_table.id}",
              "Key": {
                "pk": {
                  "S.$": "States.Format('INSTANCE#{}', $.type)"
                },
                "sk": {
                  "S.$": "States.Format('ID#{}', $.Instance.InstanceId)"
                }
              }
            },
            "ResultPath": null,
            "Next": "Fail"
          },
          "Fail": {
            "Type": "Fail"
          }
        }
      },
      "ItemsPath": "$.Instances.Instances",
      "Parameters": {
        "type.$": "$.type",
        "launchTemplateName.$": "$.launchTemplateName",
        "launchTemplateVersion.$": "$.launchTemplateVersion",
        "Instance.$": "$$.Map.Item.Value"
      },
      "MaxConcurrency": 40,
      "Next": "Success"
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
EOF
}


resource "aws_iam_role" "event_bus_invoke_step_function_role" {
  name               = "${var.project}-${var.environment}-preallocate-instance-invoke-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "event_bus_invoke_step_function_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.preallocate_instance.arn]
  }
}

resource "aws_iam_policy" "event_bus_invoke_step_function_policy" {
  name   = "${var.project}-${var.environment}-preallocate-instance-policy"
  policy = data.aws_iam_policy_document.event_bus_invoke_step_function_policy_document.json
}

resource "aws_iam_role_policy_attachment" "event_bus_invoke_step_function_policy_attachment" {
  role       = aws_iam_role.event_bus_invoke_step_function_role.name
  policy_arn = aws_iam_policy.event_bus_invoke_step_function_policy.arn
}

resource "aws_cloudwatch_event_rule" "step_function_event_rule" {
  name                = "${var.project}-${var.environment}-preallocate-instance-rule"
  schedule_expression = "cron(0 5 ? * 2-6 *)"
  description         = "Rule to trigger instance pre allocation automatically every morning"
}

resource "aws_cloudwatch_event_target" "step_function_event_target" {
  target_id = "${var.project}-${var.environment}-preallocate-instance-rule-target"
  rule      = aws_cloudwatch_event_rule.step_function_event_rule.name
  arn       = aws_sfn_state_machine.preallocate_instance.arn
  role_arn  = aws_iam_role.event_bus_invoke_step_function_role.arn
  input = jsonencode({
    count                 = 1,
    launchTemplateName    = "amazon-linux-2" # you can change this to create windows instances or create multiple rules for multiple OS
    launchTemplateVersion = "$Default",
    type                  = "preallocate",
  })
}
