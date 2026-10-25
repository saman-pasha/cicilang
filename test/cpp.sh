#!/bin/sh
# The gate for cicilang++, the C++ reader (M5): the checks are test/cpp.pl, one
# clause per construct, one process in memory (no store: the C++ headers are
# too big for the AST cache as cocolog's store stands, see bin/cicilang++); then
# the build only the command can make: a C++ file that is C, through cicilang++
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
#   CPP_WHY=1 sh test/cpp.sh    # a fixture whose BUILD fails gets test/why.sh's account in its verdict (two more builds each)
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
. "$HERE/parlib.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cicilang.so" ] || { echo "SKIP (no library/cicilang.so -- sh module/build.sh)"; exit 0; }
D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-cpp-XXXXXX")
trap 'rm -rf "$D"' EXIT
export CCL_TEST_ROOT="$ROOT" CCL_TEST_TMP="$D"
out=$("$C" --local query "ensure_loaded('$ROOT/test/cpp.pl'), cpp_main" 2>&1); rc=$?
echo "$out" | grep -a "^ok\|^FAIL\|^--\|^SKIP\|^     \|^GREEN\|^RED\|ERROR" || echo "$out" | tail -5
failures=$(echo "$out" | grep -ac "^FAIL")
# a gate that DIES says so with its exit status and its raw tail, as the libc++ one does (0.84's finding):
# a cocolog that cannot get memory answers `false.' and prints an Unknown message about a _G variable,
# neither of which the filter above keeps, and a crash prints nothing at all
echo "$out" | grep -aq "^GREEN\|^RED" || { echo "RED: the gate did not finish (query exit $rc)"; printf '%s\n' "$out" | tail -20; exit 1; }
echo "-- cicilang++, the command"
cd "$D"
got=$("$ROOT/bin/cicilang++" "$ROOT/test/cpp/hello.cpp" -o hello 2>&1 && ./hello)
if [ "$got" = "hello, cicilang++" ]; then echo "ok   cicilang++ hello.cpp -o hello: a binary that runs, linked through c++"; else echo "FAIL cicilang++ hello.cpp -o hello"; echo "     got  $got"; failures=$((failures + 1)); fi
s1=$(date +%s); "$ROOT/bin/cicilang++" "$ROOT/test/cpp/hello.cpp" -o hello2 >/dev/null 2>&1; t1=$(( $(date +%s) - s1 )); n=$(ls "$HOME/.cicilang/cpp/"*.sum 2>/dev/null | wc -l | tr -d ' ')
if [ "$t1" -lt 8 ] && [ "$n" -ge 1 ]; then echo "ok   a second build reads stdio.h's summary from ~/.cicilang/cpp, no preprocessing ($t1 s, $n summaries)"; else echo "FAIL a second build is served from the summary cache"; echo "     got  $t1 s, $n summaries"; failures=$((failures + 1)); fi
got=$("$ROOT/bin/cicilang++" -fsyntax-only "$ROOT/test/cpp/classes.cpp" 2>&1; echo "exit $?")
if [ "$got" = "exit 0" ]; then echo "ok   cicilang++ -fsyntax-only reads a file of classes, and says nothing"; else echo "FAIL cicilang++ -fsyntax-only classes.cpp"; echo "     got  $got"; failures=$((failures + 1)); fi
# THE COLD HEADERS OF A BUILD, EACH READ BY A PROCESS OF ITS OWN (0.188): stdcstdlib.cpp's five library headers, cold in a
# summary directory of the check's own (its HOME), read by five processes four at a time, then the build and its binary
mkdir -p "$D/coldhome"; said=$(HOME="$D/coldhome" CICILANG_JOBS=4 "$ROOT/bin/cicilang++" -v "$ROOT/test/cpp/run/stdcstdlib.cpp" -o cold 2>&1)
nk=$(printf '%s\n' "$said" | grep -ac 'in a process of its own'); got=$(./cold < /dev/null; echo "exit $?")
if [ "$nk" = 5 ] && printf '%s\n' "$said" | grep -aq ': 5 summaries written' && [ "$got" = "$(cat "$ROOT/test/cpp/run/stdcstdlib.expect")" ]; then echo "ok   a cold build reads its five library headers by processes of their own, four at a time, and its binary prints what it should"; else echo "FAIL the cold headers by processes of their own"; echo "     got  $nk processes; $(printf '%s\n' "$said" | grep -a 'summaries written' | cut -c1-160); $(printf '%s' "$got" | tail -1)"; failures=$((failures + 1)); fi
# TWO UNITS BUILT APART (0.192): test/cpp/link/units_a.cpp and units_b.cpp, each built by cicilang++ -c in a process of its own,
# then linked -- each unit's closures, local classes, unnamed namespace, static functions and their type information are its own,
# and the header's (units.h) inline variables and inline static members are one object each, constructed and destroyed once
"$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/link/units_a.cpp" -o units_a.o > units.log 2>&1 && "$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/link/units_b.cpp" -o units_b.o >> units.log 2>&1 \
  && "$ROOT/bin/cicilang++" units_a.o units_b.o -o units >> units.log 2>&1; got=$(./units < /dev/null 2>&1; echo "exit $?")
