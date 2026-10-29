#!/bin/sh
# test/gates.sh -- run every gate, in the order and the parallelism that suits it (0.105).
# The TOOLCHAIN check comes first (0.223): every tool the gates need, beside test/toolchain.pins,
# in seconds (test/toolchain.sh). Then the FLOW gate (0.144): cocolog's library(flow/chart) reads
# the library without running it and names a call nothing answers, a predicate defined twice, a
# clause never tried, in some three minutes, its files charted in parallel (test/flow.sh).
# The four small gates and the proof are one cocolog process each and fast, so they run one
# after another. Then the LIBRARY READ (test/libcxx.sh) reads every library header cold in
# parallel and leaves the C++ summary cache warm -- it replaces the old separate warm.sh.
# Then the C++ gate (test/cpp.sh) builds its fixtures in parallel over that warm cache. So
# the two phases that took five hours between them -- a serial warm and a serial libc++ read
# of the same headers -- are one parallel read, and the C++ gate's 176 builds run four at a
# time instead of one. Each phase names its checks, seconds and peak; a RED stops the chain.
#
#   sh test/gates.sh                     # the toolchain check, then all nine, in one chain
#   GATES_JOBS=3 sh test/gates.sh        # narrower parallelism (a smaller box)
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
J=${GATES_JOBS:-4}
export LX_JOBS="$J" CPP_JOBS="$J" FLOW_JOBS="$J"
fail=0
run() {   # run NAME SCRIPT...: time it, print its GREEN/RED line and elapsed, stop the chain on RED
  name=$1; shift; s=$(date +%s)
  "$@"; rc=$?; e=$(( $(date +%s) - s ))
  if [ "$rc" -eq 0 ]; then echo "== $name: GREEN in ${e} s"; else echo "== $name: RED (exit $rc) in ${e} s"; fail=1; fi
  return "$rc"
}
run toolchain sh "$HERE/toolchain.sh" || exit 1   # first of all (0.223): every tool the gates need, beside test/toolchain.pins -- seconds
run flow     sh "$HERE/flow.sh"    || exit 1   # first (0.144): the library read by library(flow/chart), nothing run -- three minutes (0.223), where a mis-edit cost the chain's hour
run reader   sh "$HERE/reader.sh"  || exit 1
run compile  sh "$HERE/compile.sh" || exit 1
run driver   sh "$HERE/driver.sh"  || exit 1
run objects  sh "$HERE/objects.sh" || exit 1
run proof    sh "$HERE/../proof/run.sh" || exit 1
run cross    sh "$HERE/cross.sh"   || exit 1   # another machine (0.131): aarch64 Linux under qemu, a SKIP without the cross tools
run libcxx   sh "$HERE/libcxx.sh"  || exit 1
run cpp      sh "$HERE/cpp.sh"     || exit 1
[ "$fail" -eq 0 ] && echo "ALL GREEN" || echo "SOME RED"
exit "$fail"
