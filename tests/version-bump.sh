#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

check() {
  local name="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL - $name: expected $expected, got $actual" >&2
    exit 1
  fi

  echo "ok   - $name"
}

printf "0.1.0\n" > "$temp_dir/VERSION"
bash "$repo_root/scripts/bump-version.sh" "$temp_dir/VERSION"
check "bumps patch version" "$(cat "$temp_dir/VERSION")" "0.1.1"

printf "1.2.9\n" > "$temp_dir/VERSION"
bash "$repo_root/scripts/bump-version.sh" "$temp_dir/VERSION"
check "carries no version components" "$(cat "$temp_dir/VERSION")" "1.2.10"

printf "1.2\n" > "$temp_dir/VERSION"
if bash "$repo_root/scripts/bump-version.sh" "$temp_dir/VERSION" >/dev/null 2>&1; then
  echo "FAIL - rejects malformed version" >&2
  exit 1
fi
echo "ok   - rejects malformed version"
