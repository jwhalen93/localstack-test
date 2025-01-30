import json
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function triggered by SQS. It extracts the S3 bucket name and object key from the SNS message.
    Includes improved error handling for missing or malformed data.
    """
    try:
        for record in event.get("Records", []):
            try:
                # Extract SQS message body
                sqs_body = json.loads(record.get("body", "{}"))  # Convert string to JSON
                
                # Extract S3 event records
                s3_records = sqs_body.get("Records", [])

                for s3_record in s3_records:
                    # Extract S3 bucket name and object key safely
                    bucket_name = s3_record.get("s3", {}).get("bucket", {}).get("name")
                    object_key = s3_record.get("s3", {}).get("object", {}).get("key")

                    if bucket_name and object_key:
                        logger.info(f"✅ Received S3 Event - Bucket: {bucket_name}, Key: {object_key}")
                    else:
                        logger.warning(f"⚠️ Incomplete S3 event data: {json.dumps(s3_record, indent=2)}")
            except json.JSONDecodeError as e:
                logger.error(f"❌ Failed to decode JSON: {e}")
            except Exception as e:
                logger.error(f"❌ Error processing individual record: {e}")
    except Exception as e:
        logger.error(f"❌ Unexpected error: {e}")

    return {"statusCode": 200, "body": "S3 event processed"}
