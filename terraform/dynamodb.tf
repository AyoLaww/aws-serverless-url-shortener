resource "aws_dynamodb_table" "links" {
  name         = "${var.project}-links"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }

  # Expired links are removed automatically, for free
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # Keep teardown simple for a portfolio project
  deletion_protection_enabled = false
}