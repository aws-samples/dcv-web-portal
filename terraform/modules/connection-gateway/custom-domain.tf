# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# resource "aws_route53_record" "connection_gateway_record" {
#   zone_id = var.route53_hosted_zone_id
#   name    = "connection-gateway.${var.route53_domain}"
#   type    = "A"

#   alias {
#     name                   = aws_lb.connection_gateway_lb.dns_name
#     zone_id                = aws_lb.connection_gateway_lb.zone_id
#     evaluate_target_health = true
#   }
# }