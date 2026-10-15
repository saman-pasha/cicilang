#!/bin/sh
# gen-bidrt.sh: compiles module/bidrt.c with cicilang (C23, -O1, the IR text) and writes library/ccl_bidrt.pl through
# module/gen-bidrt.pl (0.137). Run it after a change to bidrt.c; the generated file is committed.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
timeout -s KILL 600 "$ROOT/bin/cicilang" --no-kb -std=c23 -O1 -S -emit-llvm "$HERE/bidrt.c" -o "$TMP/bidrt.ll" < /dev/null
perl "$HERE/gen-bidrt.pl" < "$TMP/bidrt.ll" > "$TMP/ccl_bidrt.pl"
mv "$TMP/ccl_bidrt.pl" "$ROOT/library/ccl_bidrt.pl"
echo "gen-bidrt: library/ccl_bidrt.pl, $(grep -c '^ccl_bidrt_text' "$ROOT/library/ccl_bidrt.pl") facts"
