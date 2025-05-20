import boto3
from PIL import Image
import io
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    print("Evento recibido:", event)

    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    response = s3.get_object(Bucket=bucket, Key=key)
    image_content = response['Body'].read()
    
    image = Image.open(io.BytesIO(image_content))
    image = image.resize((128, 128))

    buffer = io.BytesIO()
    image.save(buffer, 'JPEG')
    buffer.seek(0)

    processed_bucket = os.environ.get("PROCESSED_BUCKET", "my-image-processed-marcelo")
    
    s3.put_object(Bucket=processed_bucket, Key=key, Body=buffer, ContentType='image/jpeg')

    return {
        'statusCode': 200,
        'body': f'Imagen {key} procesada y subida al bucket {processed_bucket}'
    }
