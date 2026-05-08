terraform {
  required_version = "~> 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}


# SECTION: DynamoDB table for visitor counts
resource "aws_dynamodb_table" "visitor_count_table" {
  name         = "${var.project_name}-${var.environment}-visitor_count_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "page"
  attribute {
    name = "page"
    type = "S"
  }
}




# SECTION: IAM role and policies for Lambda function
# IAM: trust policy document
# Defines WHO can assume this role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM: permissions policy document for DynamoDB
# Defines WHAT the role can do once assumed.
data "aws_iam_policy_document" "lambda_dynamodb_policy" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:UpdateItem"
    ]

    resources = [aws_dynamodb_table.visitor_count_table.arn]
  }
}

# IAM: the role itself
# Creates the role in AWS with its trust policy.
resource "aws_iam_role" "db_update_lambda_role" {
  name               = "${var.project_name}-${var.environment}-db_update_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# IAM: managed policy attachment for CloudWatch Logs
# AWSLambdaBasicExecutionRole is an AWS-managed policy that grants the three
# log actions a Lambda needs: CreateLogGroup, CreateLogStream, PutLogEvents.
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.db_update_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM: inline policy for DynamoDB
# aws_iam_role_policy creates an INLINE policy — one that lives on this role
# and only this role.
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "${var.project_name}-${var.environment}-lambda_dynamodb_access"
  role   = aws_iam_role.db_update_lambda_role.id
  policy = data.aws_iam_policy_document.lambda_dynamodb_policy.json
}





# SECTION: Lambda function
# Package the Lambda function code
data "archive_file" "db_update_fn" {
  type        = "zip"
  source_file = "${path.module}/../../../lambda/db_update_fn.py"
  output_path = "${path.module}/../../../lambda/db_update_fn.zip"
}

# Lambda function
resource "aws_lambda_function" "db_update_fn" {
  filename      = data.archive_file.db_update_fn.output_path
  function_name = "${var.project_name}-${var.environment}-db_update_fn"
  role          = aws_iam_role.db_update_lambda_role.arn
  handler       = "db_update_fn.lambda_handler" # The handler is the entry point for the Lambda function, in the format "file_name.function_name"
  code_sha256   = data.archive_file.db_update_fn.output_base64sha256
  runtime       = "python3.12"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_count_table.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.db_update_fn]

  tags = {
    Name = "${var.project_name}-${var.environment}-db_update_fn"
  }
}

resource "aws_cloudwatch_log_group" "db_update_fn" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-db_update_fn"
  retention_in_days = 14
}




# SECTION: API Gateway
resource "aws_apigatewayv2_api" "visitor_count_api" {
  name          = "${var.project_name}-${var.environment}-visitor_count_api_http"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = [var.cors_allow_origins]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
    max_age       = 86400
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.visitor_count_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.db_update_fn.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_route" {
  api_id    = aws_apigatewayv2_api.visitor_count_api.id
  route_key = "POST /visitor-count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.visitor_count_api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }
}

resource "aws_ssm_parameter" "api_endpoint" {
  name  = "/${var.project_name}/${var.environment}/visitor-counter/api-endpoint"
  type  = "String"
  value = "${aws_apigatewayv2_api.visitor_count_api.api_endpoint}/visitor-count"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.db_update_fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_count_api.execution_arn}/*/*"
}