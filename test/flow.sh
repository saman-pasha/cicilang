#!/bin/sh
# test/flow.sh -- THE FLOW GATE (0.144): cocolog's library(flow/chart) reads every file of the library and says,
# without running anything, what will go wrong -- a call that nothing answers, a predicate defined twice, a clause
# no call can reach, an argument free where a builtin needs it bound, a recursion that never reads input, the
# clauses of a predicate split by another's -- each at its file, line and column. It runs FIRST in the chain and
# takes about a minute, where the next RED of that kind cost the chain's hour: a mis-edited name, a helper given a
# name already taken (0.141's two definitions of one predicate), a clause a cut above it makes dead.
#
# HOW: test/flow.pl writes, for each library file, a copy with a ROOT that calls every predicate the file defines
# (a chart starts at one call pattern). Each copy is charted with the rest of the compiler loaded -- the file itself
# stubbed out of the library path, so it is read once -- and the two modules' Cicili sources given as modules(Files),
# whence the chart takes cicilang's own C predicates and follows the libraries their Prolog halves load for the tables
# the compiler declares as it runs (cocolog 1.11.4; 0.144 wrote both itself). One job a file in the memory-gated pool
# (test/parlib.sh), longest first.
#
# THE VERDICT: the findings must be test/flow.expect's, a line each, keyed without line numbers (a finding moves
# with every edit above it): `KIND SEVERITY FILE IN', and the callee for an unknown procedure, the text for the rest;
# each key once, since one predicate charted for two call patterns says one thing twice, and how many patterns the
# chart sees changes with the chart (0.146). A finding that is not there is RED, and so is one that is gone: fixing
# one updates the expect file in the same step, so it never holds a finding that a later edit could bring back
# unseen. The severity is part of the key: a call nothing answers is a warning where a catch/3 takes its error, and
# the same call without the catch is an error again.
#
#   sh test/flow.sh                      # the gate
#   FLOW_UPDATE=1 sh test/flow.sh        # the expect file written from this run (after reading every new line)
#   FLOW_KEEP=DIR sh test/flow.sh        # the copies, the logs and each file's findings kept in DIR
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
. "$HERE/parlib.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cicilang.so" ] || { echo "SKIP (no library/cicilang.so -- sh module/build.sh)"; exit 0; }
[ -f "$COCOLOG/library/flow/chart.pl" ] || { echo "SKIP (cocolog has no library(flow/chart): 1.10.8 or later)"; exit 0; }
[ -f "$COCOLOG/library/flow/tables.pl" ] || { echo "SKIP (no library/flow/tables.pl in cocolog -- make modules writes it)"; exit 0; }
grep -q 'flow_module_portals' "$COCOLOG/library/flow/read.pl" 2>/dev/null || { echo "SKIP (cocolog's library(flow/chart) has no modules(Files): 1.11.4 or later)"; exit 0; }
FLOW_SECS=${FLOW_SECS:-900}
FLOW_JOBS=${FLOW_JOBS:-4}; FLOW_LAUNCH_MB=${FLOW_LAUNCH_MB:-9000}; FLOW_HARD_MB=${FLOW_HARD_MB:-14000}
FLOW_TIMES=${FLOW_TIMES:-$HOME/.cicilang/flow-times}
FILES="ccl_syntax ccl_pp ccl_include ccl_infer ccl_format ccl_cpp ccl_check ccl_ir ccl_build ccl_driver"
if [ -n "$FLOW_KEEP" ]; then D=$FLOW_KEEP; rm -rf "$D"; mkdir -p "$D"; else D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-flow-XXXXXX"); trap 'rm -rf "$D"' EXIT; fi
mkdir -p "$D/src" "$D/out" "$D/res" "$D/stub"
start=$(date +%s)

# the copies with their roots
list=""; for f in $FILES; do list="$list${list:+,}'$ROOT/library/$f.pl'"; done
out=$(cd "$ROOT" && timeout -s KILL 300 "$C" --local query "use_module(library(cicilang)), ensure_loaded('$ROOT/test/flow.pl'), fg_roots_main([$list], '$D/src')" 2>&1 < /dev/null)
[ -f "$D/src/roots.txt" ] || { echo "RED: the roots were not written"; printf '%s\n' "$out" | tail -10; exit 1; }
echo "-- every library file charted from a root that calls each predicate it defines ($(awk '{ s += $3 } END { print s }' "$D/src/roots.txt") predicates)"

# one job a file, the heaviest first
loads="[library(cicilang), library(ccl_llvm), library(ccl_bidrt), library(ccl_uninames), library(ccl_format)]"
mods="['$ROOT/module/cicilang.cicili', '$ROOT/module/ccl_llvm.cicili']"
for f in $FILES; do
  n=$(awk -v b="$f.pl" '$1 == b { print $2 }' "$D/src/roots.txt")
  mkdir -p "$D/stub/$f"; : > "$D/stub/$f/$f.pl"
  echo "$f COCOLOG_LIBRARY='$D/stub/$f:$COCOLOG_LIBRARY' fg_job $f $n"
