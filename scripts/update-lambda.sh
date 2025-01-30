#!/bin/bash

set -e  # Exit script on error

# Define resource names
SCRIPTS_DIR="$PWD"
LAMBDA_DIR="$SCRIPTS_DIR/../lambda"
LAMBDA_NAME="my-function"
LAMBDA_ROLE="arn:aws:iam::000000000000:role/lambda-role"
HANDLER="lambda_function.lambda_handler"
RUNTIME="python3.12"
ZIP_FILE="$LAMBDA_DIR/deployment-package.zip"
AWS_CMD="awslocal"

# Step 1: Prepare Lambda Deployment (Using Virtual Environment)
echo "🐍 Setting up Python virtual environment..."
cd $LAMBDA_DIR
pwd
rm -rf venv  # Remove old virtual environment
rm -rf package
python3 -m venv venv
source venv/bin/activate
mkdir -p package
pip install -r requirements.txt -t ./package
cp ./src/lambda_function.py ./package/
deactivate

echo "📦 Packaging Lambda function..."
rm -f $ZIP_FILE
cd package
zip -r ../deployment-package.zip .
cd  $SCRIPTS_DIR

# Step 2: Update Lambda Function in LocalStack
echo "🔄 Updating Lambda function..."
$AWS_CMD lambda update-function-code \
    --function-name $LAMBDA_NAME \
    --zip-file fileb://$ZIP_FILE

echo "✅ Lambda function deployed successfully!"
