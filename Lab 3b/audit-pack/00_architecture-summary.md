# Lab 3B — Architecture Summary
## APPI-Compliant Cross-Region Medical Architecture

**Generated:** See evidence.json for timestamp  
**Account ID:** 200819971986  
**Lab:** Japan Medical — Lab 3A/3B  

---

## Architecture Overview

This system serves a global medical application while complying with Japan's
Act on the Protection of Personal Information (APPI / 個人情報保護法).

```
Internet Users (global)
        |
        v
CloudFront (E1MQONXZ6LPX94) — single global distribution
  - WAF attached (CLOUDFRONT scope, us-east-1)
  - Origin cloaking (X-Shinjuku-Growl secret header)
  - TLS termination at edge
  - Cache-Control respected (no PHI cached)
        |
        +---> Tokyo ALB (ap-northeast-1)  [primary origin]
        |           |
        |           v
        |     Tokyo EC2 (shinjuku-final-ec201)
        |           |
        |           v
        |     Tokyo RDS MySQL (shinjuku-final-rds01)  <-- PHI LIVES HERE ONLY
        |
        +---> Sao Paulo ALB (sa-east-1)  [secondary origin]
                    |
                    v
              SP EC2 (liberdale-final-ec201)  [stateless compute]
                    |
                    v
              Transit Gateway (tgw-055c4115682138ae5)
                    |
              [TGW Peering — AWS private backbone]
                    |
              Transit Gateway (tgw-0372e6a6b4b4da24b)
                    |
                    v
              Tokyo RDS MySQL  <-- same DB, cross-region via TGW
```

---

## Regional Roles

| Region | Role | Contains PHI? |
|---|---|---|
| ap-northeast-1 (Tokyo) | Data authority | YES — RDS only here |
| sa-east-1 (Sao Paulo) | Stateless compute | NO — reads/writes via TGW |

---

## APPI Compliance Posture

### Core Principle
**Global access does not equal global storage.**

Japanese patient medical records (PHI) are stored exclusively in
`ap-northeast-1` (Tokyo). This satisfies the most conservative interpretation
of APPI, which requires that personal medical data be stored physically within
Japan even when accessed from abroad.

### What Is Allowed
- CloudFront serving requests from global edge locations (no PHI stored)
- Sao Paulo EC2 reading/writing to Tokyo RDS via Transit Gateway
- Credentials in Parameter Store (not PHI — tightly controlled)

### What Is Not Allowed (and enforced)
- RDS outside `ap-northeast-1` — enforced by architecture
- Cross-region replicas or Aurora Global Database — not deployed
- CloudFront caching PHI — Cache-Control: private, no-store on all PHI endpoints
- Direct ALB access — blocked via origin cloaking (secret header)

---

## Key Resource Identifiers

| Resource | ID / Value |
|---|---|
| CloudFront Distribution | E1MQONXZ6LPX94 |
| CloudFront Domain | d3soab3h6migp9.cloudfront.net |
| Tokyo TGW | tgw-0372e6a6b4b4da24b |
| Sao Paulo TGW | tgw-055c4115682138ae5 |
| TGW Peering Attachment | tgw-attach-001ca2046d97cf069 |
| Tokyo VPC | vpc-0b9de40ee844fa645 (10.100.0.0/16) |
| Sao Paulo VPC | vpc-0c90d6182b218c5ae (10.200.0.0/16) |
| Tokyo RDS Endpoint | shinjuku-final-rds01.cf2s8kkgau9w.ap-northeast-1.rds.amazonaws.com |
| Global URL | https://firstpointand.click |

---

## Six Audit Evidence Points

| # | Evidence Type | File | Status |
|---|---|---|---|
| 1 | Data Residency | 01_data-residency-proof.txt | See file |
| 2 | Edge Security | 02_edge-proof-cloudfront.txt | See file |
| 3 | WAF Security | 03_waf-proof.txt | See file |
| 4 | Change Trail | 04_cloudtrail-change-proof.txt | See file |
| 5 | Network Corridor | 05_network-corridor-proof.txt | See file |
| 6 | Machine Evidence | evidence.json | See file |
