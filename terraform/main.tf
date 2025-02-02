provider "aws" {
  region = "us-east-1"
}

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# IAM Policy Attachment for Lambda execution
resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 Bucket to store Lambda code
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "my-lambda-code-bucket-1234"
  force_destroy = true
}

# Upload Lambda code to S3
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda_function.zip"
  source = "../lambda/lambda_function.zip"
  etag   = filemd5("../lambda/lambda_function.zip")
  depends_on = [aws_s3_bucket.lambda_bucket]  # Ensures the bucket is created first 
}

# Lambda function definition
resource "aws_lambda_function" "my_lambda" {
  function_name = "MyLambdaFunction"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambda_zip.key
  runtime       = "python3.8"
  handler       = "index.lambda_handler"  # Update to your handler
  role          = aws_iam_role.lambda_role.arn
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "MyAPI"
  description = "API Gateway to trigger Lambda"
}

# Define the /hello resource in API Gateway
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "hello"
}

# Define the GET method for /hello
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integration between API Gateway and Lambda
resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.my_lambda.invoke_arn
}

# Grant API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = aws_lambda_function.my_lambda.function_name
}

# API Gateway Deployment (Removed stage_name)
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
 

  depends_on = [
    aws_api_gateway_integration.integration,  # Ensure integration is created first
    aws_lambda_permission.lambda_permission  # Ensure permission is granted first
  ]
}

# API Gateway Stage (Created separately)
resource "aws_api_gateway_stage" "api_stage" {
  stage_name  = "dev"  # You can name it 'dev', 'prod', etc.
  rest_api_id = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
}