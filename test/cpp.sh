#!/bin/sh
# The gate for cocolang++, the C++ reader (M5): the checks are test/cpp.pl, one
# clause per construct, one process in memory (no store: the C++ headers are
# too big for the AST cache as cocolog's store stands, see bin/cocolang++); then
# the build only the command can make: a C++ file that is C, through cocolang++
# to a binary.
#
# THE FIXTURE BUILDS RUN IN PARALLEL (0.105), through the memory-gated pool of
# test/parlib.sh: up to CPP_JOBS at once, a new one launched only while the
# summed resident size of every cocolog process is under CPP_LAUNCH_MB, the
# whole pool killed past CPP_HARD_MB -- so the many light fixtures pack onto the
# cores and a heavy one holds the next launch back. One at a time is CPP_JOBS=1.
# The summary cache must be WARM first (test/libcxx.sh writes it): a gate build
# only READS a summary, which is parallel-safe; a cold flatten under load is not.
#
#   sh test/cpp.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
. "$HERE/parlib.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cocolang.so" ] || { echo "SKIP (no library/cocolang.so -- sh module/build.sh)"; exit 0; }
D=$(mktemp -d "${TMPDIR:-/tmp}/cocolang-cpp-XXXXXX")
trap 'rm -rf "$D"' EXIT
export CCL_TEST_ROOT="$ROOT" CCL_TEST_TMP="$D"
out=$("$C" --local query "ensure_loaded('$ROOT/test/cpp.pl'), cpp_main" 2>&1); rc=$?
echo "$out" | grep -a "^ok\|^FAIL\|^--\|^SKIP\|^     \|^GREEN\|^RED\|ERROR" || echo "$out" | tail -5
failures=$(echo "$out" | grep -ac "^FAIL")
# a gate that DIES says so with its exit status and its raw tail, as the libc++ one does (0.84's finding):
# a cocolog that cannot get memory answers `false.' and prints an Unknown message about a _G variable,
# neither of which the filter above keeps, and a crash prints nothing at all
echo "$out" | grep -aq "^GREEN\|^RED" || { echo "RED: the gate did not finish (query exit $rc)"; printf '%s\n' "$out" | tail -20; exit 1; }
echo "-- cocolang++, the command"
cd "$D"
got=$("$ROOT/bin/cocolang++" "$ROOT/test/cpp/hello.cpp" -o hello 2>&1 && ./hello)
if [ "$got" = "hello, cocolang++" ]; then echo "ok   cocolang++ hello.cpp -o hello: a binary that runs, linked through c++"; else echo "FAIL cocolang++ hello.cpp -o hello"; echo "     got  $got"; failures=$((failures + 1)); fi
s1=$(date +%s); "$ROOT/bin/cocolang++" "$ROOT/test/cpp/hello.cpp" -o hello2 >/dev/null 2>&1; t1=$(( $(date +%s) - s1 )); n=$(ls "$HOME/.cocolang/cpp/"*.sum 2>/dev/null | wc -l | tr -d ' ')
if [ "$t1" -lt 8 ] && [ "$n" -ge 1 ]; then echo "ok   a second build reads stdio.h's summary from ~/.cocolang/cpp, no preprocessing ($t1 s, $n summaries)"; else echo "FAIL a second build is served from the summary cache"; echo "     got  $t1 s, $n summaries"; failures=$((failures + 1)); fi
got=$("$ROOT/bin/cocolang++" -fsyntax-only "$ROOT/test/cpp/classes.cpp" 2>&1; echo "exit $?")
if [ "$got" = "exit 0" ]; then echo "ok   cocolang++ -fsyntax-only reads a file of classes, and says nothing"; else echo "FAIL cocolang++ -fsyntax-only classes.cpp"; echo "     got  $got"; failures=$((failures + 1)); fi
echo "-- M6, in steps: C++ that is C with names, classes, virtual, templates, lambdas, the B-tree the C++ way, a bag of names, members of class type, C++20, C++23, template template parameters, overloads as C++ chooses, libc++'s std::swap -- built and run (test/cpp/run/NAME.cpp against NAME.expect), in parallel over the pool"
# A FIXTURE'S BUILD HAS A TIME CAP (0.93): on libc++ 18 two <algorithm> fixtures ran past thirty minutes, and a gate with no
# cap hangs for the owner (0.92 kept a fixture out of the tree for exactly that). The cap is CPP_FIXTURE_SECS (2400: the
# slowest fixture seen on macOS is stdalgorithm3 at about 1700 s); past it the build's whole process tree is killed --
# cocolog is the command's grandchild, so a signal to the command alone leaves it running -- and the fixture FAILs with
# `TIMEOUT after N s', which names the environment's cost rather than hiding it.
CPP_FIXTURE_SECS=${CPP_FIXTURE_SECS:-2400}
CPP_JOBS=${CPP_JOBS:-4}; CPP_LAUNCH_MB=${CPP_LAUNCH_MB:-9000}; CPP_HARD_MB=${CPP_HARD_MB:-14000}
ccl_needs_met() {   # ccl_needs_met COND [flags]: does the box's library meet a preprocessor condition? <version> is the library's smallest header, and the marker survives -E only where COND holds
  cond=$1; shift; f=$(mktemp -t needs.XXXXXX.cpp)
  printf '#include <version>\n#if %s\nccl_needs_met\n#endif\n' "$cond" > "$f"
  "$ROOT/bin/cocolang++" "$@" -E "$f" 2>/dev/null | grep -q ccl_needs_met; r=$?; rm -f "$f"; return $r
}
ccl_kill_tree() { for c in $(pgrep -P "$1" 2>/dev/null); do ccl_kill_tree "$c"; done; kill -9 "$1" 2>/dev/null; }
ccl_capped() {   # ccl_capped SECS CMD...: the command's output on stdout, its exit status returned; past SECS the tree is killed, the output ends `TIMEOUT after SECS s' and the status is 124
  secs=$1; shift; out=$(mktemp); st=$(mktemp)
  ( "$@" > "$out" 2>&1; echo $? > "$st" ) & p=$!
  t=0; while kill -0 "$p" 2>/dev/null; do sleep 1; t=$((t + 1)); if [ "$t" -ge "$secs" ]; then ccl_kill_tree "$p"; echo "TIMEOUT after ${secs} s" >> "$out"; echo 124 > "$st"; break; fi; done
  wait "$p" 2>/dev/null; cat "$out"; r=$(cat "$st"); rm -f "$out" "$st"; return "$r"
}
# ONE FIXTURE, self-contained: build (capped), run with its .stdin, compare with .expect; the verdict
# to $RES/NAME.res as `ok ...' / `FAIL ...' / `skip ...', so the pool's parallel jobs never interleave on stdout
RES="$D/res"; mkdir -p "$RES"
ccl_fixture() {
  n=$1; src="$ROOT/test/cpp/run/$n.cpp"; r="$RES/$n.res"
  flags=$(cat "$ROOT/test/cpp/run/$n.flags" 2>/dev/null)
  inp="$ROOT/test/cpp/run/$n.stdin"; [ -f "$inp" ] || inp=/dev/null   # a fixture that READS gives its input as NAME.stdin (stdcin.cpp); the rest read nothing
  if [ -f "$ROOT/test/cpp/run/$n.needs" ] && ! ccl_needs_met "$(cat "$ROOT/test/cpp/run/$n.needs")" $flags; then   # A FIXTURE BEYOND THE BOX'S LIBRARY IS SKIPPED BY NAME (0.95): NAME.needs holds a preprocessor condition over the library's own macros (`_LIBCPP_VERSION >= 210000': optional<T &> is C++26's and libc++ 18 refuses it), and a box whose library fails it prints the fixture as skipped -- neither ok nor a failure, never a RED for what the environment lacks
    echo "skip $n.cpp: needs $(cat "$ROOT/test/cpp/run/$n.needs"), which this box's library does not meet" > "$r"; return; fi
  t0=$(date +%s); bout=$(ccl_capped "$CPP_FIXTURE_SECS" "$ROOT/bin/cocolang++" $flags "$src" -o "$D/bin_$n"); bst=$?; secs=$(( $(date +%s) - t0 ))
  if [ "$bst" -eq 0 ]; then got=$(printf '%s' "$bout"; "$D/bin_$n" < "$inp"; echo "exit $?"); else got=$bout; fi
  case "$got" in *"TIMEOUT after"*) echo "FAIL $n.cpp: $(printf '%s' "$got" | tail -1), the build never finished (the environment's cost, named rather than hidden)" > "$r"; return ;; esac
  if [ "$got" = "$(cat "$ROOT/test/cpp/run/$n.expect")" ]; then echo "ok   $n.cpp: built through cocolang++, runs, and prints what it should" > "$r"
    ccl_time_record "$CPP_TIMES" "$n" "$secs"   # a PASSING build's seconds only, for the next run's longest-first order: a failure's time says nothing of the cost
  else { echo "FAIL $n.cpp"; echo "$got" | diff "$ROOT/test/cpp/run/$n.expect" - 2>&1 | head -6 | sed 's/^/     /'; } > "$r"; fi
}
# LONGEST FIRST: the fixtures ordered by their last recorded build time, heaviest first (the unknown
# ones before them), so a heavy fixture never starts last and holds the gate alone at its end
CPP_TIMES=${CPP_TIMES:-$HOME/.cocolang/fixture-times}
names=$(for src in "$ROOT"/test/cpp/run/*.cpp; do basename "$src" .cpp; done | ccl_lpt_order "$CPP_TIMES")
{ for n in $names; do echo "ccl_fixture $n"; done; } | ccl_pool "$CPP_JOBS" "$CPP_LAUNCH_MB" "$CPP_HARD_MB"
pool_rc=$?
skipped=0
for n in $(printf '%s\n' $names | sort); do   # collect the verdicts in a stable order, count failures and skips
  r="$RES/$n.res"
  if [ -f "$r" ]; then cat "$r"; case "$(head -1 "$r")" in FAIL*) failures=$((failures + 1)) ;; skip*) skipped=$((skipped + 1)) ;; esac
  else echo "FAIL $n.cpp: no verdict (the pool was killed before it ran)"; failures=$((failures + 1)); fi
done
[ "$pool_rc" -ne 0 ] && { echo "RED: the fixture pool hit the hard memory cap (CPP_HARD_MB=$CPP_HARD_MB) -- some fixtures did not run"; failures=$((failures + 1)); }
got=$("$ROOT/bin/cocolang++" "$ROOT/test/cpp/classes.cpp" -o classes 2>&1 && { ./classes; echo "exit $?"; })
if [ "$got" = "exit 34" ]; then echo "ok   classes.cpp, the reader's fixture (virtual, override, new, delete[], operators, defaults), builds and exits 34"; else echo "FAIL classes.cpp should build and exit 34"; echo "     got  $got" | head -3; failures=$((failures + 1)); fi
got=$("$ROOT/bin/cocolang++" "$ROOT/test/cpp/templates.cpp" -o templates 2>&1 && { ./templates; echo "exit $?"; })
if [ "$got" = "exit 10" ]; then echo "ok   templates.cpp, the reader's fixture (a function and two class templates, an alias, a template in a namespace), builds and exits 10"; else echo "FAIL templates.cpp should build and exit 10"; echo "     got  $got" | head -3; failures=$((failures + 1)); fi
echo "-- and the forms of the later steps are refused by name, not dropped"
for pair in "control:try" "coro:coroutine" "concept_fail:constraint_not_satisfied" "deduced_this:deduced_this" "constrained_fail:constraint_not_satisfied" "abstract:pure_virtual"; do
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cocolang++" -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"not lowered yet: $what"*"exit 1"*) echo "ok   $n.cpp is refused: not lowered yet: $what" ;; *) echo "FAIL $n.cpp should be refused with 'not lowered yet: $what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
echo "-- and the safe part refuses what leaves its scope"
for pair in "escape:a borrow leaves the function"; do   # a closure holding a reference to a local returned (0.100)
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cocolang++" -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
[ "$skipped" -gt 0 ] && echo "-- $skipped fixture(s) skipped: beyond this box's library (NAME.needs)"
if [ "$failures" -eq 0 ]; then echo "GREEN: cocolang++"; else echo "RED: $failures failure(s)"; exit 1; fi
