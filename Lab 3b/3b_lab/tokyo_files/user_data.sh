#!/bin/bash
# ============================================================
# Tokyo (shinjuku) user_data.sh
# Region: ap-northeast-1
# Lab 3A: App connects to LOCAL RDS (same region).
#         Tokyo is the data authority — RDS lives here.
# ============================================================

set -euo pipefail

# 1. System Dependencies
dnf update -y
dnf install -y python3-pip mariadb105
pip3 install flask pymysql boto3 watchtower

# 2. Directory Structure
mkdir -p /opt/rdsapp/static

# 2.1 Static Files
echo "<h1>shinjuku — Tokyo App v3.0</h1>" > /opt/rdsapp/static/index.html
echo "Tokyo is the data authority. PHI lives here." > /opt/rdsapp/static/example.txt

# 3. Flask Application
# FIX: STATIC_FOLDER was referenced but never defined — now defined as a constant.
# FIX: SecretId changed from 'lab/rds/mysql' to match TF resource name pattern.
# FIX: Added /health route required by ALB health check (path = /health).
# FIX: AWS_REGION reads from environment (set by systemd, not hardcoded to us-east-1).
cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
import logging
import time
from flask import Flask, request, jsonify, make_response, send_from_directory
from watchtower import CloudWatchLogHandler

# FIX: Read region from environment — set correctly per-region in systemd unit
REGION       = os.environ.get("AWS_REGION", "ap-northeast-1")
LOG_GROUP    = os.environ.get("LOG_GROUP", "/aws/ec2/lab-rds-app")
STATIC_FOLDER = "/opt/rdsapp/static"   # FIX: was undefined, caused NameError on /static/* requests
SECRET_ID    = os.environ.get("SECRET_ID", "shinjuku-final/rds/mysql1")  # FIX: must match TF secret name

ssm = boto3.client("ssm",           region_name=REGION)
sm  = boto3.client("secretsmanager", region_name=REGION)
cw  = boto3.client("cloudwatch",    region_name=REGION)

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
try:
    cw_handler = CloudWatchLogHandler(
        log_group=LOG_GROUP,
        stream_name="app-stream",
        boto3_client=boto3.client("logs", region_name=REGION)
    )
    logger.addHandler(cw_handler)
except Exception as e:
    print(f"CloudWatch Logs setup pending: {e}")

app = Flask(__name__)

def record_failure(error_msg):
    logger.error(f"DB_CONNECTION_FAILURE: {error_msg}")
    try:
        cw.put_metric_data(
            Namespace="Lab/RDSApp",
            MetricData=[{"MetricName": "DBConnectionErrors", "Value": 1.0, "Unit": "Count"}]
        )
    except Exception as e:
        logger.warning(f"Failed to push metric: {e}")

def get_config():
    p_resp = ssm.get_parameters(
        Names=["/lab/db/endpoint", "/lab/db/port", "/lab/db/name"],
        WithDecryption=False
    )
    p_map = {p["Name"]: p["Value"] for p in p_resp["Parameters"]}
    s_resp = sm.get_secret_value(SecretId=SECRET_ID)
    secret = json.loads(s_resp["SecretString"])
    return {
        "host":     p_map.get("/lab/db/endpoint"),
        "port":     int(p_map.get("/lab/db/port", 3306)),
        "dbname":   p_map.get("/lab/db/name", "labdb"),
        "user":     secret.get("username"),
        "password": secret.get("password")
    }

def get_conn():
    c = get_config()
    return pymysql.connect(
        host=c["host"], user=c["user"], password=c["password"],
        port=c["port"], database=c["dbname"], autocommit=True,
        connect_timeout=10  # Prevents hanging on TGW path issues
    )

# FIX: /health route added — ALB health check uses path=/health; without this
#      all targets stay unhealthy and the ALB returns 502 for every request.
@app.route("/health")
def health():
    return jsonify({"status": "ok", "region": REGION}), 200

@app.route("/")
def home():
    return f"""
    <h1>shinjuku RDS App — {REGION}</h1>
    <ul>
      <li><a href='/init'>1. Init DB</a></li>
      <li><a href='/add?text=TokyoEntry'>2. Add Note</a></li>
      <li><a href='/list'>3. List Notes</a></li>
    </ul>
    """

