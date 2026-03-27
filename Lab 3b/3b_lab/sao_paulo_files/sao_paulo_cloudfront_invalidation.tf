############################################
# lab3a_cloudfront_invalidation.tf
# São Paulo — READ THIS BEFORE ASKING WHY IT'S EMPTY
#
# ─────────────────────────────────────────────────
# WHY SÃO PAULO DOES NOT OWN A CLOUDFRONT DISTRIBUTION
# ─────────────────────────────────────────────────
# There is ONE CloudFront distribution in this
# architecture. It is declared in Tokyo's bonus_b.tf
# as aws_cloudfront_distribution.shinjuku_cf01.
#
# CloudFront is a GLOBAL service. A single
# distribution serves ALL regions. São Paulo EC2
# is one of the origins behind it — not the owner.
#
# Architecture recap:
#
#   https://firstpointand.click
#          ↓
#   CloudFront (global, owned by Tokyo TF state)
#          ↓  routes to nearest healthy origin
#   ┌──────────────┬──────────────────┐
#   │  Tokyo EC2   │  São Paulo EC2   │
#   │  (origin 1)  │  (origin 2)      │
#   └──────────────┴──────────────────┘
#
# Invalidations operate on the distribution, not
# on the origin. Running an invalidation flushes
# the edge cache globally — it does not matter
# which origin served the content.
#
# ─────────────────────────────────────────────────
# WHERE INVALIDATIONS ARE MANAGED
# ─────────────────────────────────────────────────
# → tokyo/lab3a_cloudfront_invalidation.tf
#
# That file contains:
#   - The null_resource break-glass trigger
#   - The full CLI runbook
#   - The invalidation budget policy
#   - The four operational rules
#
# ─────────────────────────────────────────────────
# WHAT SÃO PAULO IS RESPONSIBLE FOR INSTEAD
# ─────────────────────────────────────────────────
# São Paulo EC2 must set correct Cache-Control
# headers on responses so CloudFront knows what
# it is and is not allowed to cache:
#
#   /static/*          → Cache-Control: public, max-age=31536000, immutable
#                        (versioned assets only — hashed filenames)
#
#   /static/index.html → Cache-Control: no-cache, must-revalidate
#                        (entrypoint — never immutable, always revalidated)
#
#   /api/list          → Cache-Control: private, no-store
#                        (PHI — CloudFront must NEVER cache this)
#
#   /api/public-feed   → Cache-Control: public, s-maxage=30, max-age=0
#                        (safe public data — CloudFront caches for 30s)
#
# These headers are set in app.py (user_data.sh)
# and are the same in both regions.
#
# Correct headers here = fewer invalidations needed.
# Fewer invalidations = lower operational cost.
# Lower cost = your manager likes you.
############################################

# No Terraform resources in this file.
# See tokyo/lab3a_cloudfront_invalidation.tf for all invalidation logic.
