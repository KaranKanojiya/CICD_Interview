#!/usr/bin/env bash
# Triggers the cicd-demo job through the REST API (crumb + session cookie) and waits for the result.
# Jenkins checks out the committed main branch, so commit before running.
set -euo pipefail
cd "$(dirname "$0")"

JENKINS=http://localhost:8081
JOB=cicd-demo
PASS=${JENKINS_ADMIN_PASSWORD:-$(cat .admin-password)}
AUTH="admin:${PASS}"
jar=$(mktemp)
trap 'rm -f "$jar"' EXIT

crumb=$(curl -fsS -u "$AUTH" -c "$jar" "$JENKINS/crumbIssuer/api/json" \
  | sed -E 's/.*"crumbRequestField":"([^"]+)".*"crumb":"([^"]+)".*/\1:\2/; s/.*"crumb":"([^"]+)".*"crumbRequestField":"([^"]+)".*/\2:\1/')

before=$(curl -fsS -u "$AUTH" -b "$jar" "$JENKINS/job/$JOB/api/json?tree=lastBuild%5Bnumber%5D" | sed -E 's/.*"number":([0-9]+).*/\1/; t; s/.*/0/')

curl -fsS -u "$AUTH" -b "$jar" -H "$crumb" -X POST "$JENKINS/job/$JOB/buildWithParameters?DEPLOY_PROD=false" -o /dev/null
build=$((before + 1))
echo "Triggered $JOB #$build"

for i in $(seq 1 180); do
  json=$(curl -fsS -u "$AUTH" -b "$jar" "$JENKINS/job/$JOB/$build/api/json?tree=building,result" 2>/dev/null || true)
  if printf '%s' "$json" | grep -q '"building":false'; then
    result=$(printf '%s' "$json" | sed -E 's/.*"result":"?([A-Z]+)"?.*/\1/')
    curl -fsS -u "$AUTH" -b "$jar" "$JENKINS/job/$JOB/$build/consoleText" | tail -40
    echo
    echo "Result: $result  ($JENKINS/job/$JOB/$build/)"
    [ "$result" = "SUCCESS" ]
    exit
  fi
  sleep 5
done
echo "Timed out waiting for #$build" >&2
exit 1
