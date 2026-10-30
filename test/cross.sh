#!/bin/sh
# The other machine's gate (0.131): Linux on aarch64, AAPCS64, run under qemu. Every test/c/run/NAME.c is built by
# `cicilang --target=aarch64-linux-gnu' and by `clang --target=aarch64-linux-gnu', the reference -- that machine's
# output is the reference, not this one's .expect: plain char and wchar_t are unsigned there, long double is an IEEE
# quad -- and both binaries run under qemu-aarch64 over the cross sysroot; a fixture written in the language's own
# forms, which clang does not read, is held to its .expect, and so is one whose NAME.ref says `expect' (0.225): its
# .expect is gcc's, where clang's build prints otherwise. Then the ABI both ways against aarch64-linux-gnu-gcc:
# structs by value (test/c/link/abi_*.c), variadic calls of every AAPCS64 kind (test/c/link/va_*.c) and vectors by value
# (test/c/link/vec_*.c, 0.162). Then C++ (0.161):
# fixtures built by `cicilang++ --target' and by clang++ over that machine's libc++, and the C++ gate's ABI checks, where
# its libc++ is under the sysroot (a SKIP line where not). A SKIP where the box has no qemu-aarch64, no
# aarch64-linux-gnu-gcc or no clang (Debian and Ubuntu: qemu-user, gcc-aarch64-linux-gnu, libc6-dev-arm64-cross).
# GREEN or RED.
#
#   sh test/cross.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cicilang.so" ] || { echo "SKIP (no library/cicilang.so -- sh module/build.sh)"; exit 0; }
[ -f "$ROOT/library/ccl_llvm.so" ] || { echo "SKIP (no library/ccl_llvm.so -- sh module/build-llvm.sh)"; exit 0; }
SYS=/usr/aarch64-linux-gnu
command -v qemu-aarch64 > /dev/null 2>&1 && command -v aarch64-linux-gnu-gcc > /dev/null 2>&1 && [ -d "$SYS/include" ] \
  || { echo "SKIP (no qemu-aarch64, aarch64-linux-gnu-gcc or $SYS -- apt install qemu-user gcc-aarch64-linux-gnu libc6-dev-arm64-cross)"; exit 0; }
