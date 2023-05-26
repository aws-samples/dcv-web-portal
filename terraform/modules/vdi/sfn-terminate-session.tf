# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "sfn_terminate_session_role" {
  name_prefix = "${var.project}-${var.environment}-terminate-session-role"

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
    name = "${var.project}-${var.environment}"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "states:StartExecution.sync",
            "states:StartExecution",
          ]
          Effect   = "Allow"
          Resource = aws_sfn_state_machine.terminate_instance.arn
        },
        {
          Action = [
            "states:DescribeExecution",
            "states:StopExecution"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:states:${var.region}:${var.account_id}:execution:${aws_sfn_state_machine.terminate_instance.name}:*"
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
    name = "${var.project}-${var.environment}-dynamodb"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "dynamodb:GetItem",
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

resource "aws_cloudwatch_log_group" "sfn_terminate_session_logs" {
  name              = "${var.project}-${var.environment}-sfn-terminate-session-logs"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_sfn_state_machine" "terminate_session" {
  name     = "${var.project}-${var.environment}-terminate-session"
  role_arn = aws_iam_role.sfn_terminate_session_role.arn

  logging_configuration {
    level                  = "ALL"
    include_execution_data = true
    log_destination        = "${aws_cloudwatch_log_group.sfn_terminate_session_logs.arn}:*"
  }

  tracing_configuration {
    enabled = true
  }

  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Get session",
  "States": {
    "Get session": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:getItem",
      "Parameters": {
        "TableName":  "${aws_dynamodb_table.application_table.name}",
        "Key": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$":  "States.Format('SESSION#{}', $.sessionId)"
          }
        }
      },
      "ResultPath": "$.session",
      "Next": "Has a running instance?",
      "Retry": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "BackoffRate": 1,
          "IntervalSeconds": 3,
          "MaxAttempts": 5
        }
      ],
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "ResultPath": "$.error",
          "Next": "Set session as FAILED_TERMINATING"
        }
      ]
    },
    "Set session as FAILED_TERMINATING": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName":  "${aws_dynamodb_table.application_table.name}",
        "Key": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$": "States.Format('SESSION#{}', $.sessionId)"
          }
        },
        "UpdateExpression": "SET #status = :statusRef, #lastUpdatedAt = :lastUpdatedAtRef, #details = :detailsRef",
        "ExpressionAttributeNames": {
          "#status": "status",
          "#details": "details",
          "#lastUpdatedAt": "lastUpdatedAt"
        },
        "ExpressionAttributeValues": {
          ":statusRef": {
            "S": "FAILED_TERMINATING"
          },
          ":detailsRef": {
            "S.$": "$.error.Cause"
          },
          ":lastUpdatedAtRef": {
            "S.$": "$$.State.EnteredTime"
          }
        }
      },
      "Next": "Fail"
    },
    "Fail": {
      "Type": "Fail"
    },
    "Has a running instance?": {
      "Type": "Choice",
      "Choices": [
        {
          "And": [
            {
              "Variable": "$.session.Item",
              "IsPresent": true
            },
            {
              "Not": {
                "Variable": "$.session.Item.status.S",
                "StringEquals": "TERMINATING"
              }
            }
          ],
          "Comment": "If use has an instance e and it's not stopping",
          "Next": "Set session as TERMINATING"
        }
      ],
      "Default": "Remove session from DB"
    },
    "Set session as TERMINATING": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName":  "${aws_dynamodb_table.application_table.name}",
        "Key": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$": "States.Format('SESSION#{}', $.sessionId)"
          }
        },
        "UpdateExpression": "SET #status = :statusRef, #lastUpdatedAt = :lastUpdatedAtRef",
        "ExpressionAttributeNames": {
          "#status": "status",
          "#lastUpdatedAt": "lastUpdatedAt"
        },
        "ExpressionAttributeValues": {
          ":statusRef": {
            "S": "TERMINATING"
          },
          ":lastUpdatedAtRef": {
            "S.$": "$$.State.EnteredTime"
          }
        }
      },
      "ResultPath": null,
      "Next": "Terminate instance",
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
    "Terminate instance": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution.sync:2",
      "Parameters": {
        "StateMachineArn": "${aws_sfn_state_machine.terminate_instance.arn}",
        "Input": {
          "instanceId.$": "$.session.Item.instanceId.S",
          "type.$": "$.sessionId",
          "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID.$": "$$.Execution.Id"
        }
      },
      "Next": "Remove session from DB",
      "ResultPath": "$.terminateInstance",
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "ResultPath": "$.error",
          "Next": "Set session as FAILED_TERMINATING"
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
    "Remove session from DB": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:deleteItem",
      "Parameters": {
        "TableName":  "${aws_dynamodb_table.application_table.name}",
        "Key": {
          "pk": {
            "S.$": "States.Format('USER#{}', $.username)"
          },
          "sk": {
            "S.$": "States.Format('SESSION#{}', $.sessionId)"
          }
        }
      },
      "Next": "Success",
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
    "Success": {
      "Type": "Succeed"
    }
  }
}
EOF
}