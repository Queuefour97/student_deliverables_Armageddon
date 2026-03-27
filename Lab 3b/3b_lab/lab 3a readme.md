# Lab 3A — Cross-Region Medical Architecture
## Tokyo (ap-northeast-1) + Sao Paulo (sa-east-1) | APPI-Compliant

---

## Quick Reference

| Item | Value |
|---|---|
| Global URL | `https://firstpointand.click` |
| Tokyo VPC CIDR | `10.100.0.0/16` |
| Sao Paulo VPC CIDR | `10.200.0.0/16` |
| Tokyo TGW ASN | `64512` |
| Sao Paulo TGW ASN | `64513` |
| CloudFront Distribution ID | `E245PRDE0X0ZBS` |
| CloudFront Domain Name | `d3ccuk0gv0dfex.cloudfront.net` |

> **Note:** TGW IDs, RDS endpoint, VPC IDs, EC2 instance IDs, and ALB DNS names
> will change every time you tear down and redeploy. Always run `terraform output`
> after each apply and use those fresh values in all commands below.

---

## How to Start Lab 3A (Deploy Order)

Run every step in this exact order. Each step produces values the next step needs.

### Step 1 — Sao Paulo: TGW only

```bash
cd saopaulo/
terraform init
terraform apply -target=aws_ec2_transit_gateway.liberdale_tgw01
```

Copy from outputs:
```
saopaulo_tgw_id = "tgw-xxxxxxxxxxxxxxxxx"
```

---

### Step 2a — Tokyo: Full apply

```bash
cd tokyo/
terraform init
terraform apply -var="saopaulo_tgw_id=<saopaulo_tgw_id from Step 1>"
```

Copy from outputs:
```
tokyo_tgw_peering_attachment_id = "tgw-attach-xxxxxxxxxxxxxxxxx"
shinjuku_rds_endpoint           = "<hostname>.ap-northeast-1.rds.amazonaws.com"
cloudfront_domain_name          = "dXXXXXXXX.cloudfront.net"
tokyo_vpc_cidr                  = "10.100.0.0/16"
tokyo_tgw_id                    = "tgw-xxxxxxxxxxxxxxxxx"
```

> **Important:** Pass `cloudfront_domain_name` (ends in `.cloudfront.net`) to Sao Paulo —
> NOT `cloudfront_distribution_id` (e.g. `E245PRDE0X0ZBS`). These are different outputs.

---

### Step 3 — Sao Paulo: Full apply (accepts TGW peering)

```bash
cd saopaulo/
terraform apply \
  -var="tokyo_tgw_peering_attachment_id=<from Step 2a>" \
  -var="tokyo_rds_endpoint=<shinjuku_rds_endpoint from Step 2a>" \
  -var="tokyo_cloudfront_domain_name=<cloudfront_domain_name from Step 2a>"
```

After this completes, verify in **AWS Console → VPC → Transit Gateway Peering Attachments**
in **both** `ap-northeast-1` and `sa-east-1` — status must show **Available** before Step 2b.

---

### Step 2b — Tokyo: Re-apply to create TGW static route

Only run this after Step 3 is complete and peering shows **Available** in both regions.

```bash
cd tokyo/
terraform apply \
  -var="saopaulo_tgw_id=<saopaulo_tgw_id from Step 1>" \
  -var="tgw_peering_accepted=true"
```

---

## Verification Commands

> Replace all placeholder values with live values from `terraform output`.

---

### 1. Confirm Tokyo Exports Required Outputs

```bash
cd tokyo/
terraform output tokyo_vpc_cidr
terraform output tokyo_tgw_id
terraform output shinjuku_rds_endpoint
```

Expected shape:
```
tokyo_vpc_cidr        = "10.100.0.0/16"
tokyo_tgw_id          = "tgw-xxxxxxxxxxxxxxxxx"
shinjuku_rds_endpoint = "<hostname>.ap-northeast-1.rds.amazonaws.com"
```

---

### 2. Data Residency — RDS Only in Tokyo

RDS must exist in Tokyo:
```bash
aws rds describe-db-instances \
  --region ap-northeast-1 \
  --query "DBInstances[].{DB:DBInstanceIdentifier,AZ:AvailabilityZone,Endpoint:Endpoint.Address}" \
  --output table
```

