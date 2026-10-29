#!/bin/sh
# test/toolchain.sh -- THE TOOLCHAIN CHECK (0.223): what the build and the gates need, each found and its version
# printed beside test/toolchain.pins -- the neighbours' commits and versions, the embedded LLVM and the libc++ trees the
# gates were last GREEN on. It runs FIRST in the chain (test/gates.sh) and in the CI job (test/ci.sh), and takes a few
# seconds.
#
# THE VERDICT: a tool the build or a gate needs that is missing or broken is MISSING, with what to do, and RED; a
# neighbour at another commit or version than its pin, or a module built before the cocolog it runs on, is DIFFERS --
# a line, and RED only under TOOLCHAIN_STRICT=1 (the CI job, which clones the pins), since a step that moves a pin runs
# the gates before it writes the new one; what only an optional part needs -- the cross gate's tools, gcc's decimal
# types, a libc++ tree no pass of this run reads -- is a skip line, as that gate's own SKIP is. Every cocolog run here
# has its time cap and its memory cap, summed over its process tree (CLAUDE.md, Caps). ON A MAC (0.224) the trees are
# Homebrew's kegs, llvm@N (brew links no versioned formula), libc++'s library under the keg's lib/c++, the SDK the one
# the compiler reads (ccl_sdk_dirs/1: $SDKROOT's, the command line tools', Xcode's), and the cross gate Linux's.
#
#   sh test/toolchain.sh                       # the check
#   TOOLCHAIN_STRICT=1 sh test/toolchain.sh    # a neighbour off its pin is RED too
#   TOOLCHAIN_TREES=18 sh test/toolchain.sh    # these libc++ trees asked for, not the pins' (empty: none)
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
[ -f "$HERE/toolchain.pins" ] || { echo "RED: no test/toolchain.pins"; exit 1; }
. "$HERE/toolchain.pins"
CICILI=${CICILI:-$HOME/Projects/GitHub/cicili}
COCOLOG=${COCOLOG:-$HOME/Projects/GitHub/cocolog}
ZIGURATIP=${ZIGURATIP:-$(dirname "$COCOLOG")/ZiguratIP}
C="$COCOLOG/cocolog"
TOOLCHAIN_STRICT=${TOOLCHAIN_STRICT:-0}; tc_trees=${TOOLCHAIN_TREES-$LIBCXX_TREES}
tc_tmp=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-toolchain-XXXXXX"); trap 'rm -rf "$tc_tmp"' EXIT
tc_bad=0; tc_diff=0

tc_line() { printf '%-8s %-16s %s\n' "$1" "$2" "$3"; }
tc_ok() { tc_line ok "$1" "$2"; }
tc_missing() { tc_line MISSING "$1" "$2"; tc_bad=$((tc_bad + 1)); }
tc_differs() { tc_line DIFFERS "$1" "$2"; tc_diff=$((tc_diff + 1)); }
tc_skip() { tc_line skip "$1" "$2"; }
# the process tree of a pid, and its resident size in MB; a helper's names are its own (sh has no locals, 0.107)
tc_tree() { echo "$1"; for _tc_c in $(pgrep -P "$1" 2>/dev/null); do tc_tree "$_tc_c"; done; }
tc_rss() { _tc_s=0; for _tc_p in $(tc_tree "$1"); do _tc_r=$(ps -o rss= -p "$_tc_p" 2>/dev/null); _tc_s=$((_tc_s + ${_tc_r:-0})); done; echo $((_tc_s / 1024)); }
tc_run() {   # tc_run SECS MB OUT CMD...: CMD's output to OUT, under a time cap and a memory cap over its process tree
  _tc_secs=$1; _tc_mb=$2; _tc_out=$3; shift 3
  "$@" > "$_tc_out" 2>&1 < /dev/null &
  _tc_pid=$!; _tc_n=0
  while kill -0 "$_tc_pid" 2>/dev/null; do
    sleep 0.2; _tc_n=$((_tc_n + 1))
    if [ "$(tc_rss "$_tc_pid")" -gt "$_tc_mb" ] || [ "$_tc_n" -ge $((_tc_secs * 5)) ]; then
      for _tc_p in $(tc_tree "$_tc_pid"); do kill -9 "$_tc_p" 2>/dev/null; done
      echo "KILLED at its cap ($_tc_secs s, $_tc_mb MB)" >> "$_tc_out"; break
    fi
  done
  wait "$_tc_pid" 2>/dev/null
}
tc_commit() { git -C "$1" rev-parse --short=7 HEAD 2>/dev/null; }
tc_pin() {   # tc_pin NAME DIR PIN: the checkout's commit beside its pin, by their first seven digits
  _tc_have=$(tc_commit "$2")
  if [ -z "$_tc_have" ]; then tc_line note "$1" "$2 is no git checkout: its commit is not known (the pin is $3)"
  elif [ "$(printf '%s' "$_tc_have" | cut -c1-7)" != "$(printf '%s' "$3" | cut -c1-7)" ]; then tc_differs "$1" "the checkout at $2 is at $_tc_have, the pin is $3"; fi
}
tc_major() { echo "$1" | grep -o '[0-9][0-9]*\.[0-9][0-9.]*' | head -1 | cut -d. -f1; }
case "$(uname -s)" in Darwin) tc_os=macos ;; *) tc_os=linux ;; esac
# LLVM N's tree, and the package that brings a tool: Debian's and Ubuntu's, or Homebrew's
tc_llvm() { if [ "$tc_os" = macos ]; then echo "$(brew --prefix 2>/dev/null || echo /usr/local)/opt/llvm@$1"; else echo "/usr/lib/llvm-$1"; fi; }
tc_get() { if [ "$tc_os" = macos ]; then echo "brew install $2"; else echo "apt-get install $1"; fi; }
tc_lib() {   # tc_lib DIR NAME: the library NAME in the tree DIR, Debian's lib/NAME.so or Homebrew's lib/c++/NAME.dylib
  for _tc_f in "$1"/lib/$2.so* "$1"/lib/c++/$2.*dylib "$1"/lib/$2.*dylib; do [ -e "$_tc_f" ] && return 0; done; return 1
}

