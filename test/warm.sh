#!/bin/sh
# test/warm.sh -- folded into test/libcxx.sh (0.105). The C++ summary cache is now warmed by
# the library read phase itself, which reads every library header cold in parallel and leaves
# the summaries written, so there is no separate serial warm before the gates any more (the
# two used to read the same headers twice). This shim runs that phase, so an old invocation of
# `sh test/warm.sh' still warms the cache; the gates call test/gates.sh, which runs it once.
HERE=$(cd "$(dirname "$0")" && pwd)
exec sh "$HERE/libcxx.sh" "$@"
