#!/bin/sh
# Build library(cocolang): transpile module/cocolang.cicili with Cicili and
# compile the C against cocolog's module SDK into library/cocolang.so.
#
#   CICILI=~/Projects/GitHub/cicili COCOLOG=~/Projects/GitHub/cocolog sh module/build.sh
#
# The three neighbours are used as they are: Cicili transpiles, cocolog's
# lib/sdk.cicili is symlinked in (so the module names no path), and its
# tools/cc/env.sh picks the compiler the way cocolog's own modules do.
# Nothing this makes is committed.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
CICILI=${CICILI:-$HOME/Projects/GitHub/cicili}
COCOLOG=${COCOLOG:-$HOME/Projects/GitHub/cocolog}
[ -f "$CICILI/cicili.lisp" ] || { echo "cocolang: no Cicili at $CICILI (set CICILI)" >&2; exit 1; }
[ -f "$COCOLOG/lib/sdk.cicili" ] || { echo "cocolang: no cocolog SDK at $COCOLOG/lib/sdk.cicili (set COCOLOG)" >&2; exit 1; }
ROOT_SAVED=$ROOT
ROOT=$COCOLOG
. "$COCOLOG/tools/cc/env.sh"
ROOT=$ROOT_SAVED
OUT=${OUT:-$ROOT/library}

ln -sfn "$COCOLOG/lib/sdk.cicili" "$HERE/sdk.cicili"
mkdir -p "$OUT"
( cd "$CICILI" && sbcl --script cicili.lisp --release "$HERE/cocolang.cicili" )
"$CC" -shared -fPIC -O2 -Wno-unused-function \
    -o "$OUT/cocolang.so" "$HERE/cocolang.c"
echo "built $OUT/cocolang.so (Cicili at $CICILI, cocolog SDK at $COCOLOG)"
