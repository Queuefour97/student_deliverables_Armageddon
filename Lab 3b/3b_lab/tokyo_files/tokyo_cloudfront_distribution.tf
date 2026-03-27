# Explanation: CloudFront is the only public doorway — armageddon stands behind it with private infrastructure.
resource "aws_cloudfront_distribution" "shinjuku_cf01" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name}-cf01"

  origin {
    origin_id   = "${var.project_name}-alb-origin01"
    domain_name = aws_lb.shinjuku_alb01.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Explanation: CloudFront whispers the secret growl — the ALB only trusts this.
    custom_header {
      name  = "X-shinjuku-Growl"
      value = random_password.shinjuku_origin_header_value01.result
    }
  }

  # Original default_cache_behavior
  # default_cache_behavior {
  #   target_origin_id       = "${var.project_name}-alb-origin01"
  #   viewer_protocol_policy = "redirect-to-https"

  #   allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
  #   cached_methods  = ["GET", "HEAD"]


  # New default_cache_behavior
  default_cache_behavior {
    target_origin_id       = "${var.project_name}-alb-origin01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    # TODO: students choose cache policy / origin request policy for their app type
    # For APIs, typically forward all headers/cookies/querystrings.
    # Added per lookup 02192026
    # forwarded_values {
    #   query_string = true
    #   headers      = ["*"]
    #   cookies { forward = "all" }
    # }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    cache_policy_id          = aws_cloudfront_cache_policy.shinjuku_cache_api_disabled01.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.shinjuku_orp_api01.id
  }
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "${var.project_name}-alb-origin01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id            = aws_cloudfront_cache_policy.shinjuku_cache_static01.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.shinjuku_orp_static01.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.shinjuku_rsp_static01.id
  }

  #   # TODO: students choose cache policy / origin request policy for their app type
  # #   # For APIs, typically forward all headers/cookies/querystrings.
  #   forwarded_values {
  #     query_string = true
  #     headers      = ["*"]
  #     cookies { forward = "all" }
  #   }
  # }

  # Explanation: Attach WAF at the edge — now WAF moved to CloudFront.
  web_acl_id = aws_wafv2_web_acl.shinjuku_cf_waf01.arn

  # TODO: students set aliases for shinjuku-growl.com and app.shinjuku-growl.com
  aliases = [
    var.domain_name,
    "${var.app_subdomain}.${var.domain_name}"
  ]

  # TODO: students must use ACM cert in us-east-1 for CloudFront


  viewer_certificate {
    # acm_certificate_arn      = var.cloudfront_acm_cert_arn
    # Changed from armageddon to shinjuku-final; if it blows-up replace with "armageddon"
    acm_certificate_arn      = aws_acm_certificate.shinjuku_cf_cert01.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

#You’ll need this variable:
variable "cloudfront_acm_cert_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront (covers shinjuku-growl.com and app.shinjuku-growl.com)."
  type        = string
  default     = "arn:aws:cloudfront::975598471165:distribution/E18ZG1CDXH524N"
}
