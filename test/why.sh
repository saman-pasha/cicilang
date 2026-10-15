#!/bin/sh
# test/why.sh -- WHERE A BUILD GIVES UP (0.144): the build of a file run under cocolog's library(flow/debug), which
# records its last inferences and reads back the failure that ended it. A refusal names a function, `not lowered yet:
# item(function(pick, block/1))', and `the check or the lowering failed without saying why' names nothing; this
# names the call that failed, down the path that got furthest, its arguments, the clause it failed in and that
# clause's last goal -- in two runs of the build at full speed, where finding it by hand took probes and traces.
#
#   sh test/why.sh [cicilang's arguments] FILE     a C file through bin/cicilang, a C++ one through bin/cicilang++
#   WHY_WINDOW=N    the inferences recorded before the end (20000); a failure further back needs more
#   WHY_KEEP=DIR    the debugger's files kept in DIR: why.txt (the run, a call a line), why.svg, why.xml
#   WHY_SECS=S WHY_MB=M   the caps: S seconds (2400) and M MB summed over the run's process group (2800)
#
# The build is made to end at its first error: the program the debugger runs sets '$ccl_why', under which the driver
# takes no error the compiler raises (dr_catch/3) and throws after one it says (dr_why_stop/3; library/ccl_driver.pl),
# so the recording ends where the compiler gave up, and cocolog 1.11.4's flow_why_raised/3 reads the error's path
# back (test/why.pl). The goal is the command's own (bin/cicilang writes it under CICILANG_GOAL), compiled with -c
# and no store.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
grep -q 'flow_why_raised' "$COCOLOG/library/flow/dbgwhy.pl" 2>/dev/null || { echo "SKIP (cocolog's library(flow/debug) has no flow_why_raised/3: 1.11.4 or later)"; exit 0; }
[ $# -ge 1 ] || { echo "usage: sh test/why.sh [cicilang's arguments] FILE" >&2; exit 2; }
WHY_WINDOW=${WHY_WINDOW:-20000}; WHY_SECS=${WHY_SECS:-2400}; WHY_MB=${WHY_MB:-2800}
if [ -n "$WHY_KEEP" ]; then D=$WHY_KEEP; mkdir -p "$D"; else D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-why-XXXXXX"); trap 'rm -rf "$D"' EXIT; fi
# the arguments, each file among them made absolute (the runs start in D); a C++ file goes through cicilang++
cmd="$ROOT/bin/cicilang"; n=$#
while [ "$n" -gt 0 ]; do
  a=$1; shift; n=$((n - 1))
  case "$a" in -*) ;; *) [ -f "$a" ] && a="$(cd "$(dirname "$a")" && pwd)/$(basename "$a")" ;; esac
  case "$a" in *.cpp|*.cc|*.cxx|*.C|*.cppm|*.ccm|*.cxxm|*.ixx|*.mpp) cmd="$ROOT/bin/cicilang++" ;; esac
  set -- "$@" "$a"
done
rm -f "$D/goal"; CICILANG_GOAL="$D/goal" "$cmd" "$@" -c -o "$D/why.o"
[ -s "$D/goal" ] || { echo "RED: $cmd made no goal of these arguments"; exit 1; }
# THE BUILD ONCE AS IT IS, first: what it says, and the C++ summaries it reads written before the debugger's two runs
# -- else the probe flattens a header and writes its summary, the replay reads the summary, and the two runs differ
# (cocolog calls that DIVERGED: abstract.cpp's probe spent 4.4 million inferences, its replay 181 thousand)
echo "-- the build: $(basename "$cmd") $*"
if timeout -s KILL "$WHY_SECS" "$cmd" "$@" -c -o "$D/plain.o" < /dev/null > "$D/plain.out" 2>&1; then
  sed 's/^/   /' "$D/plain.out"; echo "-- it builds: nothing to explain"; exit 0
fi
sed 's/^/   /' "$D/plain.out"
{ echo ":- use_module(library(cicilang))."; printf "cw_goal :- nb_setval('\$ccl_why', yes), %s.\n" "$(cat "$D/goal")"; } > "$D/top.pl"
# one run of the debugger, its whole process group under the two caps (a cap kills the tree: CLAUDE.md, Caps)
cd "$D" || exit 2
timeout -s KILL "$WHY_SECS" "$C" --local query "use_module(library(flow/debug)), ensure_loaded('$ROOT/test/why.pl'), cw_main('$D/top.pl', '$D/why', $WHY_WINDOW)" < /dev/null > "$D/why.out" 2>&1 &
P=$!; peak=0; sleep 0.3; PG=$(ps -o pgid= -p "$P" | tr -d ' ')
while kill -0 "$P" 2>/dev/null; do
  sleep 1
  rss=$(ps -eo pgid,rss | awk -v g="$PG" '$1 == g { s += $2 } END { print int(s / 1024) }')
  [ "$rss" -gt "$peak" ] && peak=$rss
  if [ "$rss" -gt "$WHY_MB" ]; then kill -9 -- "-$PG" 2>/dev/null; echo "RED: the run passed $WHY_MB MB (WHY_MB)"; break; fi
done
wait "$P"; rc=$?
grep -av '^  1\.\|answer(s)\.$' "$D/why.out"
[ "$rc" -eq 137 ] && echo "RED: the run passed $WHY_SECS s (WHY_SECS)"
grep -aq '^-- the build under' "$D/why.out" || { echo "RED: the debugger did not finish (exit $rc; peak $peak MB)"; exit 1; }
echo "-- peak $peak MB"
