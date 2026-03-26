#!/bin/bash
# ============================================================
# São Paulo (liberdade) user_data.sh
# Region: sa-east-1
# Lab 3A: STATELESS COMPUTE — no local DB.
#         App reads /lab/db/endpoint from SSM,
#         which points to Tokyo RDS via TGW.
# ============================================================

set -euo pipefail

# 1. System Dependencies
dnf update -y
dnf install -y python3-pip mariadb105 nc  # nc for TGW connectivity testing
pip3 install flask pymysql boto3 watchtower

# 2. Directory Structure
mkdir -p /opt/rdsapp/static

# 2.1 Static Files
echo "<h1>liberdade — São Paulo App v3.0</h1>" > /opt/rdsapp/static/index.html
echo "São Paulo is stateless. Data lives in Tokyo." > /opt/rdsapp/static/example.txt

# 3. Flask Application
# IMPORTANT: This app.py is IDENTICAL to Tokyo's except for region and secret name.
# It reads /lab/db/endpoint from SSM — in São Paulo, that parameter points to Tokyo.
# The TGW handles the network path transparently. No app code changes needed.
cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
import logging
import time
from flask import Flask, request, jsonify, make_response, send_from_directory
from watchtower import CloudWatchLogHandler

REGION        = os.environ.get("AWS_REGION", "sa-east-1")         # FIX: correct region
LOG_GROUP     = os.environ.get("LOG_GROUP",  "/aws/ec2/lab-rds-app")
STATIC_FOLDER = "/opt/rdsapp/static"                               # FIX: was undefined
SECRET_ID     = os.environ.get("SECRET_ID",  "shinjuku-final/rds/mysql1")  # FIX: Tokyo secret

# NOTE: SSM and Secrets Manager clients use sa-east-1 (local region).
# SSM /lab/db/endpoint was written by Terraform pointing to the Tokyo RDS hostname.
# The pymysql connect() uses that hostname, which resolves to Tokyo private IP,
# and traffic flows: São Paulo EC2 → TGW → Tokyo VPC → Tokyo RDS.
ssm = boto3.client("ssm",            region_name=REGION)
sm  = boto3.client("secretsmanager", region_name=REGION)
cw  = boto3.client("cloudwatch",     region_name=REGION)

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
    # Credentials live in Tokyo Secrets Manager — but São Paulo's IAM role has
    # cross-region read via HTTPS (not TGW, Secrets Manager is a public endpoint).
    # Alternatively, replicate the secret to sa-east-1 Secrets Manager.
    s_resp = sm.get_secret_value(SecretId=SECRET_ID)
    secret = json.loads(s_resp["SecretString"])
    return {
        "host":     p_map.get("/lab/db/endpoint"),   # Tokyo RDS hostname
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
        connect_timeout=15  # Slightly higher timeout for cross-region TGW latency
    )

# FIX: /health route — ALB health check configured with path=/health
@app.route("/health")
def health():
    return jsonify({"status": "ok", "region": REGION, "db": "tokyo-via-tgw"}), 200

@app.route("/")
def home():
    return f"""
    <h1>liberdade (São Paulo) — {REGION}</h1>
    <p>Stateless compute. All data reads/writes go to Tokyo RDS via TGW.</p>
    <ul>
      <li><a href='/init'>1. Init DB (Tokyo)</a></li>
      <li><a href='/add?text=SaoPauloEntry'>2. Add Note</a></li>
      <li><a href='/list'>3. List Notes (from Tokyo)</a></li>
    </ul>
    """

@app.route("/add")
def add_note():
    note_text = request.args.get("text", "SP Entry")
    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("INSERT INTO notes (note) VALUES (%s)", (note_text,))
        cur.close(); conn.close()
        return f"Added to Tokyo RDS: {note_text} | <a href='/list'>View</a>"
    except Exception as e:
        record_failure(str(e))
        return f"Add Failed (TGW or RDS unreachable?): {e}", 500

@app.route("/static/<path:filename>")
def serve_static(filename):
    return send_from_directory(STATIC_FOLDER, filename)

@app.route("/api/public-feed")
def public_feed():
    data = {"message": "São Paulo feed — data from Tokyo", "server_time_utc": time.time(), "region": REGION}
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
        data = {"notes": [r[0] for r in rows], "status": "private", "served_by": REGION, "db": "tokyo"}
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
        return "<h3>Notes (Tokyo RDS via TGW):</h3>" + "".join([f"<li>{r[1]}</li>" for r in rows]) + "<br><a href='/'>Back</a>"
    except Exception as e:
        record_failure(str(e))
        return f"List Failed: {e}", 500

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
        return "Init OK on Tokyo RDS! <a href='/'>Back</a>"
    except Exception as e:
        record_failure(str(e))
        return f"Init Failed (check TGW route and RDS SG): {e}", 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

# 4. Systemd Service
# FIX: AWS_REGION is now sa-east-1 — was incorrectly us-east-1 in original code.
cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=liberdade RDS App (São Paulo — stateless compute)
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/rdsapp
ExecStartPre=/usr/bin/sleep 20
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always
RestartSec=10s
Environment=AWS_REGION=sa-east-1
Environment=SECRET_ID=shinjuku-final/rds/mysql1
Environment=LOG_GROUP=/aws/ec2/liberdade-final-rds-app

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp
