#!/bin/bash

set -e  # Exit script on error

echo "🚀 Deploying Lambda function..."

# Define resource names
LAMBDA_NAME="my-function"
HANDLER="lambda_function.lambda_handler"
RUNTIME="python3.12"
LAMBDA_DIR="../lambda"
ZIP_FILE="$LAMBDA_DIR/deployment-package.zip"
AWS_CMD="awslocal"

# Step 1: Navigate to Lambda Directory
cd $LAMBDA_DIR

# Step 2: Prepare Lambda Deployment (Using Virtual Environment)
echo "🐍 Setting up Python virtual environment..."
cd $LAMBDA_DIR
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
cd ../../scripts
# Step 3: Update Lambda Function in LocalStack
echo "🔄 Updating Lambda function..."
$AWS_CMD lambda update-function-code \
    --function-name $LAMBDA_NAME \
    --zip-file fileb://$ZIP_FILE

echo "✅ Lambda function deployed successfully!"
