resource "aws_iam_role" "lambda_ingest_role" {
  name = "lambda-ingest-rawdata-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_ingest_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "ingest_raw_object" {
  function_name = "ingest-raw-object"
  role          = aws_iam_role.lambda_ingest_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"

  filename         = "${path.module}/lambda/ingest_raw_object.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/ingest_raw_object.zip")
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3InvokeIngestLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_raw_object.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_data_bucket.arn
}

resource "aws_s3_bucket_notification" "raw_data_events" {
  bucket = aws_s3_bucket.raw_data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest_raw_object.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke
  ]
}