done | ccl_lpt_order "$FLOW_TIMES" | sed 's/^[^ ]* //' > "$D/jobs"
fg_job() {   # fg_job FILE ARITY: chart the copy, write the verdict line; its own variable names (sh has no locals, 0.107)
  _fj_s=$(date +%s)
  timeout -s KILL "$FLOW_SECS" "$C" --local query "use_module(library(flow/chart)), ensure_loaded('$ROOT/test/flow.pl'), fg_findings_main('$D/src/$1.pl', $2, $loads, $mods, '$D/out/$1.txt')" > "$D/out/$1.log" 2>&1 < /dev/null
  _fj_rc=$?; _fj_t=$(( $(date +%s) - _fj_s ))
  if [ "$_fj_rc" -eq 0 ] && [ -f "$D/out/$1.txt" ] && grep -aq '^1 answer' "$D/out/$1.log"; then
    echo "ok $1 $_fj_t" > "$D/res/$1"; ccl_time_record "$FLOW_TIMES" "$1" "$_fj_t"
  elif [ "$_fj_rc" -eq 137 ]; then echo "FAIL $1: TIMEOUT after $_fj_t s" > "$D/res/$1"
  else echo "FAIL $1: the chart did not finish (exit $_fj_rc)" > "$D/res/$1"; fi
}
ccl_pool "$FLOW_JOBS" "$FLOW_LAUNCH_MB" "$FLOW_HARD_MB" < "$D/jobs"; pooled=$?
[ "$pooled" -eq 0 ] || { echo "RED: the pool was killed at its hard cap ($FLOW_HARD_MB MB)"; exit 1; }

# the verdicts, then every finding keyed as the expect file keys it
bad=0
for f in $FILES; do
  r=$(cat "$D/res/$f" 2>/dev/null || echo "FAIL $f: no verdict")
  case "$r" in
    ok*) set -- $r; echo "ok   library/$f.pl charted in $3 s: $(wc -l < "$D/out/$f.txt" | tr -d ' ') findings" ;;
    *) echo "$r"; tail -5 "$D/out/$f.log" 2>/dev/null | sed 's/^/     /'; bad=1 ;;
  esac
done
[ "$bad" -eq 0 ] || { echo "RED: a file was not charted"; exit 1; }
for f in $FILES; do
  awk -F '\t' -v file="library/$f.pl" '{
      kind = $1; sev = $2; in_ = $3; text = $6
      if (kind == "discontiguous" || kind == "defined_twice") key = kind " " sev " " file " " in_
      else if (kind == "unknown_procedure") { c = text; sub(/ is defined nowhere.*/, "", c); key = kind " " sev " " file " " in_ " " c }
      else { t = text; gsub(/[0-9]+/, "N", t); key = kind " " sev " " file " " in_ " " t }
      print key "\t" file ":" $4 ":" $5 ": " sev ": " in_ ": " text
  }' "$D/out/$f.txt"
done | LC_ALL=C sort > "$D/found"
cut -f1 "$D/found" | LC_ALL=C sort -u > "$D/keys"
if [ -n "$FLOW_UPDATE" ]; then cp "$D/keys" "$HERE/flow.expect"; echo "-- test/flow.expect written: $(wc -l < "$D/keys" | tr -d ' ') findings"; fi
grep -v '^#' "$HERE/flow.expect" 2>/dev/null | LC_ALL=C sort -u > "$D/expect"
LC_ALL=C comm -23 "$D/keys" "$D/expect" > "$D/new"
LC_ALL=C comm -13 "$D/keys" "$D/expect" > "$D/gone"
e=$(( $(date +%s) - start ))
if [ -s "$D/new" ]; then   # each place once: a predicate charted for two call patterns says one thing twice
  awk -F '\t' 'NR == FNR { k[$0] = 1; next } ($1 in k) { print "     " $2 }' "$D/new" "$D/found" | LC_ALL=C sort -u > "$D/places"
  echo "-- NEW findings, $(wc -l < "$D/places" | tr -d ' ') places, each at its file, line and column:"
  cat "$D/places"
fi
if [ -s "$D/gone" ]; then
  echo "-- findings in test/flow.expect that this run did not meet ($(wc -l < "$D/gone" | tr -d ' ')): remove them from it"
  sed 's/^/     /' "$D/gone"
fi
if [ -s "$D/new" ] || [ -s "$D/gone" ]; then echo "RED: $(wc -l < "$D/keys" | tr -d ' ') findings, not test/flow.expect's ($e s)"; exit 1; fi
echo "GREEN: $(wc -l < "$D/keys" | tr -d ' ') findings, all of them test/flow.expect's ($e s)"
