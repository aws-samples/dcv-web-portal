import os
import boto3
import secrets
import string

client = boto3.client('secretsmanager')
alphabet = string.ascii_letters + string.digits

def lambda_handler(event, context):
    print(event)

    password = ''.join(secrets.choice(alphabet) for i in range(10))
    print(password)

    try:
        client.create_secret(
            Name='dcv-'+event['userName']+'-credentials',
            Description='Workstation password for '+event['userName'],
            KmsKeyId=os.environ['KMS_KEY_ID'],
            SecretString=password
        )
    except Exception as e:
      print("Unable to create secret for "+event['userName'])
      print(e)

    # you can use Amazon SES to send the password to the user (see https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ses/client/send_email.html)

    event['response']['autoConfirmUser']=True

    if 'email' in event['request']['userAttributes']:
        event['response']['autoVerifyEmail'] = True

    if 'phone_number' in event['request']['userAttributes']:
        event['response']['autoVerifyPhone'] = True

    return event