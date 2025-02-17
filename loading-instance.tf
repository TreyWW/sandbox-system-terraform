resource "random_id" "random_static_assets_id" {
  byte_length = 8
}

resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.company_prefix}-static-files-${random_id.random_static_assets_id.hex}"
}

resource "aws_s3_object " "loading_sandbox" {
  bucket = aws_s3_bucket.static_assets.bucket
  key    = "loading_sandbox.html"
  source = "${path.module}/templates/loading_sandbox.html"

  etag = filemd5("${path.module}/templates/loading_sandbox.html")
}

resource "aws_cloudfront_distribution" "loading_sandbox" {
  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_domain_name
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

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "static_assets" {
  name                              = "static-assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}