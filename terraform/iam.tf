data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- create_link: may only write new items ---
resource "aws_iam_role" "create_link" {
  name               = "${var.project}-create-link"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "create_link" {
  statement {
    sid       = "WriteLinks"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.links.arn]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.create_link.arn}:*"]
  }
}

resource "aws_iam_role_policy" "create_link" {
  name   = "create-link"
  role   = aws_iam_role.create_link.id
  policy = data.aws_iam_policy_document.create_link.json
}

# --- redirect: may only read items and bump the click counter ---
resource "aws_iam_role" "redirect" {
  name               = "${var.project}-redirect"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "redirect" {
  statement {
    sid       = "ReadAndCountLinks"
    actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.links.arn]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.redirect.arn}:*"]
  }
}

resource "aws_iam_role_policy" "redirect" {
  name   = "redirect"
  role   = aws_iam_role.redirect.id
  policy = data.aws_iam_policy_document.redirect.json
}