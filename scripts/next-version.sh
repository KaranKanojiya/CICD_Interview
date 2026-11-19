#!/usr/bin/env bash
# Prints the next semantic version (X.Y.Z, no "v") from Conventional Commits since the last vX.Y.Z tag.
#
#   feat!: / fix!: / any "BREAKING CHANGE:" footer  -> major
#   feat:                                          -> minor
#   fix: / perf:                                   -> patch
#   only docs/chore/test/ci/refactor/style         -> no release (exit 2)
#
# Same rules as semantic-release / release-please. Works with macOS's bash 3.2.
set -euo pipefail

last_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)
if [ -z "$last_tag" ]; then
  last_version="0.0.0"
  range="HEAD"
else
  last_version="${last_tag#v}"
  range="${last_tag}..HEAD"
fi

subjects=$(git log --format='%s' $range)
bodies=$(git log --format='%b' $range)

if [ -z "$subjects" ]; then
  echo "No commits since ${last_tag:-the beginning}" >&2
  exit 2
fi

bump=""
if printf '%s\n' "$subjects" | grep -Eq '^[a-z]+(\([^)]*\))?!:' || printf '%s\n' "$bodies" | grep -q '^BREAKING CHANGE:'; then
  bump="major"
elif printf '%s\n' "$subjects" | grep -Eq '^feat(\([^)]*\))?:'; then
  bump="minor"
elif printf '%s\n' "$subjects" | grep -Eq '^(fix|perf)(\([^)]*\))?:'; then
  bump="patch"
fi

if [ -z "$bump" ]; then
  echo "No release-worthy commits (feat/fix/perf/breaking) since ${last_tag:-the beginning}" >&2
  exit 2
fi

IFS=. read -r major minor patch <<< "$last_version"
case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac
echo "${major}.${minor}.${patch}"
