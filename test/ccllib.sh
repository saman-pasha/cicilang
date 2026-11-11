#!/bin/sh
# The ccllib gate (0.273): THE THREE RUNS of CCLLIB.md's Tests and measures (the owner's decision of 2026-11-08). Each
# program of test/ccllib is one ccllib program, NAME.c, and its twin over std::, NAME.cpp: cicilang builds NAME.c as C,
# cicilang++ builds it as C++, and the reference clang++ ($LLVM's, else the one on the path) builds the twin over its
# libc++. The three print the same lines, NAME.expect, which the twin made; with NAME.count, a count for a longer run
# (`first 2000000'), the three print the same lines for that run too. cicilang++ builds NAME.c AT THE TWIN'S LEVEL too
# (0.284; CCLLIB_STD, c++23), and that build prints NAME.expect: until then an instance's `v[i]' was C++'s own at
# C++23, where a subscript takes a list of arguments, and every ccllib program with an index was refused there.
#
# EVERY BLOCK IS FREED: where valgrind is, each of the three runs under it with no error and no block left, the longer
# run with a count of 5000 too -- an object is dropped where its scope ends, a moved one by who took it (the autodrop of
# 0.262, whose own fixtures every machine runs). No valgrind: the check is skipped by name, never a RED for what the box
# lacks.
#
# WHAT THE SAFE PART REFUSES (0.274): each test/ccllib/safe/NAME.c is refused by cicilang as C and by cicilang++ as C++,
# with the words of NAME.expect (NAME.expect.cpp where C++ has words of its own) -- a borrow of a vector's buffer used
# after a call that may replace it, a vector used after its move, an element that a container does not take. They
# stand here and not in test/c/safe: the compile gate reads its fixtures in one process, where two macro files that
# define one predicate (the fixtures' type_vector/3 and ccllib's) are one.
#
# THE PROGRAMS THAT STAND ALONE (0.281): each test/ccllib/alone/NAME.c has no twin over std::, since it asks what C++
# does not say. cicilang builds it as C and cicilang++ as C++, and both print NAME.expect. stops.c: WHAT STOPS A CCLLIB
# PROGRAM -- each of its cases goes past what a container holds (an index past the end, the front of an empty one, a
# place that a new entry of a map ended) in a child of its own, and a line says for each whether abort stopped it; C++
# throws there, or says nothing of what follows. tree_rules.c: the rules of the tree of <set.pl> and <map.pl>, read
# from the instance's own fields over a walk of chance; table_rules.c (0.283): the rules of the hash table of
# <unordered_set.pl> and <unordered_map.pl>, read so too; bitset_rules.c (0.286): the rules of <bitset.pl>'s set of
# bits, held to a model of a byte a bit at the counts where a rule can break, the bits of its last word past the count
# read in the instance's own words.
#
# THE COSTS, a line a run, are a record and no check: the build of the program (the best of CCLLIB_REPEAT: its seconds
# and the megabytes of its largest process), the IR's types, functions and lines, the object's bytes, and the longer
# run, built at -O2 (its seconds and megabytes). test/cost.c measures, built by cc: the wall clock, and wait4's
# ru_maxrss. The store and the summaries are the HOME's, warm from the builds of the checks.
#
# A BUILD IS THE BUILD AFTER A CHANGE OF THE FILE (0.289): the program is a copy whose time changes before each timed
# build, so that the store serves the headers and the program is read, checked and lowered again -- what a programmer
# meets at each edit, and what clang++'s build of the twin does at each build. Until 0.289 the C line timed a build of
# the file as it was, which the store serves from the IR that it kept (dr_ir/3): a rebuild of a file that did not
# change, a third to a half of the build after a change. A FOURTH LINE, `cicilang, C, unchanged', keeps that number.
# The C++ builds have no kept IR (CICILANG_NO_IR_CACHE, test/config.sh), so each reads its program as it is.
#
#   sh test/ccllib.sh
#   LLVM=/usr/lib/llvm-22 sh test/ccllib.sh     # the C++ build and the twin over that tree's libc++
#   CCLLIB_COSTS=0 sh test/ccllib.sh            # the checks alone
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cicilang.so" ] || { echo "SKIP (no library/cicilang.so -- sh module/build.sh)"; exit 0; }
D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-ccllib-XXXXXX")
trap 'rm -rf "$D"' EXIT
T="$ROOT/test/ccllib"
CCLLIB_SECS=${CCLLIB_SECS:-600}             # a build's cap: timeout kills the process group it leads, cocolog included
CCLLIB_RUN_SECS=${CCLLIB_RUN_SECS:-120}     # a run's cap
CCLLIB_STD=${CCLLIB_STD:-c++23}             # the twin's level
CCLLIB_COSTS=${CCLLIB_COSTS:-1}; CCLLIB_REPEAT=${CCLLIB_REPEAT:-3}
failures=0; nprog=0
# THE REFERENCE CLANG++, as the C++ gate finds it: the tree's, else the one on the path; on a Mac it is given the SDK.
# The twin runs over the tree's libc++ too, where the tree has one (the run path), as cicilang++'s link names it.
CXXREF=clang++; [ -n "$LLVM" ] && [ -x "$LLVM/bin/clang++" ] && CXXREF="$LLVM/bin/clang++"
CXXSDK=""; [ "$(uname -s)" = Darwin ] && CXXSDK=$(xcrun --show-sdk-path 2>/dev/null) && [ -d "$CXXSDK" ] || CXXSDK=""
CXXRUN=""; [ -n "$LLVM" ] && [ -f "$LLVM/lib/libc++.so.1" ] && CXXRUN="-Wl,-rpath,$LLVM/lib"
# its command is a file, so that test/cost.c runs it as it runs the two others
{ echo '#!/bin/sh'; echo "exec \"$CXXREF\" ${CXXSDK:+-isysroot \"$CXXSDK\"} -std=$CCLLIB_STD -stdlib=libc++ -w $CXXRUN \"\$@\""; } > "$D/twin"; chmod +x "$D/twin"
ccl_twin() { "$D/twin" "$@"; }
printf '#include <vector>\n#include <version>\nint main() { std::vector<int> v; v.push_back(_LIBCPP_VERSION); return v.size() != 1; }\n' > "$D/ref.cpp"
twin=no; if command -v "$CXXREF" > /dev/null 2>&1 && ccl_twin "$D/ref.cpp" -o "$D/ref" > "$D/ref.log" 2>&1 && "$D/ref"; then twin=yes; fi
if [ "$twin" = yes ]; then
  printf '#include <version>\nccl_libcxx _LIBCPP_VERSION\n' > "$D/ver.cpp"
  lv=$(ccl_twin -E "$D/ver.cpp" 2>/dev/null | awk '$1 == "ccl_libcxx" { print int($2 / 10000) }')
  cv=$("$CXXREF" --version 2>/dev/null | sed -n '1s/.*version \([0-9][0-9.]*\).*/\1/p')
  who="clang++ $cv over libc++ $lv"
