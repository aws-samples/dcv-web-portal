# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "application_table_name" {
  value = aws_dynamodb_table.application_table.name
}

output "application_table_arn" {
  value = aws_dynamodb_table.application_table.arn
}

output "create_session_machine_arn" {
  value = aws_sfn_state_machine.create_session.arn
}

output "create_instance_machine_arn" {
  value = aws_sfn_state_machine.preallocate_instance.arn
}

output "terminate_session_machine_arn" {
  value = aws_sfn_state_machine.terminate_session.arn
}