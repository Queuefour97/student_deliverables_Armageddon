############################################
# Bonus B - Route53 (Hosted Zone + DNS records + ACM validation + ALIAS to ALB)
############################################

# locals consolidated into sao_paulo_main.tf

############################################
# Hosted Zone (optional creation)
############################################

# Explanation: A hosted zone is like claiming Kashyyyk in DNS—names here become law across the galaxy.
resource "aws_route53_zone" "liberdale_zone01" {
  count = var.manage_route53_in_terraform ? 1 : 0

  name = var.domain_name

  tags = {
    Name = "${var.project_name}-zone01"
  }
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "liberdale_existing_zone01" {
  zone_id = var.route53_hosted_zone_id
}

############################################
# ACM DNS Validation Records
############################################

# Explanation: ACM asks “prove you own this planet”—DNS validation is Chewbacca roaring in the right place.
resource "aws_route53_record" "liberdale_acm_validation_records01" {
  for_each = var.certificate_validation_method == "DNS" ? {
    for dvo in aws_acm_certificate.liberdale_acm_cert01.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}


  allow_overwrite = true
  zone_id         = var.route53_hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 6

  records = [each.value.record]
}

# Explanation: This ties the “proof record” back to ACM—armageddon gets his green checkmark for TLS.
resource "aws_acm_certificate_validation" "liberdale_acm_validation01_dns_bonus" {
  count = var.certificate_validation_method == "DNS" ? 1 : 0

  certificate_arn = aws_acm_certificate.liberdale_acm_cert01.arn

  validation_record_fqdns = [
    for r in aws_route53_record.liberdale_acm_validation_records01 : r.fqdn
  ]
}