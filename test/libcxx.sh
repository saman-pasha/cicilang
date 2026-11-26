#!/bin/sh
# The road to libc++, AND the warm the C++ gate needs -- one cold parallel pass (0.105).
# Until 0.104 this was two serial phases doing the same expensive work twice: test/warm.sh
# flattened and read every library header to write its summary, and this gate flattened and
# read the SAME headers again under a fresh HOME to assert each reads whole. cocolog's
# summaries are keyed by the reader version and every dep's mtime, so a version bump makes
# them all cold anyway and the fresh HOME was redundant; here the phase wipes the target
# cache, reads the UNION of the library-asserted headers and the fixtures' headers cold, in
# parallel through the pool (test/parlib.sh), asserts the item count for the library subset,
# and LEAVES the summaries written -- so test/cpp.sh after it is fully warm and needs no
# separate warm.sh. One cold read of each header per gate run, across the cores.
#
#   sh test/libcxx.sh                 # writes ~/.cicilang/cpp, asserts the counts
#   LX_HOME=/tmp/x sh test/libcxx.sh  # a throwaway cache instead of the user's
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
. "$HERE/parlib.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cicilang.so" ] || { echo "SKIP (no library/cicilang.so -- sh module/build.sh)"; exit 0; }
LX_JOBS=${LX_JOBS:-4}; LX_LAUNCH_MB=${LX_LAUNCH_MB:-9000}; LX_HARD_MB=${LX_HARD_MB:-14000}
LX_SECS=${LX_SECS:-2400}   # one read's cap: coreutils' timeout kills the process group it leads, the cocolog grandchild included
WARMHOME=${LX_HOME:-$HOME}
D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-libcxx-XXXXXX")
trap 'rm -rf "$D"' EXIT
export CCL_TEST_TMP="$D"
# COLD: wipe the target summary cache, so every read below is a genuine WHOLE read (the proof)
# and a clean warm (the product). It is only a cache; the store is elsewhere.
rm -rf "$WARMHOME/.cicilang/cpp"

# THE LIBRARY-ASSERTED SET (header level min min23): each must read whole to at least Min items,
# a floor under the counts of libc++ 18 and of libc++ 21 (which includes less at C++23: <optional> 397 -> 222 items, <string> 522 -> 410), the proof this gate has always made. At C++17 unless a level is named.
# MIN23 IS THE FLOOR OF A TREE WITHOUT TRANSITIVE INCLUDES (1.6.21): libc++ 23 includes no header that it does not use, at
# every level (_LIBCPP_KEEP_TRANSITIVE_INCLUDES_LLVM23 keeps them) -- clang 23's own preprocessor brings 451 headers and
# 12,321 lines for <vector> at C++17, where libc++ 22's brought 931 and 36,830 -- and its counts at C++17 and C++20 are
# what its C++23 ones are: <vector> 336 items at C++17 (libc++ 22's 784), <ranges> 449 at C++20. Each is about a tenth
# under libc++ 23's count, taken where the tree read is libc++ 23 or later (its _LIBCPP_VERSION, lx_notrans)
asserted="vector 17 400 300
string 17 400 300
iostream 17 600 300
map 17 400 290
set 17 400 290
unordered_map 17 300 260
unordered_set 17 300 260
optional 17 150 150
memory 17 300 260
functional 17 400 320
tuple 17 150 150
compare 20 300 130
vector 20 750 370
string 20 700 350
iostream 20 750 350
set 20 450 340
map 20 450 340
unordered_map 20 350 310
unordered_set 20 350 310
ranges 20 900 400
optional 23 200 200
string 23 380 350
optional 26 200 200"

