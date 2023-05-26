# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import os
import logging
import boto3
import base64

ec2 = boto3.client('ec2')

# create logger
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

ADMIN_GROUP_NAME = 'admin'

def lambda_handler(event, context):
    logger.debug(event)

    method = event['httpMethod']
    resource = event['resource']

    status_code = 200
    body = {"error": True}
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET,OPTIONS,POST,PUT,DELETE',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
    }

    request_context = event['requestContext']
    authorizer = request_context['authorizer']
    claims = authorizer['claims']

    if 'cognito:groups' in claims:
        groups = claims['cognito:groups']
    else:
        groups = 'user'

    if groups == ADMIN_GROUP_NAME:
        if method == 'GET' and resource == '/templates':
            body = get_templates(event)
        if method == 'GET' and resource == '/templates/{id}':
            body = get_template(event)
        if method == 'POST' and resource == '/templates/{id}':
            body = update_template(event)

        return {
            'statusCode': status_code,
            'headers': headers,
            'body': json.dumps(body)
        }
    else:
        if method == 'GET' and resource == '/templates':
            body = get_template_names(event)
            return {
                'statusCode': status_code,
                'headers': headers,
                'body': json.dumps(body)
            }

        return {
            'statusCode': 403,
            'headers': headers,
            'body': json.dumps({'error': True, 'details': 'Forbidden'})
        }

def get_templates(event):
    templates = ec2.describe_launch_templates(Filters=[{'Name': 'tag:admin_ui', 'Values': ['show']}])

    data = [{
        'templateId': template['LaunchTemplateId'],
        'name': template['LaunchTemplateName'],
        'createdAt': str(template['CreateTime']),
        'defaultVersion': template['DefaultVersionNumber'],
        'latestVersion':  template['LatestVersionNumber']
    } for template in templates['LaunchTemplates']]

    return {'templates': data}

def get_template_names(event):
    templates = ec2.describe_launch_templates(Filters=[{'Name': 'tag:admin_ui', 'Values': ['show']}])

    data = [{ 'name': template['LaunchTemplateName'] } for template in templates['LaunchTemplates']]

    return {'templates': data}

def get_template(event):
    path_parameters = event['pathParameters']
    template_id = path_parameters['id']

    templates = ec2.describe_launch_templates(LaunchTemplateIds=[template_id])
    templates = templates['LaunchTemplates']
    if len(templates) == 0:
        return {"error": True}

    template = templates[0]
    template = {
        'templateId': template['LaunchTemplateId'],
        'name': template['LaunchTemplateName'],
        'createdAt': str(template['CreateTime']),
        'defaultVersion': template['DefaultVersionNumber'],
        'latestVersion':  template['LatestVersionNumber']
    }

    default_version = template['defaultVersion']
    min_ver = str(max(default_version - 50, 0))
    versions = ec2.describe_launch_template_versions(LaunchTemplateId=template_id,
                                                    MinVersion=min_ver)

    data = [{
        'templateId': version['LaunchTemplateId'],
        'name': version['LaunchTemplateName'],
        'version': version['VersionNumber'],
        'createTime': str(version['CreateTime']),
        'imageId': version['LaunchTemplateData'].get('ImageId',''),
        'default': version['VersionNumber'] == default_version
    } for version in versions['LaunchTemplateVersions']]

    data = list(filter(lambda item: item['imageId'] or item['version'] == default_version, data))

    return {'template': template, 'versions': data}

def update_template(event):
    path_parameters = event['pathParameters']
    template_id = path_parameters['id']
    body = json.loads(event['body'])
    version = body['version']
    token = body['token']

    response = ec2.modify_launch_template(LaunchTemplateId=template_id,
        DefaultVersion=str(version),
        ClientToken=token)

    template = response['LaunchTemplate']

    template = {
        'templateId': template['LaunchTemplateId'],
        'name': template['LaunchTemplateName'],
        'createdAt': str(template['CreateTime']),
        'defaultVersion': template['DefaultVersionNumber'],
        'latestVersion':  template['LatestVersionNumber']
    }

    return {'template': template}