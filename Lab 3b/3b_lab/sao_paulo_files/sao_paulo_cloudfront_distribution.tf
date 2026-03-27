############################################
# sao_paulo_cloudfront_distribution.tf
#
# Sao Paulo does NOT own a CloudFront distribution.
# There is ONE global CloudFront distribution in this
# architecture, declared in tokyo/tokyo_cloudfront_distribution.tf
# as aws_cloudfront_distribution.shinjuku_cf01.
#
# Sao Paulo EC2/ALB is an ORIGIN behind that distribution.
# The cache policies defined in sao_paulo_cloudfront_cache_policies.tf
# ARE active - they are used by behaviors on the Tokyo distribution.
#
# The distribution resource and the orphaned variable block below
# are fully commented out to prevent init/plan errors.
############################################

# resource "aws_cloudfront_distribution" "liberdale_cf01" {
#   enabled         = true
#   is_ipv6_enabled = true
#   comment         = "${var.project_name}-cf01"
#
#   origin {
#     origin_id   = "${var.project_name}-alb-origin01"
#     domain_name = aws_lb.liberdale_alb01.dns_name
#
#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "http-only"
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }
#
#     custom_header {
#       name  = "X-liberdale-Growl"
#       value = random_password.liberdale_origin_header_value01.result
#     }
#   }
#
#   default_cache_behavior {
#     target_origin_id       = "${var.project_name}-alb-origin01"
#     viewer_protocol_policy = "redirect-to-https"
#     allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
#     cached_methods         = ["GET", "HEAD"]
#     min_ttl                = 0
#     default_ttl            = 0
#     max_ttl                = 0
#     cache_policy_id          = aws_cloudfront_cache_policy.liberdale_cache_api_disabled01.id
#     origin_request_policy_id = aws_cloudfront_origin_request_policy.liberdale_orp_api01.id
#   }
#
#   ordered_cache_behavior {
#     path_pattern               = "/static/*"
#     target_origin_id           = "${var.project_name}-alb-origin01"
#     viewer_protocol_policy     = "redirect-to-https"
#     allowed_methods            = ["GET", "HEAD", "OPTIONS"]
#     cached_methods             = ["GET", "HEAD"]
#     cache_policy_id            = aws_cloudfront_cache_policy.liberdale_cache_static01.id
#     origin_request_policy_id   = aws_cloudfront_origin_request_policy.liberdale_orp_static01.id
#     response_headers_policy_id = aws_cloudfront_response_headers_policy.liberdale_rsp_static01.id
#   }
#
#   web_acl_id = aws_wafv2_web_acl.liberdale_cf_waf01.arn
#
#   aliases = [
#     var.domain_name,
#     "${var.app_subdomain}.${var.domain_name}"
#   ]
#
#   viewer_certificate {
#     acm_certificate_arn      = aws_acm_certificate.liberdale_cf_cert01.arn
#     ssl_support_method       = "sni-only"
#     minimum_protocol_version = "TLSv1.2_2021"
#   }
#
#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
# }

# variable "cloudfront_acm_cert_arn" {
#   description = "ACM certificate ARN in us-east-1 for CloudFront."
#   type        = string
#   default     = "arn:aws:cloudfront::975598471165:distribution/E18ZG1CDXH524N"
# }
