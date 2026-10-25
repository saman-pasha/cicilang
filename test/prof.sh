#!/bin/sh
# test/prof.sh -- WHERE A BUILD'S STEPS AND ITS TIME GO (0.148, 0.152, 0.156): the build of a file profiled by
# cocolog's library(flow/debug) over windows along its run, each window recorded by a cocolog of its own,
# their profiles added up: each predicate's calls and the steps spent inside them, the steps by
# what took them, who made the calls, the goals asked more than once, (cocolog 1.13.3) each predicate's
# inclusive and self time, its window's probe run untraced under a clock read at every step, the window and step of
# its largest call (1.15.0), and (1.15.0) the WHOLE run's self time by predicate, the build run once more untraced
# under a clock read at every step (test/prof.pl).
#
#   sh test/prof.sh [cicilang's arguments] FILE     a C file through bin/cicilang, a C++ one through bin/cicilang++
#   PROF_WINDOWS=N   the windows spread along the run (6), the last ending where it ends
#   PROF_WINDOW=W    the steps each records (20000)
#   PROF_JOBS=J      the windows recorded at once (2): each is a whole build to its window's end, twice
#   PROF_TOP=K       the rows of each view printed (20); PROF_KEEP=DIR keeps DIR/prof.prof, every row
#   PROF_SECS=S PROF_MB=M   the caps: S seconds (2400) and M MB summed over the run's process group (2800)
#
# The goal is the command's own (bin/cicilang writes it under CICILANG_GOAL), compiled with -c and no store. A
# count of steps is no count of time: a copy of a global (nb_getval/2) is one step however big it is
# (RULES.md, Time and memory); the TIME view says what it costs. An older library(flow/debug), with no time(T),
# gives the four other views, and one with no flow_run_time/3 (before 1.15.0) no RUN view.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
grep -q 'flow_debug_windows' "$COCOLOG/library/flow/debug.pl" 2>/dev/null || { echo "SKIP (cocolog's library(flow/debug) has no flow_debug_windows/4: 1.11.10 or later)"; exit 0; }
[ $# -ge 1 ] || { echo "usage: sh test/prof.sh [cicilang's arguments] FILE" >&2; exit 2; }
PROF_WINDOWS=${PROF_WINDOWS:-6}; PROF_WINDOW=${PROF_WINDOW:-20000}; PROF_JOBS=${PROF_JOBS:-2}; PROF_TOP=${PROF_TOP:-20}
PROF_SECS=${PROF_SECS:-2400}; PROF_MB=${PROF_MB:-2800}
PT=no; grep -q 'flow_time_text' "$COCOLOG/library/flow/dbgprof.pl" 2>/dev/null && PT=yes
PR=no; grep -q '^flow_run_time(' "$COCOLOG/library/flow/debug.pl" 2>/dev/null && PR=yes
if [ -n "$PROF_KEEP" ]; then D=$PROF_KEEP; mkdir -p "$D"; else D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-prof-XXXXXX"); trap 'rm -rf "$D"' EXIT; fi
# the arguments, each file among them made absolute (the runs start in D); a C++ file goes through cicilang++
cmd="$ROOT/bin/cicilang"; n=$#
while [ "$n" -gt 0 ]; do
  a=$1; shift; n=$((n - 1))
  case "$a" in -*) ;; *) [ -f "$a" ] && a="$(cd "$(dirname "$a")" && pwd)/$(basename "$a")" ;; esac
  case "$a" in *.cpp|*.cc|*.cxx|*.C|*.cppm|*.ccm|*.cxxm|*.ixx|*.mpp) cmd="$ROOT/bin/cicilang++" ;; esac
  set -- "$@" "$a"
done
rm -f "$D/goal"; CICILANG_GOAL="$D/goal" "$cmd" "$@" -c -o "$D/prof.o"
[ -s "$D/goal" ] || { echo "RED: $cmd made no goal of these arguments"; exit 1; }
# THE BUILD ONCE AS IT IS, first: what it says, and the C++ summaries it reads written before the windows' runs,
# which would otherwise each flatten the headers again and differ from one another
echo "-- the build: $(basename "$cmd") $*"
s0=$(date +%s)
timeout -s KILL "$PROF_SECS" "$cmd" "$@" -c -o "$D/plain.o" < /dev/null > "$D/plain.out" 2>&1
sed 's/^/   /' "$D/plain.out"; echo "-- it took $(( $(date +%s) - s0 )) s"
{ echo ":- use_module(library(cicilang))."; printf "cp_goal :- %s.\n" "$(cat "$D/goal")"; } > "$D/top.pl"
# one run of the profiler, its whole process TREE under the two caps (a cap kills the tree: CLAUDE.md, Caps): the
# windows' cocologs, and each window's probe and replay, run in process groups or sessions of their own, and
# are found by their parents
cp_tree() { echo "$1"; for c in $(pgrep -P "$1" 2>/dev/null); do cp_tree "$c"; done; }
cp_kill_tree() { for c in $(pgrep -P "$1" 2>/dev/null); do cp_kill_tree "$c"; done; kill -9 "$1" 2>/dev/null; }
cd "$D" || exit 2
"$C" --local query "use_module(library(flow/debug)), ensure_loaded('$ROOT/test/prof.pl'), cp_main('$D/top.pl', '$D/prof', $PROF_WINDOWS, $PROF_WINDOW, $PROF_JOBS, $PROF_TOP, $PT, $PR, $PROF_SECS)" < /dev/null > "$D/prof.out" 2>&1 &
P=$!; peak=0; t0=$(date +%s); capped=""
while kill -0 "$P" 2>/dev/null; do
  sleep 1
  rss=$(ps -o rss= -p "$(cp_tree "$P" | paste -sd, -)" 2>/dev/null | awk '{ s += $1 } END { print int(s / 1024) }')
  [ "$rss" -gt "$peak" ] && peak=$rss
  if [ "$rss" -gt "$PROF_MB" ]; then cp_kill_tree "$P"; capped="RED: the run passed $PROF_MB MB (PROF_MB)"; break; fi
  if [ $(( $(date +%s) - t0 )) -ge "$PROF_SECS" ]; then cp_kill_tree "$P"; capped="RED: the run passed $PROF_SECS s (PROF_SECS)"; break; fi
done
wait "$P"; rc=$?
grep -av '^  1\.\|answer(s)\.$' "$D/prof.out"
[ -n "$capped" ] && echo "$capped"
grep -aq '^-- the windows:' "$D/prof.out" || { echo "RED: the profiler did not finish (exit $rc; peak $peak MB)"; exit 1; }
[ "$PT" = yes ] || echo "-- no time view: cocolog's library(flow/debug) has no time(T) (1.13.3 or later)"
[ "$PR" = yes ] || echo "-- no run view: cocolog's library(flow/debug) has no flow_run_time/3 (1.15.0 or later)"
echo "-- peak $peak MB"
