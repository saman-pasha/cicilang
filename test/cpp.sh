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
# A STRUCT THAT A DECLARATION ALONE NAMES IS DEFINED (0.250): declstruct.cpp's 136-byte instance by value in a declared function
# only -- macOS's fpos<mbstate_t> in basic_streambuf::seekpos, `use of undefined type' in every stream program on the Intel Mac
got=$("$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/declstruct.cpp" -o declstruct.o 2>&1; echo "exit $?")
if [ "$got" = "exit 0" ]; then echo "ok   a struct that a declaration alone names by value is defined in the module (declstruct.cpp, -c)"; else echo "FAIL a struct that a declaration alone names (declstruct.cpp, -c)"; echo "     got  $(printf '%s' "$got" | head -2 | cut -c1-300)"; failures=$((failures + 1)); fi
# THE COLD HEADERS OF A BUILD, EACH READ BY A PROCESS OF ITS OWN (0.188): stdcstdlib.cpp's five library headers, cold in a
# summary directory of the check's own (its HOME), read by five processes four at a time, then the build and its binary
mkdir -p "$D/coldhome"; said=$(HOME="$D/coldhome" CICILANG_JOBS=4 "$ROOT/bin/cicilang++" -v "$ROOT/test/cpp/run/stdcstdlib.cpp" -o cold 2>&1)
nk=$(printf '%s\n' "$said" | grep -ac 'in a process of its own'); got=$(./cold < /dev/null; echo "exit $?")
if [ "$nk" = 5 ] && printf '%s\n' "$said" | grep -aq ': 5 summaries written' && [ "$got" = "$(cat "$ROOT/test/cpp/run/stdcstdlib.expect")" ]; then echo "ok   a cold build reads its five library headers by processes of their own, four at a time, and its binary prints what it should"; else echo "FAIL the cold headers by processes of their own"; echo "     got  $nk processes; $(printf '%s\n' "$said" | grep -a 'summaries written' | cut -c1-160); $(printf '%s' "$got" | tail -1)"; failures=$((failures + 1)); fi
# A HEADER READ IN THE BUILD'S OWN PROCESS AFTER ANOTHER SERVED FROM ITS SUMMARY (0.218): stdcharconv.cpp over a summary
# directory of the check's own, where a build of charconvfirst.cpp left <charconv>'s summary and the rest of its headers
# are cold, one process reading them in turn (CICILANG_JOBS=1) -- <system_error>'s read took `__traits' from <charconv>'s
mkdir -p "$D/mixhome"; HOME="$D/mixhome" CICILANG_JOBS=1 "$ROOT/bin/cicilang++" "$ROOT/test/cpp/charconvfirst.cpp" -o mixfirst > /dev/null 2>&1
got=$(HOME="$D/mixhome" CICILANG_JOBS=1 "$ROOT/bin/cicilang++" "$ROOT/test/cpp/run/stdcharconv.cpp" -o mix 2>&1 && ./mix < /dev/null; echo "exit $?")
if [ "$got" = "$(cat "$ROOT/test/cpp/run/stdcharconv.expect")" ]; then echo "ok   a header read in the build's own process after another was served from its summary is registered as a served one is (stdcharconv.cpp, <charconv> warm, the rest cold)"; else echo "FAIL a header read in the build's own process after another served from its summary (stdcharconv.cpp, <charconv> warm, the rest cold)"; echo "     got  $(printf '%s' "$got" | tr '\n' '|' | cut -c1-300)"; failures=$((failures + 1)); fi
# A SUMMARY DIRECTORY MOVED TO ANOTHER HOME SERVES ITS HEADERS (0.259): longterms.cpp's <utility> and <tuple>, each summary
# with a long term in its clause file, read cold in a HOME of the check's own; the .cicilang moved to another HOME, the
# second build reads no header again -- no process of its own, no summary written -- and its binary prints what it should.
# The clauses named the summary by its full path, so a moved one matched none: both headers read by processes of their
# own, `0 summaries written', then each read again in the build's own process
mkdir -p "$D/longhome" "$D/movedhome"; HOME="$D/longhome" "$ROOT/bin/cicilang++" "$ROOT/test/cpp/longterms.cpp" -o long1 > /dev/null 2>&1
nb=$(ls "$D/longhome/.cicilang/cpp/"*.big.pl 2>/dev/null | wc -l | tr -d ' '); mv "$D/longhome/.cicilang" "$D/movedhome/.cicilang" && touch "$D/longmark" && sleep 1
said=$(HOME="$D/movedhome" "$ROOT/bin/cicilang++" -v "$ROOT/test/cpp/longterms.cpp" -o long2 2>&1); got=$(./long2 < /dev/null; echo "exit $?")
nk=$(printf '%s\n' "$said" | grep -ac 'in a process of its own'); nw=$(find "$D/movedhome/.cicilang/cpp" -newer "$D/longmark" -name '*.sum' 2>/dev/null | wc -l | tr -d ' ')
if [ "$nb" -ge 2 ] && [ "$nk" = 0 ] && [ "$nw" = 0 ] && [ "$got" = "$(printf '7 7\nexit 0')" ]; then echo "ok   a summary directory moved to another HOME serves its headers, their long terms read from the clause files beside them: none read again (longterms.cpp, $nb clause files)"; else echo "FAIL a summary directory moved to another HOME (longterms.cpp)"; echo "     got  $nb clause files, $nk processes of their own, $nw summaries written again; $(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)"; failures=$((failures + 1)); fi
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
# ON A MAC THE REFERENCE CLANG++ IS GIVEN THE SDK (0.249): Homebrew's llvm@18 found no C library's headers on the CI's Intel
# Mac, so byval.h's `#include <cstdio>' failed and the by-value check with it, while the two helpers that include nothing
# built -- Apple's clang has its SDK of its own, and cicilang finds one (ccl_sdk_dirs/1). A helper that does not build says
# why, under the check's FAIL (its errors had gone to /dev/null).
CXXSDK=""; [ "$(uname -s)" = Darwin ] && CXXSDK=$(xcrun --show-sdk-path 2>/dev/null) && [ -d "$CXXSDK" ] || CXXSDK=""
ccl_ref_cxx() { "$CXXREF" ${CXXSDK:+-isysroot "$CXXSDK"} -std=c++17 -w -c "$ROOT/test/cpp/link/$1.cpp" -o "$1.o" > "$1.log" 2>&1; }   # ccl_ref_cxx NAME: test/cpp/link/NAME.cpp into NAME.o, its errors in NAME.log
ccl_ref_said() { [ -f "$1.o" ] || echo "     $1.cpp did not build: $(head -3 "$1.log" | tr '\n' ' ' | cut -c1-300)"; }
if command -v "$CXXREF" > /dev/null 2>&1; then
  ccl_ref_cxx abi_helper
  got=$("$ROOT/bin/cicilang++" "$ROOT/test/cpp/link/abi_main.cpp" abi_helper.o -o abi 2>&1 && ./abi)
  if [ "$got" = "1 2 3 60 | 245 | 8 8 | 16 16" ]; then echo "ok   classes cross a call to clang++'s code as the Itanium ABI lays them (a base's tail padding, the table pointer first)"; else echo "FAIL the class layout against clang++'s (test/cpp/link)"; echo "     got  $got"; ccl_ref_said abi_helper; failures=$((failures + 1)); fi
  # ... AND POINTERS TO MEMBER FUNCTIONS BOTH WAYS (0.161): memptr_helper.cpp by clang++, memptr_main.cpp by cicilang++ -- a
  # virtual member, a second base's adjustment, an override of its virtual, the null pointer
  ccl_ref_cxx memptr_helper
  got=$("$ROOT/bin/cicilang++" "$ROOT/test/cpp/link/memptr_main.cpp" memptr_helper.o -o memptr 2>&1 && ./memptr)
  if [ "$got" = "11 21 53 42 63 | 11 21 53 42 63 | 1 0 0 1" ]; then echo "ok   pointers to member functions cross a call to clang++'s code both ways ({ ptr, adj } as the Itanium ABI has it)"; else echo "FAIL pointers to member functions against clang++'s (test/cpp/link/memptr_*.cpp)"; echo "     got  $got"; ccl_ref_said memptr_helper; failures=$((failures + 1)); fi
  # ... AND A BY-VALUE PARAMETER OF A CLASS WITH A DESTRUCTOR BOTH WAYS (0.207): byval_helper.cpp by clang++, byval_main.cpp
  # by cicilang++ -- a prvalue and a copy each way, each object destroyed once, by the caller, after its full-expression
  ccl_ref_cxx byval_helper
  got=$("$ROOT/bin/cicilang++" "$ROOT/test/cpp/link/byval_main.cpp" byval_helper.o -o byval 2>&1 && ./byval)
  if [ "$got" = "[1] ~T(1) [102] ~T(102) ~T(2) ~T(103) ~T(3) ~T(3) [212] live 0" ]; then echo "ok   a by-value parameter of a class with a destructor crosses a call to clang++'s code both ways, destroyed once by the caller after its full-expression (the Itanium ABI)"; else echo "FAIL a by-value parameter against clang++'s code (test/cpp/link/byval_*.cpp)"; echo "     got  $got"; ccl_ref_said byval_helper; failures=$((failures + 1)); fi
