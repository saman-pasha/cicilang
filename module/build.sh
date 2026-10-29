#!/bin/sh
# Build library(cicilang): transpile module/cicilang.cicili with Cicili and
# compile the C against cocolog's module SDK into library/cicilang.so.
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
[ -f "$CICILI/cicili.lisp" ] || { echo "cicilang: no Cicili at $CICILI (set CICILI)" >&2; exit 1; }
[ -f "$COCOLOG/lib/sdk.cicili" ] || { echo "cicilang: no cocolog SDK at $COCOLOG/lib/sdk.cicili (set COCOLOG)" >&2; exit 1; }
ROOT_SAVED=$ROOT
ROOT=$COCOLOG
. "$COCOLOG/tools/cc/env.sh"
ROOT=$ROOT_SAVED
OUT=${OUT:-$ROOT/library}

ln -sfn "$COCOLOG/lib/sdk.cicili" "$HERE/sdk.cicili"
# the Unicode name table for `\N{NAME}', spelled ONCE from library/ccl_uninames.pl (0.103): the names sorted for the
# native lexer's binary search (strcmp's order, LC_ALL=C), the hex-suffixed families' runs after them
TAB=$(printf '\t')
{
  echo "static const struct ccl_uname_row { const char *n; unsigned c; } ccl_unames[] = {"
  awk -F"'" '/^ccl_uname\(/ { v = $3; sub(/^, /, "", v); sub(/\).*$/, "", v); print $2 "\t" v }' "$ROOT/library/ccl_uninames.pl" \
    | LC_ALL=C sort -t "$TAB" -k1,1 | awk -F"\t" '{ printf "{\"%s\", %s},\n", $1, $2 }'
  echo "};"
  echo "static const struct ccl_uname_fam { const char *p; unsigned lo, hi; } ccl_uname_fams[] = {"
  awk -F"'" '/^ccl_uname_range\(/ { v = $3; sub(/^, /, "", v); sub(/\).*$/, "", v); printf "{\"%s\", %s},\n", $2, v }' "$ROOT/library/ccl_uninames.pl"
  echo "};"
} > "$HERE/ccl_uninames.h"
# the identifier's characters past ASCII and the white space past ASCII, spelled ONCE from library/ccl_xid.pl (0.221): a table of
# ranges a set, ascending, for the native lexer's binary search
{
  for s in xs xc c11 c11n c99 c99n ws; do
    echo "static const unsigned ccl_xid_$s[][2] = {"
    awk -v s="$s" -F'[(), ]+' '$1 == "ccl_xid" && $2 == s { printf "{%s, %s},\n", $3, $4 }' "$ROOT/library/ccl_xid.pl"
    echo "};"
  done
} > "$HERE/ccl_xid.h"
mkdir -p "$OUT"
# cicili.lisp loads its system through ASDF: THIS checkout's, named first, never another copy the box links (0.223;
# a ~/common-lisp/cicili of another commit answered first in cocolog's builds, its CLAUDE.md, 2026-10-28)
( cd "$CICILI" && CL_SOURCE_REGISTRY="$(pwd)/:${CL_SOURCE_REGISTRY:-}" sbcl --script cicili.lisp --release "$HERE/cicilang.cicili" )
"$CC" -shared -fPIC -O2 -Wno-unused-function \
    -o "$OUT/cicilang.so" "$HERE/cicilang.c"
echo "built $OUT/cicilang.so (Cicili at $CICILI, cocolog SDK at $COCOLOG)"
