#!/usr/bin/env python3
"""
malgus_residency_proof.py
Lab 3B — Data Residency Proof

Proves that:
  - RDS exists in Tokyo (ap-northeast-1)
  - NO RDS exists in Sao Paulo (sa-east-1)

Output: 01_data-residency-proof.txt + contributes to evidence.json
"""

import boto3
import json
import datetime
import sys

# ── Locked values ──────────────────────────────────────────────────────────────
TOKYO_REGION   = "ap-northeast-1"
SP_REGION      = "sa-east-1"
ACCOUNT_ID     = "200819971986"
EXPECTED_RDS   = "shinjuku-final-rds01"
OUTPUT_FILE    = "audit-pack/01_data-residency-proof.txt"
EVIDENCE_FILE  = "audit-pack/evidence.json"

SEPARATOR = "=" * 70

def ts():
    return datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

def check_rds(region):
    client = boto3.client("rds", region_name=region)
    resp   = client.describe_db_instances()
    return resp.get("DBInstances", [])

def format_instance(db, region):
    return {
        "DBInstanceIdentifier": db.get("DBInstanceIdentifier"),
        "DBInstanceStatus":     db.get("DBInstanceStatus"),
        "AvailabilityZone":     db.get("AvailabilityZone"),
        "Region":               region,
        "Endpoint":             db.get("Endpoint", {}).get("Address", "N/A"),
        "MultiAZ":              db.get("MultiAZ"),
        "Engine":               db.get("Engine"),
        "StorageEncrypted":     db.get("StorageEncrypted"),
    }

def run():
    print(f"[{ts()}] Running malgus_residency_proof.py ...")

    lines   = []
    result  = {}
    passed  = True

    lines.append(SEPARATOR)
    lines.append("LAB 3B — DATA RESIDENCY PROOF")
    lines.append(f"Generated : {ts()}")
    lines.append(f"Account   : {ACCOUNT_ID}")
    lines.append(SEPARATOR)
    lines.append("")

    # ── Tokyo ──────────────────────────────────────────────────────────────────
    lines.append("[ CHECK 1 ] RDS instances in Tokyo (ap-northeast-1)")
    lines.append("-" * 50)
    try:
        tokyo_dbs = check_rds(TOKYO_REGION)
        if tokyo_dbs:
            tokyo_formatted = [format_instance(db, TOKYO_REGION) for db in tokyo_dbs]
            for db in tokyo_formatted:
                lines.append(f"  DB Identifier  : {db['DBInstanceIdentifier']}")
                lines.append(f"  Status         : {db['DBInstanceStatus']}")
                lines.append(f"  Availability   : {db['AvailabilityZone']}")
                lines.append(f"  Endpoint       : {db['Endpoint']}")
                lines.append(f"  Engine         : {db['Engine']}")
                lines.append(f"  Encrypted      : {db['StorageEncrypted']}")
                lines.append(f"  Multi-AZ       : {db['MultiAZ']}")
                lines.append("")
            result["tokyo_rds"] = tokyo_formatted
            lines.append(f"  RESULT: PASS — {len(tokyo_dbs)} RDS instance(s) confirmed in ap-northeast-1")
        else:
            lines.append("  RESULT: WARN — No RDS found in Tokyo. Expected shinjuku-final-rds01.")
            result["tokyo_rds"] = []
            passed = False
    except Exception as e:
        lines.append(f"  ERROR: {e}")
        result["tokyo_rds"] = {"error": str(e)}
        passed = False

    lines.append("")

    # ── Sao Paulo ──────────────────────────────────────────────────────────────
    lines.append("[ CHECK 2 ] RDS instances in Sao Paulo (sa-east-1)")
    lines.append("-" * 50)
    try:
        sp_dbs = check_rds(SP_REGION)
        if sp_dbs:
            lines.append(f"  RESULT: FAIL — {len(sp_dbs)} RDS instance(s) found in sa-east-1.")
            lines.append("  APPI VIOLATION: PHI storage outside Japan is not permitted.")
            for db in sp_dbs:
                lines.append(f"    - {db.get('DBInstanceIdentifier')} ({db.get('DBInstanceStatus')})")
            result["saopaulo_rds"] = [format_instance(db, SP_REGION) for db in sp_dbs]
            passed = False
        else:
            lines.append("  Instances found : 0")
            lines.append("  RESULT: PASS — No RDS in sa-east-1. APPI data residency confirmed.")
            result["saopaulo_rds"] = []
    except Exception as e:
        lines.append(f"  ERROR: {e}")
        result["saopaulo_rds"] = {"error": str(e)}
        passed = False

    lines.append("")

    # ── Summary ────────────────────────────────────────────────────────────────
    lines.append(SEPARATOR)
    lines.append("SUMMARY")
    lines.append("-" * 50)
    lines.append(f"  Overall result : {'PASS' if passed else 'FAIL'}")
    lines.append(f"  APPI principle : Global access != Global storage")
    lines.append(f"  PHI location   : ap-northeast-1 ONLY")
    lines.append(f"  Compute only   : sa-east-1 (no DB, no PHI)")
    lines.append(SEPARATOR)

    output = "\n".join(lines)
    print(output)

    # ── Write proof file ───────────────────────────────────────────────────────
    with open(OUTPUT_FILE, "w") as f:
        f.write(output)
    print(f"\n[OK] Written to {OUTPUT_FILE}")

    # ── Merge into evidence.json ───────────────────────────────────────────────
    try:
        with open(EVIDENCE_FILE, "r") as f:
            evidence = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        evidence = {}

    evidence["data_residency"] = {
        "timestamp": ts(),
        "passed":    passed,
        "result":    result,
    }

    with open(EVIDENCE_FILE, "w") as f:
        json.dump(evidence, f, indent=2, default=str)
    print(f"[OK] evidence.json updated")

    return 0 if passed else 1

if __name__ == "__main__":
    sys.exit(run())