echo "-- the toolchain, beside test/toolchain.pins (cocolog $COCOLOG_VERSION $COCOLOG_COMMIT, Cicili $CICILI_VERSION $CICILI_COMMIT, ZiguratIP $ZIGURATIP_COMMIT, LLVM $LLVM_MAJOR, libc++ $LIBCXX_TREES)"

# the shell's tools the gates and the pool call
tc_have=""; tc_none=""
for t in awk sed grep timeout pgrep pkill ps mktemp git make cc c++; do
  if command -v "$t" >/dev/null 2>&1; then tc_have="$tc_have $t"; else tc_none="$tc_none $t"; fi
done
if [ -z "$tc_none" ]; then tc_ok "tools" "$tc_have"
elif [ "$tc_os" = macos ]; then tc_missing "tools" "not on PATH:$tc_none (macOS has no timeout: brew install coreutils, its gtimeout linked as timeout first on PATH, as test/ci.sh does; git, make, cc and c++ are the Xcode command line tools')"
else tc_missing "tools" "not on PATH:$tc_none (coreutils, procps, git, make, a C and a C++ compiler)"; fi

# SBCL and Cicili: the modules are Cicili, transpiled through SBCL
if command -v sbcl >/dev/null 2>&1; then tc_ok "sbcl" "$(sbcl --version 2>&1 | head -1)"; else tc_missing "sbcl" "not on PATH ($(tc_get sbcl sbcl)): Cicili runs on it"; fi
if [ -f "$CICILI/cicili.lisp" ]; then
  tc_run 120 2800 "$tc_tmp/cicili" sh -c 'cd "$1" && CL_SOURCE_REGISTRY="$(pwd)/:" exec sbcl --script cicili.lisp --version' sh "$CICILI"
  tc_v=$(grep -o '^[0-9][0-9.]*$' "$tc_tmp/cicili" | tail -1)
  if [ -z "$tc_v" ]; then tc_missing "Cicili" "$CICILI/cicili.lisp did not say its version: $(tail -n 2 "$tc_tmp/cicili" | tr '\n' ' ' | cut -c1-120)"
  elif [ "$tc_v" != "$CICILI_VERSION" ]; then tc_differs "Cicili" "$tc_v at $CICILI, the pin is $CICILI_VERSION"
  else tc_ok "Cicili" "$tc_v ($(tc_commit "$CICILI")) at $CICILI"; fi
  tc_pin "Cicili" "$CICILI" "$CICILI_COMMIT"
else
  tc_missing "Cicili" "no $CICILI/cicili.lisp: set CICILI, or clone https://github.com/saman-pasha/cicili at $CICILI_COMMIT"
fi