if [ "$got" = "$(cat "$ROOT/test/cpp/link/units.expect")" ]; then echo "ok   two units built apart keep their closures, local classes, unnamed namespaces and type information apart, and share the header's inline variables, built and destroyed once"; else echo "FAIL two units built apart (test/cpp/link/units_*.cpp)"; echo "     got  $(printf '%s' "$got" | tr '\n' '|' | cut -c1-300); $(tail -2 units.log | tr '\n' ' ' | cut -c1-200)"; failures=$((failures + 1)); fi
# THE CLASS LAYOUT AGAINST CLANG++'S (0.135): test/cpp/link/abi_helper.cpp built by the reference compiler of the tree read
# ($LLVM's clang++, else the one on the path), linked with abi_main.cpp built by cicilang++ -- a base's tail padding reused
# and the table pointer first, values and sizes crossing the call both ways. No clang++: a SKIP, named.
CXXREF=clang++; [ -n "$LLVM" ] && [ -x "$LLVM/bin/clang++" ] && CXXREF="$LLVM/bin/clang++"
if command -v "$CXXREF" > /dev/null 2>&1; then
  "$CXXREF" -std=c++17 -w -c "$ROOT/test/cpp/link/abi_helper.cpp" -o abi_helper.o 2>/dev/null
  got=$("$ROOT/bin/cicilang++" "$ROOT/test/cpp/link/abi_main.cpp" abi_helper.o -o abi 2>&1 && ./abi)
  if [ "$got" = "1 2 3 60 | 245 | 8 8 | 16 16" ]; then echo "ok   classes cross a call to clang++'s code as the Itanium ABI lays them (a base's tail padding, the table pointer first)"; else echo "FAIL the class layout against clang++'s (test/cpp/link)"; echo "     got  $got"; failures=$((failures + 1)); fi
  # ... AND POINTERS TO MEMBER FUNCTIONS BOTH WAYS (0.161): memptr_helper.cpp by clang++, memptr_main.cpp by cicilang++ -- a
  # virtual member, a second base's adjustment, an override of its virtual, the null pointer
  "$CXXREF" -std=c++17 -w -c "$ROOT/test/cpp/link/memptr_helper.cpp" -o memptr_helper.o 2>/dev/null
  got=$("$ROOT/bin/cicilang++" "$ROOT/test/cpp/link/memptr_main.cpp" memptr_helper.o -o memptr 2>&1 && ./memptr)
  if [ "$got" = "11 21 53 42 63 | 11 21 53 42 63 | 1 0 0 1" ]; then echo "ok   pointers to member functions cross a call to clang++'s code both ways ({ ptr, adj } as the Itanium ABI has it)"; else echo "FAIL pointers to member functions against clang++'s (test/cpp/link/memptr_*.cpp)"; echo "     got  $got"; failures=$((failures + 1)); fi
