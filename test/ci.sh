#!/bin/sh
# test/ci.sh -- THE CI JOB'S STEPS (0.223), in the repository so that any Ubuntu 24.04 box runs what the job runs
# (.github/workflows/gates.yml): the neighbours cloned at test/toolchain.pins' commits, side by side, and built by
# cocolog's own installer (install/install-linux.sh: Quicklisp and the Lisp systems Cicili is built from, ZiguratIP,
# cocolog, make schema, make modules); this checkout's two modules built over them; the toolchain checked STRICTLY;
# then the job's gates. A checkout already there at another commit is left alone and the job stops: the script never
# moves a checkout it did not make.
#
#   sh test/ci.sh smoke     # the flow, reader, compile, driver and objects gates and the proof, over libc++ 18
#   sh test/ci.sh full      # all nine over libc++ 18, then the library read and the C++ gate over libc++ 21
#   sh test/ci.sh JOB setup # the setup alone (the packages, the neighbours, the modules, the check), then
#   sh test/ci.sh JOB gates # the job's gates alone: the workflow keeps Quicklisp in its cache between the two
#   CI_PACKAGES=1 ...       # the system packages first, through sudo where the user is not root (the job's machine)
#   CI_ROOT=DIR ...         # where the neighbours are, or are cloned (default $HOME/Projects/GitHub, the gates' own)
#   CI_LOGS=DIR ...         # the logs, the run's artifact (default ${TMPDIR:-/tmp}/cicilang-ci)
#
# A GREEN JOB HAS NO SKIP IT DID NOT EXPECT (cocolog's CI, 2026-10-29): a gate that finds no cocolog or no module
# prints SKIP and exits 0, and a gate's part that finds no tool prints a SKIP line, so a broken setup would read
# GREEN. Each gate's output is read: a line that starts with SKIP is RED, but the reader gate's optional files (`SKIP
# FILE (not here)') and, on these machines, the cross gate's C++ part (no arm64 libc++ under the sysroot).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
JOB=${1:-smoke}; PHASE=${2:-all}
case "$JOB" in smoke|full) ;; *) echo "test/ci.sh: the job is smoke or full, not '$JOB'" >&2; exit 2 ;; esac
case "$PHASE" in all|setup|gates) ;; *) echo "test/ci.sh: the phase is setup, gates or all, not '$PHASE'" >&2; exit 2 ;; esac
. "$HERE/toolchain.pins"
CI_ROOT=${CI_ROOT:-$HOME/Projects/GitHub}; mkdir -p "$CI_ROOT"; CI_ROOT=$(cd "$CI_ROOT" && pwd)   # absolute: ASDF takes no other
CI_LOGS=${CI_LOGS:-${TMPDIR:-/tmp}/cicilang-ci}; mkdir -p "$CI_LOGS"; CI_LOGS=$(cd "$CI_LOGS" && pwd)
CICILI=$CI_ROOT/cicili; COCOLOG=$CI_ROOT/cocolog; ZIGURATIP=$CI_ROOT/ZiguratIP; ZIGURATIP_HOME=$ZIGURATIP/home
CL_SOURCE_REGISTRY="$CICILI/:"   # cicili.lisp loads its system through ASDF: this copy, never another the box links
export CICILI COCOLOG ZIGURATIP ZIGURATIP_HOME CL_SOURCE_REGISTRY
ci_step() { printf '\n== ci: %s (%s)\n' "$1" "$(date -u +%H:%M:%S)"; }
ci_die() { echo "RED: ci: $*"; ci_summary "RED: $*"; exit 1; }
ci_summary() { [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"; return 0; }

if [ "$PHASE" != gates ]; then
if [ "${CI_PACKAGES:-0}" = 1 ]; then
  ci_step "the system packages"
  SUDO=""; [ "$(id -u)" = 0 ] || SUDO=sudo
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get -qq update || ci_die "apt-get update"
  $SUDO apt-get -qq install -y curl gnupg ca-certificates > /dev/null || ci_die "apt-get install curl gnupg"
  # the gates call clang, clang++ and llvm-dwarfdump by their plain names (the clang and llvm packages), and the
  # driver gate builds a C++ file too (its IR cache check), so the smoke job reads the libc++ of LLVM_MAJOR
  ci_pk="build-essential git sbcl clang clang-$LLVM_MAJOR llvm llvm-$LLVM_MAJOR-dev libc++-$LLVM_MAJOR-dev libc++abi-$LLVM_MAJOR-dev libunwind-$LLVM_MAJOR-dev"
  if [ "$JOB" = full ]; then
    ci_pk="$ci_pk qemu-user gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-arm64-cross"
    for n in $LIBCXX_TREES; do
      # a tree the distribution does not ship comes from apt.llvm.org, the LLVM project's own packages
      if [ "$n" != "$LLVM_MAJOR" ] && ! apt-cache show "libc++-$n-dev" >/dev/null 2>&1; then
        curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | $SUDO gpg --dearmor -o /usr/share/keyrings/llvm-apt.gpg
        echo "deb [signed-by=/usr/share/keyrings/llvm-apt.gpg] https://apt.llvm.org/noble/ llvm-toolchain-noble-$n main" | $SUDO tee "/etc/apt/sources.list.d/llvm$n.list" > /dev/null
      fi
      [ "$n" = "$LLVM_MAJOR" ] || ci_pk="$ci_pk libc++-$n-dev libc++abi-$n-dev libunwind-$n-dev clang-$n"
    done
  fi
  $SUDO apt-get -qq update || ci_die "apt-get update"
  # shellcheck disable=SC2086
  $SUDO apt-get -qq install -y $ci_pk > /dev/null || ci_die "apt-get install $ci_pk"
  echo "installed: $ci_pk"
fi

ci_step "the neighbours at their pins, in $CI_ROOT"
ci_summary "| checkout | pin | commit |"
ci_summary "|---|---|---|"
for spec in "cicili $CICILI_COMMIT" "ZiguratIP $ZIGURATIP_COMMIT" "cocolog $COCOLOG_COMMIT"; do
  # shellcheck disable=SC2086
  set -- $spec; ci_r=$1; ci_c=$2; ci_d=$CI_ROOT/$ci_r
  if [ ! -d "$ci_d/.git" ]; then
    git clone -q "https://github.com/saman-pasha/$ci_r.git" "$ci_d" || ci_die "git clone $ci_r"
    git -C "$ci_d" checkout -q --detach "$ci_c" || ci_die "$ci_r has no commit $ci_c"
  fi
  ci_have=$(git -C "$ci_d" rev-parse --short=7 HEAD)
  [ "$(printf '%s' "$ci_have" | cut -c1-7)" = "$(printf '%s' "$ci_c" | cut -c1-7)" ] || ci_die "$ci_d is at $ci_have, its pin $ci_c: this script moves no checkout it did not make (set CI_ROOT to an empty directory)"
  echo "$ci_r at $ci_have"; ci_summary "| $ci_r | \`$ci_c\` | \`$(git -C "$ci_d" rev-parse HEAD)\` |"
done

ci_step "Cicili, ZiguratIP and cocolog built by cocolog's install/install-linux.sh"
CICILI_CC=${CICILI_CC:-clang-$LLVM_MAJOR}; CICILI_CXX=${CICILI_CXX:-clang++-$LLVM_MAJOR}; export CICILI_CC CICILI_CXX
ci_nopk=1; [ "${CI_PACKAGES:-0}" = 1 ] && ci_nopk=0   # the installer's own packages where this job installs packages
{ NO_PACKAGES=$ci_nopk LOG="$CI_LOGS/install" sh "$COCOLOG/install/install-linux.sh" < /dev/null 2>&1; echo "exit $?" > "$CI_LOGS/install.rc"; } | tee "$CI_LOGS/install.out"
[ "$(cat "$CI_LOGS/install.rc")" = "exit 0" ] || ci_die "cocolog's installer ($(cat "$CI_LOGS/install.rc"); its logs are $CI_LOGS/install.*)"
# THE INSTALLER'S OWN EXPORTS, the lines it prints for a shell profile (ZiguratIP's library path among them), for every
# step after it -- the gates phase reads them back -- rather than a second copy of them here (cocolog's CI does so)
grep -E '^   export [A-Za-z_][A-Za-z0-9_]*=' "$CI_LOGS/install.out" | sed 's/^   //' > "$CI_LOGS/exports.sh"
echo "the installer's exports: $(sed 's/^export //; s/=.*//' "$CI_LOGS/exports.sh" | tr '\n' ' ')"
. "$CI_LOGS/exports.sh"

ci_step "this checkout's two modules"
( cd "$ROOT" && sh module/build.sh ) > "$CI_LOGS/build.log" 2>&1 || { tail -20 "$CI_LOGS/build.log"; ci_die "module/build.sh"; }
( cd "$ROOT" && LLVM=/usr/lib/llvm-$LLVM_MAJOR sh module/build-llvm.sh ) > "$CI_LOGS/build-llvm.log" 2>&1 || { tail -20 "$CI_LOGS/build-llvm.log"; ci_die "module/build-llvm.sh"; }
tail -n 1 "$CI_LOGS/build.log"; tail -n 1 "$CI_LOGS/build-llvm.log"

ci_step "the toolchain, strictly"
if [ "$JOB" = smoke ]; then ci_tc="env LLVM=/usr/lib/llvm-$LLVM_MAJOR TOOLCHAIN_TREES=$LLVM_MAJOR"; else ci_tc="env"; fi
$ci_tc TOOLCHAIN_STRICT=1 sh "$HERE/toolchain.sh" < /dev/null 2>&1 | tee "$CI_LOGS/toolchain.log"
grep -q '^GREEN: the toolchain' "$CI_LOGS/toolchain.log" || ci_die "the toolchain (above)"
fi
[ "$PHASE" = setup ] && { echo "GREEN: ci $JOB setup"; exit 0; }

[ -f "$CI_LOGS/exports.sh" ] && . "$CI_LOGS/exports.sh"
ci_fail=0
ci_summary ""; ci_summary "| gate | verdict | seconds |"; ci_summary "|---|---|---|"
ci_run() {   # ci_run NAME CMD...: as test/gates.sh runs a gate, its GREEN or RED line and its time; its SKIPs read
  ci_n=$1; shift; ci_s=$(date +%s); ci_l="$CI_LOGS/gate-$(echo "$ci_n" | tr ' ' '-').log"
  { "$@" < /dev/null 2>&1; echo "exit $?" > "$ci_l.rc"; } | tee "$ci_l"
  ci_rc=$(sed 's/^exit //' "$ci_l.rc"); ci_e=$(( $(date +%s) - ci_s ))
  ci_skip=$(grep -a '^SKIP' "$ci_l" | grep -av '^SKIP [^ ]* (not here)$' | grep -av '^SKIP the C++ part: no libc++ of aarch64' || true)
  if [ "$ci_rc" -eq 0 ] && [ -z "$ci_skip" ]; then echo "== $ci_n: GREEN in ${ci_e} s"; ci_summary "| $ci_n | GREEN | $ci_e |"
  elif [ "$ci_rc" -eq 0 ]; then
    echo "== $ci_n: RED in ${ci_e} s, a SKIP this job does not expect:"; printf '%s\n' "$ci_skip" | sed 's/^/     /'
    ci_summary "| $ci_n | RED: $(printf '%s' "$ci_skip" | head -1 | cut -c1-100) | $ci_e |"; ci_fail=1
  else echo "== $ci_n: RED (exit $ci_rc) in ${ci_e} s"; ci_summary "| $ci_n | RED (exit $ci_rc) | $ci_e |"; ci_fail=1; fi
}
if [ "$JOB" = smoke ]; then
  ci_step "the six small gates"
  for g in flow reader compile driver objects; do ci_run "$g" env LLVM="/usr/lib/llvm-$LLVM_MAJOR" sh "$HERE/$g.sh"; [ "$ci_fail" = 0 ] || break; done
  [ "$ci_fail" = 0 ] && ci_run proof sh "$ROOT/proof/run.sh"
else
  ci_step "all nine gates over libc++ $LLVM_MAJOR"
  ci_run gates env LLVM="/usr/lib/llvm-$LLVM_MAJOR" sh "$HERE/gates.sh"
  for n in $LIBCXX_TREES; do
    [ "$n" = "$LLVM_MAJOR" ] && continue
    [ "$ci_fail" = 0 ] || break
    ci_step "the library read and the C++ gate over libc++ $n"
    ci_run "libcxx $n" env LLVM="/usr/lib/llvm-$n" sh "$HERE/libcxx.sh"
    [ "$ci_fail" = 0 ] && ci_run "cpp $n" env LLVM="/usr/lib/llvm-$n" sh "$HERE/cpp.sh"
  done
fi
if [ "$ci_fail" = 0 ]; then echo "GREEN: ci $JOB"; else echo "RED: ci $JOB"; fi
exit "$ci_fail"
