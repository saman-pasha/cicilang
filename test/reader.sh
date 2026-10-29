#!/bin/sh
# The gate for the reader. The checks are a cocolog program, test/reader.pl:
# one process over one fresh knowledge base runs every one of them -- the
# grammar, includes, the cache, macros, :=, patterns, format, name { } --
# with each header parsed once. This wrapper adds the one check a single
# process cannot make: that a LATER process finds what the first one read.
#
#   sh test/reader.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cicilang.so" ] || { echo "SKIP (no library/cicilang.so -- sh module/build.sh)"; exit 0; }
D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-reader-XXXXXX")
trap 'rm -rf "$D"' EXIT
export CCL_TEST_ROOT="$ROOT" CCL_TEST_TMP="$D"

# the store is the user's (test/config.sh): the headers were read once, by whoever came first
# ensure_loaded from a query, never `run FILE goal': under a store `run' consults the program INTO it
out=$("$C" --embed "$CICILANG_KB" query "ensure_loaded('$ROOT/test/reader.pl'), reader_main" 2>&1)
echo "$out" | grep -a "^ok\|^FAIL\|^--\|^SKIP\|^     \|^GREEN\|^RED\|ERROR" || echo "$out" | tail -5
failures=$(echo "$out" | grep -ac "^FAIL")
echo "$out" | grep -aq "^GREEN\|^RED" || { echo "RED: the gate did not finish"; exit 1; }

echo "-- a later process, the same store"
# SERVED, NOT ONLY FAST (0.225): <stdio.h>'s row under the key a read makes now, every header it depends on unchanged --
# what the read is served from (ccl_kb_cached/3), asked before the read writes anything -- then hello.c read in under
# 10 s; the answer names the store's files and the seconds each part took. It was fast alone, and it was no serving: the
# first process's last read of <stdio.h> was C23's, which took the C17 row's place, and the later process read it again
# -- a second on Linux, 18 s on a Mac (0.224). The store keeps a row a level since 0.225 (ccl_kb_remember/3)
s=$(date +%s)
"$C" --embed "$CICILANG_KB" query "use_module(library(cicilang)), get_time(T0), ccl_kb_ready, '\$ccl_ast'(P, _, meta(included(_), _, _)), sub_atom(P, _, _, 0, '/stdio.h'), ccl_ensure_globals, ccl_set_lang('$ROOT/test/c/hello.c'), ( ccl_kb_key(P, K), '\$ccl_ast'(P, K, meta(included(_), _, Ds)), ccl_kb_deps_fresh(Ds) -> S = served ; S = stale ), get_time(T1), cicilang_ast('$ROOT/test/c/hello.c', U), ccl_declares(U, printf, _), get_time(T2), aggregate_all(count, '\$ccl_ast'(_, _, _), N), A is round((T1 - T0) * 10) / 10, B is round((T2 - T1) * 10) / 10, write(answer(S, N, A, B)), nl" > "$D/later.out" 2>&1 < /dev/null
got=$(grep -aoE -m 1 'answer\(.*\)' "$D/later.out")
t=$(( $(date +%s) - s ))
lim=10
# shellcheck disable=SC2046
case "$got" in
  "answer(served,"*) set -- $(echo "$got" | sed 's/^answer(served,//; s/)$//; s/,/ /g'); how="the store's $1 files, $2 s to ask it, $3 s to read" ;;
  *) how="" ;;
esac
if [ -n "$how" ] && [ "$t" -lt "$lim" ]; then
  printf 'ok   %s\n' "a later process finds hello.c's headers served from the store and reads it in ${t} s ($how)"
else
  printf 'FAIL a later process finds hello.c'"'"'s headers served from the store and reads it in under %s s\n     got  %s in %s s\n' "$lim" "$got" "$t"
  failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then echo "GREEN: reader"; else echo "RED: $failures failure(s)"; exit 1; fi
