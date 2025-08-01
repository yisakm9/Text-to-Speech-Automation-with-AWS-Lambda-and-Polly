provider "aws" {
  region = "ap-south-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Buckets
resource "aws_s3_bucket" "notes" {
  bucket = "voicevault-notes-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "audio" {
  bucket = "voicevault-audio-${random_id.suffix.hex}"
}

# Lambda Role
resource "aws_iam_role" "lambda_role" {
  name = "voicevault-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["polly:SynthesizeSpeech"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["logs:*"],
        Resource = "*"
      }
    ]
  })
}

# Package Lambda locally: zip lambda_function.py into lambda_function.zip

resource "aws_lambda_function" "voicevault" {
  function_name    = "voicevault-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  filename         = "lambda/lambda_function.zip"
  source_code_hash = filebase64sha256("lambda/lambda_function.zip")

  environment {
    variables = {
      AUDIO_BUCKET = aws_s3_bucket.audio.bucket
    }
  }
}

# Trigger Lambda when a file is uploaded to notes bucket
resource "aws_s3_bucket_notification" "notes_notification" {
  bucket = aws_s3_bucket.notes.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.voicevault.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_function.voicevault,
    aws_lambda_permission.allow_s3
  ]
}

# Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.voicevault.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.notes.arn
}

# API Gateway to trigger Lambda (optional extra)
resource "aws_apigatewayv2_api" "api" {
  name          = "voicevault-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.voicevault.arn
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /generate"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.voicevault.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
output "notes_bucket" {
  value = aws_s3_bucket.notes.bucket
}

output "audio_bucket" {
  value = aws_s3_bucket.audio.bucket
}

output "api_endpoint" {
  value = "${aws_apigatewayv2_api.api.api_endpoint}/generate"
}