CLANG=$(command -v clang || command -v "${LLVM:-/usr/lib/llvm-18}/bin/clang" || command -v clang-18)
[ -n "$CLANG" ] || { echo "SKIP (no clang for the references)"; exit 0; }
D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-cross-XXXXXX")
trap 'rm -rf "$D"' EXIT
QE="qemu-aarch64 -L $SYS"; T=--target=aarch64-linux-gnu; CC="$ROOT/bin/cicilang"; RUN="$ROOT/test/c/run"; LINK="$ROOT/test/c/link"
failures=0
echo "-- every run fixture, built for aarch64 Linux and run under qemu beside clang's build"
for src in "$RUN"/*.c; do
  n=$(basename "$src" .c); std=""; [ -f "$RUN/$n.std" ] && std=$(cat "$RUN/$n.std")
  ( cd "$RUN" && "$CC" $T $std "$src" -o "$D/$n" > "$D/$n.log" 2>&1 < /dev/null )
  if [ "$(cat "$RUN/$n.ref" 2>/dev/null)" != expect ] && ( cd "$RUN" && "$CLANG" $T -w $std "$src" -o "$D/$n.ref" -lm > /dev/null 2>&1 ); then   # NAME.ref's `expect': its .expect, gcc's, on every machine (0.225)
    ( cd "$RUN" && $QE "$D/$n.ref" arg1 arg2 > "$D/$n.want" 2>&1 < /dev/null; echo "exit $?" >> "$D/$n.want" ); how=clang
  else cp "$RUN/$n.expect" "$D/$n.want"; how=expect; fi
  if [ ! -x "$D/$n" ]; then printf 'FAIL %-14s %s\n' "$n" "$(grep -a 'error' "$D/$n.log" | head -1 | cut -c1-140)"; failures=$((failures + 1)); continue; fi
  ( cd "$RUN" && $QE "$D/$n" arg1 arg2 > "$D/$n.got" 2>&1 < /dev/null; echo "exit $?" >> "$D/$n.got" )
  if cmp -s "$D/$n.got" "$D/$n.want"; then printf 'ok   %-14s %-6s %s\n' "$n" "$how" "$(tail -1 "$D/$n.got")"
  else printf 'FAIL %-14s output differs from %s\n' "$n" "$how"; diff "$D/$n.want" "$D/$n.got" | head -6 | sed 's/^/     /'; failures=$((failures + 1)); fi
done
echo "-- the ABI against aarch64-linux-gnu-gcc, both ways"
check() {   # check NAME GOT WANT
  if [ "$2" = "$3" ]; then printf 'ok   %s\n' "$1"; else printf 'FAIL %s\n     got:  %s\n     want: %s\n' "$1" "$(echo "$2" | head -3)" "$(echo "$3" | head -3)"; failures=$((failures + 1)); fi
}
check "structs by value: cicilang's main over gcc's helper, which calls the main's functions back" "$(cd "$D" && aarch64-linux-gnu-gcc -c "$LINK/abi_helper.c" -o abi_helper.o && "$CC" $T "$LINK/abi_main.c" abi_helper.o -o abi > abi.log 2>&1 && $QE ./abi > abi.out && aarch64-linux-gnu-gcc "$LINK/abi_main.c" "$LINK/abi_helper.c" -o abi_ref && $QE ./abi_ref > abi_ref.out && cmp -s abi.out abi_ref.out && echo same && wc -l < abi.out | tr -d ' ')" "same
7"
check "variadic calls: cicilang's va_arg under gcc's calls" "$(cd "$D" && aarch64-linux-gnu-gcc -c "$LINK/va_main.c" -o va_main.o && "$CC" $T "$LINK/va_func.c" va_main.o -o va1 > va1.log 2>&1 && $QE ./va1 > va1.out && aarch64-linux-gnu-gcc "$LINK/va_main.c" "$LINK/va_func.c" -o va_ref && $QE ./va_ref > va_ref.out && cmp -s va1.out va_ref.out && echo same && wc -l < va1.out | tr -d ' ')" "same
12"
check "variadic calls: cicilang's calls into gcc's va_arg" "$(cd "$D" && aarch64-linux-gnu-gcc -c "$LINK/va_func.c" -o va_func.o && "$CC" $T "$LINK/va_main.c" va_func.o -o va2 > va2.log 2>&1 && $QE ./va2 > va2.out && cmp -s va2.out va_ref.out && echo same)" "same"
check "vectors by value: cicilang's main over gcc's helper, which calls the main's functions back" "$(cd "$D" && aarch64-linux-gnu-gcc -c "$LINK/vec_helper.c" -o vec_helper.o && "$CC" $T "$LINK/vec_main.c" vec_helper.o -o vec > vec.log 2>&1 && $QE ./vec > vec.out && aarch64-linux-gnu-gcc "$LINK/vec_main.c" "$LINK/vec_helper.c" -o vec_ref && $QE ./vec_ref > vec_ref.out && cmp -s vec.out vec_ref.out && echo same && wc -l < vec.out | tr -d ' ')" "same
4"
check "vectors by value: gcc's main over cicilang's helper" "$(cd "$D" && "$CC" $T -c "$LINK/vec_helper.c" -o vec_helper_ours.o > vech.log 2>&1 && aarch64-linux-gnu-gcc "$LINK/vec_main.c" vec_helper_ours.o -o vec_rev && $QE ./vec_rev > vec_rev.out && cmp -s vec_rev.out vec_ref.out && echo same)" "same"
# C++ FOR AARCH64 LINUX (0.161): that machine's libc++ under the cross sysroot -- the tree cicilang++ reads ($LLVM, else the
# newest /usr/lib/llvm-NN) at $SYS$TREE, where Debian's and Ubuntu's arm64 packages put it when extracted into $SYS --
# each fixture built by `cicilang++ --target=aarch64-linux-gnu' and by clang++ for that machine over the same libc++, both
# run under qemu and compared; then the C++ ABI checks of the C++ gate (test/cpp/link) on that machine. A SKIP line where
# the tree is not there: the C part above stands alone.
XR=${LLVM:-$(ls -d /usr/lib/llvm-* 2>/dev/null | sort -t- -k2 -n | tail -1)}; XS="$SYS$XR"; CXX="$ROOT/bin/cicilang++"
. "$HERE/parlib.sh"   # ccl_cocolog_rss: every cocolog query and run on the box, summed, as the pool sums them
XSECS=${CROSS_SECS:-1800}; XMB=${CROSS_MB:-2800}   # each C++ build's caps: a cold read of that machine's headers (its summaries are its own, keyed by the target)
ccl_xkill() { for _xc in $(pgrep -P "$1" 2>/dev/null); do ccl_xkill "$_xc"; done; kill -9 "$1" 2>/dev/null; }
ccl_xcapped() {   # ccl_xcapped CMD...: one build under the time cap XSECS and the memory cap XMB; past either its tree is killed, a line says which, and the status is 124
  "$@" & _xp=$!; _xt=0; _xr=0
  while kill -0 "$_xp" 2>/dev/null; do
    sleep 1; _xt=$((_xt + 1))
    if [ "$_xt" -ge "$XSECS" ]; then ccl_xkill "$_xp"; echo "error: TIMEOUT after ${XSECS} s"; _xr=124; break; fi
    if [ "$(ccl_cocolog_rss)" -gt "$XMB" ]; then ccl_xkill "$_xp"; echo "error: KILLED past ${XMB} MB"; _xr=124; break; fi
  done
  wait "$_xp" 2>/dev/null; _xw=$?; [ "$_xr" -ne 0 ] && return "$_xr"; return "$_xw"
}
CLANGXX=$(command -v "$XR/bin/clang++" || command -v clang++)
if [ -f "$XS/include/c++/v1/vector" ] && [ -f "$XS/lib/libc++.so.1" ] && [ -n "$CLANGXX" ] && command -v aarch64-linux-gnu-g++ > /dev/null 2>&1; then
  echo "-- C++ for aarch64 Linux over $XS, run under qemu beside clang++'s build"
  XREF="$CLANGXX $T -stdlib=libc++ -nostdinc++ -isystem $XS/include/c++/v1 -w -L$XS/lib -Wl,-rpath-link,$XS/lib -Wl,-rpath,$XR/lib"
  CR="$ROOT/test/cpp/run"
  for src in "$ROOT/test/cpp/hello.cpp" "$ROOT/test/cpp/classes.cpp" "$ROOT/test/cpp/templates.cpp" "$CR/counter.cpp" "$CR/shapes.cpp" \
             "$CR/lambdas.cpp" "$CR/bag.cpp" "$CR/stdvector.cpp" "$CR/stdstring.cpp" "$CR/stdmap.cpp" "$CR/stdunorderedmap.cpp" \
             "$CR/exceptions.cpp" "$CR/rtti.cpp" "$CR/virtualbase.cpp" "$CR/multibase3.cpp" "$CR/memfnptr.cpp" "$CR/memfnadj.cpp" \
             "$CR/ldouble.cpp" "$CR/charpromote.cpp" "$CR/int128.cpp" "$CR/cogenerator.cpp" "$CR/stdvariant.cpp" "$CR/memptrnull.cpp" \
             "$CR/vector.cpp" "$CR/gnuasm.cpp" "$CR/asmgoto.cpp" "$CR/vbtailpad.cpp" "$CR/vbempty.cpp" "$CR/vbtables.cpp" \
             "$CR/emptybaseorder.cpp" "$CR/vbasens.cpp" "$CR/lambdanames.cpp" "$CR/localnames.cpp" "$CR/closureident.cpp" \
             "$CR/abitagnames.cpp"; do
    n=$(basename "$src" .cpp); dir=$(dirname "$src"); fl=""; [ -f "$dir/$n.flags" ] && fl=$(cat "$dir/$n.flags")
    inp="$dir/$n.stdin"; [ -f "$inp" ] || inp=/dev/null
    ( cd "$dir" && ccl_xcapped "$CXX" $T $fl "$src" -o "$D/x$n" ) > "$D/x$n.log" 2>&1 < /dev/null
    if ( cd "$dir" && $XREF $fl "$src" -o "$D/x$n.ref" > "$D/x$n.rlog" 2>&1 ); then
      ( cd "$dir" && $QE "$D/x$n.ref" > "$D/x$n.want" 2>&1 < "$inp"; echo "exit $?" >> "$D/x$n.want" ); how=clang++
    elif [ -f "$dir/$n.expect" ]; then cp "$dir/$n.expect" "$D/x$n.want"; how=expect   # the language's own forms (`own'), which clang++ does not read: held to the fixture's .expect, as the C fixtures are
    else printf 'FAIL C++ %-14s clang++ built no reference: %s\n' "$n" "$(head -1 "$D/x$n.rlog" | cut -c1-120)"; failures=$((failures + 1)); continue; fi
    if [ ! -x "$D/x$n" ]; then printf 'FAIL C++ %-14s %s\n' "$n" "$(grep -a 'error' "$D/x$n.log" | head -1 | cut -c1-140)"; failures=$((failures + 1)); continue; fi
    ( cd "$dir" && $QE "$D/x$n" > "$D/x$n.got" 2>&1 < "$inp"; echo "exit $?" >> "$D/x$n.got" )
    if cmp -s "$D/x$n.got" "$D/x$n.want"; then printf 'ok   C++ %-14s %-7s %s\n' "$n" "$how" "$(tail -1 "$D/x$n.got")"
    else printf 'FAIL C++ %-14s output differs from %s\n' "$n" "$how"; diff "$D/x$n.want" "$D/x$n.got" | head -6 | sed 's/^/     /'; failures=$((failures + 1)); fi
  done
  check "C++ classes cross a call to clang++'s code on aarch64 as the Itanium ABI lays them" "$(cd "$D" && $XREF -std=c++17 -c "$ROOT/test/cpp/link/abi_helper.cpp" -o xabi_helper.o && ccl_xcapped "$CXX" $T "$ROOT/test/cpp/link/abi_main.cpp" xabi_helper.o -o xabi > xabi.log 2>&1 && $QE ./xabi > xabi.out && $XREF -std=c++17 "$ROOT/test/cpp/link/abi_main.cpp" "$ROOT/test/cpp/link/abi_helper.cpp" -o xabi_ref && $QE ./xabi_ref > xabi_ref.out && cmp -s xabi.out xabi_ref.out && echo same && cat xabi.out)" "same
1 2 3 60 | 245 | 8 8 | 16 16"
  check "C++ pointers to member functions cross a call to clang++'s code on aarch64 both ways (ARM's { ptr, adj })" "$(cd "$D" && $XREF -std=c++17 -c "$ROOT/test/cpp/link/memptr_helper.cpp" -o xmemptr_helper.o && ccl_xcapped "$CXX" $T "$ROOT/test/cpp/link/memptr_main.cpp" xmemptr_helper.o -o xmemptr > xmemptr.log 2>&1 && $QE ./xmemptr)" "11 21 53 42 63 | 11 21 53 42 63 | 1 0 0 1"
  check "C++ a by-value parameter of a class with a destructor crosses a call to clang++'s code on aarch64 both ways, destroyed once by the caller" "$(cd "$D" && $XREF -std=c++17 -c "$ROOT/test/cpp/link/byval_helper.cpp" -o xbyval_helper.o && ccl_xcapped "$CXX" $T "$ROOT/test/cpp/link/byval_main.cpp" xbyval_helper.o -o xbyval > xbyval.log 2>&1 && $QE ./xbyval)" "[1] ~T(1) [102] ~T(102) ~T(2) ~T(103) ~T(3) ~T(3) [212] live 0"
else
  echo "SKIP the C++ part: no libc++ of aarch64 at $XS (Debian and Ubuntu: dpkg-deb -x the arm64 libc++-NN-dev, libc++1-NN, libc++abi-NN-dev, libc++abi1-NN, libunwind-NN and libunwind-NN-dev into $SYS), no clang++ or no aarch64-linux-gnu-g++"
fi
if [ "$failures" -eq 0 ]; then echo "GREEN: cross"; else echo "RED: $failures failure(s)"; exit 1; fi