fi
vg=no; command -v valgrind > /dev/null 2>&1 && vg=yes
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; shift; for l in "$@"; do printf '%s\n' "$l" | head -6 | cut -c1-300 | sed 's/^/     /'; done; failures=$((failures + 1)); }
# ccl_ran BIN OUT [ARG]: what BIN prints and returns, to OUT
ccl_ran() { _r_b=$1; _r_o=$2; shift 2; { timeout -s KILL "$CCLLIB_RUN_SECS" "$_r_b" "$@" < /dev/null 2>&1; echo "exit $?"; } > "$_r_o"; }
# ccl_freed BIN LOG [ARG]: under valgrind BIN has no error and leaves no block
ccl_freed() {
  _f_b=$1; _f_l=$2; shift 2
  timeout -s KILL "$CCLLIB_RUN_SECS" valgrind --leak-check=full --error-exitcode=99 "$_f_b" "$@" > /dev/null 2> "$_f_l" < /dev/null || return 1
  grep -aq 'All heap blocks were freed' "$_f_l" && grep -aq 'ERROR SUMMARY: 0 errors' "$_f_l"
}
echo "-- the three runs (CCLLIB.md, Tests and measures): a ccllib program built by cicilang as C and by cicilang++ as C++, and its twin over std:: built by ${who:-clang++}, print the same lines"
for src in "$T"/*.c; do
  [ -f "$src" ] || continue
  n=$(basename "$src" .c); nprog=$((nprog + 1)); want="$T/$n.expect"; cnt=""; [ -f "$T/$n.count" ] && cnt=$(cat "$T/$n.count")
  # the C build and the C++ build, each against NAME.expect
  for how in c cpp; do
    if [ "$how" = c ]; then cmd="$ROOT/bin/cicilang"; as="C by cicilang"; else cmd="$ROOT/bin/cicilang++"; as="C++ by cicilang++"; fi
    if timeout -s KILL "$CCLLIB_SECS" "$cmd" "$src" -o "$D/${n}_$how" > "$D/${n}_$how.log" 2>&1 < /dev/null; then
      ccl_ran "$D/${n}_$how" "$D/${n}_$how.out"
      if cmp -s "$D/${n}_$how.out" "$want"; then ok "$n.c, built as $as, prints what its twin prints"
      else bad "$n.c, built as $as, prints what its twin prints" "$(diff "$want" "$D/${n}_$how.out" 2>&1)"; fi
    else bad "$n.c builds as $as" "$(cat "$D/${n}_$how.log")"; rm -f "$D/${n}_$how"; fi
  done
  # the C++ build at the twin's level (0.284)
  if timeout -s KILL "$CCLLIB_SECS" "$ROOT/bin/cicilang++" "-std=$CCLLIB_STD" "$src" -o "$D/${n}_std" > "$D/${n}_std.log" 2>&1 < /dev/null; then
    ccl_ran "$D/${n}_std" "$D/${n}_std.out"
    if cmp -s "$D/${n}_std.out" "$want"; then ok "$n.c, built as C++ at the twin's level ($CCLLIB_STD), prints what its twin prints"
    else bad "$n.c, built as C++ at the twin's level ($CCLLIB_STD), prints what its twin prints" "$(diff "$want" "$D/${n}_std.out" 2>&1)"; fi
  else bad "$n.c builds as C++ at the twin's level ($CCLLIB_STD)" "$(cat "$D/${n}_std.log")"; fi
  rm -f "$D/${n}_std"
  # the twin, which made NAME.expect
  if [ "$twin" = yes ]; then
    if ccl_twin "$T/$n.cpp" -o "$D/${n}_twin" > "$D/${n}_twin.log" 2>&1; then
      ccl_ran "$D/${n}_twin" "$D/${n}_twin.out"
      if cmp -s "$D/${n}_twin.out" "$want"; then ok "$n.cpp, the twin over std::, built by $who, prints $n.expect"
      else bad "$n.cpp, the twin over std::, built by $who, prints $n.expect" "$(diff "$want" "$D/${n}_twin.out" 2>&1)"; fi
    else bad "$n.cpp, the twin over std::, builds by $who" "$(cat "$D/${n}_twin.log")"; rm -f "$D/${n}_twin"; fi
  else echo "SKIP $n.cpp (not here)"; fi
  # the longer run: the three agree on it too
  if [ -n "$cnt" ]; then
    ref=""; said=""
    for how in twin c cpp; do
      [ -x "$D/${n}_$how" ] || continue
      ccl_ran "$D/${n}_$how" "$D/${n}_$how.long" "$cnt"
      if [ -z "$ref" ]; then ref="$D/${n}_$how.long"; elif ! cmp -s "$ref" "$D/${n}_$how.long"; then said="$said $how"; fi
    done
    if [ -n "$ref" ] && [ -z "$said" ] && grep -aq '^exit 0$' "$ref"; then ok "$n $cnt: the runs print the same line ($(sed -n 1p "$ref" | cut -c1-60))"
    else bad "$n $cnt: the runs print the same line" "not as the first:${said:- none; it did not end with exit 0}" "$(cat "$ref" 2>/dev/null)"; fi
  fi
  # and no block is left, under valgrind
  if [ "$vg" = yes ]; then
    left=""
    for how in c cpp twin; do
      [ -x "$D/${n}_$how" ] || continue
      ccl_freed "$D/${n}_$how" "$D/${n}_$how.vg" || left="$left $how"
      if [ -n "$cnt" ]; then ccl_freed "$D/${n}_$how" "$D/${n}_$how.vgl" 5000 || left="$left $how(5000)"; fi
    done
    # an instruction that valgrind does not know stops the run with its blocks in use: the report names it (0.283)
    if [ -z "$left" ]; then ok "$n: under valgrind each run has no error and frees every block${cnt:+, with a count of 5000 too}"
    else bad "$n: under valgrind each run has no error and frees every block" "not so:$left" "$(for h in c cpp twin; do grep -a 'Unrecognised instruction\|ERROR SUMMARY\|definitely lost\|in use at exit' "$D/${n}_$h.vg" "$D/${n}_$h.vgl" 2>/dev/null; done)"; fi
  else echo "SKIP $n.valgrind (not here)"; fi
done
[ "$nprog" -gt 0 ] || { echo "RED: ccllib (no program in test/ccllib)"; exit 1; }
nsafe=0
if ls "$T"/safe/*.c > /dev/null 2>&1; then
  echo "-- and the safe part refuses what a ccllib program may not do (test/ccllib/safe), as C and as C++"
  for src in "$T"/safe/*.c; do
    n=$(basename "$src" .c); nsafe=$((nsafe + 1))
    for how in c cpp; do
      w=$(cat "$T/safe/$n.expect")
      if [ "$how" = c ]; then cmd="$ROOT/bin/cicilang"; as="C"; else cmd="$ROOT/bin/cicilang++"; as="C++"; [ -f "$T/safe/$n.expect.cpp" ] && w=$(cat "$T/safe/$n.expect.cpp"); fi
      got=$(timeout -s KILL "$CCLLIB_SECS" "$cmd" -c "$src" -o "$D/safe_${n}_$how.o" 2>&1 < /dev/null; echo "exit $?")
      case "$got" in *"$w"*"exit 1") ok "safe/$n.c, as $as, is refused: $w" ;; *) bad "safe/$n.c, as $as, should be refused: $w" "$got" ;; esac
    done
  done
fi
nalone=0
if ls "$T"/alone/*.c > /dev/null 2>&1; then
  echo "-- and the programs that stand alone, with no twin (test/ccllib/alone): what stops a ccllib program, and the rules of the tree, of the hash table, of the bitset and of the string, as C and as C++"
  for src in "$T"/alone/*.c; do
    n=$(basename "$src" .c); nalone=$((nalone + 1))
    for how in c cpp; do
      if [ "$how" = c ]; then cmd="$ROOT/bin/cicilang"; as="C by cicilang"; else cmd="$ROOT/bin/cicilang++"; as="C++ by cicilang++"; fi
      if timeout -s KILL "$CCLLIB_SECS" "$cmd" "$src" -o "$D/alone_${n}_$how" > "$D/alone_${n}_$how.log" 2>&1 < /dev/null; then
        ccl_ran "$D/alone_${n}_$how" "$D/alone_${n}_$how.out"
        if cmp -s "$D/alone_${n}_$how.out" "$T/alone/$n.expect"; then ok "alone/$n.c, built as $as, prints $n.expect"
        else bad "alone/$n.c, built as $as, prints $n.expect" "$(diff "$T/alone/$n.expect" "$D/alone_${n}_$how.out" 2>&1)"; fi
      else bad "alone/$n.c builds as $as" "$(cat "$D/alone_${n}_$how.log")"; fi
    done
  done
fi
# ---- the costs: a record, no check ------------------------------------------------------------------------------
# ccl_cost OUT CMD...: the best of CCLLIB_REPEAT runs of CMD -- its seconds and megabytes to OUT, `- -' for one that fails.
# Where _c_touch names a file, the file takes a new time before each run (ccl_new_time)
ccl_cost() {
  _c_o=$1; shift; _c_s=""; _c_k=""; _c_i=0
  while [ "$_c_i" -lt "$CCLLIB_REPEAT" ]; do
    _c_i=$((_c_i + 1)); [ -z "$_c_touch" ] || ccl_new_time "$_c_touch"
    "$D/cost" "$D/cost.one" "$@" > /dev/null 2>&1 < /dev/null || { echo "- -" > "$_c_o"; return 1; }
    read -r _c_s1 _c_k1 < "$D/cost.one"
    if [ -z "$_c_s" ] || awk -v a="$_c_s1" -v b="$_c_s" 'BEGIN { exit !(a < b) }'; then _c_s=$_c_s1; _c_k=$_c_k1; fi
  done
  awk -v s="$_c_s" -v k="$_c_k" 'BEGIN { printf "%.3f %.1f\n", s, k / 1024 }' > "$_c_o"
}
# ccl_new_time FILE: FILE takes a time that it did not have, a minute a call from the first of January 2001 (POSIX's
# `touch -t', which a Mac's touch has too): the store's key of a unit is its file's time
_c_n=0
ccl_new_time() {
  _c_n=$((_c_n + 1))
  touch -t "200101$(printf '%02d%02d%02d' $((1 + _c_n / 1440 % 28)) $((_c_n / 60 % 24)) $((_c_n % 60)))" "$1"
}
ccl_ir() { [ -f "$1" ] && echo "$(grep -ac '^%[^ ]* = type' "$1") $(grep -ac '^define ' "$1") $(wc -l < "$1" | tr -d ' ')" || echo "- - -"; }
ccl_size() { [ -f "$1" ] && wc -c < "$1" | tr -d ' ' || echo "-"; }
if [ "$CCLLIB_COSTS" != 0 ]; then
  if cc -O1 -o "$D/cost" "$HERE/cost.c" > "$D/cost.log" 2>&1; then
    mkdir -p "$D/edit"; for f in "$T"/*.pl "$T"/*.pl.h; do [ -f "$f" ] && cp "$f" "$D/edit/"; done   # the programs' own macro files
    for src in "$T"/*.c; do
      n=$(basename "$src" .c); cnt=""; [ -f "$T/$n.count" ] && cnt=$(cat "$T/$n.count")
      cp "$src" "$D/edit/$n.c"
      echo "-- the costs of $n, a line a run: the program's build after a change of the file (the best of $CCLLIB_REPEAT: seconds, the megabytes of its largest process), the IR's types, functions and lines, the object's bytes, and \`$n${cnt:+ $cnt}' built at -O2 (seconds, megabytes); a fourth line, the C build of the file unchanged, which the store serves"
      printf '     %-24s %8s %7s %6s %10s %7s %9s %8s %7s\n' "run" "build s" "MB" "types" "functions" "lines" "object B" "run s" "MB"
      for how in c cpp twin again; do
        _c_touch=""; chg=""
        case $how in
          c)    label="cicilang, C";     in="$D/edit/$n.c"; chg=$in; set -- timeout -s KILL "$CCLLIB_SECS" "$ROOT/bin/cicilang" ;;
          cpp)  label="cicilang++, C++"; in="$D/edit/$n.c"; chg=$in; set -- timeout -s KILL "$CCLLIB_SECS" "$ROOT/bin/cicilang++" ;;
          twin) [ "$twin" = yes ] || continue
                label="clang++ $cv, std::"; in="$T/$n.cpp"; set -- "$D/twin" ;;
          again) # the C build of the file as it is: the store serves its kept IR
                "$ROOT/bin/cicilang" "$D/edit/$n.c" -o "$D/c_${n}_again" > /dev/null 2>&1 < /dev/null
                ccl_cost "$D/c_build" timeout -s KILL "$CCLLIB_SECS" "$ROOT/bin/cicilang" "$D/edit/$n.c" -o "$D/c_${n}_again"
                read -r bs bm < "$D/c_build"
                printf '     %-24s %8s %7s %6s %10s %7s %9s %8s %7s\n' "cicilang, C, unchanged" "$bs" "$bm" "-" "-" "-" "-" "-" "-"
                continue ;;
        esac
        if [ "$how" = twin ]; then "$@" -S -emit-llvm "$in" -o "$D/c_${n}_$how.ll" > /dev/null 2>&1 < /dev/null
        else "$@" -emit-llvm -c "$in" -o "$D/c_${n}_$how.ll" > /dev/null 2>&1 < /dev/null; fi
        "$@" -c "$in" -o "$D/c_${n}_$how.o" > /dev/null 2>&1 < /dev/null
        _c_touch=$chg; ccl_cost "$D/c_build" "$@" "$in" -o "$D/c_${n}_$how"; _c_touch=""
        if "$@" -O2 "$in" -o "$D/c_${n}_$how.o2" > /dev/null 2>&1 < /dev/null; then ccl_cost "$D/c_run" timeout -s KILL "$CCLLIB_RUN_SECS" "$D/c_${n}_$how.o2" $cnt; else echo "- -" > "$D/c_run"; fi
        read -r bs bm < "$D/c_build"; read -r rs rm < "$D/c_run"; set -- $(ccl_ir "$D/c_${n}_$how.ll")
        printf '     %-24s %8s %7s %6s %10s %7s %9s %8s %7s\n' "$label" "$bs" "$bm" "$1" "$2" "$3" "$(ccl_size "$D/c_${n}_$how.o")" "$rs" "$rm"
      done
    done
  else echo "-- the costs are not measured: cc did not build test/cost.c ($(head -1 "$D/cost.log" | cut -c1-160))"; fi
fi
runs="three runs"; [ "$twin" = yes ] || runs="two runs: no clang++ over libc++ here builds the twins"
if [ "$failures" -eq 0 ]; then echo "GREEN: ccllib ($nprog program(s) in $runs, $nsafe refused, $nalone alone)"; else echo "RED: ccllib ($failures failure(s))"; exit 1; fi