# THE FIXTURES' HEADER-LEVEL UNION (warm only): every header test/cpp/*.cpp and
# test/cpp/run/*.cpp include, at the level its .flags gives and at C++17, plus Cicili's own
# test/cpp/*.cpp that the reader's gate reads whole (<sstream>, <stdexcept>). This is what
# test/warm.sh warmed; it is folded in here so the C++ gate is warm after this one phase.
# A line is `STD CFG HEADER': CFG the configuration flags the .flags names, joined by `,' (0.191: -fno-rtti, whose
# summaries are keyed apart), else `-'
ccl_union() {
  for f in "$ROOT"/test/cpp/*.cpp "$ROOT"/test/cpp/run/*.cpp "$CICILI"/test/cpp/*.cpp; do
    std=17; cfg=-; fl="${f%.cpp}.flags"; [ -f "$fl" ] && std=$(sed -n 's/.*-std=c++\([0-9]*\).*/\1/p' "$fl"); [ -n "$std" ] || std=17
    [ -f "$fl" ] && cfg=$(tr ' ' '\n' < "$fl" | grep -x -e '-fno-rtti' -e '-fno-exceptions' | sort | tr '\n' ',' | sed 's/,$//'); [ -n "$cfg" ] || cfg=-
    sed -n 's/^#include <\([^>]*\)>.*/\1/p' "$f" | sed "s/^/$std $cfg /"
  done | sort -u
}
[ -n "$(ls "$CICILI"/test/cpp/*.cpp 2>/dev/null)" ] || echo "-- note: no C++ test files under CICILI=$CICILI -- Cicili's headers (<sstream>, <stdexcept>) are NOT warmed"

RES="$D/res"; mkdir -p "$RES"
# each read's seconds, kept OUTSIDE the wiped cpp/ directory, so the next run starts the longest first
LX_TIMES=${LX_TIMES:-$WARMHOME/.cicilang/header-times}
# ONE ASSERTED HEADER: read whole in its own process (readhdr.pl), item count vs Min, summary written
ccl_read() {   # ccl_read HEADER STD MIN
  h=$1; std=$2; min=$3; t0=$(date +%s)
  timeout -s KILL "$LX_SECS" env CCL_HDR="$h" CCL_STD="$std" CCL_MIN="$min" CCL_TEST_TMP="$D" HOME="$WARMHOME" \
    "$C" --local query "ensure_loaded('$ROOT/test/readhdr.pl'), readhdr_main" > "$RES/a_${h}_${std}.res" 2>&1
  grep -aq "^ok\|^FAIL\|^warm" "$RES/a_${h}_${std}.res" || echo "FAIL <$h> at C++$std: the read did not finish" >> "$RES/a_${h}_${std}.res"
  grep -aq "^ok" "$RES/a_${h}_${std}.res" && ccl_time_record "$LX_TIMES" "$h@$std" $(( $(date +%s) - t0 ))   # a good read's seconds only
}
# ONE WARM-ONLY HEADER: a syntax-only build writes its summary; nothing is asserted
ccl_warm() {   # ccl_warm HEADER STD [CFG]: CFG as ccl_union gives it, the build's configuration flags
  h=$1; std=$2; cfg=${3:--}; t0=$(date +%s)
  case "$cfg" in -) fls=""; tag=""; key="$h@$std" ;; *) fls=$(echo "$cfg" | tr ',' ' '); tag=$(echo "$cfg" | tr ',' '_'); key="$h@$std@$cfg" ;; esac
  hf=$(echo "$h" | tr '/' '_')   # a header in a directory, <sys/wait.h>: its files' names hold no slash (0.200: the warm wrote into a directory that is not there, and the header was never warmed)
  f="$D/warm_${hf}_${std}${tag}.cpp"; printf '#include <%s>\nint main() { return 0; }\n' "$h" > "$f"
  if timeout -s KILL "$LX_SECS" env HOME="$WARMHOME" "$ROOT/bin/cicilang++" -std=c++$std $fls -fsyntax-only "$f" > "$RES/w_${hf}_${std}${tag}.out" 2>&1; then
    echo "warm <$h> C++$std${fls:+ $fls}" > "$RES/w_${hf}_${std}${tag}.res"; ccl_time_record "$LX_TIMES" "$key" $(( $(date +%s) - t0 ))
  else echo "warm <$h> C++$std${fls:+ $fls}: FAILED to flatten (a fixture including it will cold-flatten in the gate)" > "$RES/w_${hf}_${std}${tag}.res"; fi
}

