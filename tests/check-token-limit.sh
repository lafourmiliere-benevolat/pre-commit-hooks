#!/bin/sh
# Runs hooks/check-token-limit against a throwaway git repo.
# Usage: tests/check-token-limit.sh
set -eu

hook="$(cd "$(dirname "$0")/.." && pwd)/hooks/check-token-limit"
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
cd "$repo"
git init -q

failures=0
check() { # description, expected exit code, hook args...
  description=$1 expected=$2
  shift 2
  status=0
  "$hook" "$@" >/dev/null 2>&1 || status=$?
  if [ "$status" -eq "$expected" ]; then
    echo "ok   $description"
  else
    echo "FAIL $description (exit $status, expected $expected)"
    failures=$((failures + 1))
  fi
}

bytes() { head -c "$1" /dev/zero | tr '\0' a; }

bytes 20000 >at_limit.txt
bytes 20001 >over_limit.txt
git add at_limit.txt over_limit.txt

check "passes a file at the limit" 0 at_limit.txt
check "rejects a file over the limit" 1 over_limit.txt
check "takes the limit from --max-tokens" 0 --max-tokens=6000 over_limit.txt
check "rejects a bad --max-tokens" 2 --max-tokens=lots at_limit.txt

: >over_limit.txt
check "measures the staged copy, not the working tree" 1 over_limit.txt

bytes 20001 >untracked.txt
check "falls back to disk for untracked files" 1 untracked.txt

[ "$failures" -eq 0 ]
