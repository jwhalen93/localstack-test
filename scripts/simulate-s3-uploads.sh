#!/bin/bash
set -e

S3_BUCKET="local-bucket"
S3_PREFIX="migrate"
ENDPOINT_URL="http://localhost:4566"

# Function to generate a random XML file
generate_xml() {
  local filename=$1
  cat > "$filename" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<document>
    <docId>$(uuidgen)</docId>
    <content>Sample XML Content</content>
</document>
EOL
}

# Create a temp directory
TMP_DIR=$(mktemp -d)
cd $TMP_DIR

# Generate random files (XML and other types)
for i in {6..20}; do
  generate_xml "file_$i.xml"
done

# Upload all files to S3
for file in *; do
  echo "Uploading $file to S3..."
  awslocal --endpoint-url=$ENDPOINT_URL s3 cp "$file" "s3://$S3_BUCKET/$S3_PREFIX/$file"
done

# Cleanup temp files
cd -
rm -rf $TMP_DIR

echo "File uploads complete!"
