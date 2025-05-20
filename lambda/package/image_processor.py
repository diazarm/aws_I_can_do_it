import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    print("Evento recibido:", event)

    # Datos del evento
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    # Descargar la imagen original
    response = s3.get_object(Bucket=bucket, Key=key)
    image_content = response['Body'].read()

    # Nombre del bucket destino
    processed_bucket = os.environ.get("PROCESSED_BUCKET", "my-image-processed-marcelo")

    # Nuevo nombre para la imagen procesada
    file_name = key.split("/")[-1]  # solo el nombre, sin carpeta
    new_key = f"processed_{file_name}"

    # Subir la imagen con el nuevo nombre al bucket destino
    s3.put_object(
        Bucket=processed_bucket,
        Key=new_key,
        Body=image_content,
        ContentType=response['ContentType']
    )

    return {
        'statusCode': 200,
        'body': f'Imagen {key} procesada como {new_key} y guardada en {processed_bucket}'
    }
