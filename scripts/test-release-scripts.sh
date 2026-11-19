#!/usr/bin/env bash
# Self-test for next-version.sh and release.sh in a throwaway git repo.
set -euo pipefail
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
git init --quiet -b main
git config user.name test && git config user.email test@example.com
mkdir scripts && cp "$SCRIPTS/next-version.sh" "$SCRIPTS/release.sh" scripts/
git add scripts && git commit --quiet -m "chore: add release scripts"

PASS=0; FAIL=0
check() { if [ "$2" = "$3" ]; then echo "  PASS  $1 ($3)"; PASS=$((PASS+1)); else echo "  FAIL  $1: expected '$2', got '$3'"; FAIL=$((FAIL+1)); fi; }
commit() { echo "$RANDOM" >> file.txt; git add file.txt; git commit --quiet -m "$1" ${2:+-m "$2"}; }
next() { scripts/next-version.sh 2>/dev/null || echo "none"; }

commit "chore: initial setup"
check "only chores -> no release" "none" "$(next)"

commit "feat: add version endpoint"
check "first feat from nothing -> 0.1.0" "0.1.0" "$(next)"

SKIP_TESTS=1 scripts/release.sh > /dev/null
check "release.sh created the tag" "v0.1.0" "$(git describe --tags --abbrev=0)"
check "tag is annotated" "tag" "$(git cat-file -t v0.1.0)"
grep -q '## \[0.1.0\]' CHANGELOG.md && check "changelog has 0.1.0" ok ok || check "changelog has 0.1.0" ok missing

commit "fix(api): handle missing build info"
check "fix after 0.1.0 -> 0.1.1" "0.1.1" "$(next)"

commit "feat(api): add commit id"
check "feat + fix -> minor 0.2.0" "0.2.0" "$(next)"

commit "refactor: tidy controller" "BREAKING CHANGE: /api/version renamed fields"
check "BREAKING CHANGE footer -> major 1.0.0" "1.0.0" "$(next)"

SKIP_TESTS=1 scripts/release.sh > /dev/null
commit "feat!: drop Java 17 support"
check "feat! -> major 2.0.0" "2.0.0" "$(next)"

git checkout --quiet -b feature/x
if SKIP_TESTS=1 scripts/release.sh > /dev/null 2>&1; then check "refuses non-main branch" refused allowed; else check "refuses non-main branch" refused refused; fi

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
