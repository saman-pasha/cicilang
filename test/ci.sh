#!/bin/sh
# test/ci.sh -- THE CI JOB'S STEPS (0.223), in the repository so that any Ubuntu 24.04 box, or Mac -- Intel on macOS 26
# (0.224), Apple silicon on macOS 15 (0.246) -- runs what the job runs (.github/workflows/gates.yml): the neighbours
# cloned at test/toolchain.pins' commits, side by side, and built by cocolog's own installer (install/install-linux.sh
# or install/install-macos.sh: Quicklisp and the Lisp systems Cicili is built from, ZiguratIP, cocolog, make schema,
# make modules); this checkout's two modules built over them; the toolchain checked STRICTLY; then the job's gates. A
# checkout already there at another commit is left alone and the job stops: the script never moves a checkout it did
# not make.
#
#   sh test/ci.sh smoke     # the flow, reader, compile, driver and objects gates and the proof, over LLVM_MAJOR's libc++
#   sh test/ci.sh full      # all ten over LLVM_MAJOR's libc++, then the library read and the C++ gate over each other tree (Linux)
#   sh test/ci.sh cpp       # the library read and the C++ gate over LLVM_MAJOR's libc++, under caps that fit a Mac (0.246)
#   sh test/ci.sh JOB setup # the setup alone (the packages, the neighbours, the modules, the check), then
#   sh test/ci.sh JOB gates # the job's gates alone: the workflow keeps Quicklisp in its cache between the two
#   CI_PACKAGES=1 ...       # the system packages first: apt-get, through sudo where the user is not root, or Homebrew
#   CI_ROOT=DIR ...         # where the neighbours are, or are cloned (default $HOME/Projects/GitHub, the gates' own)
#   CI_LOGS=DIR ...         # the logs, the run's artifact (default ${TMPDIR:-/tmp}/cicilang-ci)
#
# A GREEN JOB HAS NO SKIP IT DID NOT EXPECT (cocolog's CI, 2026-10-29): a gate that finds no cocolog or no module
# prints SKIP and exits 0, and a gate's part that finds no tool prints a SKIP line, so a broken setup would read
# GREEN. Each gate's output is read: a line that starts with SKIP is RED, but the reader gate's optional files (`SKIP
# FILE (not here)'). The full job puts that machine's libc++ under the cross sysroot for the cross gate's C++ part
# (0.246: Ubuntu's arm64 packages, from ports.ubuntu.com). The smoke job runs its six gates whatever one of them says
# (0.224): the whole picture in one run, the verdict at the end.
#
# ON A MAC (0.224): Homebrew's llvm@N is the embedded LLVM, a keg (brew links no versioned formula), or its llvm where N
# is its newest major (23, 1.6.21), and only from a bottle -- Homebrew has built no Intel bottles since September 2026,
# and LLVM from source is hours, so the setup stops where the formula data names none (llvm 23.1.6 has none); the workflow's HOMEBREW_NO_AUTO_UPDATE keeps the data the runner image was
# built with, which names one (cocolog's CI found sbcl so). macOS has no `timeout', which the flow gate and the pools
# cap their runs with: coreutils' gtimeout, under that one name, in a directory of the job's own at the front of PATH,
# so that BSD's date, sed and wc stay what a Mac has (cocolog's CI). The full job is Linux's: the cross gate runs under
# qemu-user over Debian's aarch64 sysroot.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
JOB=${1:-smoke}; PHASE=${2:-all}
case "$JOB" in smoke|full|cpp) ;; *) echo "test/ci.sh: the job is smoke, full or cpp, not '$JOB'" >&2; exit 2 ;; esac
case "$PHASE" in all|setup|gates) ;; *) echo "test/ci.sh: the phase is setup, gates or all, not '$PHASE'" >&2; exit 2 ;; esac
case "$(uname -s)" in Linux) CI_OS=linux ;; Darwin) CI_OS=macos ;; *) echo "test/ci.sh: no CI job for $(uname -s)" >&2; exit 2 ;; esac
[ "$CI_OS" = macos ] && [ "$JOB" = full ] && { echo "test/ci.sh: the full job runs on Linux, where the cross gate's qemu-user and aarch64 sysroot are" >&2; exit 2; }
. "$HERE/toolchain.pins"
CI_ROOT=${CI_ROOT:-$HOME/Projects/GitHub}; mkdir -p "$CI_ROOT"; CI_ROOT=$(cd "$CI_ROOT" && pwd)   # absolute: ASDF takes no other
CI_LOGS=${CI_LOGS:-${TMPDIR:-/tmp}/cicilang-ci}; mkdir -p "$CI_LOGS"; CI_LOGS=$(cd "$CI_LOGS" && pwd)
CICILI=$CI_ROOT/cicili; COCOLOG=$CI_ROOT/cocolog; ZIGURATIP=$CI_ROOT/ZiguratIP; ZIGURATIP_HOME=$ZIGURATIP/home
CL_SOURCE_REGISTRY="$CICILI/:"   # cicili.lisp loads its system through ASDF: this copy, never another the box links
export CICILI COCOLOG ZIGURATIP ZIGURATIP_HOME CL_SOURCE_REGISTRY
ci_step() { printf '\n== ci: %s (%s)\n' "$1" "$(date -u +%H:%M:%S)"; }
ci_die() { echo "RED: ci: $*"; ci_summary "RED: $*"; exit 1; }
ci_summary() { [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"; return 0; }
# LLVM N's tree: Debian's and Ubuntu's /usr/lib/llvm-N, Homebrew's keg llvm@N -- or Homebrew's llvm where N is its newest
# major, which Homebrew names with no version (LLVM 23, 1.6.21: llvm is 23.1.6, and no llvm@23 is there)
ci_llvm() {
  if [ "$CI_OS" = linux ]; then echo "/usr/lib/llvm-$1"; return 0; fi
  ci_bp=$(brew --prefix 2>/dev/null || echo /usr/local)
  if [ ! -d "$ci_bp/opt/llvm@$1" ] && [ -x "$ci_bp/opt/llvm/bin/llvm-config" ] && [ "$("$ci_bp/opt/llvm/bin/llvm-config" --version | cut -d. -f1)" = "$1" ]; then echo "$ci_bp/opt/llvm"
  else echo "$ci_bp/opt/llvm@$1"; fi
}
# THE PLAIN NAMES ON LINUX ARE LLVM_MAJOR'S (1.6.21): the gates call clang, clang++ and llvm-dwarfdump by their plain
# names, and a distribution's are its own LLVM's (Ubuntu 24.04's are 18's), so they are linked to LLVM_MAJOR's tree in a
# directory of the job's own at the front of PATH, as a Mac's timeout is; a Mac's clang stays Apple's. Asked again after
# the packages, which bring the tree to a fresh box
ci_llvm_names() {
  [ "$CI_OS" = linux ] && [ -x "/usr/lib/llvm-$LLVM_MAJOR/bin/clang" ] || return 0
  mkdir -p "$CI_ROOT/.ci-bin" || ci_die "mkdir $CI_ROOT/.ci-bin"
  for ci_t in clang clang++ llvm-dwarfdump; do ln -sf "/usr/lib/llvm-$LLVM_MAJOR/bin/$ci_t" "$CI_ROOT/.ci-bin/$ci_t" || ci_die "ln $ci_t"; done
  case ":$PATH:" in *":$CI_ROOT/.ci-bin:"*) ;; *) PATH="$CI_ROOT/.ci-bin:$PATH"; export PATH ;; esac
}
ci_timeout() {   # a Mac's timeout: gtimeout under that name, first on PATH, where no timeout is there already
  [ "$CI_OS" = macos ] || return 0
  command -v timeout >/dev/null 2>&1 && return 0
  ci_gt=$(command -v gtimeout 2>/dev/null || echo "$(brew --prefix 2>/dev/null)/bin/gtimeout")
  [ -x "$ci_gt" ] || return 0   # the toolchain check names it MISSING
  mkdir -p "$CI_ROOT/.ci-bin" && ln -sf "$ci_gt" "$CI_ROOT/.ci-bin/timeout" && PATH="$CI_ROOT/.ci-bin:$PATH" && export PATH
}
ci_timeout
ci_llvm_names
# ONE LIBC++ TREE BESIDE THE OTHERS (0.227): every libc++-N-dev package, Ubuntu's and apt.llvm.org's, provides and conflicts
# with libc++-x.y-dev, and apt.llvm.org's runtimes are one package, libc++1, so apt holds one tree at a time -- the full job's
# one install of 18's and 21's could not be made, and 22's install here removed 21's. Every tree but LLVM_MAJOR's is unpacked:
# its packages, development and runtime, fetched at its own apt source's version; its headers under /usr/lib/llvm-N/include
# and its runtime libraries, as files, under /usr/lib/llvm-N/lib, which the link names with its rpath (ccl_link_libs). THE
# TWO SOURCES NAME AND LAY THEM OUT APART (1.6.21, where LLVM_MAJOR became 23 and Ubuntu's 18 a tree beside it): apt.llvm.org's
# runtimes are libc++1, libc++abi1 and llvm-libunwind1, each a file under the machine's lib directory that llvm-N/lib links
# to; Ubuntu's are libc++1-N, libc++abi1-N and libunwind-N, each a file under llvm-N/lib that the machine's directory links
# to. Each name of both places is copied as the file it names, llvm-N/lib's first, so that libc++.so is the machine
# directory's linker script, INPUT(libc++.so.1 -lc++abi ...), never the ELF file that llvm-N/lib's libc++.so links to
ci_unpack_libcxx() {
  ci_v=$(apt-cache madison "libc++-$1-dev" 2>/dev/null | awk 'NR == 1 { print $3 }')
  [ -n "$ci_v" ] || ci_die "no libc++-$1-dev in the apt sources"
  # by madison's exact version: `apt-cache show NAME=VERSION' exits 0 where NAME has no such version (1.6.21)
  if apt-cache madison "libc++1-$1" 2>/dev/null | awk -v v="$ci_v" '$3 == v { f = 1 } END { exit !f }'; then ci_rt="libc++1-$1=$ci_v libc++abi1-$1=$ci_v libunwind-$1=$ci_v"
  else ci_rt="libc++1=$ci_v libc++abi1=$ci_v llvm-libunwind1=$ci_v"; fi
  ci_d=$(mktemp -d) || ci_die "mktemp"
  # shellcheck disable=SC2086
  ( cd "$ci_d" && apt-get -qq download "libc++-$1-dev=$ci_v" "libc++abi-$1-dev=$ci_v" "libunwind-$1-dev=$ci_v" $ci_rt ) > /dev/null 2>&1 \
    || ci_die "apt-get download of libc++ $1 ($ci_v)"
  for ci_f in "$ci_d"/*.deb; do dpkg-deb -x "$ci_f" "$ci_d/root" || ci_die "dpkg-deb -x $ci_f"; done
  $SUDO mkdir -p "/usr/lib/llvm-$1/include" "/usr/lib/llvm-$1/lib" || ci_die "mkdir /usr/lib/llvm-$1"
  $SUDO cp -a "$ci_d/root/usr/lib/llvm-$1/include/." "/usr/lib/llvm-$1/include/" || ci_die "the headers of libc++ $1"
  for ci_f in "$ci_d/root/usr/lib/llvm-$1"/lib/libc++* "$ci_d/root/usr/lib/llvm-$1"/lib/libunwind* \
              "$ci_d"/root/usr/lib/*-linux-gnu/libc++* "$ci_d"/root/usr/lib/*-linux-gnu/libunwind*; do
    [ -e "$ci_f" ] || continue
    $SUDO cp -L --remove-destination "$ci_f" "/usr/lib/llvm-$1/lib/" || ci_die "the libraries of libc++ $1 ($ci_f)"
  done
  [ -e "/usr/lib/llvm-$1/lib/libc++.so.1" ] || ci_die "no libc++.so.1 of libc++ $1 among its packages' files"
  rm -rf "$ci_d"; echo "unpacked: libc++ $1 ($ci_v) under /usr/lib/llvm-$1"
}
# THE CROSS GATE'S C++ PART (0.246): that machine's libc++ of LLVM_MAJOR under the sysroot, where test/cross.sh reads it
# ($SYS/usr/lib/llvm-N). Ubuntu serves arm64 from ports.ubuntu.com, not from its own archive: the packages are fetched by
# an apt of the job's own -- that one source and both architectures, its lists and cache in a directory of its own, the
# machine's sources and dpkg left as they are -- and extracted, as on the gates' box (the same files, 0.246). An LLVM_MAJOR
# that the distribution does not ship comes from apt.llvm.org's arm64 packages, by their names (1.6.21: 23), whose links
# from llvm-N/lib into the machine's lib directory are relative and stay inside the sysroot
ci_arm64_libcxx() {
  ci_a=$(mktemp -d) || ci_die "mktemp"
  mkdir -p "$ci_a/parts" "$ci_a/lists/partial" "$ci_a/cache/archives/partial" "$ci_a/deb" || ci_die "mkdir $ci_a"
  case " $ci_from_llvm " in
    *" $LLVM_MAJOR "*)
      printf 'Types: deb\nURIs: https://apt.llvm.org/noble/\nSuites: llvm-toolchain-noble-%s\nComponents: main\nArchitectures: arm64\nSigned-By: /usr/share/keyrings/llvm-apt.gpg\n' "$LLVM_MAJOR" > "$ci_a/parts/llvm-arm64.sources"
      ci_src=apt.llvm.org; ci_rt="libc++1:arm64 libc++abi1:arm64 llvm-libunwind1:arm64" ;;
    *)
      printf 'Types: deb\nURIs: http://ports.ubuntu.com/ubuntu-ports\nSuites: noble noble-updates\nComponents: main universe\nArchitectures: arm64\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' > "$ci_a/parts/ports-arm64.sources"
      ci_src=ports.ubuntu.com; ci_rt="libc++1-$LLVM_MAJOR:arm64 libc++abi1-$LLVM_MAJOR:arm64 libunwind-$LLVM_MAJOR:arm64" ;;
  esac
  ci_o="-o Dir::Etc::SourceList=/dev/null -o Dir::Etc::SourceParts=$ci_a/parts -o Dir::State::Lists=$ci_a/lists -o Dir::Cache=$ci_a/cache"
  ci_o="$ci_o -o APT::Architectures::=amd64 -o APT::Architectures::=arm64 -o Debug::NoLocking=1"
  # shellcheck disable=SC2086
  $SUDO apt-get -qq $ci_o update > "$ci_a/update.log" 2>&1 || { tail -5 "$ci_a/update.log"; ci_die "apt-get update of $ci_src (arm64)"; }
  # shellcheck disable=SC2086
  ( cd "$ci_a/deb" && $SUDO apt-get -qq $ci_o download "libc++-$LLVM_MAJOR-dev:arm64" "libc++abi-$LLVM_MAJOR-dev:arm64" "libunwind-$LLVM_MAJOR-dev:arm64" $ci_rt ) \
      > "$ci_a/download.log" 2>&1 || { tail -5 "$ci_a/download.log"; ci_die "apt-get download of the arm64 libc++ $LLVM_MAJOR ($ci_src)"; }
  for ci_f in "$ci_a"/deb/*.deb; do $SUDO dpkg-deb -x "$ci_f" /usr/aarch64-linux-gnu || ci_die "dpkg-deb -x $ci_f"; done
  echo "unpacked: the arm64 libc++ $LLVM_MAJOR ($ci_src) under /usr/aarch64-linux-gnu: $(cd "$ci_a/deb" && ls | tr '\n' ' ')"
  $SUDO rm -rf "$ci_a"
}

if [ "$PHASE" != gates ]; then
ci_summary "**$JOB, $(uname -s) $(uname -r) on $(uname -m)**"; ci_summary ""
if [ "${CI_PACKAGES:-0}" = 1 ] && [ "$CI_OS" = linux ]; then
  ci_step "the system packages"
  SUDO=""; [ "$(id -u)" = 0 ] || SUDO=sudo
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get -qq update || ci_die "apt-get update"
  $SUDO apt-get -qq install -y curl gnupg ca-certificates > /dev/null || ci_die "apt-get install curl gnupg"
  # the gates call clang, clang++ and llvm-dwarfdump by their plain names, LLVM_MAJOR's (ci_llvm_names), and the
  # driver gate builds a C++ file too (its IR cache check), so the smoke job reads the libc++ of LLVM_MAJOR
  ci_pk="build-essential git sbcl clang-$LLVM_MAJOR llvm-$LLVM_MAJOR-dev libc++-$LLVM_MAJOR-dev libc++abi-$LLVM_MAJOR-dev libunwind-$LLVM_MAJOR-dev"
  # LLVM_MAJOR AND EACH TREE THE DISTRIBUTION DOES NOT SHIP come from apt.llvm.org, the LLVM project's own packages: LLVM_MAJOR
  # too since 1.6.21, when it became 23, which Ubuntu 24.04 has not. ci_from_llvm names them; a source this script added
  # on an earlier run is one of them, as apt-cache then finds the package through it
  ci_from_llvm=""; ci_ns=$LLVM_MAJOR; [ "$JOB" = full ] && ci_ns="$ci_ns $LIBCXX_TREES"
  for n in $ci_ns; do
    case " $ci_from_llvm " in *" $n "*) continue ;; esac
    if [ -f "/etc/apt/sources.list.d/llvm$n.list" ] || ! apt-cache show "libc++-$n-dev" >/dev/null 2>&1; then
      [ -s /usr/share/keyrings/llvm-apt.gpg ] || curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | $SUDO gpg --batch --yes --dearmor -o /usr/share/keyrings/llvm-apt.gpg \
        || ci_die "the key of apt.llvm.org"
      echo "deb [signed-by=/usr/share/keyrings/llvm-apt.gpg] https://apt.llvm.org/noble/ llvm-toolchain-noble-$n main" | $SUDO tee "/etc/apt/sources.list.d/llvm$n.list" > /dev/null
      ci_from_llvm="$ci_from_llvm $n"
    fi
  done
  echo "from apt.llvm.org: LLVM${ci_from_llvm:- none}"
  if [ "$JOB" = full ]; then
    # valgrind (0.273): the ccllib gate runs each of its three runs under it, where it is
    ci_pk="$ci_pk qemu-user gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-arm64-cross valgrind"
    # each tree's clang++: the C++ gate's reference and the ccllib gate's twin over that tree
    for n in $LIBCXX_TREES; do [ "$n" = "$LLVM_MAJOR" ] || ci_pk="$ci_pk clang-$n"; done
  fi
  $SUDO apt-get -qq update || ci_die "apt-get update"
  # shellcheck disable=SC2086
  $SUDO apt-get -qq install -y $ci_pk > /dev/null || ci_die "apt-get install $ci_pk"
  echo "installed: $ci_pk"
  ci_llvm_names
  if [ "$JOB" = full ]; then
    for n in $LIBCXX_TREES; do [ "$n" = "$LLVM_MAJOR" ] || ci_unpack_libcxx "$n"; done
    ci_arm64_libcxx
  fi
elif [ "${CI_PACKAGES:-0}" = 1 ]; then
  ci_step "the Homebrew packages"
  command -v brew >/dev/null 2>&1 || ci_die "no Homebrew (https://brew.sh): the Mac's packages come from it"
  xcode-select -p >/dev/null 2>&1 || ci_die "no Xcode command line tools (xcode-select --install): Apple's clang and the SDK"
  brew --version | sed -n 1p   # sed reads it all: head -1 closed the pipe, and a Mac's runner ignores SIGPIPE
  ci_f="llvm@$LLVM_MAJOR"
  # Homebrew's newest LLVM is llvm, with no version in its name (1.6.21: llvm is 23.1.6, and there is no llvm@23)
  if ! brew info --json=v2 "$ci_f" >/dev/null 2>&1; then
    ci_lv=$(brew info --json=v2 llvm 2>/dev/null | python3 -c 'import json, sys; print(json.load(sys.stdin)["formulae"][0]["versions"]["stable"])' 2>/dev/null)
    [ "${ci_lv%%.*}" = "$LLVM_MAJOR" ] || ci_die "no formula llvm@$LLVM_MAJOR, and this Homebrew's llvm is ${ci_lv:-not known}, not $LLVM_MAJOR"
    ci_f=llvm
  fi
  if ! brew list --formula "$ci_f" >/dev/null 2>&1; then
    # the bottles this Homebrew's formula data names for it: an Intel Mac takes one that is no arm64_ and no _linux one
    ci_tags=$(brew info --json=v2 "$ci_f" 2>/dev/null | python3 -c 'import json, sys; f = json.load(sys.stdin)["formulae"][0]; print(f["versions"]["stable"], " ".join(sorted(((f.get("bottle") or {}).get("stable") or {}).get("files", {}))))' 2>/dev/null)
    echo "$ci_f in this Homebrew's formula data: ${ci_tags:-nothing}"
    ci_intel=""; for t in ${ci_tags#* }; do case "$t" in arm64_*|*_linux|all) ;; *) ci_intel="$ci_intel $t" ;; esac; done
    if [ "$(uname -m)" = x86_64 ] && [ -z "$ci_intel" ]; then
      ci_die "$ci_f has no Intel bottle in this Homebrew's formula data (${ci_tags:-none}): it would build LLVM from source, for hours"
    fi
    brew install "$ci_f" || ci_die "brew install $ci_f"
  fi
  command -v gtimeout >/dev/null 2>&1 || command -v timeout >/dev/null 2>&1 || brew install coreutils || ci_die "brew install coreutils"
  ci_timeout
  echo "installed: $(brew list --versions "$ci_f"), $(timeout --version | sed -n 1p)"
  ci_summary "Homebrew: $(brew list --versions "$ci_f"); $(timeout --version | sed -n 1p)"; ci_summary ""
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

ci_inst=install/install-$CI_OS.sh
ci_step "Cicili, ZiguratIP and cocolog built by cocolog's $ci_inst"
# Linux's clang is LLVM_MAJOR's (23 since 1.6.21, apt.llvm.org's; Ubuntu's clang-18 until then); a Mac's is the one
# cocolog's tools/cc picks there (Apple's)
if [ "$CI_OS" = linux ]; then CICILI_CC=${CICILI_CC:-clang-$LLVM_MAJOR}; CICILI_CXX=${CICILI_CXX:-clang++-$LLVM_MAJOR}; export CICILI_CC CICILI_CXX; fi
ci_nopk=1; [ "${CI_PACKAGES:-0}" = 1 ] && ci_nopk=0   # the installer's own packages where this job installs packages
{ NO_PACKAGES=$ci_nopk LOG="$CI_LOGS/install" sh "$COCOLOG/$ci_inst" < /dev/null 2>&1; echo "exit $?" > "$CI_LOGS/install.rc"; } | tee "$CI_LOGS/install.out"
[ "$(cat "$CI_LOGS/install.rc")" = "exit 0" ] || ci_die "cocolog's installer ($(cat "$CI_LOGS/install.rc"); its logs are $CI_LOGS/install.*)"
# THE INSTALLER'S OWN EXPORTS, the lines it prints for a shell profile (ZiguratIP's library path among them, and on a
# Mac Homebrew's CPATH and LIBRARY_PATH), for every step after it -- the gates phase reads them back -- rather than a
# second copy of them here (cocolog's CI does so)
grep -E '^   export [A-Za-z_][A-Za-z0-9_]*=' "$CI_LOGS/install.out" | sed 's/^   //' > "$CI_LOGS/exports.sh"
echo "the installer's exports: $(sed 's/^export //; s/=.*//' "$CI_LOGS/exports.sh" | tr '\n' ' ')"
. "$CI_LOGS/exports.sh"

ci_step "this checkout's two modules"
( cd "$ROOT" && sh module/build.sh ) > "$CI_LOGS/build.log" 2>&1 || { tail -20 "$CI_LOGS/build.log"; ci_die "module/build.sh"; }
( cd "$ROOT" && LLVM=$(ci_llvm "$LLVM_MAJOR") sh module/build-llvm.sh ) > "$CI_LOGS/build-llvm.log" 2>&1 || { tail -20 "$CI_LOGS/build-llvm.log"; ci_die "module/build-llvm.sh"; }
tail -n 1 "$CI_LOGS/build.log"; tail -n 1 "$CI_LOGS/build-llvm.log"

ci_step "the toolchain, strictly"
if [ "$JOB" != full ]; then ci_tc="env LLVM=$(ci_llvm "$LLVM_MAJOR") TOOLCHAIN_TREES=$LLVM_MAJOR"; else ci_tc="env"; fi
$ci_tc TOOLCHAIN_STRICT=1 sh "$HERE/toolchain.sh" < /dev/null 2>&1 | tee "$CI_LOGS/toolchain.log"
grep -q '^GREEN: the toolchain' "$CI_LOGS/toolchain.log" || ci_die "the toolchain (above)"
fi
[ "$PHASE" = setup ] && { echo "GREEN: ci $JOB setup"; exit 0; }

[ -f "$CI_LOGS/exports.sh" ] && . "$CI_LOGS/exports.sh"
ci_fail=0
ci_summary ""; ci_summary "| gate | verdict | seconds |"; ci_summary "|---|---|---|"
# A CRASH'S REPORT (0.251): on a Mac the C library ends a program by abort() with no line of its own where a check fails
# (_FORTIFY_SOURCE's, the stack protector's: the reason goes to the crash log alone), and macOS keeps a report of each
# crash, its reason and its stack, in ~/Library/Logs/DiagnosticReports -- the job keeps those its gates made in its logs
ci_crash_dir="$HOME/Library/Logs/DiagnosticReports"; : > "$CI_LOGS/gates.start"
ci_crashes() {
  [ "$CI_OS" = macos ] && [ -d "$ci_crash_dir" ] || return 0
  find "$ci_crash_dir" -type f -newer "$CI_LOGS/gates.start" > "$CI_LOGS/crash.list" 2>/dev/null
  [ -s "$CI_LOGS/crash.list" ] || return 0
  mkdir -p "$CI_LOGS/crash"; while IFS= read -r ci_cf; do cp "$ci_cf" "$CI_LOGS/crash/"; done < "$CI_LOGS/crash.list"
  echo "the crash reports of this job's gates, kept in the logs (crash/): $(sed 's|.*/||' "$CI_LOGS/crash.list" | tr '\n' ' ')"
}
ci_run() {   # ci_run NAME CMD...: as test/gates.sh runs a gate, its GREEN or RED line and its time; its SKIPs read
  ci_n=$1; shift; ci_s=$(date +%s); ci_l="$CI_LOGS/gate-$(echo "$ci_n" | tr ' ' '-').log"
  { "$@" < /dev/null 2>&1; echo "exit $?" > "$ci_l.rc"; } | tee "$ci_l"
  ci_rc=$(sed 's/^exit //' "$ci_l.rc"); ci_e=$(( $(date +%s) - ci_s ))
  ci_skip=$(grep -a '^SKIP' "$ci_l" | grep -av '^SKIP [^ ]* (not here)$' || true)
  if [ "$ci_rc" -eq 0 ] && [ -z "$ci_skip" ]; then echo "== $ci_n: GREEN in ${ci_e} s"; ci_summary "| $ci_n | GREEN | $ci_e |"
  elif [ "$ci_rc" -eq 0 ]; then
    echo "== $ci_n: RED in ${ci_e} s, a SKIP this job does not expect:"; printf '%s\n' "$ci_skip" | sed 's/^/     /'
    ci_summary "| $ci_n | RED: $(printf '%s' "$ci_skip" | head -1 | cut -c1-100) | $ci_e |"; ci_fail=1
  else echo "== $ci_n: RED (exit $ci_rc) in ${ci_e} s"; ci_summary "| $ci_n | RED (exit $ci_rc) | $ci_e |"; ci_fail=1; fi
}
if [ "$JOB" = smoke ]; then
  ci_step "the six small gates"
  # THE FLOW GATE'S POOL BY THE MACHINE'S MEMORY (0.246): four lanes under 9000 and 14000 MB summed fit 14 GB and more;
  # Apple silicon's runner has 7 GB, where the pool takes two lanes, a launch below 3500 MB, the pool killed past 5500
  # (on the gates' box: four lanes wide its peak was 4504 MB, at 0.245; two lanes wide 3224 MB, GREEN in 192 s, at 0.246)
  if [ "$CI_OS" = macos ]; then ci_mb=$(( $(sysctl -n hw.memsize) / 1048576 )); else ci_mb=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo); fi
  ci_pool=""; [ "${ci_mb:-0}" -lt 12000 ] && ci_pool="FLOW_JOBS=2 FLOW_LAUNCH_MB=3500 FLOW_HARD_MB=5500"
  echo "this machine's memory: $ci_mb MB; the flow gate's pool: ${ci_pool:-its defaults}"
  # shellcheck disable=SC2086
  for g in flow reader compile driver objects; do ci_run "$g" env LLVM="$(ci_llvm "$LLVM_MAJOR")" $ci_pool sh "$HERE/$g.sh"; done
  ci_run proof sh "$ROOT/proof/run.sh"
