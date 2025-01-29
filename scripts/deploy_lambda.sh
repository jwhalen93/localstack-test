#!/bin/bash

set -e  # Exit script on error

echo "🚀 Deploying Lambda function..."

# Define resource names
LAMBDA_NAME="my-function"
LAMBDA_ROLE="arn:aws:iam::000000000000:role/lambda-role"
HANDLER="lambda_function.lambda_handler"
RUNTIME="python3.12"
LAMBDA_DIR="../lambda"
ZIP_FILE="$LAMBDA_DIR/deployment-package.zip"

# Step 1: Navigate to Lambda Directory
cd $LAMBDA_DIR

# Step 2: Set Up Virtual Environment
echo "🐍 Setting up Python virtual environment..."
rm -rf venv  # Remove old virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

# Step 3: Package Lambda Function
echo "📦 Packaging Lambda..."
rm -f $ZIP_FILE
cd src
zip -r9 ../lambda.zip . ../venv/lib/python3.9/site-packages/*
cd ../../scripts

# Step 4: Update Lambda Function in LocalStack
echo "🔄 Updating Lambda function..."
awslocal lambda update-function-code \
    --function-name $LAMBDA_NAME \
    --zip-file fileb://$ZIP_FILE

echo "✅ Lambda function deployed successfully!"
