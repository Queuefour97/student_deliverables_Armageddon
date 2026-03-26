# Deliverable B — Auditor Narrative
## Why This Architecture Is APPI-Safe and Why the Database Cannot Be Stored Overseas

This system is designed to comply with Japan's Act on the Protection of Personal
Information (APPI / 個人情報保護法) at the architectural level, not merely by policy.
All patient medical records — classified as sensitive personal information (要配慮個人情報)
under APPI — are stored exclusively in AWS region ap-northeast-1 (Tokyo, Japan). This is
enforced by design: the Sao Paulo region (sa-east-1) deploys compute infrastructure only
and contains no database, no read replicas, and no cross-region backups. When doctors in
South America read or write patient records, their requests travel from the Sao Paulo EC2
instance through an AWS Transit Gateway peering connection to the Tokyo RDS instance over
the AWS private backbone — no patient data ever resides outside Japan, even transiently.
CloudFront serves as the global entry point and is explicitly permitted under this design
because it does not store patient data: all PHI endpoints return Cache-Control: private,
no-store, preventing edge caching of any medical records. The WAF layer, attached to the
CloudFront distribution at global scope, provides an additional security perimeter that
blocks known attack patterns before requests reach any compute layer. CloudTrail provides
a 90-day immutable record of every configuration change — who changed what, when, and
from where — satisfying the audit trail requirement. In short: global access is achieved
through network routing, not data replication. The database does not move; only the
application layer reaches across the network to retrieve it.
