# ############################################
# # Bonus B - Route53 Zone Apex + ALB Access Logs to S3
# ############################################
#
# add to grant S3 log delivery permissions
data "aws_elb_service_account" "main" {}

# ############################################
# # Route53: Zone Apex (root domain) -> ALB
# ############################################

# Explanation: The zone apex is the throne room—armageddon-growl.com itself should lead to the ALB.
# resource "aws_route53_record" "armageddon_apex_alias01" {
#   zone_id = "Z0577510JJCMGIYZ7086"    # local.armageddon_zone_id
#   name    = local.armageddon_app_fqdn #var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_lb.armageddon_alb01.dns_name
#     zone_id                = aws_lb.armageddon_alb01.zone_id
#     evaluate_target_health = true
#   }
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_route53_record" "root_domain_name_alias01" {
#   zone_id = "Z0577510JJCMGIYZ7086" # local.armageddon_zone_id
#   name    = var.domain_name        #var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_lb.armageddon_alb01.dns_name
#     zone_id                = aws_lb.armageddon_alb01.zone_id
#     evaluate_target_health = true
#   }
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# ############################################
# # S3 bucket for ALB access logs
# ############################################

# Explanation: This bucket is armageddon’s log vault—every visitor to the ALB leaves footprints here.
resource "aws_s3_bucket" "armageddon_alb_logs_bucket01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = "${var.project_name}-alb-logs-${data.aws_caller_identity.armageddon_self01.account_id}"

  force_destroy = true

  tags = {
    Name = "${var.project_name}-alb-logs-bucket01"
  }
}

# Explanation: Block public access—armageddon does not publish the ship’s black box to the galaxy.
resource "aws_s3_bucket_public_access_block" "armageddon_alb_logs_pab01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.armageddon_alb_logs_bucket01[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: Bucket ownership controls prevent log delivery chaos—armageddon likes clean chain-of-custody.
resource "aws_s3_bucket_ownership_controls" "armageddon_alb_logs_owner01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.armageddon_alb_logs_bucket01[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Explanation: TLS-only—armageddon growls at plaintext and throws it out an airlock.
resource "aws_s3_bucket_policy" "armageddon_alb_logs_policy01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.armageddon_alb_logs_bucket01[0].id

  # NOTE: This is a skeleton. Students may need to adjust for region/account specifics.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.armageddon_alb_logs_bucket01[0].arn,
          "${aws_s3_bucket.armageddon_alb_logs_bucket01[0].arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid = "AllowELBWriteLogs"
        #Sid    = "AllowELBPutObject"
        Effect = "Allow"
        #Principal = {
        #Service = "elasticloadbalancing.amazonaws.com"
        #}
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.armageddon_alb_logs_bucket01[0].arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.armageddon_self01.account_id}/*"
      }
    ]
  })
}

############################################
# Enable ALB access logs (on the ALB resource)
############################################

# Explanation: Turn on access logs—armageddon wants receipts when something goes wrong.
# NOTE: This is a skeleton patch: students must merge this into aws_lb.armageddon_alb01
# by adding/accessing the `access_logs` block. Terraform does not support "partial" blocks.
#
# NOTE: ***Added resource on 01/31/2026, inside aws_lb.armageddon_alb01 in bonus_b.tf
#
# Add this inside resource "aws_lb" "armageddon_alb01" { ... } in bonus_b.tf:
#
# access_logs {
#   bucket  = aws_s3_bucket.armageddon_alb_logs_bucket01[0].bucket
#   prefix  = var.alb_access_logs_prefix
#   enabled = var.enable_alb_access_logs
# }