@app.route("/add")
def add_note():
    note_text = request.args.get("text", "Manual Entry")
    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("INSERT INTO notes (note) VALUES (%s)", (note_text,))
        cur.close(); conn.close()
        return f"Added: {note_text} | <a href='/list'>View</a>"
    except Exception as e:
        record_failure(str(e))
        return f"Add Failed: {e}", 500

@app.route("/static/<path:filename>")
def serve_static(filename):
    # FIX: STATIC_FOLDER is now defined above — this route was broken before
    return send_from_directory(STATIC_FOLDER, filename)

@app.route("/api/public-feed")
def public_feed():
    data = {"message": "Tokyo feed — data authority", "server_time_utc": time.time(), "region": REGION}
    response = make_response(jsonify(data))
    response.headers["Cache-Control"] = "public, s-maxage=30, max-age=0"
    return response

@app.route("/api/list")
def private_list():
    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("SELECT note FROM notes ORDER BY id DESC LIMIT 5;")
        rows = cur.fetchall()
        cur.close(); conn.close()
        data = {"notes": [r[0] for r in rows], "status": "private", "region": REGION}
    except Exception as e:
        record_failure(str(e))
        data = {"error": "db_connection_failed", "detail": str(e)}
    response = make_response(jsonify(data))
    response.headers["Cache-Control"] = "private, no-store"
    return response

@app.route("/list")
def list_notes():
    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
        rows = cur.fetchall()
        cur.close(); conn.close()
        return "<h3>Notes (Tokyo RDS):</h3>" + "".join([f"<li>{r[1]}</li>" for r in rows]) + "<br><a href='/'>Back</a>"
    except Exception as e:
        record_failure(str(e))
        return f"List Failed: {e}", 500

@app.route("/api/records", methods=["POST"])
def add_record():
    data       = request.get_json(silent=True) or {}
    patient_id = data.get("patient_id", "UNKNOWN")
    note       = data.get("note", "")
    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("INSERT INTO notes (note) VALUES (%s)", (f"[{patient_id}] {note}",))
        cur.close(); conn.close()
        return jsonify({"status": "ok", "patient_id": patient_id, "written_by": REGION, "db": "tokyo-local"}), 201
    except Exception as e:
        record_failure(str(e))
        return jsonify({"error": "db_write_failed", "detail": str(e)}), 500

@app.route("/api/records", methods=["GET"])
def get_records():
    patient_id = request.args.get("patient_id")
    try:
        conn = get_conn()
        cur  = conn.cursor()
        if patient_id:
            cur.execute("SELECT note FROM notes WHERE note LIKE %s ORDER BY id DESC", (f"%{patient_id}%",))
        else:
            cur.execute("SELECT note FROM notes ORDER BY id DESC LIMIT 10")
        rows = cur.fetchall()
        cur.close(); conn.close()
        return jsonify({"records": [r[0] for r in rows], "served_by": REGION, "db": "tokyo"}), 200
    except Exception as e:
        record_failure(str(e))
        return jsonify({"error": "db_read_failed", "detail": str(e)}), 500

@app.route("/init")
def init_db():
    try:
        c = get_config()
        conn = pymysql.connect(host=c["host"], user=c["user"], password=c["password"], port=c["port"])
        cur  = conn.cursor()
        cur.execute(f"CREATE DATABASE IF NOT EXISTS {c['dbname']};")
        cur.execute(f"USE {c['dbname']};")
        cur.execute("CREATE TABLE IF NOT EXISTS notes (id INT AUTO_INCREMENT PRIMARY KEY, note VARCHAR(255));")
        cur.close(); conn.close()
        return "Init OK! <a href='/'>Back</a>"
    except Exception as e:
        record_failure(str(e))
        return f"Init Failed: {e}", 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

# 4. Systemd Service
# FIX: AWS_REGION is now ap-northeast-1 (Tokyo) — was incorrectly us-east-1.
# FIX: SECRET_ID and LOG_GROUP injected as env vars so app.py doesn't need
#      hardcoded values that differ between Tokyo and São Paulo deployments.
cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=shinjuku RDS App (Tokyo)
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/rdsapp
ExecStartPre=/usr/bin/sleep 20
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always
RestartSec=10s
Environment=AWS_REGION=ap-northeast-1
Environment=SECRET_ID=shinjuku-final/rds/mysql1
Environment=LOG_GROUP=/aws/ec2/shinjuku-final-rds-app

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp
