#!/bin/bash

# ECRにログイン
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Dockerイメージのプル
docker pull $CONTAINER_NAME:latest

# イメージのタグ付け
docker tag $CONTAINER_NAME:latest $REPO_URL:latest

# イメージをECRにプッシュ
docker push $REPO_URL:latest
