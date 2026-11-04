data "aws_caller_identity" "current" {}

locals {
  site_bucket_name = "${var.project}-site-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  site_origin_id   = "s3-site"
  api_origin_id    = "api-gateway"
}

# ---------- Private S3 bucket ----------
resource "aws_s3_bucket" "site" {
  bucket = local.site_bucket_name

  # Lets `terraform destroy` empty the bucket during teardown
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------- CloudFront ----------
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project}-site-oac"
  description                       = "Lets CloudFront read the private site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS-managed policies, so there is nothing to maintain
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = "${var.project} frontend and API"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  http_version        = "http2and3"
  is_ipv6_enabled     = true

  # Origin 1: the static site
  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = local.site_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # Origin 2: the API
  origin {
    domain_name = replace(aws_apigatewayv2_api.http.api_endpoint, "https://", "")
    origin_id   = local.api_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default: the website
  default_cache_behavior {
    target_origin_id           = local.site_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id
  }

  # POST /links: create a short link
  ordered_cache_behavior {
    path_pattern             = "/links"
    target_origin_id         = local.api_origin_id
    viewer_protocol_policy   = "https-only"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  # GET /<7-character code>: redirect. Not cached, so every click is counted
  ordered_cache_behavior {
    path_pattern             = "/???????"
    target_origin_id         = local.api_origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  # Missing pages and unknown links show the site's own 404 page
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# ---------- Bucket policy: only this distribution may read ----------
data "aws_iam_policy_document" "site" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}