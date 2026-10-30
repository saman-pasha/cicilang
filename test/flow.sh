#!/bin/sh
# test/flow.sh -- THE FLOW GATE (0.144): cocolog's library(flow/chart) reads every file of the library and says,
# without running anything, what will go wrong -- a call that nothing answers, a predicate defined twice, a clause
# no call can reach, an argument free where a builtin needs it bound, a recursion that never reads input, the
# clauses of a predicate split by another's -- each at its file, line and column. It runs FIRST in the chain and
# takes some two minutes (132 s at 0.230; 205 s on the same box while the desugaring's seventeen files were charted
# apart, 0.223 to 0.229), where the next RED of that
# kind cost the chain's hour: a mis-edited name, a helper given a name already taken (0.141's two definitions of one
# predicate), a clause a cut above it makes dead, a predicate in two files (0.223).
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
FILES="ccl_syntax ccl_pp ccl_include ccl_infer ccl_format ccl_cpp ccl_cpp_namespace ccl_cpp_mangle ccl_cpp_library
ccl_cpp_class ccl_cpp_layout ccl_cpp_overload ccl_cpp_virtual ccl_cpp_init ccl_cpp_stmt ccl_cpp_expr ccl_cpp_eval
ccl_cpp_template ccl_cpp_deduce ccl_cpp_traits ccl_cpp_lambda ccl_cpp_concept ccl_check ccl_ir ccl_build ccl_driver"   # ccl_cpp and its sixteen parts (0.223)
# THE DESUGARING'S SEVENTEEN FILES ARE CHARTED AS ONE PROGRAM (0.230): joined, in their order, into ccl_cpp_all.pl with one
# root over all their predicates (fg_roots_main/3), so a call from one part into another is charted, not a box, and each
# finding is put back at its part's own file and line (src/joined.txt). Charted apart (0.223 to 0.229), each part's chart
# worked to its own fixed point and the gate took 205 s, where the one program lets it take 132 s on the same box
PARTS="ccl_cpp ccl_cpp_namespace ccl_cpp_mangle ccl_cpp_library ccl_cpp_class ccl_cpp_layout ccl_cpp_overload
ccl_cpp_virtual ccl_cpp_init ccl_cpp_stmt ccl_cpp_expr ccl_cpp_eval ccl_cpp_template ccl_cpp_deduce ccl_cpp_traits
ccl_cpp_lambda ccl_cpp_concept"
JOINED=ccl_cpp_all
ALONE=""; for f in $FILES; do case " $(echo $PARTS) " in *" $f "*) ;; *) ALONE="$ALONE${ALONE:+ }$f" ;; esac; done   # the library's other nine, each charted alone
TFILES="reader compile cpp readhdr census libcxx flow why prof"   # THE GATES' OWN PROLOG (0.161), charted as the library is: a mis-edit in a gate
fg_path() { case " $TFILES " in *" $1 "*) echo "test/$1.pl" ;; *) echo "library/$1.pl" ;; esac; }
if [ -n "$FLOW_KEEP" ]; then D=$FLOW_KEEP; rm -rf "$D"; mkdir -p "$D"; else D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-flow-XXXXXX"); trap 'rm -rf "$D"' EXIT; fi
mkdir -p "$D/src" "$D/out" "$D/res" "$D/stub"
start=$(date +%s)

# the copies with their roots
list=""; for f in $FILES $TFILES; do list="$list${list:+,}'$ROOT/$(fg_path $f)'"; done
plist=""; for f in $PARTS; do plist="$plist${plist:+,}'$ROOT/library/$f.pl'"; done
out=$(cd "$ROOT" && timeout -s KILL 300 "$C" --local query "use_module(library(cicilang)), ensure_loaded('$ROOT/test/flow.pl'), fg_roots_main([$list], join('$JOINED.pl', [$plist]), '$D/src')" 2>&1 < /dev/null)
[ -f "$D/src/roots.txt" ] || { echo "RED: the roots were not written"; printf '%s\n' "$out" | tail -10; exit 1; }
echo "-- every library file and gate program charted from a root that calls each predicate it defines ($(awk -v parts=" $(echo $PARTS) " '{ b = $1; sub(/\.pl$/, "", b) } index(parts, " " b " ") == 0 { s += $3 } END { print s }' "$D/src/roots.txt") predicates)"   # a part's own copy is written, not charted
# A PREDICATE IN TWO FILES is RED (0.223; fg_twice/2): one namespace, so it is one predicate read from two places,
# which no chart sees -- the desugaring's seventeen files among the library's, a gate program beside the library
[ -f "$D/src/twice.txt" ] || { echo "RED: the roots were written, the check of a predicate in two files was not"; exit 1; }
if [ -s "$D/src/twice.txt" ]; then
  echo "RED: $(wc -l < "$D/src/twice.txt" | tr -d ' ') predicate(s) defined in two files -- one namespace: each is one predicate read from two places"
  sed 's/^/     /' "$D/src/twice.txt"; exit 1
