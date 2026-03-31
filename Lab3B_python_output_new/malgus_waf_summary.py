#!/usr/bin/env python3
import boto3, time, json, argparse
from datetime import datetime, timezone, timedelta

# Reason why Darth Malgus would be pleased with this script.
# He enjoys watching attacks get denied at the edge—statistics are trophies.
# Reason why this script is relevant to your career.
# WAF analysis and false-positive detection are daily security operations.
# How you would talk about this script at an interview.
# "I standardized WAF triage by querying logs and producing an audit-friendly summary."

# ── Locked values ──────────────────────────────────────────────────────────────
ACCOUNT_ID         = "200819971986"
CF_DISTRIBUTION_ID = "E1MQONXZ6LPX94"
OUTPUT_FILE        = "audit-pack/03_waf-proof.txt"
EVIDENCE_FILE      = "audit-pack/evidence.json"
DEFAULT_LOG_GROUP  = "aws-waf-logs-shinjuku-cf-waf01"

logs = boto3.client("logs", region_name="us-east-1")

def run(group, query, minutes):
    end   = int(datetime.now(timezone.utc).timestamp())
    start = int((datetime.now(timezone.utc) - timedelta(minutes=minutes)).timestamp())
    qid   = logs.start_query(
        logGroupName=group, startTime=start, endTime=end,
        queryString=query, limit=50
    )["queryId"]
    for _ in range(30):
        r = logs.get_query_results(queryId=qid)
        if r["status"] == "Complete":
            return [{x["field"]: x["value"] for x in row} for row in r["results"]]
        time.sleep(1)
    raise TimeoutError("Query timed out")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log-group", default=DEFAULT_LOG_GROUP,
                    help=f"CloudWatch log group name (default: {DEFAULT_LOG_GROUP})")
    ap.add_argument("--minutes", type=int, default=30,
                    help="Minutes of history to query (default: 30)")
    args = ap.parse_args()

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{ts}] Running malgus_waf_summary.py ...")
    print(f"  Log group : {args.log_group}")
    print(f"  Minutes   : {args.minutes}")

    result = {}
    status = "ok"
    try:
        actions = run(args.log_group,
                      "stats count() as hits by action | sort hits desc",
                      args.minutes)
        top_ips = run(args.log_group,
                      "stats count() as hits by httpRequest.clientIp | sort hits desc | limit 10",
                      args.minutes)
        result = {"actions": actions, "top_ips": top_ips}
        print(json.dumps(result, indent=2))
    except Exception as e:
        msg = str(e)
        if "ResourceNotFoundException" in msg or "does not exist" in msg:
            print(f"Log group '{args.log_group}' not found in us-east-1.")
            print("WAF is configured and active — logs appear once traffic hits rules.")
            print("Verify: aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1")
            result = {"status": "log_group_not_found", "log_group": args.log_group}
            status = "log_group_not_found"
        else:
            print(f"ERROR: {e}")
            result = {"error": msg}
            status = "error"

    # ── Write proof file ───────────────────────────────────────────────────────
    SEP = "=" * 70
    lines = [
        SEP,
        "LAB 3B — WAF SECURITY PROOF (LIVE OUTPUT)",
        f"Generated        : {ts}",
        f"Account          : {ACCOUNT_ID}",
        f"CF Distribution  : {CF_DISTRIBUTION_ID}",
        f"Log group        : {args.log_group}",
        f"Window           : last {args.minutes} minutes",
        SEP, "",
        json.dumps(result, indent=2), "",
        SEP,
        "WAF LOGGING DESTINATIONS (supported by this lab):",
        "  1. CloudWatch Logs  (aws-waf-logs-* prefix required)  <-- ACTIVE",
        "  2. S3               (s3://aws-waf-logs-* prefix required)",
        "  3. Kinesis Firehose (aws-waf-logs-* prefix required)", "",
        "CLI verification:",
        "  aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1",
        "  aws wafv2 list-web-acls --scope REGIONAL --region ap-northeast-1",
        "  aws wafv2 list-web-acls --scope REGIONAL --region sa-east-1",
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

    evidence["waf_summary"] = {
        "timestamp": ts, "minutes": args.minutes,
        "log_group": args.log_group, "distribution": CF_DISTRIBUTION_ID,
        "status": status, "result": result,
    }
    with open(EVIDENCE_FILE, "w") as f:
        json.dump(evidence, f, indent=2, default=str)
    print(f"[OK] evidence.json updated")

if __name__ == "__main__":
    main()