Must return empty list `[]` in Sao Paulo:
```bash
aws rds describe-db-instances \
  --region sa-east-1 \
  --query "DBInstances[].DBInstanceIdentifier" \
  --output table
```

---

### 3. Network Reachability — nc from Sao Paulo EC2 to Tokyo RDS

#### Step A: SSM into the Sao Paulo EC2 instance

```bash
aws ssm start-session \
  --target <liberdale_ec2_instance_id from saopaulo terraform output> \
  --region sa-east-1
```

#### Step B: Once inside the instance, test port 3306

```bash
nc -vz <shinjuku_rds_endpoint from tokyo terraform output> 3306
```

Expected success output:
```
Connection to <rds-hostname>.ap-northeast-1.rds.amazonaws.com 3306 port [tcp/mysql] succeeded!
```

#### If nc fails — run these diagnostics in order:

**Check 1: Is the route in the SP private route table?**
```bash
aws ec2 describe-route-tables \
  --region sa-east-1 \
  --filters "Name=vpc-id,Values=<liberdale_vpc_id>" \
  --query "RouteTables[].Routes[?DestinationCidrBlock=='10.100.0.0/16']" \
  --output table
```
Must show `State = active` and a `TransitGatewayId`. If empty, Step 2b has not been run
or the SP route resource failed to create.

**Check 2: Is the TGW peering Available in both regions?**
```bash
aws ec2 describe-transit-gateway-peering-attachments \
  --region ap-northeast-1 \
  --query "TransitGatewayPeeringAttachments[].{ID:TransitGatewayAttachmentId,State:State}" \
  --output table

aws ec2 describe-transit-gateway-peering-attachments \
  --region sa-east-1 \
  --query "TransitGatewayPeeringAttachments[].{ID:TransitGatewayAttachmentId,State:State}" \
  --output table
```
Both must show `State = available`. If either shows `pendingAcceptance`, re-run Step 3.

**Check 3: Does the Tokyo RDS SG allow inbound 3306 from 10.200.0.0/16?**
```bash
aws ec2 describe-security-groups \
  --region ap-northeast-1 \
  --filters "Name=group-name,Values=shinjuku-final-rds-sg01" \
  --query "SecurityGroups[].IpPermissions[?FromPort==\`3306\`]" \
  --output json
```
Must include `"CidrIp": "10.200.0.0/16"` in the result. If missing, the
`saopaulo_vpc_cidr` variable was not passed correctly during Tokyo apply.

**Check 4: Verify the EC2 is in the private subnet (not public)**
```bash
aws ec2 describe-instances \
  --region sa-east-1 \
  --instance-ids <liberdale_ec2_instance_id> \
  --query "Reservations[].Instances[].SubnetId" \
  --output text
```
The subnet ID must match one of the `liberdale_private_subnet_ids` from SP outputs.
If the EC2 is in a public subnet the route table for TGW traffic will be different.

---

### 4. App-Level Verification — Write from Sao Paulo, Read from Tokyo

This proves one database serves both regions.

#### Step A: Initialize the DB (only needed once after first deploy)

From inside the Sao Paulo SSM session:
```bash
curl http://localhost/init
```
Expected: `Init OK on Tokyo RDS!`

#### Step B: Write a record from Sao Paulo

```bash
curl -X POST http://localhost/api/records \
  -H "Content-Type: application/json" \
  -d '{"patient_id": "TEST-SP-001", "note": "Written from Sao Paulo EC2"}'
```

Expected response:
```json
{"status": "ok", "patient_id": "TEST-SP-001", "written_by": "sa-east-1", "db": "tokyo-via-tgw"}
```

#### Step C: Read the same record via Tokyo ALB

From your local machine:
```bash
curl "http://<alb_dns_name from tokyo terraform output>/api/records?patient_id=TEST-SP-001"
```

Expected response:
```json
{"records": ["[TEST-SP-001] Written from Sao Paulo EC2"], "served_by": "ap-northeast-1", "db": "tokyo"}
```

The record written in `sa-east-1` appears when read from `ap-northeast-1` — one DB, two regions.

---

