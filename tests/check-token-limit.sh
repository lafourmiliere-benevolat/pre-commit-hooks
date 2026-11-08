#!/bin/sh
# Runs hooks/check-token-limit against a throwaway git repo.
# Usage: tests/check-token-limit.sh
set -eu
# Run as a commit hook, git exports these for the outer repo; the
# throwaway repo below must not write into its index.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

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

check "passes an empty file list" 0

# A path with a newline: staged over the limit, emptied on disk.
newline_name='new
line.txt'
bytes 20001 >"$newline_name"
git add "$newline_name"
: >"$newline_name"
check "measures the staged copy of a path with a newline" 1 "$newline_name"

# Many files mixing staged, untracked and spaced names, behind the newline
# path, so a size read for one file can't land on another.
mkdir many
i=0
expected=""
while [ $i -lt 300 ]; do
  case $((i % 3)) in
    0) name="many/small $i.txt" size=10 ;;
    1) name="many/big $i.txt" size=20001 ;;
    2) name="many/untracked-big-$i.txt" size=20001 ;;
  esac
  bytes "$size" >"$name"
  [ $((i % 3)) -eq 2 ] || git add "$name"
  [ "$size" -eq 10 ] || expected="$expected$name
"
  i=$((i + 1))
done
reported=$("$hook" "$newline_name" many/* 2>&1 |
  sed -n 's/^  \(many\/.*\): ~5000 tokens (20001 bytes)$/\1/p' | sort)
expected=$(printf %s "$expected" | sort)
if [ "$reported" = "$expected" ]; then
  echo "ok   reports exactly the files over the limit, across many"
else
  echo "FAIL reports exactly the files over the limit, across many"
  failures=$((failures + 1))
fi

[ "$failures" -eq 0 ]
