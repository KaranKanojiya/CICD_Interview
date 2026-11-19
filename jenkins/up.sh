#!/usr/bin/env bash
# Starts the local Jenkins (http://localhost:8081, user admin).
# Password: $JENKINS_ADMIN_PASSWORD if set, otherwise generated once into jenkins/.admin-password (git-ignored).
set -euo pipefail
cd "$(dirname "$0")"

if [ -z "${JENKINS_ADMIN_PASSWORD:-}" ]; then
  if [ ! -s .admin-password ]; then
    (umask 077; openssl rand -base64 18 | tr -d '/+=' > .admin-password)
  fi
  JENKINS_ADMIN_PASSWORD=$(cat .admin-password)
fi
export JENKINS_ADMIN_PASSWORD

docker compose up -d --build

echo "Waiting for Jenkins..."
for i in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8081/login || true)
  if [ "$code" = "200" ]; then
    echo "Jenkins is up: http://localhost:8081  (user: admin, password in jenkins/.admin-password or \$JENKINS_ADMIN_PASSWORD)"
    exit 0
  fi
  sleep 2
done
echo "Jenkins did not come up; check: docker compose -f jenkins/docker-compose.yml logs" >&2
exit 1
