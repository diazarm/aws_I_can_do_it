provider "aws" {
  region = "us-east-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "originals" {
  bucket        = "my-image-originals-marcelo-${random_id.suffix.hex}"
  force_destroy = true

  website {
    index_document = "index.html"
  }

  tags = {
    Name = "Original Images Bucket"
  }
  
}

resource "aws_s3_bucket" "processed" {
  bucket        = "my-image-processed-marcelo-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "Processed Images Bucket"
  }
}

resource "aws_iam_role" "lambda_exec_role_us" {
  name = "lambda_exec_role_marcelo_us"

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

resource "aws_iam_role_policy" "lambda_policy_us" {
  name = "lambda_policy_marcelo_us"
  role = aws_iam_role.lambda_exec_role_us.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = [
          "${aws_s3_bucket.originals.arn}/*",
          "${aws_s3_bucket.processed.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [
          aws_s3_bucket.originals.arn,
          aws_s3_bucket.processed.arn
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

resource "aws_lambda_function" "image_processor_us" {
  function_name = "image-processor-marcelo-us"
  role          = aws_iam_role.lambda_exec_role_us.arn
  handler       = "image_processor.lambda_handler"
  runtime       = "python3.9"
  timeout       = 10

  filename         = "${path.module}/../lambda/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/function.zip")

  environment {
    variables = {
      UPLOAD_BUCKET    = aws_s3_bucket.originals.bucket
      PROCESSED_BUCKET = aws_s3_bucket.processed.bucket
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy_us]
}

resource "aws_lambda_permission" "allow_s3_us" {
  statement_id  = "AllowS3InvokeUS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor_us.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.originals.arn
}

resource "aws_s3_bucket_notification" "trigger_lambda_us" {
  bucket = aws_s3_bucket.originals.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor_us.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_us
  ]
}

resource "aws_api_gateway_rest_api" "upload_api" {
  name        = "UploadAPI"
  description = "API Gateway para subir imágenes y activar la Lambda"
}

resource "aws_api_gateway_resource" "upload_resource" {
  rest_api_id = aws_api_gateway_rest_api.upload_api.id
  parent_id   = aws_api_gateway_rest_api.upload_api.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_method" {
  rest_api_id   = aws_api_gateway_rest_api.upload_api.id
  resource_id   = aws_api_gateway_resource.upload_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.upload_api.id
  resource_id             = aws_api_gateway_resource.upload_resource.id
  http_method             = aws_api_gateway_method.upload_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.image_processor_us.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor_us.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.upload_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "upload_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.upload_api.id
  stage_name  = "prod"
}

output "processed_bucket_url" {
  description = "URL base del bucket de imágenes procesadas"
  value       = "https://${aws_s3_bucket.processed.bucket}.s3.amazonaws.com/"
}

output "frontend_bucket_website_url" {
  description = "URL del sitio estático hospedado en el bucket de imágenes originales"
  value       = aws_s3_bucket.originals.website_endpoint
}

output "api_gateway_endpoint" {
  description = "Endpoint de API Gateway para subir imágenes"
  value       = "${aws_api_gateway_deployment.upload_deployment.invoke_url}/upload"
}

resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.upload_api.id
  resource_id   = aws_api_gateway_resource.upload_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.upload_api.id
  resource_id = aws_api_gateway_resource.upload_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.upload_api.id
  resource_id = aws_api_gateway_resource.upload_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.upload_api.id
  resource_id = aws_api_gateway_resource.upload_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,filename'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}
