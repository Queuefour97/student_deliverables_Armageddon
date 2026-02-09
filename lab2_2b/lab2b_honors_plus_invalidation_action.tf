# ############################################
# # Lab 2B-Honors+ - Optional invalidation action (run on demand)
# ############################################

# # Explanation: This is armageddon’s “break glass” lever — use it sparingly or the bill will bite.
# resource "aws_cloudfront_create_invalidation" "armageddon_invalidate_index01" {
#   distribution_id = aws_cloudfront_distribution.armageddon_cf01.id

#   # TODO: students must pick the smallest path set that fixes the issue.
#   paths = [
#     "/static/index.html"
#   ]
# }