# the asserted (header@std) as a key set, so the union's warm-only jobs skip them (read once); each key between
# blanks and matched WHOLE (0.180): `ostream@17' is a substring of `iostream@17', and <ostream> was never warmed
akeys=" $(printf '%s\n' "$asserted" | awk 'NF {printf "%s@%s ", $1, $2}')"
# the tree read: $LLVM's, else the newest /usr/lib/llvm-N, as the library takes it (ccl_llvm_roots/1); libc++ 23 and later
# keep no transitive include, and their floors are the table's fourth column
lx_tree=${LLVM:-$(ls -d /usr/lib/llvm-* 2>/dev/null | sort -t- -k2 -n | tail -1)}
lx_ver=$(grep -h -m1 '# *define _LIBCPP_VERSION [0-9]' "$lx_tree/include/c++/v1/__config" 2>/dev/null | awk '{ print $NF }')
lx_notrans=0; [ -n "$lx_ver" ] && [ "$lx_ver" -ge 230000 ] && lx_notrans=1
# every job keyed `HEADER@STD', ordered LONGEST FIRST by the last run's times (the unknown first),
# so a heavy header never starts last and holds the phase alone at its end
lx_start=$(date +%s)
{
  printf '%s\n' "$asserted" | while read -r h std min min23; do [ "$lx_notrans" = 1 ] && min=$min23; [ -n "$h" ] && echo "$h@$std ccl_read $h $std $min"; done
  ccl_union | while read -r std cfg h; do
    case "$cfg" in -) k="$h@$std" ;; *) k="$h@$std@$cfg" ;; esac
    case "$akeys" in *" $k "*) : ;; *) echo "$k ccl_warm $h $std $cfg" ;; esac
  done
} | ccl_lpt_order "$LX_TIMES" | sed 's/^[^ ]* //' | ccl_pool "$LX_JOBS" "$LX_LAUNCH_MB" "$LX_HARD_MB"
pool_rc=$?

failures=0
# the asserted verdicts first, in the list's order
printf '%s\n' "$asserted" | while read -r h std min; do [ -n "$h" ] && grep -a "^ok\|^FAIL" "$RES/a_${h}_${std}.res" 2>/dev/null; done
af=$(cat "$RES"/a_*.res 2>/dev/null | grep -ac "^FAIL")
wf=$(cat "$RES"/w_*.res 2>/dev/null | grep -ac "FAILED")
warmn=$(ls "$RES"/w_*.res 2>/dev/null | wc -l | tr -d ' ')
[ "$wf" -gt 0 ] && cat "$RES"/w_*.res 2>/dev/null | grep -a "FAILED"
echo "-- $warmn other header(s) warmed for the C++ gate ($wf failed to flatten); the phase took $(( $(date +%s) - lx_start )) s over $LX_JOBS lanes"
failures=$((af + wf))
# A SUMMARY'S AST FILE LOADS WITH NO WORD (1.6.21): it declares its two predicates discontiguous (ccl_ast_head/1), whose
# clauses alternate, and cocolog 3.67.0 and later warn at a load of clauses of one name that stand apart -- with no head,
# a warning for each change of predicate, thousands for a header, which the driver passes on to no one. The largest file
# that the reads above wrote, loaded alone, capped as one job of the pool and by time
lx_ast=$(ls -S "$WARMHOME/.cicilang/cpp/"*.ast.pl 2>/dev/null | head -1)
if [ -n "$lx_ast" ]; then
  echo "timeout -s KILL 600 \"$C\" --local query \"ensure_loaded('$lx_ast')\" > \"$D/astload.out\" 2>&1" | ccl_pool 1 2800 2800
  lx_w=$(grep -ac '^Warning' "$D/astload.out" 2>/dev/null)
  if [ "${lx_w:-0}" -eq 0 ] && grep -aq 'answer(s)\.$' "$D/astload.out"; then echo "ok   the largest summary's AST file, $(basename "$lx_ast"), loads with no warning"
  else echo "FAIL the AST file $(basename "$lx_ast") did not load silently: ${lx_w:-0} warning line(s)"; failures=$((failures + 1)); fi
fi
[ "$pool_rc" -ne 0 ] && { echo "RED: the read pool hit the hard memory cap (LX_HARD_MB=$LX_HARD_MB)"; failures=$((failures + 1)); }
if [ "$failures" -eq 0 ]; then echo "GREEN: libc++ (the reader), and the C++ summary cache is warm"; else echo "RED: $failures failure(s)"; exit 1; fi
