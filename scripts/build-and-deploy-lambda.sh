#!/bin/bash

set -e # Exit immediately if any command fails

# Define resource names
SCRIPTS_DIR="$PWD"
LAMBDA_DIR="$SCRIPTS_DIR/../lambda"
QUEUE_NAME="my-queue"
LAMBDA_NAME="my-function"
LAMBDA_ROLE="arn:aws:iam::000000000000:role/lambda-role"
HANDLER="lambda_function.lambda_handler"
RUNTIME="python3.12"
ZIP_FILE="$LAMBDA_DIR/deployment-package.zip"
AWS_CMD="awslocal"

# Step 5: Prepare Lambda Deployment (Using Virtual Environment)
echo "🐍 Setting up Python virtual environment..."
cd $LAMBDA_DIR
rm -rf venv # Remove old virtual environment
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
cd $SCRIPTS_DIR

# Step 6: Deploy Lambda Function
echo "🚀 Deploying Lambda function: $LAMBDA_NAME"
$AWS_CMD lambda create-function \
  --function-name $LAMBDA_NAME \
  --runtime $RUNTIME \
  --role $LAMBDA_ROLE \
  --handler $HANDLER \
  --memory-size 512 \
  --timeout 30 \
  --zip-file fileb://$ZIP_FILE

echo "Creating event source mapping between SQS and Lambda..."
$AWS_CMD lambda create-event-source-mapping \
  --function-name $LAMBDA_NAME \
  --event-source-arn "arn:aws:sqs:us-east-1:000000000000:$QUEUE_NAME" \
  --batch-size 10

# Step 8: Verify resources
echo "Listing LocalStack resources..."

echo "Lambda Functions:"
$AWS_CMD lambda list-functions

echo "Event Source Mappings:"
$AWS_CMD lambda list-event-source-mappings --function-name $LAMBDA_NAME
