provider "aws" {
  region = "sa-east-1"  # o "us-east-1" si decides cambiar de región
}

resource "aws_s3_bucket" "originals" {
  bucket = "my-image-originals-marcelo"
  force_destroy = true
  tags = {
    Name = "Original Images Bucket"
  }
}

resource "aws_s3_bucket" "processed" {
  bucket = "my-image-processed-marcelo"
  force_destroy = true
  tags = {
    Name = "Processed Images Bucket"
  }
}

# Configuración de la política de permisos para el bucket S3"
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role_marcelo"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Configuración de la política de permisos para la función Lambda"
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy_marcelo"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::my-image-originals-marcelo/*",
          "arn:aws:s3:::my-image-processed-marcelo/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
# Configuración de la función Lambda

resource "aws_lambda_function" "image_processor" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "image_processor.lambda_handler"
  runtime       = "python3.9"
  timeout       = 10

  filename         = "${path.module}/../lambda/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/function.zip")

  environment {
    variables = {
      PROCESSED_BUCKET = "my-image-processed-marcelo"
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

# Configuración de la política de permisos para permitir que S3 invoque la función Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::my-image-originals-marcelo"
}

# Configuración de la notificación del bucket S3 para invocar la función Lambda
resource "aws_s3_bucket_notification" "trigger_lambda" {
  bucket = aws_s3_bucket.originals.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""      # opcional: podés poner "images/"
    filter_suffix       = ".jpg"  # opcional: podés limitar a ".png", ".jpeg", etc.
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}
