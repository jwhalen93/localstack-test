import json
import logging
import boto3
import xml.etree.ElementTree as ET
import re
import time
import os

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize S3 resource for better performance
s3_resource = boto3.resource("s3", endpoint_url='http://' + os.environ["LOCALSTACK_HOSTNAME"] + ':4566')


def stream_s3_object(bucket_name, object_key):
    """Stream the S3 object line by line to find <docId> without loading full file."""
    try:
        obj = s3_resource.Object(bucket_name, object_key)
        stream = obj.get()["Body"]

        file_data = b""  # Will store the XML content in bytes
        doc_id = None
        doc_id_pattern = re.compile(r"<docId>(.*?)</docId>")  # Regex to find docId

        for chunk in iter(lambda: stream.read(1024 * 1024), b""):  # Read 1MB at a time
            file_data += chunk  # Store for potential re-upload
            chunk_text = chunk.decode("utf-8", errors="ignore")  # Convert to text

            match = doc_id_pattern.search(chunk_text)
            if match:
                doc_id = match.group(1).strip()
                logger.info(f"🆔 Found docId: {doc_id}")
                break  # Stop reading once we find <docId>

        return doc_id, file_data
    except Exception as e:
        logger.error(f"❌ Error streaming S3 object: {e}")
        return None, None


def is_xml_file(object_key):
    """Check if the file has an XML extension."""
    return object_key.lower().endswith(".xml")


def upload_s3_object(bucket_name, new_key, file_data):
    """Uploads the file data to S3 under a new key."""
    try:
        s3_resource.Object(bucket_name, new_key).put(Body=file_data)
        logger.info(f"✅ Successfully moved object to {new_key}")
    except Exception as e:
        logger.error(f"❌ Failed to upload object: {e}")


def delete_s3_object(bucket_name, object_key):
    """Deletes the original object from S3."""
    try:
        s3_resource.Object(bucket_name, object_key).delete()
        logger.info(f"🗑️ Successfully deleted original object: {object_key}")
    except Exception as e:
        logger.error(f"❌ Failed to delete object: {e}")


def lambda_handler(event, context):
    """Lambda function triggered by SQS to process S3 objects."""
    start_time = time.time()
    logger.info("Lambda function started")

    for record in event.get("Records", []):
        try:
            sqs_body = json.loads(record.get("body", "{}"))
            s3_records = sqs_body.get("Records", [])

            for s3_record in s3_records:
                bucket_name = s3_record.get("s3", {}).get("bucket", {}).get("name")
                object_key = s3_record.get("s3", {}).get("object", {}).get("key")

                if bucket_name and object_key:
                    logger.info(
                        f"✅ Processing S3 Event - Bucket: {bucket_name}, Key: {object_key}"
                    )

                    if not is_xml_file(object_key):
                        logger.info("📝 File is NOT an XML. Ignoring.")
                        continue  # Skip non-XML files

                    # Stream the object while searching for <docId>
                    doc_id, file_data = stream_s3_object(bucket_name, object_key)
                    if not doc_id:
                        logger.warning("⚠️ No <docId> found, skipping file.")
                        continue  # Skip if no docId found

                    # Rename and move file
                    new_key = f"{doc_id}.xml"
                    upload_s3_object(bucket_name, new_key, file_data)
                    delete_s3_object(bucket_name, object_key)

                else:
                    logger.warning(
                        f"⚠️ Incomplete S3 event data: {json.dumps(s3_record, indent=2)}"
                    )

        except json.JSONDecodeError as e:
            logger.error(f"❌ Failed to decode JSON: {e}")
        except Exception as e:
            logger.error(f"❌ Error processing individual record: {e}")
    elapsed_time = time.time() - start_time
    logger.info(f"⏳ Execution Time: {elapsed_time:.2f} seconds")
    return {"statusCode": 200, "body": "S3 event processed"}
