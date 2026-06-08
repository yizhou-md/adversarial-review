#!/usr/bin/env bash
set -euo pipefail

[ -x ./runtest.sh ] || {
  echo "Missing executable ./runtest.sh. Replace it with this project's real test command." >&2
  exit 2
}

out="$(mktemp -t codex-runtest.XXXXXX)"
set +e
./runtest.sh >"$out" 2>&1
status=$?
set -e

if [ "$status" -eq 0 ]; then
  rm -f "$out"
  printf '{}\n'
  exit 0
fi

{
  echo "Tests failed. Reproduce with: ./runtest.sh"
  sed -n '1,160p' "$out"
  echo
  echo "Exit code: $status"
} >&2

rm -f "$out"
exit 2
