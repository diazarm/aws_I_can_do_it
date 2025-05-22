import boto3
import base64
import os
import json

s3 = boto3.client('s3')

# Buckets
ORIGINAL_BUCKET = os.environ.get("UPLOAD_BUCKET", "my-image-originals-marcelo")
PROCESSED_BUCKET = os.environ.get("PROCESSED_BUCKET", "my-image-processed-marcelo")

def lambda_handler(event, context):
    try:
        print("Evento recibido:", event)

        # ✅ Evento desde S3 (trigger por subida directa al bucket)
        if "Records" in event and "s3" in event["Records"][0]:
            bucket = event["Records"][0]["s3"]["bucket"]["name"]
            key = event["Records"][0]["s3"]["object"]["key"]

            response = s3.get_object(Bucket=bucket, Key=key)
            image_content = response['Body'].read()
            new_key = f"processed_{key}"

            s3.put_object(Bucket=PROCESSED_BUCKET, Key=new_key, Body=image_content)

            return {
                "statusCode": 200,
                "body": json.dumps({"message": f"Imagen {key} copiada como {new_key} en {PROCESSED_BUCKET}"})
            }

        # ✅ Evento desde API Gateway (frontend)
        elif "body" in event:
            file_content = base64.b64decode(event["body"])
            filename = event["headers"].get("filename", "upload.jpg")

            s3.put_object(Bucket=ORIGINAL_BUCKET, Key=filename, Body=file_content)

            return {
                "statusCode": 200,
                "headers": {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Headers": "Content-Type,filename",
                    "Access-Control-Allow-Methods": "OPTIONS,POST"
                },
                "body": json.dumps({
                    "message": f"Archivo {filename} subido exitosamente a {ORIGINAL_BUCKET}"
                })
            }

        else:
            raise ValueError("Formato de evento no reconocido")

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,filename",
                "Access-Control-Allow-Methods": "OPTIONS,POST"
            },
            "body": json.dumps({
                "error": str(e)
            })
        }
