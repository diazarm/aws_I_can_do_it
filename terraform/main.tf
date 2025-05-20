provider "aws" {
  region = "us-east-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "originals" {
  bucket = "my-image-originals-marcelo-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "Original Images Bucket"
  }
}

resource "aws_s3_bucket" "processed" {
  bucket = "my-image-processed-marcelo-${random_id.suffix.hex}"
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
