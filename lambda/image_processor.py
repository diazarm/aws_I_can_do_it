import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    print("Evento recibido:", event)

    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    response = s3.get_object(Bucket=bucket, Key=key)
    image_content = response['Body'].read()

    processed_bucket = os.environ.get("PROCESSED_BUCKET", "my-image-processed-marcelo")

    new_key = f"processed_{key}"

    s3.put_object(Bucket=processed_bucket, Key=new_key, Body=image_content)

    return {
        'statusCode': 200,
        'body': f'Imagen {key} copiada como {new_key} en {processed_bucket}'
    }
