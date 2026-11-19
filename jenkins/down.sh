#!/usr/bin/env bash
# Stops Jenkins. Pass --wipe to also delete the jenkins_home volume (jobs, builds, Gradle cache).
set -euo pipefail
cd "$(dirname "$0")"
export JENKINS_ADMIN_PASSWORD=${JENKINS_ADMIN_PASSWORD:-unused}
if [ "${1:-}" = "--wipe" ]; then
  docker compose down -v
else
  docker compose down
fi
