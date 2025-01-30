import boto3
import xml.etree.ElementTree as ET
import requests

def extract_document_identifications(root):
    document_identifications = root.findall('.//nc:DocumentIdentification')
    if not document_identifications:
        raise ValueError("No nc:DocumentIdentification found")
    return document_identifications

def process_document_identification(doc_id):
    identification_ids = doc_id.findall('.//nc:IdentificationID')
    if not identification_ids and doc_id.text.strip() == "":
        raise ValueError("No valid document ID found")
    
    extracted_data = []
    if not identification_ids:
        # If no IdentificationID is present, use the text of the DocumentIdentification element
        extracted_data.append({
            'documentId': doc_id.text.strip(),
            'xmlData': ET.tostring(doc_id, encoding='unicode')
        })
    else:
        for ident_id in identification_ids:
            extracted_data.append({
                'documentId': ident_id.text.strip(),
                'xmlData': ET.tostring(doc_id, encoding='unicode')
            })
    
    return extracted_data

def post_document_data(url, data, access_token):
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    response = requests.post(url, json=data, headers=headers)
    if response.status_code != 200:
        raise Exception(f"Error posting XML data. Status code: {response.status_code}, Message: {response.text}")
    return response.json()

def lambda_handler(event, context):
    # Extract S3 bucket name and object key from SNS event
    sns_message = event['Records'][0]['Sns']['Message']
    sns_data = eval(sns_message)
    
    try:
        s3_bucket_name = sns_data['Records'][0]['s3']['bucket']['name']
        s3_object_key = sns_data['Records'][0]['s3']['object']['key']
        
        # Initialize S3 client
        s3_client = boto3.client('s3')
        
        # Download the object from S3 in its entirety
        response = s3_client.get_object(Bucket=s3_bucket_name, Key=s3_object_key)
        content = response['Body'].read().decode('utf-8')  # Decode to string
        
        # Parse the XML content
        root = ET.fromstring(content)
        
        # Extract document identifications
        document_identifications = extract_document_identifications(root)
        
        extracted_data = []
        for doc_id in document_identifications:
            extracted_data.extend(process_document_identification(doc_id))
        
        if not extracted_data:
            return {
                'statusCode': 400,
                'body': f'Error: No valid document ID found'
            }
        
        # Define the target URL and payload
        url = 'https://example.com/external/xml'
        
        for data in extracted_data:
            post_document_data(url, data, access_token="your_access_token_here")
        
        return {
            'statusCode': 200,
            'body': f'Document IDs posted successfully'
        }

    except Exception as e:
        print(f"An error occurred: {e}")
        return {
            'statusCode': 500,
            'body': f'Internal server error: {str(e)}'
        }