fi
echo "-- no predicate defined in two files: the $(echo $FILES | wc -w | tr -d ' ') of the library, and none of them in a gate program"

# one job a file, the heaviest first
loads="[library(cicilang), library(ccl_llvm), library(ccl_bidrt), library(ccl_uninames), library(ccl_xid), library(ccl_format)]"   # the generated tables loaded, not charted (ccl_xid: 0.221)
tloads="[library(cicilang), library(ccl_llvm), library(ccl_bidrt), library(ccl_uninames), library(ccl_xid), library(ccl_format), library(os), library(process), library(stream), library(flow/debug)]"
mods="['$ROOT/module/cicilang.cicili', '$ROOT/module/ccl_llvm.cicili']"
for f in $ALONE; do
  n=$(awk -v b="$f.pl" '$1 == b { print $2 }' "$D/src/roots.txt")
  mkdir -p "$D/stub/$f"; : > "$D/stub/$f/$f.pl"
  echo "$f COCOLOG_LIBRARY='$D/stub/$f:$COCOLOG_LIBRARY' fg_job $f $n"
done > "$D/jobs0"
n=$(awk -v b="$JOINED.pl" '$1 == b { print $2 }' "$D/src/roots.txt")   # the joined parts: each of the seventeen stubbed, so each is read once
mkdir -p "$D/stub/$JOINED"; for p in $PARTS; do : > "$D/stub/$JOINED/$p.pl"; done
echo "$JOINED COCOLOG_LIBRARY='$D/stub/$JOINED:$COCOLOG_LIBRARY' fg_job $JOINED $n" >> "$D/jobs0"
for f in $TFILES; do   # a gate program is no library file: nothing to stub, and the flow library its own two load beside the rest
  n=$(awk -v b="$f.pl" '$1 == b { print $2 }' "$D/src/roots.txt")
  echo "$f fg_job $f $n"
done >> "$D/jobs0"
ccl_lpt_order "$FLOW_TIMES" < "$D/jobs0" | sed 's/^[^ ]* //' > "$D/jobs"
fg_job() {   # fg_job FILE ARITY: chart the copy, write the verdict line; its own variable names (sh has no locals, 0.107)
  _fj_s=$(date +%s)
  case " $TFILES " in *" $1 "*) _fj_l=$tloads ;; *) _fj_l=$loads ;; esac
  timeout -s KILL "$FLOW_SECS" "$C" --local query "use_module(library(flow/chart)), ensure_loaded('$ROOT/test/flow.pl'), fg_findings_main('$D/src/$1.pl', $2, $_fj_l, $mods, '$D/out/$1.txt')" > "$D/out/$1.log" 2>&1 < /dev/null
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
for f in $ALONE $JOINED $TFILES; do
  r=$(cat "$D/res/$f" 2>/dev/null || echo "FAIL $f: no verdict")
  if [ "$f" = "$JOINED" ]; then w="library/ccl_cpp.pl and its sixteen parts, one program,"; else w=$(fg_path $f); fi
  case "$r" in
    ok*) set -- $r; echo "ok   $w charted in $3 s: $(wc -l < "$D/out/$f.txt" | tr -d ' ') findings" ;;
    *) echo "$r"; tail -5 "$D/out/$f.log" 2>/dev/null | sed 's/^/     /'; bad=1 ;;
  esac
done
[ "$bad" -eq 0 ] || { echo "RED: a file was not charted"; exit 1; }
# each finding keyed at its file: the joined program's at the part whose lines hold it, its line counted from the part's first
for f in $ALONE $JOINED $TFILES; do
  if [ "$f" = "$JOINED" ]; then jm="$D/src/joined.txt"; else jm=/dev/null; fi
  awk -F '\t' -v file="$(fg_path $f)" -v root="$ROOT/" 'FILENAME != ARGV[2] { split($0, a, " "); n++; fl[n] = a[1]; lo[n] = a[2]; hi[n] = a[3]; next }
  {
      kind = $1; sev = $2; in_ = $3; text = $6; fi_ = file; ln = $4
      for (i = 1; i <= n; i++) if (ln >= lo[i] && ln <= hi[i]) { fi_ = fl[i]; if (index(fi_, root) == 1) fi_ = substr(fi_, length(root) + 1); ln = ln - lo[i] + 1; break }
      if (kind == "discontiguous" || kind == "defined_twice") key = kind " " sev " " fi_ " " in_
      else if (kind == "unknown_procedure") { c = text; sub(/ is defined nowhere.*/, "", c); key = kind " " sev " " fi_ " " in_ " " c }
      else { t = text; gsub(/[0-9]+/, "N", t); key = kind " " sev " " fi_ " " in_ " " t }
      print key "\t" fi_ ":" ln ":" $5 ": " sev ": " in_ ": " text
  }' "$jm" "$D/out/$f.txt"
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
