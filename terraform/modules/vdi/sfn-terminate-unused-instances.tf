# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

resource "aws_iam_role" "sfn_terminate_unused_instances_role" {
  name = "${var.project}-${var.environment}-terminate-unused-instances-role"

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
            "dynamodb:Query"
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

resource "aws_cloudwatch_log_group" "sfn_terminate_unused_instances_logs" {
  name              = "${var.project}-${var.environment}-sfn-terminate-unused-instances-logs"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_sfn_state_machine" "terminate_unused_instances" {
  name     = "${var.project}-${var.environment}-terminate-unused-instances"
  role_arn = aws_iam_role.sfn_terminate_unused_instances_role.arn

  logging_configuration {
    level                  = "ALL"
    include_execution_data = true
    log_destination        = "${aws_cloudwatch_log_group.sfn_terminate_unused_instances_logs.arn}:*"
  }

  tracing_configuration {
    enabled = true
  }

  definition = <<EOF
{
  "Comment": "Destroy Unused Instances",
  "StartAt": "Are there left pre-allocated instances?",
  "States": {
    "Are there left pre-allocated instances?": {
      "Type": "Task",
      "Parameters": {
        "TableName": "${aws_dynamodb_table.application_table.id}",
        "IndexName": "${var.project}-${var.environment}-status-idx",
        "KeyConditionExpression": "#pk = :pk AND #status = :status",
        "ExpressionAttributeNames": {
          "#pk": "pk",
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":pk": {
            "S.$": "States.Format('INSTANCE#{}', $.type)"
          },
          ":status": {
            "S": "READY"
          }
        },
        "ScanIndexForward": false
      },
      "ResultPath": "$.instances",
      "Resource": "arn:aws:states:::aws-sdk:dynamodb:query",
      "Next": "For each instance"
    },
    "For each instance": {
      "Type": "Map",
      "Iterator": {
        "StartAt": "Terminate instance",
        "States": {
          "Terminate instance": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution.sync:2",
      "Parameters": {
        "StateMachineArn": "${aws_sfn_state_machine.terminate_instance.arn}",
        "Input": {
          "instanceId.$": "$.Instance.instanceId.S",
          "type.$": "$.type",
          "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID.$": "$$.Execution.Id"
        }
      },
      "ResultPath": "$.terminateInstance",
      "Retry": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "BackoffRate": 1,
          "IntervalSeconds": 1,
          "MaxAttempts": 2
        }
      ],
            "End": true
    }
        }
      },
      "ItemsPath": "$.instances.Items",
      "Parameters": {
        "type.$": "$.type",
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

resource "aws_iam_role" "invoke_step_function_destroy_unused_instances_role" {
  name               = "${var.project}-${var.environment}-destroy-unused-instances_-invoke-role"
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

data "aws_iam_policy_document" "invoke_step_function_destroy_unused_instances_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.terminate_unused_instances.arn]
  }
}

resource "aws_iam_policy" "invoke_step_function_destroy_unused_instances_policy" {
  name   = "${var.project}-${var.environment}-destroy-unused-instances-policy"
  policy = data.aws_iam_policy_document.invoke_step_function_destroy_unused_instances_policy_document.json
}

resource "aws_iam_role_policy_attachment" "invoke_step_function_policy_attachment" {
  role       = aws_iam_role.invoke_step_function_destroy_unused_instances_role.name
  policy_arn = aws_iam_policy.invoke_step_function_destroy_unused_instances_policy.arn
}

resource "aws_cloudwatch_event_rule" "invoke_terminate_unused_instances_event_rule" {
  name                = "${var.project}-${var.environment}-terminate-unused-instances"
  schedule_expression = "cron(0 8 ? * 2-6 *)"
  description         = "Rule to trigger destruction of unused instances at 10pm in the morning"
}

resource "aws_cloudwatch_event_target" "invoke_terminate_unused_instances_event_target" {
  target_id = "${var.project}-${var.environment}-terminate-unused-instances"
  rule      = aws_cloudwatch_event_rule.invoke_terminate_unused_instances_event_rule.name
  arn       = aws_sfn_state_machine.terminate_unused_instances.arn
  role_arn  = aws_iam_role.invoke_step_function_destroy_unused_instances_role.arn

  input = jsonencode({
    type = "preallocate"
  })
}
