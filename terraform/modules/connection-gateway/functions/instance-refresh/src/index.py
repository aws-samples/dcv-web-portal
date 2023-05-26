# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
import boto3
from botocore.exceptions import ClientError
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# define boto3 clients
asg_client = boto3.client('autoscaling')

asg_name = os.environ['AUTOSCALING_GROUP_NAME']
template_id = os.environ['LAUNCH_TEMPLATE_ID']

def trigger_auto_scaling_instance_refresh(asg_name, launch_template_id, launch_template_version, strategy="Rolling",
                                          min_healthy_percentage=90, instance_warmup=300):
    try:
        response = asg_client.start_instance_refresh(
            AutoScalingGroupName=asg_name,
            Strategy=strategy,
            Preferences={
                'MinHealthyPercentage': min_healthy_percentage,
                'InstanceWarmup': instance_warmup,
                'SkipMatching': True
            },
            DesiredConfiguration={
                'LaunchTemplate': {
                    'LaunchTemplateId': launch_template_id,
                    'Version': str(launch_template_version)
                }
            }
        )
        logging.info("Triggered Instance Refresh {} for Auto Scaling "
                     "group {}".format(response['InstanceRefreshId'], asg_name))

    except ClientError as e:
        logging.error("Unable to trigger Instance Refresh for "
                      "Auto Scaling group {}".format(asg_name))
        raise e


def lambda_handler(event, context):
    #logging.info(event)
    launch_template_id = event['detail']['responseElements']['ModifyLaunchTemplateResponse']['launchTemplate']['launchTemplateId']
    launch_template_version = event['detail']['responseElements']['ModifyLaunchTemplateResponse']['launchTemplate']['defaultVersionNumber']
    logging.info("Launch Template {} default version set to {}".format(launch_template_id, str(launch_template_version)))

    # Trigger Auto Scaling group Instance Refresh
    if template_id == launch_template_id:
        trigger_auto_scaling_instance_refresh(asg_name, launch_template_id, launch_template_version)

    return("Success")