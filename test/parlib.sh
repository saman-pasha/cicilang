# test/parlib.sh -- a memory-gated parallel job pool, sourced by the gates.
# cocolog has no heap collector and a build peaks in the gigabytes, so N builds
# at once can exhaust the box (CLAUDE.md's findings). The pool runs up to NMAX
# jobs concurrently but launches a new one only while the summed resident size
# of every cocolog process is under LAUNCH_MB, and kills the whole pool if that
# sum ever passes HARD_MB (a RED, as the watchdog is) -- so light builds pack
# onto the cores and a heavy one holds the next launch back until it is done.
# POSIX: the running children are tracked by PID (dash has no `jobs -r').
#
#   ccl_cocolog_rss           -> summed RSS of every cocolog query, in MB
#   ccl_pool NMAX LAUNCH_MB HARD_MB < jobfile   (one shell command a line)

ccl_cocolog_rss() { ps -eo rss,args 2>/dev/null | awk '/[c]ocolog .*query/ { s += $1 } END { print int(s / 1024) }'; }

ccl_pool_alive() {   # keep only still-running PIDs in $_pids, set _running to the count
  _live=""; _running=0
  for _p in $_pids; do
    if kill -0 "$_p" 2>/dev/null; then _live="$_live $_p"; _running=$((_running + 1)); fi
  done
  _pids=$_live
}

ccl_pool() {
  _nmax=$1; _launch=$2; _hard=$3; _pids=""; _killed=0
  while IFS= read -r _job || [ -n "$_job" ]; do
    while :; do
      ccl_pool_alive
      _rss=$(ccl_cocolog_rss)
      if [ "$_rss" -gt "$_hard" ]; then
        echo "POOL: summed cocolog RSS ${_rss} MB over hard cap ${_hard} -- killing the pool" >&2
        pkill -9 -f "[c]ocolog .*query" 2>/dev/null; _killed=1; break
      fi
      if [ "$_running" -lt "$_nmax" ] && [ "$_rss" -lt "$_launch" ]; then break; fi
      sleep 1
    done
    [ "$_killed" -eq 1 ] && break
    eval "$_job" & _pids="$_pids $!"
  done
  for _p in $_pids; do wait "$_p" 2>/dev/null; done
  return $_killed
}

# LONGEST FIRST (LPT): a pool's wall clock is its last job's end, so the heaviest jobs go first
# and the light ones fill the lanes around them. Each job's seconds are recorded in a timings
# file (`KEY SECONDS' a line, appended by the job, the last line per key wins); the next run
# orders its keys by them, the unknown ones first (a new fixture may be the heaviest).
#   ccl_time_record FILE KEY SECS
#   ccl_lpt_order FILE < lines  -> the lines, heaviest first; a line is `KEY [anything]', keyed by its first word
ccl_time_record() { mkdir -p "$(dirname "$1")" 2>/dev/null; echo "$2 $3" >> "$1"; }
ccl_lpt_order() {
  _tf=$1
  awk -v tf="$_tf" 'BEGIN { while ((getline l < tf) > 0) { split(l, a, " "); t[a[1]] = a[2] } }
       { k = $1; if (k in t) print t[k], $0; else print 999999, $0 }' | sort -s -k1,1nr | sed 's/^[^ ]* //'
}
