#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
echo "Performing some checks:"

if ! command -v terraform &> /dev/null
then
    echo "terraform could not be found, please install terraform and add it to the PATH"
    exit 1
else
    echo -e "terraform \xE2\x9C\x94"
fi

if ! command -v aws &> /dev/null
then
    echo "aws cli could not be found, please install aws cli and add it to the PATH"
    exit 1
else
    echo -e "aws \xE2\x9C\x94"
fi

if ! command -v npm &> /dev/null
then
    echo "npm could not be found, please install node and npm and add them to the PATH"
    exit 1
else
    echo -e "npm \xE2\x9C\x94"
fi

if ! command -v pip &> /dev/null
then
    echo "pip could not be found, please install python / pip and add them to the PATH"
    exit 1
else
    echo -e "pip \xE2\x9C\x94"
fi

account=$(aws sts get-caller-identity --query Account --output text);

if [ -z "$account" ]; then echo "Could not get target account to deploy on. Make sure aws cli credentials are properly configured."; exit 1; fi

aws iam get-role --role-name AWSServiceRoleForAutoScaling &> /dev/null
iam_role_result=$?
if [ $iam_role_result -ne 0 ];
then
  echo "The AWSServiceRoleForAutoScaling does not exist, creating..."
  aws iam create-service-linked-role --aws-service-name autoscaling.amazonaws.com --description "Service role for autoscaling groups"
  iam_role_creation_result=$?
  if [ $iam_role_creation_result -ne 0 ]; then exit 1; fi
fi

echo "Everything looks good, you can proceed with the deployment!"