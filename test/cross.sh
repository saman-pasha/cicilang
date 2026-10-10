#!/bin/sh
# The other machine's gate (0.131): Linux on aarch64, AAPCS64, run under qemu. Every test/c/run/NAME.c is built by
# `cicilang --target=aarch64-linux-gnu' and by `clang --target=aarch64-linux-gnu', the reference -- that machine's
# output is the reference, not this one's .expect: plain char and wchar_t are unsigned there, long double is an IEEE
# quad -- and both binaries run under qemu-aarch64 over the cross sysroot; a fixture written in the language's own
# forms, which clang does not read, is held to its .expect. Then the ABI both ways against aarch64-linux-gnu-gcc:
# structs by value (test/c/link/abi_*.c) and variadic calls of every AAPCS64 kind (test/c/link/va_*.c). A SKIP where
# the box has no qemu-aarch64, no aarch64-linux-gnu-gcc or no clang (Debian and Ubuntu: qemu-user,
# gcc-aarch64-linux-gnu, libc6-dev-arm64-cross). GREEN or RED.
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
  if ( cd "$RUN" && "$CLANG" $T -w $std "$src" -o "$D/$n.ref" -lm > /dev/null 2>&1 ); then
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
if [ "$failures" -eq 0 ]; then echo "GREEN: cross"; else echo "RED: $failures failure(s)"; exit 1; fi
