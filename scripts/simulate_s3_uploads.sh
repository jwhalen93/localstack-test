#!/bin/bash

set -e  # Exit immediately on error

# Define S3 bucket and folder
BUCKET_NAME="local-bucket"
PREFIX="migrate/"
NUM_FILES=100  # Number of files to upload

echo "📤 Simulating upload of $NUM_FILES documents to S3..."

# Create random document files
for i in $(seq 1 $NUM_FILES); do
    FILE_NAME="document_$i.txt"
    FILE_PATH="./$FILE_NAME"
    
    # Generate random content for the file
    echo "This is document number $i" > $FILE_PATH
    
    # Upload to S3
    echo "📄 Uploading $FILE_NAME to s3://$BUCKET_NAME/$PREFIX$FILE_NAME"
    awslocal s3 cp $FILE_PATH s3://$BUCKET_NAME/$PREFIX$FILE_NAME
    
    # Clean up the generated file locally
    rm -f $FILE_PATH
done

echo "✅ Successfully uploaded $NUM_FILES files to S3!"
