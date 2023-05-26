import json
import os
import logging
from urllib.parse import parse_qs
from jwt_auth import verify_jwt

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

DOMAIN_NAME =  os.environ["AD_DOMAIN_NAME"]

def lambda_handler(event, context):

    """ Handle auth via JWT """
    qs = parse_qs(event['body'])

    # JWT
    authToken = qs['authenticationToken']
    username = verify_jwt(authToken[0])
    if username is None:
        print("No username in auth token")
        return {
            'statusCode': 200,
            'body':  f'<auth result="no"/>'
        }

    print(f"{username} matched")
    return {
        'statusCode': 200,
        'body':  f'<auth result="yes"><username>{DOMAIN_NAME}\\{username}</username></auth>'
    }

def error(msg):
    return json.dumps({'error': msg})
