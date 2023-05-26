#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

./prerequisites.sh
RETURN=$?

if [ $RETURN -ne 0 ];
then
  exit 1
fi

echo "Did you configure the variables.tf properly? (y/n)"
read -r config

if [ "$config" != "y" ]; then
  echo "Please configure the variables.tf before deploying the solution"
  exit 1
fi

account=$(aws sts get-caller-identity --query Account --output text);

if [ -z "$account" ]; then
  echo "Could not get target account to deploy on. Make sure aws cli credentials are properly configured."
  exit 1
fi

echo "You are about to deploy the solution on the account $account, proceed? (y/n)"
read -r deploy

if [ "$deploy" = "y" ]; then
  # Deploy the terraform stack
  echo "======================================"
  echo "===== Infrastructure deployment ======"
  echo "======================================"
  terraform init && terraform apply --auto-approve

  terraform_result=$?

  # Deploy the frontend
  if [ $terraform_result -ne 0 ]; then
    echo "There were some errors during the deployment, please refer to the troubleshooting guide in the README and retry."
  else
    # Retrieve outputs
    frontend_bucket=$(terraform output  -raw frontend_bucket)
    frontend_distribution_id=$(terraform output  -raw frontend_distribution_id)

    echo "======================================"
    echo "======   Frontend deployment   ======="
    echo "======================================"
    cd ../web-portal && ./deploy.sh -y -s "$frontend_bucket" -d "$frontend_distribution_id"
  fi
fi