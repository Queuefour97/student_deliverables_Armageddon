

For the **Runbook** 



WAF log group: aws-waf-logs-<project>-webacl01

&nbsp; App log group: /aws/ec2/armageddon-final-rds-app



WAF logs (when you chose waf\_log\_destination="cloudwatch")

&nbsp;   App logs (your /aws/ec2/lab-rds-app group)



<prefix> = "lab"



Lab 1C-Bonus-F: Logs Insights Query Pack

Variables students fill in (for the runbook)

&nbsp; WAF log group: aws-waf-logs-<project>-webacl01

&nbsp; App log group: /aws/ec2/<project>-rds-app



Requirements: Set the time range to Last 15 minutes (or match incident window).





A) WAF Queries (CloudWatch Logs Insights)

A1) “What’s happening right now?” (Top actions: ALLOW/BLOCK)

&nbsp; fields @timestamp, action

&nbsp; | stats count() as hits by action

&nbsp; | sort hits desc



A2) Top client IPs (who is hitting us the most?)

&nbsp; fields @timestamp, httpRequest.clientIp as clientIp

| stats count() as hits by clientIp

| sort hits desc

| limit 25



A3) Top requested URIs (what are they trying to reach?)

&nbsp; fields @timestamp, httpRequest.uri as uri

| stats count() as hits by uri

| sort hits desc

| limit 25



A4) Blocked requests only (who/what is being blocked?)

&nbsp; fields @timestamp, action, httpRequest.clientIp as clientIp, httpRequest.uri as uri

| filter action = "BLOCK"

| stats count() as blocks by clientIp, uri

| sort blocks desc

| limit 25



A5) Which WAF rule is doing the blocking?

&nbsp; fields @timestamp, action, terminatingRuleId, terminatingRuleType

| filter action = "BLOCK"

| stats count() as blocks by terminatingRuleId, terminatingRuleType

| sort blocks desc

| limit 25



A6) Rate of blocks over time (did it spike?)

&nbsp; fields @timestamp, httpRequest.clientIp as clientIp, httpRequest.uri as uri

| filter uri like /wp-login|xmlrpc|\\.env|admin|phpmyadmin|\\.git|\\/login/i

| stats count() as hits by clientIp, uri

| sort hits desc

| limit 50



\#edit

fields @timestamp, httpRequest.clientIp as clientIp, httpRequest.uri as uri | filter uri =~ /wp-login|xmlrpc|\\.env|admin|phpmyadmin|\\.git|login/ | stats count() as hits by clientIp, uri | sort hits desc | limit 50



A7) Suspicious scanners (common patterns: admin paths, wp-login, etc.)

&nbsp; fields @timestamp, httpRequest.clientIp as clientIp, httpRequest.uri as uri

| filter uri like /wp-login|xmlrpc|\\.env|admin|phpmyadmin|\\.git|\\/login/i

| stats count() as hits by clientIp, uri

| sort hits desc

| limit 50



A8) Country/geo (if present in your WAF logs)

Some WAF log formats include httpRequest.country. If yours does:

&nbsp; fields @timestamp, httpRequest.country as country

| stats count() as hits by country

| sort hits desc

| limit 25



B) App Queries (EC2 app log group)

These assume your app logs include meaningful strings like ERROR, DBConnectionErrors, timeout, etc

(You should enforce this.)



B1) Count errors over time (this should line up with the alarm window)

&nbsp; fields @timestamp, @message

| filter @message like /ERROR|Exception|Traceback|DB|timeout|refused/i

| stats count() as errors by bin(1m)

| sort bin(1m) asc



B2) Show the most recent DB failures (triage view)

&nbsp; fields @timestamp, @message

| filter @message like /DB|mysql|timeout|refused|Access denied|could not connect/i

| sort @timestamp desc

| limit 50



B3) “Is it creds or network?” classifier hints

&nbsp; Credentials drift often shows: Access denied, authentication failures

&nbsp; Network/SecurityGroup often shows: timeout, refused, “no route”, hang

&nbsp; fields @timestamp, @message

| filter @message like /Access denied|authentication failed|timeout|refused|no route|could not connect/i

| stats count() as hits by

&nbsp; case(

&nbsp;   @message like /Access denied|authentication failed/i, "Creds/Auth",

&nbsp;   @message like /timeout|no route/i, "Network/Route",

&nbsp;   @message like /refused/i, "Port/SG/ServiceRefused",

&nbsp;   "Other"

&nbsp; )

| sort hits desc





B4) Extract structured fields (Requires log JSON)

If you log JSON like: {"level":"ERROR","event":"db\_connect\_fail","reason":"timeout"}:

&nbsp; fields @timestamp, level, event, reason

| filter level="ERROR"

| stats count() as n by event, reason

| sort n desc



(Thou Shalt need to emit JSON logs for this one.)



C) Correlation “Enterprise-style” mini-workflow (Runbook Section)

Add this to the incident runbook:



Step 1 — Confirm signal timing

&nbsp; CloudWatch alarm time window: last 5–15 minutes

&nbsp; Run App B1 to see error spike time bins



Step 2 — Decide: Attack vs Backend Failure

&nbsp; Run WAF A1 + A6:

&nbsp;   If BLOCK spikes align with incident time → likely external pressure/scanning

&nbsp;   If WAF is quiet but app errors spike → likely backend (RDS/SG/creds)



Step 3 — If backend failure suspected

&nbsp; Run App B2 and classify:

&nbsp;   Access denied → secrets drift / wrong password

&nbsp;   timeout → SG/routing/RDS down

&nbsp; Then retrieve known-good values:

&nbsp;   Parameter Store /lab/db/\*

&nbsp;   Secrets Manager /<prefix>/rds/mysql



Step 4 — Verify recovery

&nbsp; App errors return to baseline (B1)

&nbsp; WAF blocks stabilize (A6)

&nbsp; Alarm returns to OK

&nbsp; curl https://app.chewbacca-growl.com/list works

