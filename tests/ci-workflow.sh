#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/ci.yml"

check() {
  local name="$1"
  local pattern="$2"

  if ! grep -Fq -- "$pattern" "$workflow"; then
    echo "FAIL - $name" >&2
    exit 1
  fi

  echo "ok   - $name"
}

check "runs on pull requests" "pull_request:"
check "runs on main pushes" "      - main"
check "runs lint" "run: make lint"
check "runs tests" "run: make test"
check "bumps only after checks" "needs: checks"
check "bumps only on main" "github.ref == 'refs/heads/main'"
check "prevents bot bump loop" "github.actor != 'github-actions[bot]'"
check "skips generated bump commit" "!contains(github.event.head_commit.message, '[skip ci]')"
check "commits bumped version" 'git commit -m "chore: bump version to $version [skip ci]"'
