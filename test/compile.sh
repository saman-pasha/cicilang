#!/bin/sh
# The compiler's gate. ONE cocolog process (test/compile.pl) reads, checks,
# lowers, compiles and links every test/c/run/NAME.c to a binary, over the
# user's store, and checks that every test/c/safe/NAME.c is refused; this
# wrapper then runs each binary and compares what it printed and returned
# with test/c/run/NAME.expect, and each refusal with test/c/safe/NAME.expect.
# GREEN or RED.
#
# A FIXTURE BEYOND THE BOX'S C LIBRARY IS SKIPPED BY NAME (0.224), as the C++ gate's is (0.95): NAME.needs holds a
# preprocessor condition over the C library -- `__has_include(<endian.h>)', glibc's and no Mac's -- and a box whose
# library fails it prints the fixture as skipped, neither ok nor a failure: never a RED for what the box lacks. The
# conditions are asked in ONE run of bin/cicilang -E, a marker a fixture where its condition holds, and the run's own
# marker says it ran: a run that broke is RED, never a gate of skips.
#
# ON A MAC THE REFERENCE IS CLANG'S BUILD (0.224), as the cross gate's is that machine's (0.131): Apple's C library
# prints some values otherwise than glibc -- a subnormal's %a, a long double's %La -- and Apple's clang predefines what
# Linux's does not, so there each fixture is built by clang too and run, and what that prints is the reference; a
# fixture in the language's own forms, which clang does not read, is held to its .expect. Linux's is the .expect.
#
#   sh test/compile.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cicilang.so" ] || { echo "SKIP (no library/cicilang.so -- sh module/build.sh)"; exit 0; }
D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-compile-XXXXXX")
trap 'rm -rf "$D"' EXIT
export CCL_TEST_ROOT="$ROOT" CCL_TEST_TMP="$D"
failures=0
case $(uname -s) in Darwin) REF=clang ;; *) REF=expect ;; esac
skips=""; nskip=0
if ls "$ROOT/test/c/run"/*.needs > /dev/null 2>&1; then
  { echo '#include <limits.h>'; echo 'ccl_needs_ran'   # limits.h: the C library's own macros, __GLIBC__ among them
    for nf in "$ROOT/test/c/run"/*.needs; do printf '#if %s\nccl_needs_met_%s\n#endif\n' "$(cat "$nf")" "$(basename "$nf" .needs)"; done
  } > "$D/needs.c"
  met=$("$ROOT/bin/cicilang" -E "$D/needs.c" 2>&1 < /dev/null)
  echo "$met" | grep -qw ccl_needs_ran || { echo "RED: the fixtures' needs were not asked: $(echo "$met" | tail -3 | tr '\n' ' ')"; exit 1; }
  for nf in "$ROOT/test/c/run"/*.needs; do
    n=$(basename "$nf" .needs); echo "$met" | grep -qw "ccl_needs_met_$n" || skips="$skips $n"
  done
fi
export CCL_TEST_SKIP="$skips"   # test/compile.pl builds none of them
out=$("$C" --embed "$CICILANG_KB" query "ensure_loaded('$ROOT/test/compile.pl'), compile_main" 2>&1)
echo "$out" | grep -aq "^done$" || { echo "RED: the gate did not finish"; echo "$out" | grep -a "FAIL\|ERROR\|error" | head -5; exit 1; }

echo "-- built, run, and checked"
for src in "$ROOT/test/c/run"/*.c; do
  n=$(basename "$src" .c)
  case " $skips " in *" $n "*) printf 'skip %-14s needs %s, which this box'"'"'s C library does not meet\n' "$n" "$(cat "$ROOT/test/c/run/$n.needs")"; nskip=$((nskip + 1)); continue ;; esac
  if ! echo "$out" | grep -aq "^built $n$"; then
    printf 'FAIL %-14s %s\n' "$n" "$(echo "$out" | grep -a "^FAIL $n:" | cut -c1-140)"; failures=$((failures + 1)); continue
  fi
  got=$( "$D/$n" arg1 arg2 2>&1; echo "exit $?" )
  how=expect; want=$(cat "$ROOT/test/c/run/$n.expect" 2>/dev/null)
  if [ "$REF" = clang ]; then
    std=""; [ -f "$ROOT/test/c/run/$n.std" ] && std=$(cat "$ROOT/test/c/run/$n.std")
    # shellcheck disable=SC2086
    if ( cd "$ROOT/test/c/run" && clang -w $std "$src" -o "$D/$n.ref" > /dev/null 2>&1 < /dev/null ); then want=$( "$D/$n.ref" arg1 arg2 2>&1; echo "exit $?" ); how=clang; fi
  fi
  if [ -n "$want" ] && [ "$got" = "$want" ]; then
    if [ "$REF" = clang ]; then printf 'ok   %-14s %-6s %s\n' "$n" "$how" "$(echo "$got" | tail -1)"; else printf 'ok   %-14s %s\n' "$n" "$(echo "$got" | tail -1)"; fi
  else
    printf 'FAIL %-14s output differs%s\n' "$n" "$( [ "$REF" = clang ] && echo " from $how")"; printf '%s\n' "$want" > "$D/$n.want"
    echo "$got" | diff "$D/$n.want" - 2>&1 | head -6 | sed 's/^/     /'; failures=$((failures + 1))
  fi
done

[ "$nskip" -gt 0 ] && echo "-- $nskip fixture(s) skipped: beyond this box's C library (NAME.needs)"
echo "-- refused, by the ownership check"
for src in "$ROOT/test/c/safe"/*.c; do
  n=$(basename "$src" .c)
  got=$(echo "$out" | grep -a "^refused $n \|^compiled $n$\|^FAIL $n:" | head -1 | sed "s/^refused $n //; s/^compiled $n$/compiled/")
  want=$(cat "$ROOT/test/c/safe/$n.expect")
  if [ "$got" = "$want" ]; then printf 'ok   %-18s %s\n' "$n" "$got"; else printf 'FAIL %-18s got %s want %s\n' "$n" "$(echo "$got" | cut -c1-80)" "$want"; failures=$((failures + 1)); fi
done
if [ "$failures" -eq 0 ]; then echo "GREEN: compile"; else echo "RED: $failures failure(s)"; exit 1; fi