else echo "SKIP the class layout and the member pointers against clang++'s: no clang++"; fi
echo "-- M6, in steps: C++ that is C with names, classes, virtual, templates, lambdas, the B-tree the C++ way, a bag of names, members of class type, C++20, C++23, template template parameters, overloads as C++ chooses, libc++'s std::swap -- built and run (test/cpp/run/NAME.cpp against NAME.expect), in parallel over the pool"
# A FIXTURE'S BUILD HAS A TIME CAP (0.93): on libc++ 18 two <algorithm> fixtures ran past thirty minutes, and a gate with no
# cap hangs for the owner (0.92 kept a fixture out of the tree for exactly that). The cap is CPP_FIXTURE_SECS (2400: the
# slowest fixture seen on macOS is stdalgorithm3 at about 1700 s); past it the build's whole process tree is killed --
# cocolog is the command's grandchild, so a signal to the command alone leaves it running -- and the fixture FAILs with
# `TIMEOUT after N s', which names the environment's cost rather than hiding it.
CPP_FIXTURE_SECS=${CPP_FIXTURE_SECS:-2400}
CPP_JOBS=${CPP_JOBS:-4}; CPP_LAUNCH_MB=${CPP_LAUNCH_MB:-9000}; CPP_HARD_MB=${CPP_HARD_MB:-14000}
ccl_needs_met() {   # ccl_needs_met COND [flags]: does the box's library meet a preprocessor condition? <version> is the library's smallest header, and the marker survives -E only where COND holds
  _nd_cond=$1; shift; _nd_f=$(mktemp -t needs.XXXXXX.cpp)   # its OWN names: sh has no locals, and `r' here overwrote ccl_fixture's result path, so a skip verdict went to a file named 1 (0.107)
  printf '#include <version>\n#if %s\nccl_needs_met\n#endif\n' "$_nd_cond" > "$_nd_f"
  "$ROOT/bin/cicilang++" "$@" -E "$_nd_f" 2>/dev/null < /dev/null | grep -q ccl_needs_met; _nd_r=$?; rm -f "$_nd_f"; return $_nd_r
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
  t0=$(date +%s); bout=$(ccl_capped "$CPP_FIXTURE_SECS" "$ROOT/bin/cicilang++" $flags "$src" -o "$D/bin_$n"); bst=$?; secs=$(( $(date +%s) - t0 ))
  if [ "$bst" -eq 0 ]; then got=$(printf '%s' "$bout"; "$D/bin_$n" < "$inp"; echo "exit $?"); else got=$bout; fi
  case "$got" in *"TIMEOUT after"*) echo "FAIL $n.cpp: $(printf '%s' "$got" | tail -1), the build never finished (the environment's cost, named rather than hidden)" > "$r"; return ;; esac
  if [ "$got" = "$(cat "$ROOT/test/cpp/run/$n.expect")" ]; then echo "ok   $n.cpp: built through cicilang++, runs, and prints what it should" > "$r"
    ccl_time_record "$CPP_TIMES" "$n" "$secs"   # a PASSING build's seconds only, for the next run's longest-first order: a failure's time says nothing of the cost
  else { echo "FAIL $n.cpp"; echo "$got" | diff "$ROOT/test/cpp/run/$n.expect" - 2>&1 | head -6 | sed 's/^/     /'
         # CPP_WHY=1 (0.144): a BUILD that failed is built again under library(flow/debug) by test/why.sh, and its account --
         # the calls the error was raised through, the failed call down the path that got furthest -- joins the verdict
         if [ -n "$CPP_WHY" ] && [ "$bst" -ne 0 ]; then sh "$HERE/why.sh" $flags "$src" 2>&1 | sed -n '/^-- the error was raised\|^-- the run did not raise/,$p' | grep -v '^-- every call\|^-- peak' | sed 's/^/     /'; fi; } > "$r"; fi
}
# LONGEST FIRST: the fixtures ordered by their last recorded build time, heaviest first (the unknown
# ones before them), so a heavy fixture never starts last and holds the gate alone at its end
CPP_TIMES=${CPP_TIMES:-$HOME/.cicilang/fixture-times}
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
got=$("$ROOT/bin/cicilang++" "$ROOT/test/cpp/classes.cpp" -o classes 2>&1 && { ./classes; echo "exit $?"; })
if [ "$got" = "exit 34" ]; then echo "ok   classes.cpp, the reader's fixture (virtual, override, new, delete[], operators, defaults), builds and exits 34"; else echo "FAIL classes.cpp should build and exit 34"; echo "     got  $got" | head -3; failures=$((failures + 1)); fi
got=$("$ROOT/bin/cicilang++" "$ROOT/test/cpp/templates.cpp" -o templates 2>&1 && { ./templates; echo "exit $?"; })
if [ "$got" = "exit 10" ]; then echo "ok   templates.cpp, the reader's fixture (a function and two class templates, an alias, a template in a namespace), builds and exits 10"; else echo "FAIL templates.cpp should build and exit 10"; echo "     got  $got" | head -3; failures=$((failures + 1)); fi
echo "-- and the forms of the later steps are refused by name, not dropped"
for pair in "coro:no_member(get_return_object" "concept_fail:constraint_not_satisfied" "constrained_fail:constraint_not_satisfied" "lambda_const:assign_to_capture(n)" "access_data:access(private,'Account',balance)" "access_method:access(private,'Account',audit)" "access_protected:access(protected,'Base',tweak)" "access_ctor:access(private,'Single','\$ctor')" "access_base:access(private,'Base',secret)" "abstract:pure_virtual" "modhidden:undeclared(hidden)" "basenodefault:base_constructor('B')" "access_inherit:access(private,'Derived',pub)" "access_protobj:access(protected,'Base',secret)" "access_memptr:access(private,'Account',balance)" "access_nested:access(private,'Outer','Secret')" "access_dtor:access(private,'Handle','\$dtor')" "access_operator:access(private,'Money',operator(<))" "lambda_method:non_const_member_on_const(bump,'Counter')" "bind_const:binds_const(r)" "enumnotconst:enumerator_not_constant('B')" "fmtindex:consteval_call_not_constant('basic_format_string.char.int','Argument index outside the valid range')" "fmttype:consteval_call_not_constant('basic_format_string.char.double','__throw_invalid_type_format_error: a floating-point')" "typeidnortti:typeid_requires_rtti" "dyncastnortti:dynamic_cast_requires_rtti" "dpcnortti:instance_refused('dynamic_pointer_cast.D.B',dynamic_cast_requires_rtti)" "thrownoexc:throw_requires_exceptions" "trynoexc:try_requires_exceptions" "access_varfriend:access(private,'Fr.U1',secret)"; do   # modhidden: a name the module does not export (0.110); basenodefault: a base with constructors and no default one, named by no initializer (0.112)
  n=${pair%%:*}; what=${pair#*:}
  flags=$(cat "$ROOT/test/cpp/$n.flags" 2>/dev/null)   # a refusal at a level of its own (0.164: the format string checks are C++20's)
  got=$("$ROOT/bin/cicilang++" $flags -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"not lowered yet: $what"*"exit 1"*) echo "ok   $n.cpp is refused: not lowered yet: $what" ;; *) echo "FAIL $n.cpp should be refused with 'not lowered yet: $what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
echo "-- and the safe part refuses what leaves its scope"
for pair in "escape:a borrow leaves the function" "thisunset:owner used before it was given anything" "gotopastdtor:goto over a defer" "tryowner:use after move of"; do   # a closure holding a reference to a local returned (0.100); `this' handed out of a constructor while an own field is unset (0.133); a goto over a local with a destructor (0.138); a handler that frees again an owner its try's body freed (0.193)
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
echo "-- and a false static assertion of the program is an error"
for pair in "sassertfail:static assertion failed: wrong size" "sassertinst:static assertion failed: one byte" "memassert:static assertion failed: int is eight" "memassert2:static assertion failed: too small"; do   # at file scope, and in an instance of a function template (0.198); a class member's, and a class template instance's (0.205)
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
[ "$skipped" -gt 0 ] && echo "-- $skipped fixture(s) skipped: beyond this box's library (NAME.needs)"
if [ "$failures" -eq 0 ]; then echo "GREEN: cicilang++"; else echo "RED: $failures failure(s)"; exit 1; fi