# cocolog, its SDK and its modules
if [ -x "$C" ]; then
  tc_run 30 2800 "$tc_tmp/cocolog" "$C" --version
  tc_v=$(grep -o 'cocolog [0-9][0-9.]*' "$tc_tmp/cocolog" | head -1 | cut -d' ' -f2)
  if [ -z "$tc_v" ]; then tc_missing "cocolog" "$C did not say its version: $(head -n 2 "$tc_tmp/cocolog" | tr '\n' ' ' | cut -c1-120)"
  elif [ "$tc_v" != "$COCOLOG_VERSION" ]; then tc_differs "cocolog" "$tc_v at $COCOLOG, the pin is $COCOLOG_VERSION"
  else tc_ok "cocolog" "$tc_v ($(tc_commit "$COCOLOG")) at $COCOLOG"; fi
  tc_pin "cocolog" "$COCOLOG" "$COCOLOG_COMMIT"
  [ -f "$COCOLOG/lib/sdk.cicili" ] || tc_missing "cocolog SDK" "no $COCOLOG/lib/sdk.cicili: module/build.sh links it"
  tc_none=""
  for m in os process stream; do [ -f "$COCOLOG/library/$m.so" ] || tc_none="$tc_none library($m)"; done
  for m in chart tables debug; do [ -f "$COCOLOG/library/flow/$m.pl" ] || tc_none="$tc_none library(flow/$m)"; done
  if [ -z "$tc_none" ]; then tc_ok "cocolog modules" "os, process, stream, flow/chart, flow/tables, flow/debug"
  else tc_missing "cocolog modules" "not built:$tc_none (make modules in $COCOLOG)"; fi
  # the store is ZiguratIP, linked into the binary: one row written and read back in a store of its own
  tc_run 60 2800 "$tc_tmp/store" "$C" --embed "$tc_tmp/KB" query "assertz(ccl_toolchain_row(7)), ccl_toolchain_row(X), write(row(X)), nl"
  if grep -q 'row(7)' "$tc_tmp/store"; then tc_ok "the store" "a row written and read back through ZiguratIP ($(tc_commit "$ZIGURATIP") at $ZIGURATIP)"
  else tc_missing "the store" "cocolog's store did not answer: $(tail -n 2 "$tc_tmp/store" | tr '\n' ' ' | cut -c1-120)"; fi
  [ -d "$ZIGURATIP" ] && tc_pin "ZiguratIP" "$ZIGURATIP" "$ZIGURATIP_COMMIT"
else
  tc_missing "cocolog" "no binary at $C: set COCOLOG, or clone https://github.com/saman-pasha/cocolog at $COCOLOG_COMMIT and build it (its install/install-$tc_os.sh)"
fi

# this checkout's two modules: built, over the cocolog they run on, from the version their source names
tc_src=$(grep -o '(coco_m_arg e g 0) "[0-9][0-9.]*"' "$ROOT/module/cicilang.cicili" | grep -o '"[0-9.]*"' | tr -d '"')
if [ -f "$ROOT/library/cicilang.so" ] && [ -f "$ROOT/library/ccl_llvm.so" ] && [ -x "$C" ]; then
  tc_run 60 2800 "$tc_tmp/version" "$ROOT/bin/cicilang" --version
  tc_v=$(grep -o '^cicilang [^ ]*' "$tc_tmp/version" | cut -d' ' -f2)
  tc_l=$(grep -o 'LLVM [0-9][0-9.]*' "$tc_tmp/version" | cut -d' ' -f2)
  if [ -z "$tc_v" ]; then tc_missing "modules" "bin/cicilang --version failed: $(tail -n 2 "$tc_tmp/version" | tr '\n' ' ' | cut -c1-120)"
  elif [ "$tc_v" != "$tc_src" ]; then tc_differs "modules" "library/cicilang.so is $tc_v, module/cicilang.cicili $tc_src: sh module/build.sh"
  elif [ "$(tc_major "$tc_l")" != "$LLVM_MAJOR" ]; then tc_differs "modules" "the embedded LLVM is $tc_l, the pin is $LLVM_MAJOR: LLVM=$(tc_llvm "$LLVM_MAJOR") sh module/build-llvm.sh"
  elif [ "$C" -nt "$ROOT/library/cicilang.so" ] || [ "$C" -nt "$ROOT/library/ccl_llvm.so" ]; then
    tc_differs "modules" "cocolog is newer than this checkout's modules: a .so reads the SDK's structs by their layout, so sh module/build.sh and sh module/build-llvm.sh"
  else tc_ok "modules" "$(cat "$tc_tmp/version" | head -1)"; fi
else
  tc_missing "modules" "library/cicilang.so or library/ccl_llvm.so is not built: sh module/build.sh, LLVM=$(tc_llvm "$LLVM_MAJOR") sh module/build-llvm.sh"
fi

# LLVM: the tree module/build-llvm.sh builds against, the clang the gates hold the compiler to, the line table's reader
tc_tree_l=$(tc_llvm "$LLVM_MAJOR")
if [ -x "$tc_tree_l/bin/llvm-config" ]; then tc_ok "llvm-config" "$("$tc_tree_l/bin/llvm-config" --version) at $tc_tree_l (module/build-llvm.sh)"
else tc_missing "llvm-config" "no $tc_tree_l/bin/llvm-config ($(tc_get "llvm-$LLVM_MAJOR-dev" "llvm@$LLVM_MAJOR")): module/build-llvm.sh builds against it"; fi
for t in clang clang++; do   # a Mac's are Apple's, the system's own C and C++ compilers, as clang is Linux's
  if command -v "$t" >/dev/null 2>&1; then tc_ok "$t" "$("$t" --version 2>&1 | head -1)"
  elif [ "$tc_os" = macos ]; then tc_missing "$t" "not on PATH (the Xcode command line tools: xcode-select --install): the gates hold the compiler to it"
  else tc_missing "$t" "not on PATH (apt-get install clang-$LLVM_MAJOR): the gates hold the compiler to it"; fi