elif [ "$JOB" = cpp ]; then
  # THE C++ JOB (0.246): the C++ gates on a Mac, where they had not run since 0.90 -- the library read, then the C++ gate,
  # over LLVM_MAJOR's libc++ (Homebrew's keg), each pool under caps that fit the runner's 14 GB: three lanes, a launch below
  # 6000 MB summed, the pool killed past 10000. Each C++ gate the CI runs writes its fixtures' starts and verdicts as they
  # come into the logs (CPP_PROGRESS, 0.249), which the artifact keeps when GitHub stops a job at its six hours
  ci_step "the library read and the C++ gate over libc++ $LLVM_MAJOR"
  ci_run "libcxx $LLVM_MAJOR" env LLVM="$(ci_llvm "$LLVM_MAJOR")" LX_JOBS=3 LX_LAUNCH_MB=6000 LX_HARD_MB=10000 sh "$HERE/libcxx.sh"
  [ "$ci_fail" = 0 ] && ci_run "cpp $LLVM_MAJOR" env LLVM="$(ci_llvm "$LLVM_MAJOR")" CPP_JOBS=3 CPP_LAUNCH_MB=6000 CPP_HARD_MB=10000 CPP_PROGRESS="$CI_LOGS/cpp-progress-$LLVM_MAJOR.log" sh "$HERE/cpp.sh"
else
  ci_step "all ten gates over libc++ $LLVM_MAJOR"
  ci_run gates env LLVM="$(ci_llvm "$LLVM_MAJOR")" CPP_PROGRESS="$CI_LOGS/cpp-progress-$LLVM_MAJOR.log" sh "$HERE/gates.sh"
  for n in $LIBCXX_TREES; do
    [ "$n" = "$LLVM_MAJOR" ] && continue
    [ "$ci_fail" = 0 ] || break
    ci_step "the library read and the C++ gate over libc++ $n"
    ci_run "libcxx $n" env LLVM="$(ci_llvm "$n")" sh "$HERE/libcxx.sh"
    [ "$ci_fail" = 0 ] && ci_run "cpp $n" env LLVM="$(ci_llvm "$n")" CPP_PROGRESS="$CI_LOGS/cpp-progress-$n.log" sh "$HERE/cpp.sh"
  done
fi
ci_crashes
if [ "$ci_fail" = 0 ]; then echo "GREEN: ci $JOB"; else echo "RED: ci $JOB"; fi
exit "$ci_fail"
