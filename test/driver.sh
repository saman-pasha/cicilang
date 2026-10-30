#!/bin/sh
# The driver's gate: bin/cicilang with clang's arguments. GREEN or RED.
#
#   sh test/driver.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
[ -x "$C" ] || { echo "SKIP (no cocolog binary at $C -- set COCOLOG)"; exit 0; }
[ -f "$ROOT/library/cicilang.so" ] || { echo "SKIP (no library/cicilang.so -- sh module/build.sh)"; exit 0; }
D=$(mktemp -d "${TMPDIR:-/tmp}/cicilang-driver-XXXXXX")
trap 'rm -rf "$D"' EXIT
failures=0
check() { if [ "$2" = "$3" ]; then printf 'ok   %-56s %s\n' "$1" "$(echo "$2" | head -1 | cut -c1-40)"; else printf 'FAIL %-56s\n     got  %s\n     want %s\n' "$1" "$2" "$3"; failures=$((failures + 1)); fi; }
cd "$D"    # the store is the user's, from test/config.sh
CICILI="$ROOT/bin/cicilang"; R="$ROOT/test/c"

check "--version names cicilang, its version, cocolog's and LLVM's" "$("$CICILI" --version | sed 's/^cicilang 0\.[0-9][0-9]* (cocolog [0-9][0-9.]*; LLVM [0-9.]*)$/shape ok/')" "shape ok"
s0=$(date +%s); first=$("$CICILI" "$R/run/hello.c" -o hello && ./hello); t_first=$(( $(date +%s) - s0 ))
check "cicilang hello.c -o hello: a binary that runs" "$first" "hello, cicilang"
check "and with no -o, a.out, as clang" "$("$CICILI" "$R/run/forty2.c"; ./a.out; echo "exit $?")" "exit 42"
check "-c makes NAME.o in the working directory" "$("$CICILI" -c "$R/run/forty2.c" && ls forty2.o)" "forty2.o"
case $(uname -s) in Darwin) MAIN='^_main:'; SO=dylib; SOTEXT='dynamically linked shared library' ;; *) MAIN='^main:'; SO=so; SOTEXT='shared object' ;; esac   # Mach-O prefixes a C name with `_'; ELF does not
check "-S makes NAME.s with main in it" "$("$CICILI" -S "$R/run/forty2.c" && grep -c "$MAIN" forty2.s)" "1"
check "-emit-llvm -c makes NAME.ll with the IR" "$("$CICILI" -emit-llvm -c "$R/run/forty2.c" && grep -c 'define i32 @main' forty2.ll)" "1"
check "an own array's drain is a generated function in the IR" "$("$CICILI" -emit-llvm -c "$R/run/btree.c" && grep -c 'define internal void @ccl_drain_node' btree.ll)" "1"
check "-fsyntax-only refuses a program the safe part refuses, exit 1, one line" "$("$CICILI" -fsyntax-only "$R/safe/use_after_free.c" 2>&1 | grep -c 'error: use after move of')-$("$CICILI" -fsyntax-only "$R/safe/use_after_free.c" >/dev/null 2>&1; echo $?)" "1-1"
check "the diagnostic is file:line: error: what, clang's shape" "$("$CICILI" -fsyntax-only "$R/safe/leak.c" 2>&1 | head -1 | sed "s|$R/||")" "safe/leak.c:2: error: owner leaked: 'p' in return(int(0)) (function main)"
check "two .c files and -O2 link into one program" "$("$CICILI" -O2 "$R/link/main.c" "$R/link/lib.c" -o app && ./app)" "42"
check "a .o from -c links with a .c" "$("$CICILI" -c "$R/link/lib.c" -o lib.o && "$CICILI" "$R/link/main.c" lib.o -o app2 && ./app2)" "42"
# the ABI: structs by value of every class cross between clang-built code and ours, both ways,
# and the program prints what the same program built by clang alone prints
check "variadic calls of every kind cross the ABI both ways, as clang has it" "$(clang -c "$R/link/va_main.c" -o va_main.o && clang -c "$R/link/va_func.c" -o va_func.o && "$CICILI" "$R/link/va_func.c" va_main.o -o va1 && ./va1 > va1.out && "$CICILI" "$R/link/va_main.c" va_func.o -o va2 && ./va2 > va2.out && clang "$R/link/va_main.c" "$R/link/va_func.c" -o va_ref && ./va_ref > va_ref.out && cmp -s va1.out va_ref.out && cmp -s va2.out va_ref.out && echo same && wc -l < va1.out | tr -d ' ')" "same
12"   # va_arg of a long double, an HFA, a big struct, an __int128 (0.131: an x87 long double came wrong out of LLVM's own va_arg)
# va_arg of aggregates on Apple's arm64 (0.160): no Apple machine is here, so both walks are compiled for arm64-apple-macos,
# retargeted to this host and run over one buffer laid out as Apple's ABI lays the variadic arguments out (va_darwin_main.c)
check "va_arg of aggregates on Apple's arm64 reads what clang's reads" "$(clang --target=arm64-apple-macos -O1 -S -emit-llvm -DWALK=walk_clang "$R/link/va_darwin.c" -o vdc.ll && "$CICILI" --target=arm64-apple-macos -O1 -S -emit-llvm -DWALK=walk_cicilang "$R/link/va_darwin.c" -o vdk.ll && for f in vdc vdk; do grep -v '^target \(datalayout\|triple\)' $f.ll | sed 's/"target-cpu"="[^"]*"//; s/"target-features"="[^"]*"//' > ${f}_h.ll && clang -c -w ${f}_h.ll -o $f.o || exit 1; done && clang -w "$R/link/va_darwin_main.c" vdc.o vdk.o -o vd && ./vd)" "same"
check "structs by value cross the ABI both ways, as clang has it" "$(clang -c "$R/link/abi_helper.c" -o abi_helper.o && "$CICILI" "$R/link/abi_main.c" abi_helper.o -o abi && ./abi > abi.out && clang "$R/link/abi_main.c" "$R/link/abi_helper.c" -o abi_ref && ./abi_ref > abi_ref.out && cmp -s abi.out abi_ref.out && echo same && wc -l < abi.out | tr -d ' ')" "same
7"
check "vectors by value cross the ABI both ways, as clang has it" "$(clang -c "$R/link/vec_helper.c" -o vec_helper.o && "$CICILI" "$R/link/vec_main.c" vec_helper.o -o vec && ./vec > vec.out && "$CICILI" -c "$R/link/vec_helper.c" -o vec_helper_ours.o && clang "$R/link/vec_main.c" vec_helper_ours.o -o vec_rev && ./vec_rev > vec_rev.out && clang "$R/link/vec_main.c" "$R/link/vec_helper.c" -o vec_ref && ./vec_ref > vec_ref.out && cmp -s vec.out vec_ref.out && cmp -s vec_rev.out vec_ref.out && echo same && wc -l < vec.out | tr -d ' ')" "same
4"   # 0.162: 8- and 16-byte vectors, a struct of a vector, nine vectors, va_arg of a vector, both ways (test/c/link/vec_*.c)
# the decimal floating types (0.129) as gcc passes them -- clang has none: values, structs and a variadic call, both ways
if printf '_Decimal64 x = 1.0dd;\n' | gcc -x c -c -o /dev/null - 2>/dev/null; then
check "decimal values cross the ABI both ways, as gcc has it" "$(gcc -c "$R/link/dec_helper.c" -o dec_helper.o && "$CICILI" "$R/link/dec_main.c" dec_helper.o -o dec && ./dec > dec.out && "$CICILI" -c "$R/link/dec_helper.c" -o dec_helper_ours.o && gcc "$R/link/dec_main.c" dec_helper_ours.o -o dec_rev && ./dec_rev > dec_rev.out && gcc "$R/link/dec_main.c" "$R/link/dec_helper.c" -o dec_ref && ./dec_ref > dec_ref.out && cmp -s dec.out dec_ref.out && cmp -s dec_rev.out dec_ref.out && echo same && wc -l < dec.out | tr -d ' ')" "same
2"
check "a long double constant converted to a decimal type folds as gcc folds it" "$("$CICILI" "$R/link/decld.c" -o decld && ./decld > decld.out && gcc -w "$R/link/decld.c" -o decld_ref && ./decld_ref > decld_ref.out && cmp -s decld.out decld_ref.out && echo same && wc -l < decld.out | tr -d ' ')" "same
12"   # 0.154: LDBL_MAX, LDBL_MIN, 0.1L, 1.0L / 3.0L ... from the long double's exact value; it was refused while the literal held a double's value
else echo "skip  decimal values across the ABI: no gcc with decimal floating types"; echo "skip  a long double constant to a decimal type: no gcc with decimal floating types"; fi
check "-I adds to the inclusion path (a typedef from box.h)" "$("$CICILI" -I "$R/inc" "$R/inc/uses_box.c" -o boxed && ./boxed)" "42"
check "-shared -O1 makes a library" "$("$CICILI" -shared -O1 "$R/link/lib.c" -o libtwice.$SO && file libtwice.$SO | grep -c "$SOTEXT")" "1"
printf '#warning mind the gap\nint main(void) { return 3; }\n' > warn.c
check "#warning in the file is printed, clang's shape, and is no error" "$("$CICILI" warn.c -o warn 2>&1 >/dev/null | head -1; ./warn; echo "exit $?")" "warn.c:1: warning: mind the gap
exit 3"
printf '#error not here\nint main(void) { return 0; }\n' > err.c
errout=$("$CICILI" err.c -o err 2>&1 >/dev/null); errcode=$?
check "#error in the file is a diagnostic, exit 1" "$(echo "$errout" | head -1; echo "exit $errcode")" "err.c:1: error: not here
exit 1"
printf 'struct S { int a; _Static_assert(sizeof(int) == 8, "eight"); };\nint main(void) { return 0; }\n' > sasm.c
sasmout=$("$CICILI" sasm.c -o sasm 2>&1 >/dev/null); sasmcode=$?
check "a false static assertion among a struct's members is an error" "$(echo "$sasmout" | head -1; echo "exit $sasmcode")" "sasm.c:1: error: static assertion failed: eight
exit 1"   # 0.205: a static_assert-declaration is a struct-declaration (C11 6.7.2.1/1); it was a syntax error
cat > defs.c <<'EOF2'
#include <stdio.h>
#include <assert.h>
int main(void) {
#ifdef GREETING
  printf("%s\n", GREETING);
#endif
#ifdef GONE
  printf("gone is here\n");
#endif
  printf("%d %d\n", SQUARE(7), LEVEL);
  assert(LEVEL == 0);
  printf("after\n");
  return 0;
}
EOF2
check "-D and -U define and undefine before every file, <assert.h>'s NDEBUG among them" "$("$CICILI" -DGREETING='"hi"' '-DSQUARE(x)=((x)*(x))' -DLEVEL=3 -DNDEBUG -DGONE -UGONE defs.c -o defs && ./defs)" "hi
49 3
after"
# UNDER -DNDEBUG AN `#undef NDEBUG' BEFORE <assert.h> ASSERTS AGAIN (C17 7.2/1; 0.221): the header's own read sees no NDEBUG
cat > ndebugundef.c <<'EOF2'
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
int main(void) { printf("before\n"); fflush(stdout); assert(1 == 2); printf("after\n"); return 0; }
EOF2
check "-DNDEBUG: an #undef NDEBUG before <assert.h> asserts again" "$("$CICILI" -DNDEBUG ndebugundef.c -o ndebugundef && { ( ./ndebugundef ) 2>/dev/null; echo "exit $?"; })" "before
exit 134"
check "-E: a floating literal's text reads back as the same value, as clang reads the source" "$(printf 'int printf(const char *, ...);\nint main(void) {\n  double a = __DBL_MAX__, b = 1.5e308, c = 0.30000000000000004, d = 2.2250738585072014e-308, e = 4.9406564584124654e-324, f = 1e999;\n  float g = __FLT_MAX__, h = 1.17549435e-38f;\n  printf("%%a %%a %%a %%a %%a %%a %%a %%a\\n", a, b, c, d, e, f, (double) g, (double) h);\n  return 0;\n}\n' > et.c; "$CICILI" -E et.c -o et.e.c && clang -w et.e.c -o ete && ./ete > ete.out && clang -w et.c -o etr && ./etr > etr.out && cmp -s ete.out etr.out && echo same)" "same"
check "-E: a long double literal's text reads back as the same value, as clang reads the source" "$(printf 'int printf(const char *, ...);\nint main(void) {\n  long double a = __LDBL_MAX__, b = __LDBL_MIN__, c = __LDBL_DENORM_MIN__, d = 0.1L, e = 0x1.8p1L, f = 1e999L;\n  _Complex long double g = 0.1Li;\n  printf("%%La %%La %%La %%La %%La %%La %%La\\n", a, b, c, d, e, f, __imag__ g);\n  return 0;\n}\n' > etl.c; "$CICILI" -E etl.c -o etl.e.c && clang -w etl.e.c -o etle && ./etle > etle.out && clang -w etl.c -o etlr && ./etlr > etlr.out && cmp -s etle.out etlr.out && echo same)" "same"   # 0.154: the text kept, where -E spelled the double the literal held
check "-ast-dump prints the unit" "$("$CICILI" -ast-dump "$R/run/forty2.c" | grep -c '^unit(\[function(')" "1"
DD=$(command -v llvm-dwarfdump || echo "${LLVM:-/usr/lib/llvm-18}/bin/llvm-dwarfdump")   # -g (0.128): the line table, read by LLVM's own reader
# MACH-O KEEPS THE DWARF IN THE OBJECTS (0.224): a Mac's link writes a debug map that names them, for dsymutil to gather
# the DWARF from, and the objects cicilang links from are its own, gone after the link -- so on a Mac a check of a
# program's DWARF reads the object that -c makes of the same file under the same flags; ELF's link carries it over
dw() {   # dw PROGRAM SOURCE FLAGS...: the file whose DWARF a -g check of PROGRAM reads
  _dw_p=$1; _dw_s=$2; shift 2
  case $(uname -s) in Darwin) "$CICILI" "$@" -c "$_dw_s" -o "$_dw_p.o" > /dev/null 2>&1; echo "$_dw_p.o" ;; *) echo "$_dw_p" ;; esac
}
check "-g: line tables, a line per statement, the file named" "$(printf '#include <stdio.h>\n\nstatic int twice(int x) {\n  int y = x * 2;\n  return y;\n}\n\nint main(void) {\n  int a = twice(21);\n  printf("%%d\\n", a);\n  return 0;\n}\n' > dbg.c; "$CICILI" -g dbg.c -o dbg && ./dbg && f=$(dw dbg dbg.c -g) && "$DD" --debug-line "$f" | grep -c 'name: "dbg.c"' && "$DD" --debug-line "$f" | awk '/^0x/ { print $2 }' | sort -n -u | tr '\n' ' ')" "42
1
3 4 5 8 9 10 11 "
check "-g: each expression's column is one clang's line table has for it (a name, an operator, a call, a condition, a loop, a return)" "$(printf '#include <stdio.h>\nstatic int twice(int x) {\n  int y = x * 2;\n  return y;\n}\nint main(int argc, char **argv) {\n  int s = 0;\n  for (int i = 0; i < argc; i++) s += twice(i);\n  if (s > 3) printf("big %%d\\n", s); else printf("small %%d\\n", s);\n  return 0;\n}\n' > dbgc.c; "$CICILI" -g -c dbgc.c -o dbgc.o && clang -g -O0 -c dbgc.c -o dbgc_ref.o && "$DD" --debug-line dbgc.o | awk '/^0x/ && $3 > 0 { print $2 ":" $3 }' | LC_ALL=C sort -u > dbgc.ours && "$DD" --debug-line dbgc_ref.o | awk '/^0x/ { print $2 ":" $3 }' | LC_ALL=C sort -u > dbgc.ref && echo "$(LC_ALL=C comm -23 dbgc.ours dbgc.ref | wc -l | tr -d ' ') $(wc -l < dbgc.ours | tr -d ' ')")" "0 20"   # 0.161: none outside clang's, ten of them, a statement's column each; every location was column 1. 0.242: twenty, an expression's own column each
check "-g: the variables and their types, as DWARF describes them" "$(printf 'enum color { RED, GREEN = 5 };\nstruct point { int x; double y; };\nint g = 3;\nint main(void) {\n  struct point p = {1, 2.5};\n  enum color c = GREEN;\n  return p.x + c - 6 + g - 3;\n}\n' > dbgv.c; "$CICILI" -g dbgv.c -o dbgv && ./dbgv && "$DD" --debug-info "$(dw dbgv dbgv.c -g)" | awk '/DW_AT_name/ { gsub(/[()"]/, "", $2); print $2 }' | LC_ALL=C sort -u | tr '\n' ' ')" "GREEN RED c color dbgv.c double g int main p point x y "
check "-gline-tables-only: the lines and no variable" "$("$CICILI" -gline-tables-only dbgv.c -o dbgl && ./dbgl && "$DD" --debug-info "$(dw dbgl dbgv.c -gline-tables-only)" | grep -c 'DW_TAG_variable')" "0"
# -fdebug-macro's macros are DWARF 5's .debug_macro, and on a Mac DWARF 4's .debug_macinfo (0.225): LLVM's DWARF 5 macros
# crash on Mach-O, clang 21's for macOS 15 and later too
case $(uname -s) in Darwin) MK=MACINFO; MD=define; MU=undef ;; *) MK=MACRO; MD=define_strx; MU=undef_strx ;; esac
check "-g -fdebug-macro: each file's macros at their lines, as clang has them" "$(printf '#define TWICE(x) ((x) * 2)\n#define LIMIT 10\n' > dm.h; printf '#include "dm.h"\n#define FOO 42\n#undef LIMIT\n#define LIMIT 20\nint g = FOO + LIMIT;\nint main(void) { return TWICE(g) - 124; }\n' > dm.c; "$CICILI" -g -fdebug-macro -c dm.c -o dm.o && "$DD" --debug-macro dm.o | awk '/lineno: 0 / { z++ } /lineno: [1-9]|end_file/ { sub(/ filenum: [0-9]+/, ""); gsub(/^ +/, ""); printf "%s|", $0 } END { print (z > 300 ? "predefined" : "few") }')" "DW_${MK}_start_file - lineno: 1|DW_${MK}_${MD} - lineno: 1 macro: TWICE(x) ((x) * 2)|DW_${MK}_${MD} - lineno: 2 macro: LIMIT 10|DW_${MK}_end_file|DW_${MK}_${MD} - lineno: 2 macro: FOO 42|DW_${MK}_${MU} - lineno: 3 macro: LIMIT|DW_${MK}_${MD} - lineno: 4 macro: LIMIT 20|DW_${MK}_end_file|predefined"
check "-g: a function and an object a header defines are described in the header (0.213)" "$(printf 'static int hd_n = 41;\nstatic inline int hd(int x) {\n  return x + 1;\n}\n' > dbgh.h; printf '#include %s\nint main(void) {\n  return hd(hd_n) - 42;\n}\n' '"dbgh.h"' > dbgh.c; "$CICILI" -g dbgh.c -o dbgh && ./dbgh && "$DD" --debug-info "$(dw dbgh dbgh.c -g)" | grep -A3 'DW_AT_name.*"hd' | grep -c 'decl_file.*dbgh.h')" "2"
check "the last -std wins, its level and its mode, as clang: -std=c17 -std=gnu17 builds GNU's, -std=gnu17 -std=c17 ISO's, each its own IR in the store (0.214)" "$(printf '#ifdef __STRICT_ANSI__\nint main(void) { return 3; }\n#elif defined(__APPLE__)\nint main(void) { return 2; }\n#else\nint main(void) { return linux + unix; }\n#endif\n' > lastd.c; { "$CICILI" -std=c17 -std=gnu17 lastd.c -o lastd1 && ./lastd1; echo "$?"; "$CICILI" -std=gnu17 -std=c17 lastd.c -o lastd2 && ./lastd2; echo "$?"; } | tr '\n' ' ')" "2 3 "   # a Mac's GNU mode predefines neither linux nor unix, as clang's Darwin (0.224)
check "-g: a C++ static data member is declared in its class" "$(printf 'struct S {\n  static int count;\n  int v;\n};\nint S::count = 7;\nint main() {\n  S s{2};\n  return s.v + S::count - 9;\n}\n' > dbgs.cpp; "$ROOT/bin/cicilang++" -g -c dbgs.cpp -o dbgs.o && "$DD" --debug-info dbgs.o | awk '/DW_TAG_structure_type/ { s = index($0, "DW_TAG_"); next } /DW_TAG_/ { i = index($0, "DW_TAG_"); if (s && i <= s) s = 0; if (s && /DW_TAG_variable/) v++ } /DW_AT_specification/ { sp++ } END { print v + 0, sp + 0 }')" "1 1"
check "-g: a destructor at its scope's closing brace, as clang's" "$(printf 'struct T {\n  int v;\n  ~T() { v = 0; }\n};\nint f(int k) {\n  T a{1};\n  if (k) {\n    T b{2};\n    return 5;\n  }\n  return 0;\n}\nint main() { return f(0) + f(1) - 5; }\n' > dbgd.cpp; "$ROOT/bin/cicilang++" -g -c dbgd.cpp -o dbgd.o && "$DD" --debug-line dbgd.o | awk '$1 ~ /^0x/ { if ($2 == 10) t = 1; if ($2 == 12) w = 1 } END { print (t ? "10" : "-"), (w ? "12" : "-") }')" "10 12"
check "an unknown argument is an error, as clang says it" "$("$CICILI" --frobnicate x.c 2>&1)" "cicilang: error: unknown argument: '--frobnicate'"
check "no input files is an error" "$("$CICILI" -c 2>&1)" "cicilang: error: no input files"
check "the tie: a broken tie is refused in clang's shape" "$("$CICILI" -fsyntax-only "$R/safe/tie_arg.c" 2>&1 | head -1 | sed "s|$R/||")" "safe/tie_arg.c:4: error: value not within its tie: 'b' in call(id(gap),[id(a),id(b)]) (function main)"
check "a slot with no owner behind it is refused, in clang's shape" "$(printf '#include <stdlib.h>\nstruct s { char *q; } g;\nint main(void) { char *p = malloc(8); g.q = malloc(8); free(p); return 0; }\n' > untied.c; "$CICILI" -fsyntax-only untied.c 2>&1 | head -1)" "untied.c:3: error: no owner behind: 'g.q' in assign(=,member(id(g),q),call(id(malloc),[int(8)])) (function main)"
check "a plain pointer never consumed is refused; one freed is not" "$(printf '#include <stdlib.h>\nint main(void) { char *p = malloc(8); char *r = malloc(8); free(p); return 0; }\n' > loose.c; "$CICILI" -fsyntax-only loose.c 2>&1 | head -1)" "loose.c:2: error: plain pointer not consumed: 'r' in return(int(0)) (function main)"
check "GNU's asm goto is lowered, a callbr (0.231), and an asm output that carries a pointer is refused by name (0.215)" "$(printf 'int main(void) {\n  asm goto("jmp %%l0" :::: out);\n  return 1;\nout:\n  return 0;\n}\n' > asmgoto.c; "$CICILI" -c asmgoto.c > asmgoto.out 2>&1; echo "asm goto: exit $?"; head -1 asmgoto.out; printf 'int main(void) {\n  int x = 0, *p = &x;\n  asm("" : "=r"(p));\n  return *p;\n}\n' > asmptr.c; "$CICILI" -fsyntax-only asmptr.c 2>&1 | head -1)" "asm goto: exit 0
asmptr.c:3: error: not lowered yet: asm_pointer_output (function main)"
check "an asm goto whose jump would run a cleanup -- a defer, a C++ destructor -- is refused by name, as clang refuses it (0.231)" "$(printf 'int f(int k) {\n  {\n    defer(k) { (void)k; }\n    asm goto("" :::: out);\n  }\n  return 1;\nout:\n  return 0;\n}\nint main(void) { return f(1); }\n' > asmdefer.c; "$CICILI" -c asmdefer.c 2>&1 | head -1; printf 'struct N { int v; ~N(); };\nN::~N() {}\nint f(int x) {\n  { N n{x}; asm goto("" :::: out); }\n  return 1;\nout:\n  return 0;\n}\nint main() { return f(1); }\n' > asmdtor.cpp; "$ROOT/bin/cicilang++" -c asmdtor.cpp 2>&1 | head -1)" "asmdefer.c:4: error: not lowered yet: asm_goto_over_defer(out) (function f)
asmdtor.cpp:4: error: not lowered yet: asm_goto_over_defer(out) (function f)"
check "a syntax error names the file and the line" "$(printf 'int f(void) { return ; ; }\nint h( { }\n' > bad.c; "$CICILI" -c bad.c 2>&1 | head -1)" "bad.c:2: error: syntax error: could not read this item (gave up near line 2)"
check "an identifier's characters past ASCII by the level (0.221): C17 takes the euro sign and a middle dot, C23 does not, C99 no combining mark" "$(printf 'int a\342\202\254b = 1;\n' > euro.c; printf 'int \302\267x = 1;\n' > mdot.c; printf 'int x\314\201 = 1;\n' > comb.c; "$CICILI" -std=c17 -fsyntax-only euro.c mdot.c 2>&1; echo "c17 $?"; "$CICILI" -std=c23 -fsyntax-only euro.c 2>&1 | head -1; "$CICILI" -std=c23 -fsyntax-only mdot.c 2>&1 | head -1; "$CICILI" -std=c99 -fsyntax-only comb.c 2>&1 | head -1)" "c17 0
euro.c:1: error: character <U+20AC> not allowed in an identifier
mdot.c:1: error: character <U+00B7> not allowed at the start of an identifier
comb.c:1: error: character <U+0301> not allowed in an identifier"
check "__STDC_VERSION__ by the level (0.221): C99's, C11's, C17's and C23's" "$(printf 'long v = __STDC_VERSION__;\n' > ver.c; for s in c99 c11 c17 c23; do "$CICILI" -std=$s -E ver.c | grep -o '[0-9][0-9]*[lL]'; done | tr '\n' ' ')" "199901L 201112L 201710L 202311L "   # a number as written since 0.228, as clang's -E writes it
# -E AS CLANG WRITES IT (0.228): a literal, a number, a digraph and an alternative token as written, a name written with a
# universal character name its character, and `#x' of such a name its spelling -- the text compared with clang's, white space
# aside (test/c/espell.c, test/cpp/espell.cpp)
check "-E writes literals, numbers, digraphs and #x as clang -E does (0.228)" "$("$CICILI" -E "$R/espell.c" | tr -d ' \t\n')" "$(clang -E -P "$R/espell.c" | tr -d ' \t\n')"
check "... and in C++ alternative tokens, raw strings and named characters (0.228)" "$("$ROOT/bin/cicilang++" -std=c++23 -E "$ROOT/test/cpp/espell.cpp" | tr -d ' \t\n')" "$(clang++ -std=c++23 -E -P "$ROOT/test/cpp/espell.cpp" | tr -d ' \t\n')"
# the store: hello.c and its headers are there by now; a build of it is seconds, not the forty of a first read
s1=$(date +%s); "$CICILI" "$R/run/hello.c" -o hello2 >/dev/null; t_second=$(( $(date +%s) - s1 ))
check "the store: a build of hello.c after the first is served from it, under 10 s ($t_second s)" "$( [ "$t_second" -lt 10 ] && echo served || echo "slow")" "served"
# the IR beside the units: a rebuild of two files after one changed redoes that one, the other's IR served
cp "$R/link/main.c" "$R/link/lib.c" "$R/link/lib.h" . && "$CICILI" main.c lib.c -o two >/dev/null 2>&1
second=$("$CICILI" -v main.c lib.c -o two 2>&1 | grep -c "served .* from the store")
touch -t 203001010000 lib.c
third=$("$CICILI" -v main.c lib.c -o two 2>&1 | grep -ao "served main.c\|check and lower lib.c" | tr '\n' ' ')
check "the store: a rebuild after one file changed redoes one file, the other's IR served" "$second-$third" "2-served main.c check and lower lib.c "
# THE C++ IR CACHE (0.221): a second build of an unchanged C++ file is served its IR from ~/.cicilang/cpp/ir; a change to it
# lowers it again
printf '#include <cstdio>\nint main() { std::printf("ir %%d\\n", 7); return 0; }\n' > ircache.cpp
rm -f "$HOME"/.cicilang/cpp/ir/ircache.cpp-*.ll
irfirst=$(CICILANG_NO_IR_CACHE= "$ROOT/bin/cicilang++" -v ircache.cpp -o irc1 2>&1 | grep -ac 'served ircache.cpp from the IR cache')
irsecond=$(CICILANG_NO_IR_CACHE= "$ROOT/bin/cicilang++" -v ircache.cpp -o irc2 2>&1 | grep -ac 'served ircache.cpp from the IR cache'; ./irc2)
printf '#include <cstdio>\nint main() { std::printf("ir %%d\\n", 8); return 0; }\n' > ircache.cpp
irthird=$(CICILANG_NO_IR_CACHE= "$ROOT/bin/cicilang++" -v ircache.cpp -o irc3 2>&1 | grep -ac 'served ircache.cpp from the IR cache'; ./irc3)
check "the C++ IR cache: a rebuild is served its IR, a changed file lowered again" "$irfirst $irsecond $irthird" "0 1
ir 7 0
ir 8"
# ONE BUILD AT A TIME OVER THE STORE (0.240): four builds at once over one fresh store take KB.lock in turn -- without it
# three died of a bus error and the store was left so damaged that every later build failed -- and one more build over
# that store after them runs; no lock is left
pk="$D/kbpar"
for n in hello forty2 owners btree; do ( CICILANG_KB="$pk" "$CICILI" "$R/run/$n.c" -o "par_$n" > "par_$n.log" 2>&1 < /dev/null ) & done; wait
par=$(for n in hello forty2 owners btree; do if [ -x "par_$n" ]; then echo "$n built"; else echo "$n failed"; fi; done | tr '\n' ' ')
after=$(CICILANG_KB="$pk" "$CICILI" "$R/run/hello.c" -o parlast 2>&1 && ./parlast; ls -d "$pk.lock" 2>/dev/null)
check "builds at once over one store take its lock in turn, the store sound after" "$par/$after" "hello built forty2 built owners built btree built /hello, cicilang"
if [ "$failures" -eq 0 ]; then echo "GREEN: driver"; else echo "RED: $failures failure(s)"; exit 1; fi
