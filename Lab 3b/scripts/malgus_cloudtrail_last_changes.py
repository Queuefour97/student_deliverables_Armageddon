#!/usr/bin/env python3
import boto3, json
from datetime import datetime, timezone, timedelta

# Reason why Darth Malgus would be pleased with this script.
# Malgus doesn't ask "what changed?" — he interrogates the timeline until it confesses.
# Reason why this script is relevant to your career.
# Change attribution is core to incident response and audit defense.
# How you would talk about this script at an interview.
# "I automated change tracking by querying CloudTrail for security/network/CDN modifications."

# ── Locked values ──────────────────────────────────────────────────────────────
ACCOUNT_ID    = "200819971986"
OUTPUT_FILE   = "audit-pack/04_cloudtrail-change-proof.txt"
EVIDENCE_FILE = "audit-pack/evidence.json"

def lookup(region, minutes=120):
    ct    = boto3.client("cloudtrail", region_name=region)
    end   = datetime.now(timezone.utc)
    start = end - timedelta(minutes=minutes)

    resp   = ct.lookup_events(StartTime=start, EndTime=end, MaxResults=50)
    events = []
    for e in resp.get("Events", []):
        events.append({
            "region": region,
            "time":   str(e.get("EventTime")),
            "event":  e.get("EventName"),
            "user":   e.get("Username"),
            "source": e.get("EventSource"),
        })
    return events

def main():
    ts    = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{ts}] Running malgus_cloudtrail_last_changes.py ...")

    tokyo = lookup("ap-northeast-1")
    sp    = lookup("sa-east-1")
    result = {"tokyo": tokyo, "saopaulo": sp}
    print(json.dumps(result, indent=2))

    # ── Write proof file ───────────────────────────────────────────────────────
    SEP = "=" * 70
    lines = [
        SEP,
        "LAB 3B — CHANGE PROOF (CLOUDTRAIL — LIVE OUTPUT)",
        f"Generated : {ts}",
        f"Account   : {ACCOUNT_ID}",
        f"Note      : CloudTrail Event History provides a 90-day immutable",
        f"            record of management events by default (no Trail required).",
        SEP, "",
        json.dumps(result, indent=2), "",
        SEP,
        f"  Total Tokyo events    : {len(tokyo)}",
        f"  Total SP events       : {len(sp)}",
        f"  Retention             : 90 days (CloudTrail Event History default)",
        f"  Tamper resistant      : Yes — event history is read-only",
        f"  Long-term option      : Create Trail -> S3 with versioning",
        SEP,
    ]
    with open(OUTPUT_FILE, "w") as f:
        f.write("\n".join(lines))
    print(f"\n[OK] Written to {OUTPUT_FILE}")

    # ── Update evidence.json ───────────────────────────────────────────────────
    try:
        with open(EVIDENCE_FILE, "r") as f:
            evidence = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        evidence = {}

    evidence["cloudtrail_changes"] = {
        "timestamp":    ts,
        "lookback_hrs": 2,
        "total_events": len(tokyo) + len(sp),
        "result":       result,
    }
    with open(EVIDENCE_FILE, "w") as f:
        json.dump(evidence, f, indent=2, default=str)
    print(f"[OK] evidence.json updated")

if __name__ == "__main__":
    main()
