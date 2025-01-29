import boto3
import json
import os

def lambda_handler(event, context):
    # Initialize AWS services
    sns_client = boto3.client('sns')
    sqs_client = boto3.client('sqs')

    # Environment variables (set these in the Lambda environment settings)
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    sqs_queue_url = os.environ['SQS_QUEUE_URL']

    # Process S3 event
    for record in event['Records']:
        s3_bucket = record['s3']['bucket']['name']
        s3_key = record['s3']['object']['key']

        # Verify if the file is in the "/migrate" subfolder
        if not s3_key.startswith("migrate/"):
            print(f"File {s3_key} is not in the /migrate subfolder. Skipping...")
            continue

        # Message to send
        message = {
            "bucket": s3_bucket,
            "key": s3_key
        }

        # Notify the SNS topic
        try:
            sns_response = sns_client.publish(
                TopicArn=sns_topic_arn,
                Message=json.dumps(message)
            )
            print(f"SNS notification sent. Message ID: {sns_response['MessageId']}")
        except Exception as e:
            print(f"Failed to send SNS notification: {str(e)}")

        # Add message to the SQS queue
        # try:
        #     sqs_response = sqs_client.send_message(
        #         QueueUrl=sqs_queue_url,
        #         MessageBody=json.dumps(message)
        #     )
        #     print(f"Message added to SQS queue. Message ID: {sqs_response['MessageId']}")
        # except Exception as e:
        #     print(f"Failed to add message to SQS queue: {str(e)}")

    return {
        'statusCode': 200,
        'body': json.dumps('Function executed successfully')
    }