else echo "SKIP the class layout, the member pointers and the by-value parameters against clang++'s: no clang++"; fi
echo "-- M6, in steps: C++ that is C with names, classes, virtual, templates, lambdas, the B-tree the C++ way, a bag of names, members of class type, C++20, C++23, template template parameters, overloads as C++ chooses, libc++'s std::swap -- built and run (test/cpp/run/NAME.cpp against NAME.expect), in parallel over the pool"
# A FIXTURE'S BUILD HAS A TIME CAP (0.93): on libc++ 18 two <algorithm> fixtures ran past thirty minutes, and a gate with no
# cap hangs for the owner (0.92 kept a fixture out of the tree for exactly that). The cap is CPP_FIXTURE_SECS (2400: the
# slowest fixture seen on macOS is stdalgorithm3 at about 1700 s); past it the build's whole process tree is killed --
# cocolog is the command's grandchild, so a signal to the command alone leaves it running -- and the fixture FAILs with
# `TIMEOUT after N s', which names the environment's cost rather than hiding it.
CPP_FIXTURE_SECS=${CPP_FIXTURE_SECS:-2400}
# ... AND ITS RUN TOO (0.249): the binary's run is killed past CPP_RUN_SECS (300 s) by `timeout -s KILL', as the library
# read caps its reads, and the fixture FAILs with `TIMEOUT after N s' and its run named.
# The CI's first C++ job on the Intel Mac (41161604702) built half its fixtures in thirty minutes, then its pool waited until
# GitHub stopped the job at six hours: a run that never ends holds its lane, and the pool's end waits for every job.
CPP_RUN_SECS=${CPP_RUN_SECS:-300}
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
  if [ "$bst" -eq 0 ]; then t1=$(date +%s); got=$(printf '%s' "$bout"; timeout -s KILL "$CPP_RUN_SECS" "$D/bin_$n" < "$inp"; echo "exit $?")
    if [ $(( $(date +%s) - t1 )) -ge "$CPP_RUN_SECS" ]; then echo "FAIL $n.cpp: TIMEOUT after $CPP_RUN_SECS s, its binary's run never finished (killed: the environment's cost or a wait for ever, named rather than hidden)" > "$r"; return; fi
  else got=$bout; fi
  case "$got" in *"TIMEOUT after"*) echo "FAIL $n.cpp: $(printf '%s' "$got" | tail -1), the build never finished (the environment's cost, named rather than hidden)" > "$r"; return ;; esac
  if [ "$got" = "$(cat "$ROOT/test/cpp/run/$n.expect")" ]; then echo "ok   $n.cpp: built through cicilang++, runs, and prints what it should" > "$r"
    ccl_time_record "$CPP_TIMES" "$n" "$secs"   # a PASSING build's seconds only, for the next run's longest-first order: a failure's time says nothing of the cost
  else { echo "FAIL $n.cpp"; echo "$got" | diff "$ROOT/test/cpp/run/$n.expect" - 2>&1 | head -6 | sed 's/^/     /'
         # A BUILD THAT FAILED SAYS WHY (0.250): its first error lines, which the diff's six lines do not reach where the
         # fixture prints more -- the CI's C++ job on the Intel Mac failed twenty fixtures whose cause no line showed -- and
         # a failed link's notes, the symbols it names (0.251); a RUN that failed says how it ended, its `exit N' (0.251),
         # which the diff cut off where the fixture prints six lines or more (stdfuture.cpp, stdpmr.cpp on the Intel Mac)
         if [ "$bst" -ne 0 ]; then printf '%s\n' "$bout" | grep -a -E 'error|: note: link: ' | head -6 | cut -c1-300 | sed 's/^/     the build: /'
         else echo "     the run: $(printf '%s\n' "$got" | tail -1)"; fi
         # CPP_WHY=1 (0.144): a BUILD that failed is built again under library(flow/debug) by test/why.sh, and its account --
         # the calls the error was raised through, the failed call down the path that got furthest -- joins the verdict
         if [ -n "$CPP_WHY" ] && [ "$bst" -ne 0 ]; then sh "$HERE/why.sh" $flags "$src" 2>&1 | sed -n '/^-- the error was raised\|^-- the run did not raise/,$p' | grep -v '^-- every call\|^-- peak' | sed 's/^/     /'; fi; } > "$r"; fi
}
# A POOL STOPPED FROM OUTSIDE SAYS WHERE IT WAS (0.249): with CPP_PROGRESS naming a file, each fixture's start and its
# verdict's line are appended there as they come, the clock first -- the verdicts are printed when the pool ends, and the CI's
# C++ job on the Intel Mac was stopped at its six hours with none of them written, so nothing named the fixture that held it
ccl_fixture_run() {
  [ -z "$CPP_PROGRESS" ] || echo "$(date +%H:%M:%S) start $1" >> "$CPP_PROGRESS"
  ccl_fixture "$1"
  [ -z "$CPP_PROGRESS" ] || echo "$(date +%H:%M:%S) $(head -1 "$RES/$1.res" 2>/dev/null | cut -c1-160)" >> "$CPP_PROGRESS"
}
# LONGEST FIRST: the fixtures ordered by their last recorded build time, heaviest first (the unknown
# ones before them), so a heavy fixture never starts last and holds the gate alone at its end
CPP_TIMES=${CPP_TIMES:-$HOME/.cicilang/fixture-times}
names=$(for src in "$ROOT"/test/cpp/run/*.cpp; do basename "$src" .cpp; done | ccl_lpt_order "$CPP_TIMES")
{ for n in $names; do echo "ccl_fixture_run $n"; done; } | ccl_pool "$CPP_JOBS" "$CPP_LAUNCH_MB" "$CPP_HARD_MB"
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
# CCLLIB IN CICILANG++ (0.267; CCLLIB.md's phase 0.10): a ccllib run fixture of test/c/run, its macro file's C text in
# the part that C and C++ share, built as C++ by cicilang++, prints what its cicilang build prints, NAME.expect --
# ctext.c's C text and autodrop.c's drops at every way out of a scope; tvector.c's type macros in the program's own
# headers, tvhdr.h and tvhdr2.h, which a C++ build reads as it reads the program's file (0.268); literal.c's list and
# map literals beside the lambda's introducer (0.269); operators.c's operators on instances and unread.c's arguments
# taken unread (0.270); lazy.c's functions made at their first call and its calls by name (0.274); operators2.c's
# `& | ^ ~ %', compound assignments, typed names and `[]' as a value (0.284); born.c's objects given zero and made of a
# value of another type (0.285); dropassign.c's assignments, each dropping its object's old value (0.287);
# typednames.c's calls by name, told by an argument's type (0.288); contswitch.c's continues in a switch in a loop and
# loadedptr.c's pointers read out of slots and null tests of new memory, two programs of plain C (0.290); mirror.c's
# operators whose left operand is no instance (0.291); hdrvec.c's headers over a type macro's instance, each read in
# its place, and regnames.c's and regnames23.c's parameters beside the names that the lowering makes (0.293); condarr.c's
# conditionals whose arms are arrays, and statret.c's functions whose every return is static storage (0.294);
# staticrows.c's rows of static arrays, used as pointers, and shadowed.c's names that a block declares again (0.297);
# ownmacros.c's macros of the program's own headers and of their includer, hdrinst.c's own headers over a type macro's
# instance with no macro file of their own, widearr.c's arrays of wide characters made of wide literals, longlit.c's long
# literals in pieces, and ownundef.c's directives of the program's own headers in the file's run (0.298); outparam.c's
# pointers that a call wrote through an out-parameter, copied, moved and stored (0.299); ownwords.c's word own where
# it is the owner's, a specifier, a qualifier, a parameter with no name (0.306); staticfree.c's own array of strings in
# a file with no <stdlib.h>, each store freeing with the lowering's own free, and statichide.c's names that a local
# shares with an own array (0.307); discarded.c's calls whose value a statement throws away and that give no new
# memory (0.309); xmacro.c's #include inside an item -- an X-macro's enum and table, a struct's fields, a body's
# statements -- and its tables whose rows have no braces of their own (0.310); ownparams.c's own parameters that their
# callee stores, which C++ refused (1.6.5); loopjoins.c's loops and joins that the safe part refused, and nullcopies.c's
# copies of a pointer that its null test found null (1.6.18); looppasses.c's loops whose next pass finds what the last
# left (1.6.19); nulldecls.c's pointers declared null, given new memory on the path that a goto jumps over (1.6.20).
# elemborrow.c is test/cpp/run/elemborrowpp.cpp there (0.272): its plain functions
# noexcept, since C++'s defer rule refuses a plain struct's live owner across a call that may throw; staticarrays.c is
# not built as C++, since that rule refuses its owner live across make's call (0.307); shadowborrow.c's borrows of an
# object whose name a block declares again (1.6.33)
echo "-- ccllib in cicilang++: a ccllib run fixture of test/c/run built as C++ prints what its C build prints (CCLLIB.md's phase 0.10)"
for n in ctext autodrop tvector literal operators operators2 born dropassign typednames contswitch loadedptr mirror unread lazy hdrvec regnames regnames23 condarr statret staticrows shadowed ownmacros hdrinst widearr longlit ownundef outparam ownwords staticfree statichide discarded xmacro ownparams shadowborrow loopjoins nullcopies looppasses nulldecls reallocs handout staticrecords arrayreturns globalnames stmtstatics; do
  got=$(ccl_capped "$CPP_FIXTURE_SECS" "$ROOT/bin/cicilang++" "$ROOT/test/c/run/$n.c" -o "$D/ccl_$n" && { timeout -s KILL "$CPP_RUN_SECS" "$D/ccl_$n" < /dev/null; echo "exit $?"; })
  if [ "$got" = "$(cat "$ROOT/test/c/run/$n.expect")" ]; then echo "ok   $n.c, built as C++ by cicilang++, prints what its C build prints"
  else echo "FAIL $n.c built as C++ by cicilang++"; echo "$got" | diff "$ROOT/test/c/run/$n.expect" - 2>&1 | head -6 | cut -c1-300 | sed 's/^/     /'; failures=$((failures + 1)); fi
done
echo "-- and the forms of the later steps are refused by name, not dropped"
for pair in "coro:no_member(get_return_object" "concept_fail:constraint_not_satisfied" "constrained_fail:constraint_not_satisfied" "lambda_const:assign_to_capture(n)" "access_data:access(private,'Account',balance)" "access_method:access(private,'Account',audit)" "access_protected:access(protected,'Base',tweak)" "access_ctor:access(private,'Single','\$ctor')" "access_base:access(private,'Base',secret)" "abstract:pure_virtual" "basenodefault:base_constructor('B')" "access_inherit:access(private,'Derived',pub)" "access_protobj:access(protected,'Base',secret)" "access_memptr:access(private,'Account',balance)" "access_nested:access(private,'Outer','Secret')" "access_dtor:access(private,'Handle','\$dtor')" "access_operator:access(private,'Money',operator(<))" "lambda_method:non_const_member_on_const(bump,'Counter')" "bind_const:binds_const(r)" "enumnotconst:enumerator_not_constant('B')" "fmtindex:consteval_call_not_constant('basic_format_string.char.int','Argument index outside the valid range')" "fmttype:consteval_call_not_constant('basic_format_string.char.double','__throw_invalid_type_format_error: a floating-point')" "typeidnortti:typeid_requires_rtti" "dyncastnortti:dynamic_cast_requires_rtti" "dpcnortti:instance_refused('dynamic_pointer_cast.D.B',dynamic_cast_requires_rtti)" "thrownoexc:throw_requires_exceptions" "trynoexc:try_requires_exceptions" "access_varfriend:access(private,'Fr.U1',secret)" "stdsizeonly:no_member_of_std(size)" "refownelem:lvalue(assign(=,index(id(slot),int(0))"; do   # modhidden: a name the module does not export (0.110); basenodefault: a base with constructors and no default one, named by no initializer (0.112); stdsizeonly: std::size at C++23 with <algorithm> alone, which declares no std::size there (0.221); freeoprval: an rvalue for a free operator's `W &', no candidate (1.6.6)
  n=${pair%%:*}; what=${pair#*:}
  flags=$(cat "$ROOT/test/cpp/$n.flags" 2>/dev/null)   # a refusal at a level of its own (0.164: the format string checks are C++20's)
  got=$("$ROOT/bin/cicilang++" $flags -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"not lowered yet: $what"*"exit 1"*) echo "ok   $n.cpp is refused: not lowered yet: $what" ;; *) echo "FAIL $n.cpp should be refused with 'not lowered yet: $what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
flags=$(cat "$ROOT/test/cpp/modhidden.flags" 2>/dev/null); got=$("$ROOT/bin/cicilang++" $flags -c "$ROOT/test/cpp/modhidden.cpp" -o modhidden.o 2>&1; echo "exit $?")   # a name the module does not export: clang++'s words since 1.6.27
case "$got" in *"use of undeclared identifier 'hidden'"*"exit 1"*) echo "ok   modhidden.cpp is refused: use of undeclared identifier 'hidden'" ;; *) echo "FAIL modhidden.cpp should be refused with 'use of undeclared identifier 'hidden''"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
echo "-- and GCC's cleanup attribute names one function, in clang's words (1.6.8)"
for pair in "cleanup_overload:'cleanup' argument 'bye' is not a single function"; do
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
echo "-- and an overload with an ellipsis beside its plain twin: a call that both fit, in clang++'s words, and a static one's value (1.6.38); a compound literal's storage class (1.6.39)"
for pair in "va_ambiguous:va_ambiguous.cpp:4: error: call to 'f' is ambiguous" "va_ambiguous_member:va_ambiguous_member.cpp:3: error: call to member function 'm' is ambiguous" "va_static_value:va_static_value.cpp:3: error: not lowered yet: static_member_ellipsis_value(s)" "va_few_qualified:va_few_qualified.cpp:5: error: no matching function for call to 'f'" "complit_static:complit_static.cpp:3: error: type name does not allow storage class to be specified"; do
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
# A VOID VALUE IS NO VALUE (1.6.14; [basic.fundamental]/13, [expr.call]/7, [dcl.init.general]/16): sixty-three bodies, each
# at line 3, refused in clang++'s words at clang++'s line -- a variable, a member, an element, a new value, a return object, a
# parameter and a reference initialized by one, a call of a function, an overload, a template, a member and a constructor
# given one, a qualified call of one function, an ellipsis, the casts by their spelling, the operators, the conditions of
# if, for, while and do, a conditional of one void arm, sizeof, the deduced auto and its declarators. Through 1.6.13 each went
# to LLVM's parser, `void type only allowed for function results', at no line of the program, or ran: `sizeof(void)' was 1
# and `sizeof(f)' 8
echo "-- and a void value where a value is taken is an error, in clang++'s words at its line (1.6.14)"
vp_pre='void f() {} int g(int v) { return v; } void ov(int) {} void ov(double) {} template<class T> void tk(T) {} int vf(int, ...); struct S { int m; }; struct M { int v; M(int x) : v(x) {} void m(int) {} void o(int) {} void o(double) {} static void s(int) {} }; namespace ns { int h(int v) { return v; } } extern "C" int puts(const char *);\nint main(int argc, char **argv) { (void)argv; int z = 1, a[2] = {1, 2}; M mm(1); (void)a; (void)argc;'
vp_got=$(n=0; for body in 'int x = f(); (void)x;' 'z = f();' 'g(f());' 'return f();' 'z = f() + 1;' 'if (f()) z = 2;' 'z = !f();' 'z = (int)f();' 'z = int(f());' 'z = static_cast<int>(f());' 'S s{f()}; (void)s;' 'int *q = new int(f()); delete q;' 'struct N { int m; N() : m(f()) {} }; N n; (void)n;' 'int b[2] = { f(), 1 }; (void)b;' 'z = f() == f();' 'bool b = f(); (void)b;' 'z = sizeof(f());' 'int &r = f(); (void)r;' 'const int &r = f(); (void)r;' 'tk(f());' 'z = z ? f() : 1;' 'z = z ? 1 : f();' 'S s = f(); (void)s;' 'mm.m(f());' 'mm.o(f());' 'M m2(f()); (void)m2;' 'M m2 = M(f()); (void)m2;' 'vf(1, f());' 'ov(f());' 'z = a[f()];' 'z = *f();' 'z = f()[0];' 'f()++;' 'z = sizeof(void);' 'auto &r = f(); (void)r;' 'auto *q = f(); (void)q;' 'z = reinterpret_cast<int>(f());' 'z = const_cast<int>(f());' 'int *q = const_cast<int *>(f()); (void)q;' 'z = sizeof(f);' 'auto x = f(); (void)x;' 'z = f() || true;' 'switch (f()) { default: break; }' 'M *pm = new M(f()); delete pm;' 'M m2{f()}; (void)m2;' 'M::s(f());' 'int (*fp)(int) = g; z = fp(f());' 'g(z ? f() : f());' 'g((z, f()));' 'g((void)z);' 'g(static_cast<void>(z));' 'ns::h(f());' 'vf(f());' 'struct N { int m = f(); }; N n; (void)n;' 'S s = { ({ int x = f(); x; }) }; (void)s;' 'for (; f(); ) break;' 'while (f()) break;' 'do { } while (f());' 'auto l = []() -> S { return f(); }; (void)l;' 'S *ps = dynamic_cast<S *>(f()); (void)ps;' 'puts(f());' 'z = (f(), f()) + 1;' 'z = -(void)z;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$vp_pre" "$body" > vp$n.cpp; "$ROOT/bin/cicilang++" -std=c++20 -c vp$n.cpp -o vp.o 2>&1 | grep -m1 'error'; done)
vp_want="vp1.cpp:3: error: cannot initialize a variable of type 'int' with an rvalue of type 'void'
vp2.cpp:3: error: assigning to 'int' from incompatible type 'void'
vp3.cpp:3: error: no matching function for call to 'g'
vp4.cpp:3: error: cannot initialize return object of type 'int' with an rvalue of type 'void'
vp5.cpp:3: error: invalid operands to binary expression ('void' and 'int')
vp6.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vp7.cpp:3: error: invalid argument type 'void' to unary expression
vp8.cpp:3: error: C-style cast from 'void' to 'int' is not allowed
vp9.cpp:3: error: functional-style cast from 'void' to 'int' is not allowed
vp10.cpp:3: error: static_cast from 'void' to 'int' is not allowed
vp11.cpp:3: error: cannot initialize a member subobject of type 'int' with an rvalue of type 'void'
vp12.cpp:3: error: cannot initialize a new value of type 'int' with an rvalue of type 'void'
vp13.cpp:3: error: cannot initialize a member subobject of type 'int' with an rvalue of type 'void'
vp14.cpp:3: error: cannot initialize an array element of type 'int' with an rvalue of type 'void'
vp15.cpp:3: error: invalid operands to binary expression ('void' and 'void')
vp16.cpp:3: error: cannot initialize a variable of type 'bool' with an rvalue of type 'void'
vp17.cpp:3: error: invalid application of 'sizeof' to an incomplete type 'void'
vp18.cpp:3: error: non-const lvalue reference to type 'int' cannot bind to a temporary of type 'void'
vp19.cpp:3: error: reference to type 'const int' could not bind to an rvalue of type 'void'
vp20.cpp:3: error: no matching function for call to 'tk'
vp21.cpp:3: error: left operand to ? is void, but right operand is of type 'int'
vp22.cpp:3: error: right operand to ? is void, but left operand is of type 'int'
vp23.cpp:3: error: no viable conversion from 'void' to 'S'
vp24.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
vp25.cpp:3: error: no matching member function for call to 'o'
vp26.cpp:3: error: no matching constructor for initialization of 'M'
vp27.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'M'
vp28.cpp:3: error: cannot pass expression of type 'void' to variadic function
vp29.cpp:3: error: no matching function for call to 'ov'
vp30.cpp:3: error: array subscript is not an integer
vp31.cpp:3: error: indirection requires pointer operand ('void' invalid)
vp32.cpp:3: error: subscripted value is not an array, pointer, or vector
vp33.cpp:3: error: cannot increment value of type 'void'
vp34.cpp:3: error: invalid application of 'sizeof' to an incomplete type 'void'
vp35.cpp:3: error: cannot form a reference to 'void'
vp36.cpp:3: error: variable 'q' with type 'auto *' has incompatible initializer of type 'void'
vp37.cpp:3: error: reinterpret_cast from 'void' to 'int' is not allowed
vp38.cpp:3: error: const_cast to 'int', which is not a reference, pointer-to-object, or pointer-to-data-member
vp39.cpp:3: error: const_cast from 'void' to 'int *' is not allowed
vp40.cpp:3: error: invalid application of 'sizeof' to a function type
vp41.cpp:3: error: variable has incomplete type 'void'
vp42.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vp43.cpp:3: error: statement requires expression of integer type ('void' invalid)
vp44.cpp:3: error: no matching constructor for initialization of 'M'
vp45.cpp:3: error: no matching constructor for initialization of 'M'
vp46.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
vp47.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
vp48.cpp:3: error: no matching function for call to 'g'
vp49.cpp:3: error: no matching function for call to 'g'
vp50.cpp:3: error: no matching function for call to 'g'
vp51.cpp:3: error: no matching function for call to 'g'
vp52.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
vp53.cpp:3: error: no matching function for call to 'vf'
vp54.cpp:3: error: cannot initialize a member subobject of type 'int' with an rvalue of type 'void'
vp55.cpp:3: error: cannot initialize a variable of type 'int' with an rvalue of type 'void'
vp56.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vp57.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vp58.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vp59.cpp:3: error: no viable conversion from returned value of type 'void' to function return type 'S'
vp60.cpp:3: error: cannot use dynamic_cast to convert from 'void' to 'S *'
vp61.cpp:3: error: no matching function for call to 'puts'
vp62.cpp:3: error: invalid operands to binary expression ('void' and 'int')
vp63.cpp:3: error: invalid argument type 'void' to unary expression"
if [ "$vp_got" = "$vp_want" ]; then echo "ok   63 void values and their forms refused as clang++ refuses them, at clang++'s line"
else echo "FAIL the void values' refusals"; echo "$vp_got" > vp_got.txt; echo "$vp_want" > vp_want.txt; diff vp_want.txt vp_got.txt | head -8 | cut -c1-300 | sed 's/^/     /'; failures=$((failures + 1)); fi
# ... AND THE CASTS AND CALLS BESIDE IT (1.6.14): sixty-six bodies -- a void value cast to a pointer, a member pointer, a
# reference and a class by each cast's spelling; a qualified call of one function and of an overload set, a call through a
# using-declaration, a reference and a pointer to a function; a dynamic_cast's operand and target; a class, a plain struct and
# a class template's instance called with one void value, a class with two values, a namespace's class spelled with its
# namespace; and a refusal after an object with a destructor at its own line. Through 1.6.13 a cast to a reference reached
# LLVM's parser, `alloca void', a class's cast was a constructor's words, a dynamic_cast's misfit `phase(desugaring)'
echo "-- and the casts and calls beside a void value, in clang++'s words at their line (1.6.14)"
vc_pre='void f() {} struct S { int m; virtual ~S() {} }; struct T : S {}; struct P { int m; }; int g(int v) { return v; } void ov(int) {} void ov(double) {} template<class T0> void tk(T0) {} template<class T0> struct TT { T0 v; }; struct M { int v; M(int x) : v(x) {} }; struct C { int v; }; struct Q { void m(int) {} void o(int) {} void o(double) {} static void s(int) {} }; struct P2 { int a, b; }; typedef int *IP; enum E { E0 }; namespace ns { int h(int v) { return v; } void k(int) {} void k(double) {} template<class T0> void t(T0) {} struct NC { int v; NC(int x) : v(x) {} }; struct A { int v; }; }\nint main() { int z = 1; (void)z; S s; S *sp = &s; int *ip = &z; P pv{1}; Q qq; (void)sp; (void)ip; (void)pv; (void)qq;'
vc_got=$(n=0; for body in 'int *q = static_cast<int *>(f()); (void)q;' 'int *q = (int *)f(); (void)q;' 'int *q = reinterpret_cast<int *>(f()); (void)q;' 'S *q = static_cast<S *>(f()); (void)q;' 'E e = static_cast<E>(f()); (void)e;' 'double d = static_cast<double>(f()); (void)d;' 'bool b = static_cast<bool>(f()); (void)b;' 'C c = static_cast<C>(f()); (void)c;' 'C c = (C)f(); (void)c;' 'int &r = static_cast<int &>(f()); (void)r;' 'int &&r = static_cast<int &&>(f()); (void)r;' 'E e = (E)f(); (void)e;' 'double d = (double)f(); (void)d;' 'ns::k(f());' '::g(f());' 'ns::t(f());' 'int (S::*pm) = static_cast<int S::*>(f()); (void)pm;' 'long l = reinterpret_cast<long>(f()); (void)l;' 'int *q = const_cast<int *>(f()); (void)q;' 'int &r = const_cast<int &>(f()); (void)r;' 'char c = char(f()); (void)c;' 'int (S::*pm) = (int S::*)f(); (void)pm;' 'int (S::*pm) = reinterpret_cast<int S::*>(f()); (void)pm;' 'int &r = (int &)f(); (void)r;' 'const int &r = (const int &)f(); (void)r;' 'const int &r = static_cast<const int &>(f()); (void)r;' 'int &&r = (int &&)f(); (void)r;' 'using ns::h; h(f());' 'int x = z ? throw 1 : f(); (void)x;' 'z = f() , 1;' 'z = z ? (void)0 : throw 1, 2;' 'qq.s(f());' 'auto x = z ? f() : f(); (void)x;' '::ov(f());' 'int &r = reinterpret_cast<int &>(f()); (void)r;' 'ns::t<int>(f());' 'int (&rf)(int) = g; rf(f());' 'auto *fp = &ns::h; fp(f());' 'S *q = dynamic_cast<S *>(f()); (void)q;' 'S &q = dynamic_cast<S &>(f()); (void)q;' 'S *q = dynamic_cast<S *>(z); (void)q;' 'S *q = dynamic_cast<S *>(g(1)); (void)q;' 'S *q = dynamic_cast<S *>(ip); (void)q;' 'S *q = dynamic_cast<S *>(pv); (void)q;' 'int *q = dynamic_cast<int *>(sp); (void)q;' 'S q = dynamic_cast<S>(s); (void)q;' 'S &q = dynamic_cast<S &>(z); (void)q;' 'const S *q = dynamic_cast<const S *>(f()); (void)q;' 'S &&q = dynamic_cast<S &&>(f()); (void)q;' 'void *q = dynamic_cast<void *>(f()); (void)q;' 'void *q = dynamic_cast<void *>(z); (void)q;' 'ns::NC c = ns::NC(f()); (void)c;' 'ns::A a = ns::A(f()); (void)a;' 'TT<int> t = TT<int>(f()); (void)t;' 'ns::NC c = static_cast<ns::NC>(f()); (void)c;' 'TT<int> t = static_cast<TT<int>>(f()); (void)t;' 'TT<int> t{f()}; (void)t;' 'ns::A a = reinterpret_cast<ns::A>(f()); (void)a;' 'ns::A a = const_cast<ns::A>(f()); (void)a;' 'ns::A a = (ns::A)f(); (void)a;' 'TT<int> *p = static_cast<TT<int> *>(f()); (void)p;' 'tk<int>(f());' 'P p = P(f()); (void)p;' 'M m = M(f(), 1); (void)m;' 'P2 p = P2(f(), 1); (void)p;' 'int &r = static_cast<int &>(z ? f() : f()); (void)r;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$vc_pre" "$body" > vc$n.cpp; "$ROOT/bin/cicilang++" -std=c++20 -c vc$n.cpp -o vc.o 2>&1 | grep -m1 'error'; done)
vc_want="vc1.cpp:3: error: cannot cast from type 'void' to pointer type 'int *'
vc2.cpp:3: error: cannot cast from type 'void' to pointer type 'int *'
vc3.cpp:3: error: reinterpret_cast from 'void' to 'int *' is not allowed
vc4.cpp:3: error: cannot cast from type 'void' to pointer type 'S *'
vc5.cpp:3: error: static_cast from 'void' to 'E' is not allowed
vc6.cpp:3: error: static_cast from 'void' to 'double' is not allowed
vc7.cpp:3: error: static_cast from 'void' to 'bool' is not allowed
vc8.cpp:3: error: no matching conversion for static_cast from 'void' to 'C'
vc9.cpp:3: error: no matching conversion for C-style cast from 'void' to 'C'
vc10.cpp:3: error: non-const lvalue reference to type 'int' cannot bind to a temporary of type 'void'
vc11.cpp:3: error: reference to type 'int' could not bind to an rvalue of type 'void'
vc12.cpp:3: error: C-style cast from 'void' to 'E' is not allowed
vc13.cpp:3: error: C-style cast from 'void' to 'double' is not allowed
vc14.cpp:3: error: no matching function for call to 'k'
vc15.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
vc16.cpp:3: error: no matching function for call to 't'
vc17.cpp:3: error: cannot cast from type 'void' to member pointer type 'int S::*'
vc18.cpp:3: error: reinterpret_cast from 'void' to 'long' is not allowed
vc19.cpp:3: error: const_cast from 'void' to 'int *' is not allowed
vc20.cpp:3: error: const_cast from rvalue to reference type 'int &'
vc21.cpp:3: error: functional-style cast from 'void' to 'char' is not allowed
vc22.cpp:3: error: cannot cast from type 'void' to member pointer type 'int S::*'
vc23.cpp:3: error: reinterpret_cast from 'void' to 'int S::*' is not allowed
vc24.cpp:3: error: C-style cast from rvalue to reference type 'int &'
vc25.cpp:3: error: C-style cast from rvalue to reference type 'const int &'
vc26.cpp:3: error: reference to type 'const int' could not bind to an rvalue of type 'void'
vc27.cpp:3: error: C-style cast from rvalue to reference type 'int &&'
vc28.cpp:3: error: no matching function for call to 'h'
vc29.cpp:3: error: cannot initialize a variable of type 'int' with an rvalue of type 'void'
vc30.cpp:3: error: assigning to 'int' from incompatible type 'void'
vc31.cpp:3: error: assigning to 'int' from incompatible type 'void'
vc32.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
vc33.cpp:3: error: variable has incomplete type 'void'
vc34.cpp:3: error: no matching function for call to 'ov'
vc35.cpp:3: error: reinterpret_cast from rvalue to reference type 'int &'
vc36.cpp:3: error: no matching function for call to 't'
vc37.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
vc38.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
vc39.cpp:3: error: cannot use dynamic_cast to convert from 'void' to 'S *'
vc40.cpp:3: error: dynamic_cast from rvalue to reference type 'S &'
vc41.cpp:3: error: cannot use dynamic_cast to convert from 'int' to 'S *'
vc42.cpp:3: error: cannot use dynamic_cast to convert from 'int' to 'S *'
vc43.cpp:3: error: 'int' is not a class type
vc44.cpp:3: error: cannot use dynamic_cast to convert from 'P' to 'S *'
vc45.cpp:3: error: 'int' is not a class type
vc46.cpp:3: error: invalid target type 'S' for dynamic_cast; target type must be a reference or pointer type to a defined class
vc47.cpp:3: error: 'int' is not a class type
vc48.cpp:3: error: cannot use dynamic_cast to convert from 'void' to 'const S *'
vc49.cpp:3: error: 'void' is not a class type
vc50.cpp:3: error: cannot use dynamic_cast to convert from 'void' to 'void *'
vc51.cpp:3: error: cannot use dynamic_cast to convert from 'int' to 'void *'
vc52.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'ns::NC'
vc53.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'ns::A'
vc54.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'TT<int>'
vc55.cpp:3: error: no matching conversion for static_cast from 'void' to 'ns::NC'
vc56.cpp:3: error: no matching conversion for static_cast from 'void' to 'TT<int>'
vc57.cpp:3: error: cannot initialize a member subobject of type 'int' with an rvalue of type 'void'
vc58.cpp:3: error: reinterpret_cast from 'void' to 'ns::A' is not allowed
vc59.cpp:3: error: const_cast to 'ns::A', which is not a reference, pointer-to-object, or pointer-to-data-member
vc60.cpp:3: error: no matching conversion for C-style cast from 'void' to 'ns::A'
vc61.cpp:3: error: cannot cast from type 'void' to pointer type 'TT<int> *'
vc62.cpp:3: error: no matching function for call to 'tk'
vc63.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'P'
vc64.cpp:3: error: no matching constructor for initialization of 'M'
vc65.cpp:3: error: cannot initialize a member subobject of type 'int' with an rvalue of type 'void'
vc66.cpp:3: error: non-const lvalue reference to type 'int' cannot bind to a temporary of type 'void'"
if [ "$vc_got" = "$vc_want" ]; then echo "ok   66 casts and calls beside a void value refused as clang++ refuses them, at clang++'s line"
else echo "FAIL the casts and calls beside a void value"; echo "$vc_got" > vc_got.txt; echo "$vc_want" > vc_want.txt; diff vc_want.txt vc_got.txt | head -8 | cut -c1-300 | sed 's/^/     /'; failures=$((failures + 1)); fi
# ... AND WHAT THE DESUGARING DOES NOT TRUST, AND A CLASS COPY-INITIALIZED FROM ONE (1.6.14): thirty-two bodies -- a void
# value through a pointer or a reference to a function, as a cast's operand, a reference's, a condition's, `&&''s and `||''s,
# where the lowering refuses it; an overloaded call's as a conditional's place and object; a template declared and not
# defined; a class template's own name and a nested class's qualified name called with one; a class copy-initialized from one
# by `=', a default member initializer, an element, an aggregate's member, a static local and a qualified call's parameter;
# a class assigned one; a local class and a local plain struct by their own names. Through the first form of 1.6.14 the copies
# were `no matching constructor', a local's name its key `L.local_1_<tag>', a class's assignment C's words
echo "-- and the void values that the desugaring does not trust, and the classes copy-initialized from one (1.6.14)"
vu_pre='void f() {} int g(int v) { return v; } void ov(int) {} void ov(double) {} struct S { int m; }; struct M { int v; M(int x) : v(x) {} }; void tm(M) {} template<class T> void td(T); template<class T> struct Bx { T v; Bx(T x) : v(x) {} static Bx mk2() { return Bx(f()); } }; struct O { struct N { int v; N(int x) : v(x) {} }; }; void (*gfp)() = f;\nint main(int argc, char **argv) { (void)argv; (void)argc; int z = 1; M mm(1); void (*fp)() = f; void (&fr)() = f;'
vu_got=$(n=0; for body in '(ov(1) ? z : z) = 3;' 'M m3 = ov(1) ? M(1) : M(2); (void)m3;' 'td(f());' 'Bx<int> b = Bx<int>::mk2(); (void)b;' 'z = O::N(f()).v;' 'z = static_cast<int>(fp());' 'z = (int)fp();' 'int &r = static_cast<int &>(fp()); (void)r;' 'int *q = static_cast<int *>(fp()); (void)q;' 'char *q = (char *)fp(); (void)q;' 'const int &r = static_cast<const int &>(fp()); (void)r;' 'z = fp() && z;' 'z = z || fp();' 'z = static_cast<int>(fr());' 'z = static_cast<int>((*fp)());' 'z = (int)gfp();' 'M m2 = f(); (void)m2;' 'M m2 = z ? f() : f(); (void)m2;' 'struct N2 { M m3 = f(); }; N2 n2; (void)n2;' 'M ma[1] = { f() }; (void)ma;' 'M m2 = (f(), f()); (void)m2;' 'struct L { int v; L(int x) : v(x) {} }; L l = f(); (void)l;' 'struct L { int v; }; L l = f(); (void)l;' 'struct L { int v; }; L l = L(f()); (void)l;' 'struct L { int v; }; L l = static_cast<L>(f()); (void)l;' 'struct N3 { M m; N3() : m(f()) {} }; N3 n3; (void)n3;' 'struct A2 { M m; }; A2 a2 = { f() }; (void)a2;' '::tm(f());' 'mm = f();' 'static M sm = f(); (void)sm;' 'S s = {1}; s = f();' 'struct L { int v; }; L l = {1}; l = f();'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$vu_pre" "$body" > vu$n.cpp; "$ROOT/bin/cicilang++" -std=c++20 -c vu$n.cpp -o vu.o 2>&1 | grep -m1 'error'; done)
vu_want="vu1.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vu2.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vu3.cpp:3: error: no matching function for call to 'td'
vu4.cpp:1: error: no matching conversion for functional-style cast from 'void' to 'Bx<int>'
vu5.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'O::N'
vu6.cpp:3: error: static_cast from 'void' to 'int' is not allowed
vu7.cpp:3: error: C-style cast from 'void' to 'int' is not allowed
vu8.cpp:3: error: non-const lvalue reference to type 'int' cannot bind to a temporary of type 'void'
vu9.cpp:3: error: cannot cast from type 'void' to pointer type 'int *'
vu10.cpp:3: error: cannot cast from type 'void' to pointer type 'char *'
vu11.cpp:3: error: reference to type 'const int' could not bind to an rvalue of type 'void'
vu12.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vu13.cpp:3: error: value of type 'void' is not contextually convertible to 'bool'
vu14.cpp:3: error: static_cast from 'void' to 'int' is not allowed
vu15.cpp:3: error: static_cast from 'void' to 'int' is not allowed
vu16.cpp:3: error: C-style cast from 'void' to 'int' is not allowed
vu17.cpp:3: error: no viable conversion from 'void' to 'M'
vu18.cpp:3: error: no viable conversion from 'void' to 'M'
vu19.cpp:3: error: no viable conversion from 'void' to 'M'
vu20.cpp:3: error: no viable conversion from 'void' to 'M'
vu21.cpp:3: error: no viable conversion from 'void' to 'M'
vu22.cpp:3: error: no viable conversion from 'void' to 'L'
vu23.cpp:3: error: no viable conversion from 'void' to 'L'
vu24.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'L'
vu25.cpp:3: error: no matching conversion for static_cast from 'void' to 'L'
vu26.cpp:3: error: no matching constructor for initialization of 'M'
vu27.cpp:3: error: no viable conversion from 'void' to 'M'
vu28.cpp:3: error: no viable conversion from 'void' to 'M'
vu29.cpp:3: error: no viable overloaded '='
vu30.cpp:3: error: no viable conversion from 'void' to 'M'
vu31.cpp:3: error: no viable overloaded '='
vu32.cpp:3: error: no viable overloaded '='"
if [ "$vu_got" = "$vu_want" ]; then echo "ok   32 void values the desugaring does not trust and classes copy-initialized from one, refused as clang++ refuses them"
else echo "FAIL the void values the desugaring does not trust and the copies"; echo "$vu_got" > vu_got.txt; echo "$vu_want" > vu_want.txt; diff vu_want.txt vu_got.txt | head -8 | cut -c1-300 | sed 's/^/     /'; failures=$((failures + 1)); fi
echo "-- and the safe part refuses what leaves its scope"
for pair in "callborrow:a borrow handed to a call that may replace its owner" "callborrowptr:a borrow handed to a call that may replace its owner" "callborrowref:a borrow handed to a call that may replace its owner" "callreplaceptr:use of a borrow after a call that may replace its owner" "callreplaceref:use of a borrow after a call that may replace its owner" "escape:a borrow leaves the function" "thisunset:owner used before it was given anything" "gotopastdtor:cannot jump from this goto statement to its label" "tryowner:use after move of" "throwowner:owner live where a call may throw, and no defer frees it" "allocleak:plain pointer not consumed" "allocdouble:use after move of" "libvec:a borrow leaves the function" "libfn:a borrow leaves the function" "libview:a borrow leaves the function" "libiter:a borrow leaves the function" "libref:a borrow leaves the function" "libmap:a borrow leaves the function" "libstruct:a borrow leaves the function" "libbyval:a borrow leaves the function" "libassign:a borrow leaves the function" "libstored:a borrow stored where it cannot be followed" "libmember:a borrow stored where it cannot be followed" "libiterdangle:use of a borrow after its owner was consumed" "libptrdangle:use of a borrow after its owner was consumed" "libtwolocals:use of a borrow after its owner was consumed" "librowstore:a borrow leaves the function" "libmemberview:a borrow leaves the function" "byvalref:a borrow leaves the function" "flowmember:a borrow leaves the function" "flowfree:a borrow leaves the function" "flowwrap:a borrow leaves the function" "freeswap:a borrow leaves the function" "freefill:a borrow leaves the function" "freecopy:a borrow leaves the function" "flowview:a borrow leaves the function" "flowarith:a borrow leaves the function" "flowarith2:a borrow leaves the function" "addrview:a borrow leaves the function" "refparamfield:a borrow stored where it cannot be followed" "flowout:a borrow stored where it cannot be followed" "flowglobalvec:a borrow stored where it cannot be followed" "flowstaticlocal:a borrow stored where it cannot be followed" "callreplace:use of a borrow after a call that may replace its owner" "refreplace:use of a borrow after a call that may replace its owner" "localrefreplace:use of a borrow after a call that may replace its owner" "tiedrefreplace:use of a borrow after a call that may replace its owner" "constmethod:cannot assign to non-static data member within const member function 'bad'" "constrefslot:cannot assign to variable 'b' with const-qualified type 'const Buf &'" "nullfilledref:owner leaked" "staticns:an own array's element given to an owner with no move" "staticmember:an own array's element given to an owner with no move" "dropped_new:new memory given no owner (nothing frees it)" "dropped_new_array:new memory given no owner (nothing frees it)" "dropped_new_nothrow:new memory given no owner (nothing frees it)" "deleted_twice:use after free of" "deleted_read:use after free of" "refvalue_move:use after move of 'p'" "refcond_move:use after move of 'p'" "refassign_escape:a borrow leaves the function: 'x'" "refstep_escape:a borrow leaves the function: 'x'" "callborrowcomma:a borrow handed to a call that may replace its owner" "callreplacecomma:use of a borrow after a call that may replace its owner" "callreplacerefcomma:use of a borrow after a call that may replace its owner" "itercomma:use of a borrow after its owner was consumed" "nsleak:plain pointer not consumed" "nsleakclass:plain pointer not consumed" "nsleakanon:plain pointer not consumed" "nsleakextc:plain pointer not consumed" "nsflow:a borrow stored where it cannot be followed" "nsstatret:a borrow consumed" "nsstaticwrite:use of a borrow after a call that may replace its owner" "noreturnreturn:function 'stop' declared 'noreturn' should not return" "noreturnmember:function 'fail' declared 'noreturn' should not return" "noreturnend:function declared 'noreturn' should not return" "noreturnnxend:function declared 'noreturn' should not return" "noreturnanon:function 'stop' declared 'noreturn' should not return" "noreturnoverload:function 'stop' declared 'noreturn' should not return" "lj_dtor:a longjmp over a defer, a destructor or a drop" "lj_dtor_block:a longjmp over a defer, a destructor or a drop" "lj_dtor_out:a longjmp over a defer, a destructor or a drop" "lj_throw_write:a pointer that changed between a setjmp and a longjmp to it"; do   # a closure holding a reference to a local returned (0.100); `this' handed out of a constructor while an own field is unset (0.133); a goto over a local with a destructor (0.138); a handler that frees again an owner its try's body freed (0.193); a library object holding a local's borrow returned, or stored where it outlives the local (0.216); an iterator, a pointer or what a container holds used after its local ended, a store through a range-for's reference or into a view member, a reference to a parameter by value returned, what a function of the program or a free library function stores, the address of a local view (0.217); the safety rules of 0.265 to 0.267 in C++ (0.272): a borrow of an object's own field read after a call that may replace it -- a member function that is not const, a reference parameter that is not const, a local reference, a result tied to a reference parameter --, an own field assigned in a const member function and through a reference to const, in clang's words, and a null own field that a call may fill, leaked; an own array of a namespace and a class's static own array member, an element given to an owner with no move (0.307); a reference bound to a value whose initializer moves an owner, a call's and a conditional's, and a local returned through an assignment or a prefix ++ from a function that returns a reference, and callborrow.cpp's, callreplace.cpp's and an iterator's refusals through a comma (1.6.13); the leak of a namespace's function, of a class's member in nested namespaces, of an anonymous namespace's and of an `extern "C"' block's, and a namespace's flow, static result and static array's write, which the check never walked (1.6.16); a function declared [[noreturn]] that returns -- a namespace's, a member, an anonymous namespace's, an overload, its end and a noexcept one's end --, in clang++'s words, a longjmp over a destructor, from a block and out of the function, and a pointer stepped before a throw whose handler jumps (1.6.17)
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
# THE SAFETY RULES OF 0.265 TO 0.267 IN C++ (0.272; CCLLIB.md's phase 0.10): the C fixtures of test/c/safe that the
# same rule refuses in a C++ build, with the same words -- a type macro's instance whose push or [] may replace its
# buffer, and an own field of a const object. The four others meet C++'s own refusal first, the defer rule: a plain
# struct's live owner across a call that may throw (borrow_after_grow.c, grow_through_ptr.c, tied_after_call.c,
# null_filled.c); test/cpp/callreplace.cpp and its kin above hold those rules in C++'s forms. A borrow handed to a call
# that may replace its owner is refused before the defer rule (0.293): borrow_into_call.c and borrow_into_call_local.c
# have the C words, and test/cpp/callborrow.cpp a member function's form. Static storage freed, handed to an own
# parameter or given to an owner, and a function's result that is new memory to the check (0.294). A row of a static
# array and an array member of a static struct freed or given to an owner, and a pointer to a block's local that hides
# an outer one, used after the block (0.297). A sum of a loose pointer, a borrow of it still, and an own local that
# takes the buffer that getline wrote through an out-parameter, new memory (0.299). A borrow handed to such a call through a
# pointer to its owner, `&bp->data[0]' and `(*bp).data' over `bp = &b' (0.303); borrow_after_call_arrow.c, the rule of
# 0.265 through a pointer, meets the defer rule first, and test/cpp/callreplaceptr.cpp holds it in C++'s form. An own
# array of static storage (0.307): its element given to an owner, a field, an element or an own result with no move, a
# borrow of it used after a store, after a call that may store into the array -- deep, or through a pointer --, and a
# borrow of it returned with no tie on the result, or with one and then a store or such a call. New memory thrown
# away (0.309): an allocator's block, an own result's, the clone macro's copy, by a statement, a cast to void, a comma,
# a conditional or a for's clause; test/cpp/dropped_new.cpp, dropped_new_array.cpp and dropped_new_nothrow.cpp hold C++'s
# new-expressions through the library's allocation functions, deleted_twice.cpp and deleted_read.cpp a plain pointer
# after its delete (1.6.32), and test/cpp/run/placealloc.cpp the program's own
# placement function, whose block is the arena's and no new memory. A pointer read out of a plain slot of the program's
# global object, freed or given to an owner (1.6.31). A plain pointer that a free left freed, freed again, written
# through, read, copied, closed again and handed by its address to getline (1.6.32)
echo "-- and the safe fixtures of test/c/safe that the same rule refuses in C++ (0.272)"
for pair in "borrow_into_call_arrow:a borrow handed to a call that may replace its owner" "borrow_into_call_deref:a borrow handed to a call that may replace its owner" "static_row_free:a borrow consumed" "static_row_own:a borrow stored where it cannot be followed" "static_member_free:a borrow consumed" "shadow_dangle:use of a borrow after its owner was consumed" "sum_of_loose:plain pointer not consumed" "own_of_anchor:owner leaked" "statret_param:plain pointer not consumed" "statret_mixed:plain pointer not consumed" "free_lit:a borrow consumed" "free_glob:a borrow consumed" "free_direct:a borrow consumed" "statret_free:a borrow consumed" "own_static:a borrow stored where it cannot be followed" "own_lit:a borrow stored where it cannot be followed" "take_own:a borrow consumed" "assign_static:a borrow consumed" "borrow_into_call:a borrow handed to a call that may replace its owner" "borrow_into_call_local:a borrow handed to a call that may replace its owner" "borrow_after_push:use of a borrow after a call that may replace its owner" "elem_after_push:use of a borrow after a call that may replace its owner" "index_after_insert:use of a borrow after a call that may replace its owner" "const_replace:cannot assign to variable 'b' with const-qualified type 'const buf *'" "const_local:cannot assign to variable 'v' with const-qualified type 'const buf'" "static_elem_kept:an own array's element given to an owner with no move" "static_elem_assign:an own array's element given to an owner with no move" "static_elem_field:an own array's element given to an owner with no move" "static_elem_elem:an own array's element given to an owner with no move" "static_elem_return:an own array's element given to an owner with no move" "static_member_elem:an own array's element given to an owner with no move" "local_elem_kept:an own array's element given to an owner with no move" "static_local_elem:an own array's element given to an owner with no move" "static_borrow_store:use of a borrow after its owner was consumed" "static_borrow_call:use of a borrow after a call that may replace its owner" "static_borrow_deep:use of a borrow after a call that may replace its owner" "static_borrow_pointer:use of a borrow after a call that may replace its owner" "static_result_untied:a borrow of an own array returned with no tie on the result" "static_tied_store:use of a borrow after its owner was consumed" "static_tied_call:use of a borrow after a call that may replace its owner" "dropped_malloc:new memory given no owner (nothing frees it)" "dropped_strdup:new memory given no owner (nothing frees it)" "dropped_realloc:new memory given no owner (nothing frees it)" "dropped_own_result:new memory given no owner (nothing frees it)" "dropped_void_cast:new memory given no owner (nothing frees it)" "dropped_comma:new memory given no owner (nothing frees it)" "dropped_cond:new memory given no owner (nothing frees it)" "dropped_for_step:new memory given no owner (nothing frees it)" "dropped_for_init:new memory given no owner (nothing frees it)" "dropped_clone:new memory given no owner (nothing frees it)" "slot_free:a borrow consumed" "slot_free_direct:a borrow consumed" "slot_free_global:a borrow consumed" "slot_free_member:a borrow consumed" "slot_own:a borrow stored where it cannot be followed" "freed_twice:use after free of" "freed_write:use after free of" "freed_read:use after free of" "freed_copy:use after free of" "freed_fclose:use after free of" "freed_getline:use after free of"; do
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cicilang++" -c "$ROOT/test/c/safe/$n.c" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.c, built as C++, is refused: $what" ;; *) echo "FAIL $n.c built as C++ should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
echo "-- and a false static assertion, the program's or a library header's, is an error"
for pair in "sassertfail:static assertion failed: wrong size" "sassertinst:static assertion failed: one byte" "memassert:static assertion failed: int is eight" "memassert2:static assertion failed: too small" "sassertvirt:static assertion failed: B needs a char" "libassert:static assertion failed: Index out of bounds in std::get<> (std::array)" "libassert2:static assertion failed: instantiation of optional with a reference type is ill-formed" "libassert3:static assertion failed: variant can not have a void type as an alternative."; do   # at file scope, and in an instance of a function template (0.198); a class member's, and a class template instance's (0.205), one a probe made (0.221); a library header's (0.221)
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cicilang++" -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
echo "-- and the program's static assertion whose condition does not fold is an error, in clang's words (0.257)"
for n in sassertunfold constleak constdblfree constuseafter nceplain ncemember ncevirtual ncetemplate ncector constagg constagglocal constfloat floatdivzero cookiedelete opnewconst; do   # a throw caught in a constant evaluation (C++26's P3068, not done); a block the evaluation still holds where it ends, one freed twice, one read after its free (C++20's transient allocation); a call of the program's function that is not constexpr -- free, member, virtual, a template's instance, a constructor (0.258); a const aggregate that is not constexpr, at file scope and in a block, and a const double (0.258); a floating division by zero (0.258); an array new's block deleted by `delete', and `::operator new' outside std::allocator (0.258)
  what="static assertion expression is not an integral constant expression"
  got=$("$ROOT/bin/cicilang++" -std=c++20 -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
echo "-- and an rvalue for a free operator's W & parameter, in clang++'s words (1.6.6, 1.6.24)"
got=$("$ROOT/bin/cicilang++" $(cat "$ROOT/test/cpp/freeoprval.flags" 2>/dev/null) -c "$ROOT/test/cpp/freeoprval.cpp" -o freeoprval.o 2>&1; echo "exit $?")
case "$got" in *"no viable overloaded '+='"*"exit 1"*) echo "ok   freeoprval.cpp is refused: no viable overloaded '+='" ;; *) echo "FAIL freeoprval.cpp should be refused with 'no viable overloaded '+=''"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
echo "-- and a call of a deleted function is an error, in clang's words, its reason after (0.257)"
for pair in "delfree:call to deleted function 'g': call g(long)" "delmember:call to deleted member function 'f'" "delstatic:call to deleted function 'f'" "delctor:call to deleted constructor of 'ns::W<char>': no int" "delcopy:call to deleted constructor of 'S'" "delimplcopy:call to implicitly-deleted copy constructor of 'std::unique_ptr<int>'" "deltmpl:call to deleted function 'h'" "delop:overload resolution selected deleted operator '==': compare v" "delassign:overload resolution selected deleted operator '='" "delimplassign:object of type 'std::unique_ptr<int>' cannot be assigned because its copy assignment operator is implicitly deleted" "deldefcopy:call to implicitly-deleted copy constructor of 'DefCopy'" "deldefassign:object of type 'DA' cannot be assigned because its copy assignment operator is implicitly deleted" "deltmplfn:call to deleted function 'h'" "delmembertmpl:call to deleted member function 'f'" "delspec:call to deleted function 'p'" "delmovemember:call to implicitly-deleted copy constructor of 'S'" "delmovedflt:call to implicitly-deleted copy constructor of 'S'" "deldfltassign:object of type 'S' cannot be assigned because its copy assignment operator is implicitly deleted" "delcopyowner:call to implicitly-deleted copy constructor of 'S'" "delcopymove:call to implicitly-deleted copy constructor of 'S'" "delmovedecl:call to deleted constructor of 'M'" "delrefassign:object of type 'R' cannot be assigned because its copy assignment operator is implicitly deleted" "delconstassign:object of type 'C' cannot be assigned because its copy assignment operator is implicitly deleted" "vectorcopy:vectorcopy.cpp:3: error: call to deleted constructor of 'NC'" "vectorcopy2:vectorcopy2.cpp:3: error: call to deleted constructor of 'NC'" "delmethassign:delmethassign.cpp:2: error: object of type 'R' cannot be assigned because its copy assignment operator is implicitly deleted"; do   # a free function, a member, a static member, a constructor, a copy, the implicit copy, a template, a free operator, an assignment, the implicit assignment, a defaulted copy and a defaulted assignment defined as deleted; a deleted function template beside a plain overload, a deleted member template, a deleted explicit specialization (0.258); a member whose move is deleted, a defaulted move over it, a defaulted move assignment over one, a member that does not copy, a member whose deleted move hides its copy, a declared deleted move (0.258); a plain struct with a reference or a const member assigned (0.258); a std::vector's push_back of an lvalue whose copy is deleted, at the program's line (0.258)
  n=${pair%%:*}; what=${pair#*:}
  got=$("$ROOT/bin/cicilang++" -std=c++26 -c "$ROOT/test/cpp/$n.cpp" -o "$n.o" 2>&1; echo "exit $?")
  case "$got" in *"$what"*"exit 1"*) echo "ok   $n.cpp is refused: $what" ;; *) echo "FAIL $n.cpp should be refused with '$what'"; echo "     got  $got" | head -3; failures=$((failures + 1)) ;; esac
done
[ "$skipped" -gt 0 ] && echo "-- $skipped fixture(s) skipped: beyond this box's library (NAME.needs)"
if [ "$failures" -eq 0 ]; then echo "GREEN: cicilang++"; else echo "RED: $failures failure(s)"; exit 1; fi
