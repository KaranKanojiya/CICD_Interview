#!/usr/bin/env bash
# Cuts a release locally: computes the next version, updates CHANGELOG.md, commits, and creates an
# annotated tag vX.Y.Z. It does NOT push; pushing the tag triggers .github/workflows/release.yml,
# which builds the artifact once and publishes the GitHub Release.
#
#   scripts/release.sh --dry-run    show the version and notes, change nothing
#   scripts/release.sh              release (requires a clean tree on the release branch)
#
# Env: RELEASE_BRANCH (default main), SKIP_TESTS=1 to skip ./gradlew test.
set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true
RELEASE_BRANCH="${RELEASE_BRANCH:-main}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != "$RELEASE_BRANCH" ]; then
  echo "Releases are cut from $RELEASE_BRANCH (current: $branch)" >&2
  exit 1
fi
if ! $DRY_RUN && [ -n "$(git status --porcelain)" ]; then
  echo "Working tree not clean; commit or stash first" >&2
  exit 1
fi

version=$("$SCRIPT_DIR/next-version.sh")
tag="v$version"
last_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)
range=${last_tag:+$last_tag..}HEAD

section() { # section <title> <grep -E pattern>
  local lines
  lines=$(git log --format='%s (%h)' $range | grep -E "$2" || true)
  if [ -n "$lines" ]; then
    printf '### %s\n\n%s\n\n' "$1" "$(printf '%s\n' "$lines" | sed 's/^/- /')"
  fi
}
notes="$(section 'Breaking changes' '^[a-z]+(\([^)]*\))?!:')$(section 'Features' '^feat(\([^)]*\))?:')$(section 'Fixes' '^(fix|perf)(\([^)]*\))?:')"

echo "Next version: $tag (previous: ${last_tag:-none})"
echo
printf '%s\n' "$notes"

if $DRY_RUN; then
  exit 0
fi

if [ "${SKIP_TESTS:-0}" != "1" ]; then
  ./gradlew --quiet test
fi

entry="## [$version] - $(date +%Y-%m-%d)

$notes"
if [ -f CHANGELOG.md ]; then
  { printf '# Changelog\n\n%s\n' "$entry"; tail -n +3 CHANGELOG.md; } > CHANGELOG.md.tmp
else
  printf '# Changelog\n\n%s\n' "$entry" > CHANGELOG.md.tmp
fi
mv CHANGELOG.md.tmp CHANGELOG.md

git add CHANGELOG.md
git commit --quiet -m "chore(release): $tag"
git tag -a "$tag" -m "Release $tag" -m "$notes"

echo "Created commit and annotated tag $tag."
echo "Publish with:  git push origin $RELEASE_BRANCH --follow-tags"
