#!/bin/bash

set -e  # Exit immediately if any command fails

echo "🛠  Initializing LocalStack..."

# Define resource names
BUCKET_NAME="local-bucket"
QUEUE_NAME="my-queue"
TOPIC_NAME="my-topic"
LAMBDA_NAME="my-function"
LAMBDA_ROLE="arn:aws:iam::000000000000:role/lambda-role"
HANDLER="lambda_function.lambda_handler"
RUNTIME="python3.12"
LAMBDA_DIR="../lambda"
ZIP_FILE="$LAMBDA_DIR/deployment-package.zip"
AWS_CMD="awslocal"

# Step 1: Create S3 Bucket
echo "📦 Creating S3 bucket: $BUCKET_NAME"
$AWS_CMD s3 mb s3://$BUCKET_NAME || true

# Step 2: Create SQS Queue
echo "📬 Creating SQS queue: $QUEUE_NAME"
QUEUE_URL=$($AWS_CMD sqs create-queue --queue-name $QUEUE_NAME --query 'QueueUrl' --output text)
QUEUE_ARN=$($AWS_CMD sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-name QueueArn --query 'Attributes.QueueArn' --output text)
echo "✅ SQS Queue ARN: $QUEUE_ARN"

# Step 3: Create SNS Topic
echo "📢 Creating SNS topic: $TOPIC_NAME"
TOPIC_ARN=$($AWS_CMD sns create-topic --name $TOPIC_NAME | jq -r '.TopicArn')
echo "✅ SNS Topic ARN: $TOPIC_ARN"

# Step 4: Subscribe SQS Queue to SNS Topic
echo "🔗 Subscribing SQS Queue to SNS Topic..."
$AWS_CMD sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol "sqs" \
    --notification-endpoint "$QUEUE_ARN" \
    --attributes '{"RawMessageDelivery":"true"}'

# Step 5: Prepare Lambda Deployment (Using Virtual Environment)
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
cd ../../infrastructure

# Step 6: Deploy Lambda Function
echo "🚀 Deploying Lambda function: $LAMBDA_NAME"
$AWS_CMD lambda create-function \
    --function-name $LAMBDA_NAME \
    --runtime $RUNTIME \
    --role $LAMBDA_ROLE \
    --handler $HANDLER \
    --zip-file fileb://$ZIP_FILE

# # Step 7: Set Environment Variables for Lambda
# echo "🌍 Setting environment variables..."
# cat > env-config.json <<EOL
# {
#   "Variables": {
#     "SNS_TOPIC_ARN": "$TOPIC_ARN",
#     "SQS_QUEUE_URL": "$QUEUE_URL"
#   }
# }
# EOL

# $AWS_CMD lambda update-function-configuration \
#     --function-name $LAMBDA_NAME \
#     --environment file://env-config.json

echo "Creating event source mapping between SQS and Lambda..."
$AWS_CMD lambda create-event-source-mapping \
  --function-name $LAMBDA_NAME \
  --event-source-arn "arn:aws:sqs:us-east-1:000000000000:$QUEUE_NAME" \
  --batch-size 10


# Step 8: Set up S3 Event Notification for Lambda
echo "🔗 Configuring S3 event notifications..."
cat > lambda-function-policy.json <<EOL
{
  "TopicConfigurations": [
    {
      "TopicArn": "$TOPIC_ARN",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {"Name": "prefix", "Value": "migrate/"}
          ]
        }
      }
    }
  ]
}
EOL
$AWS_CMD s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration file://lambda-function-policy.json

echo "✅ LocalStack setup complete!"

# Step 8: Verify resources
echo "Listing LocalStack resources..."

echo "SNS Topics:"
$AWS_CMD sns list-topics

echo "SQS Queues:"
$AWS_CMD sqs list-queues

echo "Lambda Functions:"
$AWS_CMD lambda list-functions

echo "Event Source Mappings:"
$AWS_CMD lambda list-event-source-mappings --function-name $LAMBDA_NAME

echo "LocalStack setup complete!"