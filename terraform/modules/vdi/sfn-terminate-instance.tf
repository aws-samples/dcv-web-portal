# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "sfn_terminate_instance_role" {
  name_prefix = "${var.project}-${var.environment}-terminate-instance"

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
            "ec2:TerminateInstances",
            "ec2:DescribeInstanceStatus"
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

resource "aws_cloudwatch_log_group" "sfn_terminate_instance_logs" {
  name              = "${var.project}-${var.environment}-sfn-terminate-instance-logs"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_sfn_state_machine" "terminate_instance" {
  name     = "${var.project}-${var.environment}-terminate-instance"
  role_arn = aws_iam_role.sfn_terminate_instance_role.arn

  logging_configuration {
    level                  = "ALL"
    include_execution_data = true
    log_destination        = "${aws_cloudwatch_log_group.sfn_terminate_instance_logs.arn}:*"
  }

  tracing_configuration {
    enabled = true
  }

  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Remove instance from DB",
  "States": {
    "Remove instance from DB": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:deleteItem",
      "Parameters": {
        "TableName":  "${aws_dynamodb_table.application_table.name}",
        "Key": {
          "pk": {
            "S.$": "States.Format('INSTANCE#{}', $.type)"
          },
          "sk": {
            "S.$": "States.Format('ID#{}', $.instanceId)"
          }
        }
      },
      "ResultPath": null,
      "Next": "Terminate Instance",
      "Retry": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "BackoffRate": 1,
          "IntervalSeconds": 3,
          "MaxAttempts": 5
        }
      ]
    },
    "Terminate Instance": {
      "Type": "Task",
      "Next": "Get Instance Status",
      "Parameters": {
        "InstanceIds.$": "States.Array($.instanceId)"
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:terminateInstances",
      "Retry": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "BackoffRate": 1,
          "IntervalSeconds": 2,
          "MaxAttempts": 5
        }
      ],
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "Next": "Fail"
        }
      ],
      "ResultPath": "$.instance"
    },
    "Get Instance Status": {
      "Type": "Task",
      "Parameters": {
        "InstanceIds.$": "States.Array($.instanceId)",
        "IncludeAllInstances": true
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:describeInstanceStatus",
      "Next": "Is instance terminated?",
      "ResultSelector": {
        "instanceId.$": "$.InstanceStatuses[0].InstanceId",
        "status.$": "$.InstanceStatuses[0].InstanceState.Name"
      },
      "ResultPath": "$.instance",
      "Retry": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "BackoffRate": 1,
          "IntervalSeconds": 3,
          "MaxAttempts": 5
        }
      ]
    },
    "Is instance terminated?": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.instance.status",
          "StringEquals": "terminated",
          "Next": "Success"
        }
      ],
      "Default": "Wait 5s"
    },
    "Success": {
      "Type": "Succeed"
    },
    "Wait 5s": {
      "Type": "Wait",
      "Seconds": 5,
      "Next": "Get Instance Status"
    },
    "Fail": {
      "Type": "Fail"
    }
  }
}
EOF
}