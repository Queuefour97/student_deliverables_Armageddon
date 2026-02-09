# Explanation: DNS now points to CloudFront — nobody should ever see the ALB again.
resource "aws_route53_record" "chewbacca_apex_to_cf02" {
  zone_id = data.aws_route53_zone.armageddon_existing_zone01.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.armageddon_cf01.domain_name
    zone_id                = aws_cloudfront_distribution.armageddon_cf01.hosted_zone_id
    evaluate_target_health = false
  }
}

# Explanation: app.chewbacca-growl.com also points to CloudFront — same doorway, different sign.
resource "aws_route53_record" "chewbacca_app_to_cf02" {
  zone_id = data.aws_route53_zone.armageddon_existing_zone01.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.armageddon_cf01.domain_name
    zone_id                = aws_cloudfront_distribution.armageddon_cf01.hosted_zone_id
    evaluate_target_health = false
  }
}