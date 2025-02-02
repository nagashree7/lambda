provider "aws" {
  region = "us-east-1"
}

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

resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "my-lambda-code-bucket-1234"
  force_destroy = true
}


resource "aws_lambda_function" "my_lambda" {
  function_name = "MyLambdaFunction"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = "lambda_function.zip"
  runtime       = "python3.8"
  handler       = "index.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
}

