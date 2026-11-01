#!/usr/bin/env bash
# Check VERSION.INC holds a valid SemVer version with a matching CHANGELOG.md entry.
# When a tag is given (e.g. v0.2.0) it must match the version too.
# Prints the version on success.
#
# Usage: scripts/check-version.sh [tag]
set -euo pipefail

cd "$(dirname "$0")/.."

version=$(sed -n "s/.*AppVersion *= *'\([^']*\)'.*/\1/p" VERSION.INC | tr -d '\r')

semver='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
if [[ ! "$version" =~ $semver ]]; then
  echo "VERSION.INC: '$version' is not a valid SemVer version" >&2
  exit 1
fi

if ! grep -q "^## \[$version\]" CHANGELOG.md; then
  echo "CHANGELOG.md: no '## [$version]' section" >&2
  exit 1
fi

if [[ $# -gt 0 && "${1#v}" != "$version" ]]; then
  echo "Tag '$1' doesn't match VERSION.INC version '$version'" >&2
  exit 1
fi

echo "$version"
