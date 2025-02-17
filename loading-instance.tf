resource "random_id" "random_static_assets_id" {
  byte_length = 8
}

resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.company_prefix}-static-files-${random_id.random_static_assets_id.hex}"
}

resource "aws_s3_object" "loading_sandbox" {
  bucket = aws_s3_bucket.static_assets.bucket
  key    = "loading_sandbox.html"
  source = "${path.module}/templates/loading_sandbox.html"
  content_type = "text/html"
  etag = filemd5("${path.module}/templates/loading_sandbox.html")
}

resource "aws_s3_bucket_policy" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  policy = jsonencode({
        "Version": "2008-10-17",
        "Id": "PolicyForCloudFrontPrivateContent",
        "Statement": [
            {
                "Sid": "AllowCloudFrontServicePrincipal",
                "Effect": "Allow",
                "Principal": {
                    "Service": "cloudfront.amazonaws.com"
                },
                "Action": "s3:GetObject",
                "Resource": "${aws_s3_bucket.static_assets.arn}/*",
                "Condition": {
                    "StringEquals": {
                      "AWS:SourceArn": aws_cloudfront_distribution.loading_sandbox.arn
                    }
                }
            }
        ]
      })
}

resource "aws_s3_bucket" "cloudfront_access_logs" {
  bucket = "${var.company_prefix}-cf-access-logs-${random_id.random_static_assets_id.hex}"
}


resource "aws_cloudfront_origin_access_control" "loading_sandbox_s3_oac" {
  origin_access_control_origin_type = "s3"
  name                              = "${var.company_prefix}_loading_sandbox_s3_oac"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "loading_sandbox" {
  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.loading_sandbox_s3_oac.id
    origin_id   = "static-assets"
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Loading Sandbox"
  price_class = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "static-assets"

    compress               = true
    viewer_protocol_policy = "allow-all"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  logging_config {
    bucket = aws_s3_bucket.cloudfront_access_logs.bucket_domain_name
    prefix = "${var.company_prefix}/loading_sandbox/"
  }
}

resource "aws_cloudfront_origin_access_control" "static_assets" {
  name                              = "${var.company_prefix}-static-assets-ac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}