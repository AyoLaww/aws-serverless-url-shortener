locals {
  create_link_name = "${var.project}-create-link"
  redirect_name    = "${var.project}-redirect"

  common_env = {
    TABLE_NAME    = aws_dynamodb_table.links.name
    LINK_TTL_DAYS = tostring(var.link_ttl_days)
  }
}

# Package everything in api/ into one zip, shared by both functions
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../api"
  output_path = "${path.module}/build/lambda.zip"
  excludes    = ["__pycache__", "*.pyc"]
}

# Created explicitly so retention is controlled (Lambda would otherwise
# create log groups that never expire)
resource "aws_cloudwatch_log_group" "create_link" {
  name              = "/aws/lambda/${local.create_link_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "redirect" {
  name              = "/aws/lambda/${local.redirect_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "create_link" {
  function_name = local.create_link_name
  role          = aws_iam_role.create_link.arn
  runtime       = "python3.13"
  architectures = ["arm64"]
  handler       = "create_link.handler"
  memory_size   = 128
  timeout       = 5

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = merge(
      local.common_env,
      { BASE_URL = "https://${aws_cloudfront_distribution.site.domain_name}" }
    )
  }

  depends_on = [
    aws_cloudwatch_log_group.create_link,
    aws_iam_role_policy.create_link,
  ]
}

resource "aws_lambda_function" "redirect" {
  function_name = local.redirect_name
  role          = aws_iam_role.redirect.arn
  runtime       = "python3.13"
  architectures = ["arm64"]
  handler       = "redirect.handler"
  memory_size   = 128
  timeout       = 5

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = local.common_env
  }

  depends_on = [
    aws_cloudwatch_log_group.redirect,
    aws_iam_role_policy.redirect,
  ]
}