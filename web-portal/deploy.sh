#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

usage() { echo "Usage: $0 -s frontend_bucket -d frontend_distribution_id" 1>&2; exit 1; }

while getopts ":hyd:s:" o; do
   case "${o}" in
   	d)
   	  distribution=${OPTARG}
   	  ;;
   	s)
   	  s3bucket=${OPTARG}
   	  ;;
   	y)
   	  interactive=false
   	  ;;
   	h | *)	usage ;;
   esac
done

if [ -z "${s3bucket}" ] || [ -z "${distribution}" ]; then
    usage
fi

if ! command -v npm &> /dev/null
then
    echo "npm could not be found, please install node"
    exit
fi

if [ ! $interactive ]; then
  deploy="y"
else
  account=$(aws sts get-caller-identity --query Account --output text);

  if [ -z "$account" ]; then echo "Could not get target account to deploy on. Make sure aws cli credentials are properly configured."; exit; fi

  echo "You are about to deploy the web portal on the account $account, proceed? (y/n)"
  read -r deploy
fi

if [ "$deploy" = "y" ]; then
  echo "====== Install npm dependencies ======"
  npm ci

  echo "====== Build React application ======"
  npm run build

  echo "====== Deploy React application to S3 (${s3bucket}) ======"
  aws s3 sync build/ s3://${s3bucket}

  echo "====== Invalidate CloudFront cache ======"
  export AWS_MAX_ATTEMPTS=5
  aws cloudfront create-invalidation --distribution-id ${distribution} --paths "/*"
fi