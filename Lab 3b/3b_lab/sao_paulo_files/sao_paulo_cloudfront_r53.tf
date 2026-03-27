############################################
# sao_paulo_cloudfront_r53.tf
#
# Route53 records pointing to the TOKYO CloudFront
# distribution (shinjuku_cf01). Sao Paulo does not
# own the CF distribution -- it is a separate state.
#
# Pass tokyo_cloudfront_domain_name from Tokyo outputs:
#   terraform apply \
#     -var="tokyo_cloudfront_domain_name=<value from tokyo output>"
#
# tokyo_cloudfront_hosted_zone_id defaults to Z2FDTNDATAQYW2
# which is the global CloudFront hosted zone ID and never changes.
############################################

# Explanation: DNS apex points to Tokyo CloudFront - the single global distribution.
# count = 0 when tokyo_cloudfront_domain_name is empty (before Tokyo apply).
# Pass the value after Tokyo apply:
#   terraform apply -var="tokyo_cloudfront_domain_name=<Tokyo output: cloudfront_domain_name>"
resource "aws_route53_record" "liberdale_apex_to_cf01" {
  count           = var.tokyo_cloudfront_domain_name != "" ? 1 : 0
  zone_id         = local.liberdale_zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = var.tokyo_cloudfront_domain_name
    zone_id                = var.tokyo_cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# Explanation: app subdomain also points to Tokyo CloudFront.
resource "aws_route53_record" "liberdale_app_to_cf01" {
  count           = var.tokyo_cloudfront_domain_name != "" ? 1 : 0
  zone_id         = local.liberdale_zone_id
  name            = "${var.app_subdomain}.${var.domain_name}"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = var.tokyo_cloudfront_domain_name
    zone_id                = var.tokyo_cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
