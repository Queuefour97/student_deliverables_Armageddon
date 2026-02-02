############################################
# Bonus B - Route53 (Hosted Zone + DNS records + ACM validation + ALIAS to ALB)
############################################

locals {
  # Explanation: armageddon needs a home planet—Route53 hosted zone is your DNS territory.
  armageddon_zone_name = var.domain_name

  # Explanation: Use either Terraform-managed zone or a pre-existing zone ID (students choose their destiny).
  armageddon_zone_id = var.manage_route53_in_terraform ? aws_route53_zone.armageddon_zone01[0].zone_id : var.route53_hosted_zone_id

  # Explanation: This is the app address that will growl at the galaxy (app.armageddon-growl.com).
  armageddon_app_fqdn = "${var.app_subdomain}.${var.domain_name}"
}

############################################
# Hosted Zone (optional creation)
############################################

# Explanation: A hosted zone is like claiming Kashyyyk in DNS—names here become law across the galaxy.
resource "aws_route53_zone" "armageddon_zone01" {
  count = var.manage_route53_in_terraform ? 1 : 0

  name = var.domain_name

  tags = {
    Name = "${var.project_name}-zone01"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# data "aws_route53_zone" "armageddon_existing_zone01" {



# }

############################################
# ACM DNS Validation Records
############################################

# Explanation: ACM asks “prove you own this planet”—DNS validation is Chewbacca roaring in the right place.
resource "aws_route53_record" "armageddon_acm_validation_records01" {
  for_each = var.certificate_validation_method == "DNS" ? {
    for dvo in aws_acm_certificate.armageddon_acm_cert01.domain_validation_options :
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
resource "aws_acm_certificate_validation" "armageddon_acm_validation01_dns_bonus" {
  count = var.certificate_validation_method == "DNS" ? 1 : 0

  certificate_arn = aws_acm_certificate.armageddon_acm_cert01.arn

  validation_record_fqdns = [
    for r in aws_route53_record.armageddon_acm_validation_records01 : r.fqdn
  ]
}