#!/usr/bin/env bash
set -euo pipefail

version_file="${1:-VERSION}"

if [[ ! -f "$version_file" ]]; then
  echo "Version file not found: $version_file" >&2
  exit 1
fi

if [[ "$(wc -l < "$version_file" | tr -d ' ')" != "1" ]] || ! IFS= read -r version < "$version_file" || [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Invalid version in $version_file; expected MAJOR.MINOR.PATCH." >&2
  exit 1
fi

printf "%s.%s.%s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$((BASH_REMATCH[3] + 1))" > "$version_file"