done
# a Mac's C library is the SDK's: the first of the directories the compiler reads it from (ccl_sdk_dirs/1)
if [ "$tc_os" = macos ]; then
  tc_sdk=""
  for d in "${SDKROOT:+$SDKROOT/usr/include}" /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include; do
    [ -n "$d" ] && [ -f "$d/stdio.h" ] && { tc_sdk=$d; break; }
  done
  if [ -n "$tc_sdk" ]; then tc_ok "SDK" "$tc_sdk (macOS $(sw_vers -productVersion 2>/dev/null), the SDK $(xcrun --show-sdk-version 2>/dev/null) for Apple's clang)"
  else tc_missing "SDK" "no stdio.h in \$SDKROOT/usr/include, the command line tools' SDK or Xcode's: xcode-select --install"; fi
fi
if command -v llvm-dwarfdump >/dev/null 2>&1 || [ -x "$tc_tree_l/bin/llvm-dwarfdump" ]; then tc_ok "llvm-dwarfdump" "for the driver gate's -g checks"
else tc_missing "llvm-dwarfdump" "neither on PATH nor in $tc_tree_l/bin: the driver gate reads the line table with it"; fi

# the libc++ trees: the one this run's C++ gates read ($LLVM, else the newest), and each one asked for
if [ -n "$tc_trees" ]; then
  if [ "$tc_os" = macos ]; then tc_now=${LLVM:-}; else tc_now=${LLVM:-$(ls -d /usr/lib/llvm-* 2>/dev/null | sort -t- -k2 -n | tail -1)}; fi
  for n in $tc_trees; do
    d=$(tc_llvm "$n")   # the library: Debian's lib/libc++.so, Homebrew's lib/c++/libc++.dylib
    if [ -f "$d/include/c++/v1/vector" ] && tc_lib "$d" libc++ && tc_lib "$d" libc++abi; then
      tc_ok "libc++ $n" "$d$( [ "$d" = "$tc_now" ] && echo ', read by this run')"
    elif [ "$d" = "$tc_now" ] || [ "$TOOLCHAIN_STRICT" = 1 ]; then
      tc_missing "libc++ $n" "no headers or no library under $d ($(tc_get "libc++-$n-dev libc++abi-$n-dev libunwind-$n-dev" "llvm@$n"))"
    else
      tc_skip "libc++ $n" "not under $d: the C++ gates' pass over libc++ $n cannot run here"
    fi
  done
fi

# what an optional part needs: the cross gate's aarch64 tools, gcc's decimal types
tc_none=""
for t in qemu-aarch64 aarch64-linux-gnu-gcc; do command -v "$t" >/dev/null 2>&1 || tc_none="$tc_none $t"; done
[ -d /usr/aarch64-linux-gnu/lib ] || tc_none="$tc_none /usr/aarch64-linux-gnu"
if [ "$tc_os" = macos ]; then tc_skip "cross" "the cross gate is Linux's: qemu-user over Debian's aarch64 sysroot"
elif [ -z "$tc_none" ]; then tc_ok "cross" "qemu-aarch64 $(qemu-aarch64 --version 2>/dev/null | head -1 | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p'), aarch64-linux-gnu-gcc, the sysroot"
else tc_skip "cross" "missing:$tc_none -- the cross gate SKIPs (apt-get install qemu-user gcc-aarch64-linux-gnu libc6-dev-arm64-cross)"; fi
if printf '_Decimal64 x;\n' | gcc -x c -c -o /dev/null - 2>/dev/null; then tc_ok "decimal gcc" "$(gcc --version | head -1), for the driver gate's decimal checks"
else tc_skip "decimal gcc" "no gcc with decimal floating types: the driver gate's two decimal checks SKIP"; fi

if [ "$tc_bad" -gt 0 ]; then echo "RED: the toolchain, $tc_bad missing$( [ "$tc_diff" -gt 0 ] && echo ", $tc_diff off its pin")"; exit 1; fi
if [ "$tc_diff" -gt 0 ] && [ "$TOOLCHAIN_STRICT" = 1 ]; then echo "RED: the toolchain, $tc_diff off its pin (TOOLCHAIN_STRICT=1)"; exit 1; fi
echo "GREEN: the toolchain$( [ "$tc_diff" -gt 0 ] && echo ", $tc_diff off its pin (above)")"