### 5. Route Table Verification

#### Tokyo — route to Sao Paulo CIDR

```bash
aws ec2 describe-route-tables \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<shinjuku_vpc_id from tokyo terraform output>" \
  --query "RouteTables[].Routes[?DestinationCidrBlock=='10.200.0.0/16']" \
  --output json
```

Expected:
```json
[{"DestinationCidrBlock": "10.200.0.0/16", "TransitGatewayId": "tgw-xxx", "State": "active"}]
```

#### Sao Paulo — route to Tokyo CIDR

```bash
aws ec2 describe-route-tables \
  --region sa-east-1 \
  --filters "Name=vpc-id,Values=<liberdale_vpc_id from saopaulo terraform output>" \
  --query "RouteTables[].Routes[?DestinationCidrBlock=='10.100.0.0/16']" \
  --output json
```

Expected:
```json
[{"DestinationCidrBlock": "10.100.0.0/16", "TransitGatewayId": "tgw-xxx", "State": "active"}]
```

---

### 6. CloudFront Edge — Confirm Traffic Flows Through CF

```bash
curl -I https://firstpointand.click
```

Look for these headers in the response:
```
x-cache: Hit from cloudfront   (or Miss on first request — this is normal)
via: 1.1 <pop>.cloudfront.net
server: CloudFront
```

---

## Teardown Order

Always destroy Sao Paulo before Tokyo.

### Step 1 — Empty S3 buckets (destroy fails if buckets have objects)

```bash
aws s3 rm s3://liberdade-final-alb-logs-975598471165 --recursive --region sa-east-1
aws s3 rm s3://shinjuku-final-alb-logs-975598471165 --recursive --region ap-northeast-1
```

### Step 2 — Destroy Sao Paulo first

```bash
cd saopaulo/
terraform destroy \
  -var="tokyo_tgw_peering_attachment_id=<live value>" \
  -var="tokyo_rds_endpoint=<live value>" \
  -var="tokyo_cloudfront_domain_name=<live value>"
```

### Step 3 — Destroy Tokyo second

```bash
cd tokyo/
terraform destroy \
  -var="saopaulo_tgw_id=<live value>" \
  -var="tgw_peering_accepted=true"
```

> CloudFront distributions take 10-15 minutes to disable. Do not cancel — let it run.

---

## File Structure

```
lab3/
├── README.md
├── tokyo/                          # ap-northeast-1 — data authority, PHI region
│   ├── tokyo_main.tf
│   ├── tokyo_outputs.tf            # exports: tokyo_vpc_cidr, tokyo_tgw_id, shinjuku_rds_endpoint
│   ├── tokyo_variables.tf
│   ├── tokyo_providers.tf
│   ├── tokyo_tgw.tf                # TGW hub, peering request, static route (guarded by tgw_peering_accepted)
│   ├── tokyo_routes.tf
│   ├── tokyo_rds_sg_saopaulo_rule.tf
│   ├── tokyo_vpc_endpoints.tf
│   ├── tokyo_alb_waf_monitoring.tf
│   ├── tokyo_route53.tf
│   ├── tokyo_alb_logs_s3.tf
│   ├── tokyo_waf_logging.tf
│   ├── tokyo_cloudfront_*.tf       # CloudFront distribution owned here
│   └── user_data.sh                # Flask app — includes /api/records POST and GET
│
└── saopaulo/                       # sa-east-1 — stateless compute, no PHI
    ├── sao_paulo_main.tf
    ├── sao_paulo_outputs.tf
    ├── sao_paulo_variables.tf
    ├── sao_paulo_providers.tf
    ├── sao_paulo_data.tf
    ├── sao_paulo_tgw.tf            # TGW spoke, accepts peering
    ├── sao_paulo_routes.tf
    ├── sao_paulo_vpc_endpoints.tf
    ├── sao_paulo_alb_waf_monitoring.tf
    ├── sao_paulo_route53.tf
    ├── sao_paulo_alb_logs_s3.tf
    ├── sao_paulo_waf_logging.tf
    ├── sao_paulo_cloudfront_*.tf   # SP is a CF origin only — does NOT own the distribution
    └── user_data.sh                # Flask app — includes /api/records POST and GET
```
