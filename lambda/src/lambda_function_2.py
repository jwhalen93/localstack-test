import boto3
import xml.etree.ElementTree as ET
import requests

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
        content = response['Body'].read()
        
        # Parse the XML content
        root = ET.fromstring(content)
        
        # Find all 'nc:DocumentIdentification' elements and extract the corresponding 'nc:IdentificationID'
        document_identifications = root.findall('.//nc:DocumentIdentification', namespaces={'nc': 'http://www.example.com/namespace'})
        
        if not document_identifications:
            return {
                'statusCode': 500,
                'body': f'Error: No nc:DocumentIdentification found'
            }
        
        extracted_data = []
        for doc_id in document_identifications:
            identification_ids = doc_id.findall('.//nc:IdentificationID', namespaces={'nc': 'http://www.example.com/namespace'})
            for ident_id in identification_ids:
                extracted_data.append({
                    'documentId': ident_id.text.strip(),
                    'xmlData': ET.tostring(doc_id, encoding='unicode')
                })
        
        # Define the target URL and payload
        url = 'https://example.com/external/xml'
        
        if not extracted_data:
            return {
                'statusCode': 500,
                'body': f'Error: No nc:IdentificationID found under nc:DocumentIdentification'
            }
        
        for data in extracted_data:
            payload = {
                "documentId": data['documentId'],
                "xmlData": data['xmlData']
            }
            
            # Make a POST request to the external endpoint
            response = requests.post(url, json=payload)
            
            if response.status_code != 200:
                return {
                    'statusCode': response.status_code,
                    'body': f'Error posting XML data. Status code: {response.status_code}, Message: {response.text}'
                }
        
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