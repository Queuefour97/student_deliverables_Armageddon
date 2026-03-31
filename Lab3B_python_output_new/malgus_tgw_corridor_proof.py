#!/usr/bin/env python3
import boto3, json
from datetime import datetime, timezone

# Reason why Darth Malgus would be pleased with this script.
# Corridors must be explicit. Malgus hates "it should route" — he wants "it DOES route."
# Reason why this script is relevant to your career.
# Networking evidence is critical for audits and incident response in multi-region enterprises.
# How you would talk about this script at an interview.
# "I built a TGW evidence collector to prove cross-region paths and attachments during audits and outages."

# ── Locked values ──────────────────────────────────────────────────────────────
ACCOUNT_ID    = "200819971986"
TOKYO_VPC     = "vpc-024031655a0d072ea"
SP_VPC        = "vpc-0cf65b224e99213e3"
TOKYO_CIDR    = "10.100.0.0/16"
SP_CIDR       = "10.200.0.0/16"
OUTPUT_FILE   = "audit-pack/05_network-corridor-proof.txt"
EVIDENCE_FILE = "audit-pack/evidence.json"

def tgw_snapshot(region):
    ec2  = boto3.client("ec2", region_name=region)
    tgws = ec2.describe_transit_gateways().get("TransitGateways", [])
    atts = ec2.describe_transit_gateway_attachments().get("TransitGatewayAttachments", [])
    return {"region": region, "transit_gateways": tgws, "attachments": atts}

def check_routes(region, vpc_id, dest_cidr):
    ec2  = boto3.client("ec2", region_name=region)
    resp = ec2.describe_route_tables(Filters=[{"Name": "vpc-id", "Values": [vpc_id]}])
    found = []
    for rt in resp.get("RouteTables", []):
        for route in rt.get("Routes", []):
            if route.get("DestinationCidrBlock") == dest_cidr:
                found.append({
                    "RouteTableId":    rt["RouteTableId"],
                    "DestinationCidr": route.get("DestinationCidrBlock"),
                    "TransitGatewayId": route.get("TransitGatewayId", "N/A"),
                    "State":           route.get("State"),
                })
    return found

def main():
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{ts}] Running malgus_tgw_corridor_proof.py ...")

    tokyo  = tgw_snapshot("ap-northeast-1")
    sp     = tgw_snapshot("sa-east-1")

    tokyo_routes = check_routes("ap-northeast-1", TOKYO_VPC, SP_CIDR)
    sp_routes    = check_routes("sa-east-1",      SP_VPC,    TOKYO_CIDR)

    result = {
        "tokyo":        tokyo,
        "saopaulo":     sp,
        "tokyo_routes_to_sp":    tokyo_routes,
        "sp_routes_to_tokyo":    sp_routes,
    }
    print(json.dumps(result, indent=2, default=str))

    # ── Write proof file ───────────────────────────────────────────────────────
    SEP   = "=" * 70
    tokyo_tgw_ids = [t.get("TransitGatewayId") for t in tokyo["transit_gateways"]]
    sp_tgw_ids    = [t.get("TransitGatewayId") for t in sp["transit_gateways"]]
    tokyo_att_ids = [(a.get("TransitGatewayAttachmentId"), a.get("State"))
                     for a in tokyo["attachments"]]
    sp_att_ids    = [(a.get("TransitGatewayAttachmentId"), a.get("State"))
                     for a in sp["attachments"]]

    lines = [
        SEP,
        "LAB 3B — NETWORK CORRIDOR PROOF (LIVE OUTPUT)",
        f"Generated : {ts}",
        f"Account   : {ACCOUNT_ID}",
        SEP, "",
        "[ TRANSIT GATEWAYS ]",
        f"  Tokyo TGWs    : {tokyo_tgw_ids}",
        f"  SP TGWs       : {sp_tgw_ids}", "",
        "[ ATTACHMENTS ]",
        f"  Tokyo         : {tokyo_att_ids}",
        f"  SP            : {sp_att_ids}", "",
        f"[ ROUTES: Tokyo -> SP CIDR {SP_CIDR} ]",
    ]
    if tokyo_routes:
        for r in tokyo_routes:
            lines.append(f"  {r['RouteTableId']} : {r['DestinationCidr']} -> {r['TransitGatewayId']} ({r['State']})")
        lines.append("  RESULT: PASS")
    else:
        lines.append(f"  RESULT: FAIL — no route for {SP_CIDR} found in Tokyo VPC")

    lines.append("")
    lines.append(f"[ ROUTES: SP -> Tokyo CIDR {TOKYO_CIDR} ]")
    if sp_routes:
        for r in sp_routes:
            lines.append(f"  {r['RouteTableId']} : {r['DestinationCidr']} -> {r['TransitGatewayId']} ({r['State']})")
        lines.append("  RESULT: PASS")
    else:
        lines.append(f"  RESULT: FAIL — no route for {TOKYO_CIDR} found in SP VPC")

    lines += ["", SEP,
              "  Corridor type : AWS private backbone (no public internet)",
              "  PHI path      : SP EC2 -> TGW peering -> Tokyo RDS (private IPs only)",
              SEP]

    with open(OUTPUT_FILE, "w") as f:
        f.write("\n".join(lines))
    print(f"\n[OK] Written to {OUTPUT_FILE}")

    # ── Update evidence.json ───────────────────────────────────────────────────
    try:
        with open(EVIDENCE_FILE, "r") as f:
            evidence = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        evidence = {}

    evidence["network_corridor"] = {
        "timestamp":          ts,
        "passed":             bool(tokyo_routes and sp_routes),
        "tokyo_routes_to_sp": tokyo_routes,
        "sp_routes_to_tokyo": sp_routes,
    }
    with open(EVIDENCE_FILE, "w") as f:
        json.dump(evidence, f, indent=2, default=str)
    print(f"[OK] evidence.json updated")

if __name__ == "__main__":
    main()
