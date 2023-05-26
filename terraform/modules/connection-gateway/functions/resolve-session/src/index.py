# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import os
import boto3
import base64

ec2 = boto3.client('ec2')

TCP_PORT = os.environ["TCP_PORT"]
UDP_PORT = os.environ["UDP_PORT"]

# https://docs.aws.amazon.com/dcv/latest/gw-admin/session-resolver.html#implementing-session-resolver
# sessionId=session_id&transport=transport&clientIpAddress=clientIpAddress
def lambda_handler(event, context):
    print(event)
    sessionId = event['queryStringParameters']['sessionId']
    transport = event['queryStringParameters']['transport']

    if sessionId is None:
        return {
            'statusCode': 400,
            'body': "Missing sessionId parameter"
        }

    if transport != "HTTP" and transport != "QUIC":
        return {
            'statusCode': 400,
            'body': "Invalid transport parameter: " + transport
        }

    session_details = {'SessionId': "console"}
    session_details['DcvServerEndpoint'] = instance_id_to_ip(sessionId)
    if (transport == 'HTTP'):
        session_details['Port'] = int(TCP_PORT)
    else:
        session_details['Port'] = int(UDP_PORT)
    session_details['WebUrlPath'] = '/'
    session_details['TransportProtocol'] = transport

    print(f'session_details: {session_details}')
    return {
        'statusCode': 200,
        'body': json.dumps(session_details)
    }

def instance_id_to_ip(instance_id):
    """ Given an instance ID this returns the private Ip address corresponding to it """
    try:
        response = ec2.describe_instances(
            InstanceIds = [instance_id],
            )
        private_dns_name = response['Reservations'][0]['Instances'][0]['PrivateDnsName']
        return private_dns_name
    except Exception:
        print('could not resolve instance ID')
        return ""
