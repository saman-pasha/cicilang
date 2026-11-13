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

check "--version names cicilang, its version's three numbers (1.1.0), cocolog's and LLVM's" "$("$CICILI" --version | sed 's/^cicilang [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]* (cocolog [0-9][0-9.]*; LLVM [0-9.]*)$/shape ok/')" "shape ok"
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
# the calling conventions and the layouts of three machines (0.244): every function's result and parameters -- the types and the
# attributes a call reads -- and a table of sizes, offsets and alignments, in cicilang's IR and in clang's (test/abisig.awk)
check "the calling conventions and layouts of x86-64, Linux's aarch64 and Apple's arm64 are clang's" "$(for t in x86_64-linux-gnu aarch64-linux-gnu arm64-apple-macos; do "$CICILI" --target=$t -std=c23 -S -emit-llvm "$R/link/abi_targets.c" -o at_ours.ll > at.log 2>&1 && clang --target=$t -std=c23 -S -emit-llvm -w "$R/link/abi_targets.c" -o at_clang.ll && for w in ours clang; do awk -f "$ROOT/test/abisig.awk" at_$w.ll | sort -u > at_$w.sig; grep '^@sizes' at_$w.ll | sed 's/^@sizes = [a-z_ ]*global //; s/, align [0-9]*$//' >> at_$w.sig; done && cmp -s at_ours.sig at_clang.sig && echo "$t $(wc -l < at_ours.sig | tr -d ' ')"; done | tr '\n' ' ')" "x86_64-linux-gnu 64 aarch64-linux-gnu 64 arm64-apple-macos 64 "
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
check "the compiler's decimal runtime answers as libgcc's, bit for bit" "$("$CICILI" -c -std=c23 -O1 "$ROOT/module/bidrt.c" -o bidrt.o && gcc -std=gnu2x -O1 -w "$R/link/decrt.c" bidrt.o -o decrt && ./decrt 3000 | tail -1)" "0 of 549760 differ, 110 routines"   # 0.243: module/bidrt.c as cicilang compiles it, every routine the lowering calls, against libgcc's of the same name (test/c/link/decrt.c)
else echo "skip  decimal values across the ABI: no gcc with decimal floating types"; echo "skip  a long double constant to a decimal type: no gcc with decimal floating types"; echo "skip  the decimal runtime against libgcc's: no gcc with decimal floating types"; fi
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
printf 'int n = 1;\n_Static_assert(n == 1, "constant");\nint main(void) { return 0; }\n' > sanf.c
sanfout=$("$CICILI" sanf.c -o sanf 2>&1 >/dev/null); sanfcode=$?
check "a static assertion whose condition does not fold is an error, in clang's words (0.257)" "$(echo "$sanfout" | head -1; echo "exit $sanfcode")" "sanf.c:2: error: static assertion expression is not an integral constant expression
exit 1"   # it passed unasked: a condition that does not fold was no failure
ctout=$("$CICILI" -fsyntax-only "$R/ctext_bad.c" 2>&1); ctcode=$?
check "a C text that does not read: the macro's call, the macro, its file, the text's own line (0.260)" "$(echo "$ctout" | sed "s|$R/||g"; echo "exit $ctcode")" "ctext_bad.c:2: error: in the expansion of macro 'bad_items': C text: the text does not read as file-scope items (its line 3)
ctext_bad.c:2: note: the macro is bad_items in ctext.pl, called on int(0)
cicilang: 1 error(s)
exit 1"
printf 'int twice_h(int x) { return 2 * x; }\n' > absh.h
printf '#include <stdio.h>\n#include "%s/absh.h"\nint main(void) { printf("%%d\\n", twice_h(21)); return 0; }\n' "$(pwd)" > absinc.c
check "an #include of an absolute path finds the file, as clang does (0.260)" "$("$CICILI" absinc.c -o absinc 2>&1 && ./absinc)" "42"   # the path was joined to the includer's directory: the header was never read, and the build failed later at undeclared(twice_h)
check "two units that both make vector<int> link: its functions linkonce_odr, one kept (0.261)" "$("$CICILI" "$R/link/inst_a.c" "$R/link/inst_b.c" -o inst 2>&1 && ./inst)" "5 7 6"   # each unit defines vector_int_push, _at and _len; plain definitions would be duplicate symbols at the link
check "two units over <vector.pl> link, each with the functions of vector<int> that it calls, one kept of what both made (0.274)" "$("$CICILI" "$R/link/vec_a.c" "$R/link/vec_b.c" -o vecab 2>&1 && ./vecab)" "6 9 7 6"
lpout=$("$CICILI" "$R/lit_noplace.c" -o litnp 2>&1); lpcode=$?
check "a list literal where no place gives it a type, a conditional's branch, is refused by name (0.263)" "$(echo "$lpout" | sed "s|$R/||g"; echo "exit $lpcode")" "lit_noplace.c:8: error: not lowered yet: list_literal_with_no_type_given (function main)
lit_noplace.c:8: note: expanded from macro 'vector' on base([],[int])
cicilang: 1 error(s)
exit 1"
upout=$("$CICILI" "$R/unread_place.c" -o unrp 2>&1); upcode=$?
check "an argument taken unread that does not read where the macro's text puts it is refused at the call, the note naming the argument by its text (0.264)" "$(echo "$upout" | sed "s|$R/||g"; echo "exit $upcode")" "unread_place.c:3: error: in the expansion of macro 'plus_one': C text: an argument taken unread does not read where the text puts it, in an expression
unread_place.c:3: note: the macro is plus_one in unread_bad.pl, called on unread('int z')
cicilang: 1 error(s)
exit 1"
bpout=$("$CICILI" "$R/safe/borrow_after_push.c" -o bap 2>&1); bpcode=$?
check "a borrow of a vector's buffer used after a push, which may realloc it, is refused at its line, in words of its own (0.265)" "$(echo "$bpout" | sed "s|$R/safe/||g"; echo "exit $bpcode")" "borrow_after_push.c:10: error: use of a borrow after a call that may replace its owner: 'p' in borrowed_from('v.data') (function main)
cicilang: 1 error(s)
exit 1"
opout=$("$CICILI" "$R/op_undefined.c" -o opu 2>&1); opcode=$?
check "an operator that the instance's type macro does not define is refused at its line, the function it would call named (0.266)" "$(echo "$opout" | sed "s|$R/||g"; echo "exit $opcode")" "op_undefined.c:5: error: macro: the operator * of pt_double is not defined: its type macro defines no pt_double_mul
cicilang: 1 error(s)
exit 1"
iaout=$("$CICILI" "$R/safe/index_after_insert.c" -o iai 2>&1); iacode=$?
check "a place that a dictionary's [] answers, kept and read after an insertion that may realloc the buffer, is refused at its line (0.266)" "$(echo "$iaout" | sed "s|$R/safe/||g"; echo "exit $iacode")" "index_after_insert.c:13: error: use of a borrow after a call that may replace its owner: 'p' in borrowed_from('m.vals') (function main)
cicilang: 1 error(s)
exit 1"
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
# MACH-O KEEPS THE DWARF IN THE OBJECTS (0.224): a Mac's link writes a debug map that names them, for a debugger and for
# dsymutil to gather the DWARF from; since 0.245 cicilang keeps them where the map names them (~/.cicilang/objects), so on
# a Mac a check of a program's DWARF reads the object its debug map names (`nm -pa': its OSO entry); ELF's link carries it
dw() {   # dw PROGRAM SOURCE FLAGS...: the file whose DWARF a -g check of PROGRAM reads
  _dw_p=$1
  case $(uname -s) in Darwin) nm -pa "$_dw_p" | awk '/ OSO /{print $NF; exit}' ;; *) echo "$_dw_p" ;; esac
}
case $(uname -s) in
  Darwin) check "-g on a Mac: the link's debug map names the object it read, kept for the debugger (0.245)" "$("$CICILI" -g "$R/run/forty2.c" -o dbgmap > /dev/null 2>&1 && o=$(dw dbgmap) && [ -f "$o" ] && "$DD" --debug-line "$o" | grep -q forty2.c && echo kept)" "kept" ;;
  *) echo "skip  -g on a Mac: the debug map's objects (ELF's link carries the DWARF over)" ;;
esac
check "-g: line tables, a line per statement, the file named" "$(printf '#include <stdio.h>\n\nstatic int twice(int x) {\n  int y = x * 2;\n  return y;\n}\n\nint main(void) {\n  int a = twice(21);\n  printf("%%d\\n", a);\n  return 0;\n}\n' > dbg.c; "$CICILI" -g dbg.c -o dbg && ./dbg && f=$(dw dbg dbg.c -g) && "$DD" --debug-line "$f" | grep -c 'name: "dbg.c"' && "$DD" --debug-line "$f" | awk '/^0x/ { print $2 }' | sort -n -u | tr '\n' ' ')" "42
1
3 4 5 8 9 10 11 "
# ON APPLE SILICON THE COLUMNS ARE READ FROM x86-64 OBJECTS (0.247): arm64's instruction selection joins an `if''s compare to
# its branch, at the branch's column, which clang 18 and Apple's clang 17 put at the condition's first token and clang 21 and 22
# at its operator, as this compiler does (0.225) -- a line table there shows clang's version, not the columns; x86-64 keeps the
# compare a row of its own, as on the other machines
case $(uname -s)/$(uname -m) in Darwin/arm64) DT=--target=x86_64-apple-macos ;; *) DT= ;; esac
check "-g: each expression's column is one clang's line table has for it (a name, an operator, a call, a condition, a loop, a return)" "$(printf '#include <stdio.h>\nstatic int twice(int x) {\n  int y = x * 2;\n  return y;\n}\nint main(int argc, char **argv) {\n  int s = 0;\n  for (int i = 0; i < argc; i++) s += twice(i);\n  if (s > 3) printf("big %%d\\n", s); else printf("small %%d\\n", s);\n  return 0;\n}\n' > dbgc.c; "$CICILI" $DT -g -c dbgc.c -o dbgc.o && clang $DT -g -O0 -c dbgc.c -o dbgc_ref.o &&"$DD" --debug-line dbgc.o | awk '/^0x/ && $3 > 0 { print $2 ":" $3 }' | LC_ALL=C sort -u > dbgc.ours && "$DD" --debug-line dbgc_ref.o | awk '/^0x/ { print $2 ":" $3 }' | LC_ALL=C sort -u > dbgc.ref && echo "$(LC_ALL=C comm -23 dbgc.ours dbgc.ref | wc -l | tr -d ' ') $(wc -l < dbgc.ours | tr -d ' ')")" "0 20"   # 0.161: none outside clang's, ten of them, a statement's column each; every location was column 1. 0.242: twenty, an expression's own column each
check "-g: the variables and their types, as DWARF describes them" "$(printf 'enum color { RED, GREEN = 5 };\nstruct point { int x; double y; };\nint g = 3;\nint main(void) {\n  struct point p = {1, 2.5};\n  enum color c = GREEN;\n  return p.x + c - 6 + g - 3;\n}\n' > dbgv.c; "$CICILI" -g dbgv.c -o dbgv && ./dbgv && "$DD" --debug-info "$(dw dbgv dbgv.c -g)" | awk '/DW_AT_name/ { gsub(/[()"]/, "", $2); print $2 }' | LC_ALL=C sort -u | tr '\n' ' ')" "GREEN RED c color dbgv.c double g int main p point x y "
check "-gline-tables-only: the lines and no variable" "$("$CICILI" -gline-tables-only dbgv.c -o dbgl && ./dbgl && "$DD" --debug-info "$(dw dbgl dbgv.c -gline-tables-only)" | grep -c 'DW_TAG_variable')" "0"
# -fdebug-macro's macros are DWARF 5's .debug_macro, and on a Mac DWARF 4's .debug_macinfo (0.225): LLVM's DWARF 5 macros
# crash on Mach-O, clang 21's for macOS 15 and later too
case $(uname -s) in Darwin) MK=MACINFO; MD=define; MU=undef ;; *) MK=MACRO; MD=define_strx; MU=undef_strx ;; esac
check "-g -fdebug-macro: each file's macros at their lines, as clang has them" "$(printf '#define TWICE(x) ((x) * 2)\n#define LIMIT 10\n' > dm.h; printf '#include "dm.h"\n#define FOO 42\n#undef LIMIT\n#define LIMIT 20\nint g = FOO + LIMIT;\nint main(void) { return TWICE(g) - 124; }\n' > dm.c; "$CICILI" -g -fdebug-macro -c dm.c -o dm.o && "$DD" --debug-macro dm.o | awk '/lineno: 0 / { z++ } /lineno: [1-9]|end_file/ { sub(/ filenum: [0-9]+/, ""); gsub(/^ +/, ""); printf "%s|", $0 } END { print (z > 300 ? "predefined" : "few") }')" "DW_${MK}_start_file - lineno: 1|DW_${MK}_${MD} - lineno: 1 macro: TWICE(x) ((x) * 2)|DW_${MK}_${MD} - lineno: 2 macro: LIMIT 10|DW_${MK}_end_file|DW_${MK}_${MD} - lineno: 2 macro: FOO 42|DW_${MK}_${MU} - lineno: 3 macro: LIMIT|DW_${MK}_${MD} - lineno: 4 macro: LIMIT 20|DW_${MK}_end_file|predefined"
check "-g: a function and an object a header defines are described in the header (0.213)" "$(printf 'static int hd_n = 41;\nstatic inline int hd(int x) {\n  return x + 1;\n}\n' > dbgh.h; printf '#include %s\nint main(void) {\n  return hd(hd_n) - 42;\n}\n' '"dbgh.h"' > dbgh.c; "$CICILI" -g dbgh.c -o dbgh && ./dbgh && "$DD" --debug-info "$(dw dbgh dbgh.c -g)" | grep -A3 'DW_AT_name.*"hd' | grep -c 'decl_file.*dbgh.h')" "2"
check "-g: a static local in a nested block -- an if, a loop, a switch, two blocks of one name, an array -- is its function's variable, as clang's (0.294): LLVM's DWARF writer died of SIGSEGV on one in a block's scope" "$(printf '#include <stdio.h>\nstatic int f(int n) {\n  static int top = 1;\n  if (n > 0) {\n    static int count = 0;\n    count += n;\n    top += count;\n  }\n  for (int i = 0; i < 2; i++) {\n    static int loops;\n    loops++;\n    top += loops;\n  }\n  switch (n) {\n  case 1: { static int once = 5; top += once; break; }\n  default: break;\n  }\n  { static int same = 1; top += same; }\n  { static int same = 2; top += same; }\n  { static char tab[4] = "abc"; top += tab[1]; }\n  return top;\n}\nint main(void) { printf("%%d\\n", f(1)); return 0; }\n' > dbgsl.c; "$CICILI" -g dbgsl.c -o dbgsl && ./dbgsl && "$DD" --debug-info "$(dw dbgsl dbgsl.c -g)" | awk '/DW_TAG_variable/ { v = 1; next } v && /DW_AT_name/ { n = $2 } v && /DW_AT_location.*DW_OP_addr/ { gsub(/[()"]/, "", n); printf "%s ", n; v = 0 } /DW_TAG_/ && !/DW_TAG_variable/ { v = 0 }')" "111
top count loops once same same tab "
check "-g: ... and in C++ (0.294)" "$(printf '#include <stdio.h>\nstatic int f(int n) {\n  static int top = 1;\n  if (n > 0) {\n    static int count = 0;\n    count += n;\n    top += count;\n  }\n  for (int i = 0; i < 2; i++) {\n    static int loops;\n    loops++;\n    top += loops;\n  }\n  switch (n) {\n  case 1: { static int once = 5; top += once; break; }\n  default: break;\n  }\n  { static int same = 1; top += same; }\n  { static int same = 2; top += same; }\n  { static char tab[4] = "abc"; top += tab[1]; }\n  return top;\n}\nint main(void) { printf("%%d\\n", f(1)); return 0; }\n' > dbgslpp.cpp; "$ROOT/bin/cicilang++" -g -c dbgslpp.cpp -o dbgslpp.o && "$DD" --debug-info dbgslpp.o | awk '/DW_TAG_variable/ { v = 1; next } v && /DW_AT_name/ { n = $2 } v && /DW_AT_location.*DW_OP_addr/ { gsub(/[()"]/, "", n); printf "%s ", n; v = 0 } /DW_TAG_/ && !/DW_TAG_variable/ { v = 0 }')" "top count loops once same same tab "
check "the last -std wins, its level and its mode, as clang: -std=c17 -std=gnu17 builds GNU's, -std=gnu17 -std=c17 ISO's, each its own IR in the store (0.214)" "$(printf '#ifdef __STRICT_ANSI__\nint main(void) { return 3; }\n#elif defined(__APPLE__)\nint main(void) { return 2; }\n#else\nint main(void) { return linux + unix; }\n#endif\n' > lastd.c; { "$CICILI" -std=c17 -std=gnu17 lastd.c -o lastd1 && ./lastd1; echo "$?"; "$CICILI" -std=gnu17 -std=c17 lastd.c -o lastd2 && ./lastd2; echo "$?"; } | tr '\n' ' ')" "2 3 "   # a Mac's GNU mode predefines neither linux nor unix, as clang's Darwin (0.224)
check "-g: a C++ static data member is declared in its class" "$(printf 'struct S {\n  static int count;\n  int v;\n};\nint S::count = 7;\nint main() {\n  S s{2};\n  return s.v + S::count - 9;\n}\n' > dbgs.cpp; "$ROOT/bin/cicilang++" -g -c dbgs.cpp -o dbgs.o && "$DD" --debug-info dbgs.o | awk '/DW_TAG_structure_type/ { s = index($0, "DW_TAG_"); next } /DW_TAG_/ { i = index($0, "DW_TAG_"); if (s && i <= s) s = 0; if (s && /DW_TAG_variable/) v++ } /DW_AT_specification/ { sp++ } END { print v + 0, sp + 0 }')" "1 1"
check "-g: a destructor at its scope's closing brace, as clang's" "$(printf 'struct T {\n  int v;\n  ~T() { v = 0; }\n};\nint f(int k) {\n  T a{1};\n  if (k) {\n    T b{2};\n    return 5;\n  }\n  return 0;\n}\nint main() { return f(0) + f(1) - 5; }\n' > dbgd.cpp; "$ROOT/bin/cicilang++" -g -c dbgd.cpp -o dbgd.o && "$DD" --debug-line dbgd.o | awk '$1 ~ /^0x/ { if ($2 == 10) t = 1; if ($2 == 12) w = 1 } END { print (t ? "10" : "-"), (w ? "12" : "-") }')" "10 12"
check "an unknown argument is an error, as clang says it" "$("$CICILI" --frobnicate x.c 2>&1)" "cicilang: error: unknown argument: '--frobnicate'"
check "no input files is an error" "$("$CICILI" -c 2>&1)" "cicilang: error: no input files"
check "the tie: a broken tie is refused in clang's shape" "$("$CICILI" -fsyntax-only "$R/safe/tie_arg.c" 2>&1 | head -1 | sed "s|$R/||")" "safe/tie_arg.c:4: error: value not within its tie: 'b' in call(id(gap),[id(a),id(b)]) (function main)"
check "a slot with no owner behind it is refused, in clang's shape" "$(printf '#include <stdlib.h>\nstruct s { char *q; } g;\nint main(void) { char *p = malloc(8); g.q = malloc(8); free(p); return 0; }\n' > untied.c; "$CICILI" -fsyntax-only untied.c 2>&1 | head -1)" "untied.c:3: error: no owner behind: 'g.q' in assign(=,member(id(g),q),call(id(malloc),[int(8)])) (function main)"
check "a plain pointer never consumed is refused; one freed is not" "$(printf '#include <stdlib.h>\nint main(void) { char *p = malloc(8); char *r = malloc(8); free(p); return 0; }\n' > loose.c; "$CICILI" -fsyntax-only loose.c 2>&1 | head -1)" "loose.c:2: error: plain pointer not consumed: 'r' in return(int(0)) (function main)"
check "a record where another type is needed is refused by name at its line (0.286): an assignment, an initializer, an argument and a result of another struct's type, a number where a struct is needed and a struct where a number is; a unary - and ~ over a struct, in clang's words; a struct with no tag is named so (0.288)" "$(n=0; for body in 'static void f(struct A a, struct B b) { a = b; (void)a; }' 'static void f(struct B b) { struct A a = b; (void)a; }' 'static long f(struct B b) { return use(b); }' 'static struct A f(struct B b) { return b; }' 'static long f(void) { return use(5); }' 'static long f(struct A a) { long k = a; return k; }' 'static struct A f(struct A a) { return -a; }' 'static struct A f(struct A a) { return ~a; }' 'typedef struct { long w[1]; } U; static long f(U u) { return use(u); }'; do n=$((n + 1)); printf 'struct A { long w[1]; };\nstruct B { long w[1]; };\nstatic long use(struct A a) { return a.w[0]; }\n%s\nint main(void) { return 0; }\n' "$body" > conv$n.c; "$CICILI" -fsyntax-only conv$n.c 2>&1 | head -1; done)" "conv1.c:4: error: no conversion from 'struct B' to 'struct A'
conv2.c:4: error: no conversion from 'struct B' to 'struct A'
conv3.c:4: error: no conversion from 'struct B' to 'struct A'
conv4.c:4: error: no conversion from 'struct B' to 'struct A'
conv5.c:4: error: no conversion from 'int' to 'struct A'
conv6.c:4: error: no conversion from 'struct A' to 'long'
conv7.c:4: error: invalid argument type 'struct A' to unary expression
conv8.c:4: error: invalid argument type 'struct A' to unary expression
conv9.c:4: error: no conversion from 'struct <unnamed>' to 'struct A'"
check "... and in C++, where a class is named by its own name (0.286)" "$(printf 'struct A { long w[1]; };\nstruct B { long w[1]; };\nint main() {\n  A a = {{1}};\n  B b = {{2}};\n  a = b;\n  return 0;\n}\n' > convpp.cpp; "$ROOT/bin/cicilang++" -c convpp.cpp -o convpp.o 2>&1 | head -1)" "convpp.cpp:6: error: no conversion from 'B' to 'A'"
check "a pointer where a struct is needed is refused by name at its line (0.291): a text and a struct's address handed to a struct parameter, and a pointer given back as a struct, where each went to LLVM's parser" "$(n=0; for body in 'static long f(void) { return use("abc"); }' 'static long f(struct A a) { return use(&a); }' 'static struct A f(const char *p) { return p; }'; do n=$((n + 1)); printf 'struct A { long w[1]; };\nstatic long use(struct A a) { return a.w[0]; }\n%s\nint main(void) { return 0; }\n' "$body" > ptrrec$n.c; "$CICILI" -fsyntax-only ptrrec$n.c 2>&1 | head -1; done)" "ptrrec1.c:3: error: no conversion from 'char *' to 'struct A'
ptrrec2.c:3: error: no conversion from 'struct A *' to 'struct A'
ptrrec3.c:3: error: no conversion from 'const char *' to 'struct A'"
check "a floating value where a pointer is needed, and a pointer where a floating value is, are refused by name at the line (0.288): an argument each way and a cast each way" "$(n=0; for body in 'static void f(double d) { usep(d); }' 'static void f(char *q) { used(q); }' 'static double f(char *q) { return (double)q; }' 'static void f(double d) { usep((char *)d); }'; do n=$((n + 1)); printf 'static void usep(const char *p) { (void)p; }\nstatic void used(double d) { (void)d; }\n%s\nint main(void) { return 0; }\n' "$body" > fpp$n.c; "$CICILI" -fsyntax-only fpp$n.c 2>&1 | head -1; done)" "fpp1.c:3: error: no conversion from 'double' to 'const char *'
fpp2.c:3: error: no conversion from 'char *' to 'double'
fpp3.c:3: error: no conversion from 'char *' to 'double'
fpp4.c:3: error: no conversion from 'double' to 'char *'"
# THE AMBITIOUS PROGRAM'S FINDINGS 33 AND 34 (0.302): an initializer that gives more than its object holds, a call of another count
# of arguments than its prototype's, an integer and a pointer converted as if by assignment -- each refused in clang's words at its
# line; and the command's verdict, which an error that cocolog reports past the inputs took for a success
check "an initializer that gives more than its object holds is refused in clang's words at its line (0.302): an element past an array's bound, here and at file scope (finding 33: the count went below zero and the stack was gone), a designator past the bound and below zero, a member past a struct's last, a union's second, a scalar's second value, a literal longer than its array, here and at file scope" "$(n=0; for body in 'int main(void) { int a[2] = {1, 2, 3}; return a[1]; }' 'static const struct { const char *n; int v; } defs[2] = { {"a", 0}, {"b", 1}, {"c", 0} }; int main(void) { return defs[1].v; }' 'int main(void) { int a[2] = {[5] = 1}; return a[0]; }' 'static int g[2] = {[-1] = 1}; int main(void) { return g[0]; }' 'struct p { int a; }; int main(void) { struct p s = {1, 2}; return s.a; }' 'union u { int a; float b; }; static union u g = {1, 2}; int main(void) { return g.a; }' 'int main(void) { int x = {1, 2}; return x; }' 'int main(void) { char s[2] = "abc"; return s[0]; }' 'static char g[2] = "abc"; int main(void) { return g[0]; }'; do n=$((n + 1)); printf '%s\n' "$body" > init$n.c; "$CICILI" -fsyntax-only init$n.c 2>&1 | head -1; done)" "init1.c:1: error: excess elements in array initializer
init2.c:1: error: excess elements in array initializer
init3.c:1: error: array designator index (5) exceeds array bounds (2)
init4.c:1: error: array designator value '-1' is negative
init5.c:1: error: excess elements in struct initializer
init6.c:1: error: excess elements in union initializer
init7.c:1: error: excess elements in scalar initializer
init8.c:1: error: initializer-string for char array is too long
init9.c:1: error: initializer-string for char array is too long"
check "... and in C++, where a literal's terminator counts (0.302)" "$(n=0; for body in 'int main() { char s[3] = "abc"; return s[0]; }' 'int main() { int a[2] = {1, 2, 3}; return a[0]; }'; do n=$((n + 1)); printf '%s\n' "$body" > initpp$n.cpp; "$ROOT/bin/cicilang++" -c initpp$n.cpp -o initpp$n.o 2>&1 | head -1; done)" "initpp1.cpp:1: error: initializer-string for char array is too long, array size is 3 but initializer has size 4 (including the null terminating character)
initpp2.cpp:1: error: excess elements in array initializer"
# A TABLE LONGER THAN ITS BOUND (0.310; the Ambitious program's finding over its CSS table, the kin of finding 33): its rows put in
# place by an #include inside the table, under an X-macro's #define there; its bound an earlier declaration's, which an array
# of no bound takes (C17 6.2.7/3); and a global's refusal after a function's definition, which named the function's line --
# each refused at the table's line, in clang's words
printf 'R("a", 0)\nR("b", 1)\nR("c", 2)\n' > tabrows.def
check "a table longer than its bound is refused at its line: its rows an #include's, its bound an earlier declaration's, after a function's definition (0.310)" "$(n=0; for body in '#define R(n, i) {n, i},\nstatic const struct { const char *n; int v; } t[2] = {\n#include "tabrows.def"\n};\nint main(void) { return t[1].v; }' 'extern int t[2];\nint t[] = {1, 2, 3};\nint main(void) { return t[1]; }' 'static int f(void) { return 1; }\nstatic int t[1] = {1, 2};\nint main(void) { return t[0] + f(); }'; do n=$((n + 1)); printf '%b\n' "$body" > tab$n.c; "$CICILI" -fsyntax-only tab$n.c 2>&1 | head -1; done)" "tab1.c:2: error: excess elements in array initializer
tab2.c:2: error: excess elements in array initializer
tab3.c:2: error: excess elements in array initializer"
check "a call of another count of arguments than its prototype's is refused in clang's words at its line (0.302): too many, too few (finding 34), an ellipsis's named parameters, a parameter named, through a pointer, (void), a K&R definition's own words, a prototype kept by a later () declaration" "$(n=0; for body in 'static int f(int a, int b) { return a + b; } int main(void) { return f(1, 2, 3); }' 'int pick(const char *family, int bold, int italic); int main(void) { return pick("serif", 1); }' 'int printf(const char *fmt, ...); int main(void) { return printf(); }' 'static int one(int n) { return n; } int main(void) { return one(); }' 'static int one(int n) { return n; } int main(void) { return one(1, 2); }' 'static int g(int a, int b) { return a + b; } int main(void) { int (*p)(int, int) = g; return p(1); }' 'static int v(void) { return 0; } int main(void) { return v(1); }' 'int add(a, b) int a; int b; { return a + b; } int main(void) { return add(1); }' 'int f(int a, int b); int f(); int main(void) { return f(1); }' 'static int s(int a, int b, ...) { return a + b; } int main(void) { return s(1); }'; do n=$((n + 1)); printf '%s\n' "$body" > callc$n.c; "$CICILI" -std=c17 -fsyntax-only callc$n.c 2>&1 | head -1; done)" "callc1.c:1: error: too many arguments to function call, expected 2, have 3
callc2.c:1: error: too few arguments to function call, expected 3, have 2
callc3.c:1: error: too few arguments to function call, at least argument 'fmt' must be specified
callc4.c:1: error: too few arguments to function call, single argument 'n' was not specified
callc5.c:1: error: too many arguments to function call, expected single argument 'n', have 2 arguments
callc6.c:1: error: too few arguments to function call, expected 2, have 1
callc7.c:1: error: too many arguments to function call, expected 0, have 1
callc8.c:1: error: too few arguments in call to 'add'
callc9.c:1: error: too few arguments to function call, expected 2, have 1
callc10.c:1: error: too few arguments to function call, expected at least 2, have 1"
check "an integer and a pointer converted as if by assignment are refused in clang's words at the line (0.302): an argument each way, an initializer, an assignment, a result each way, an enum parameter" "$(n=0; for body in 'static int f(int a) { return a; } int main(void) { char *p = "x"; return f(p); }' 'static int g(char *p) { return p == 0; } int main(void) { return g(5); }' 'int main(void) { const char *p = "x"; int x = p; return x == 0; }' 'int main(void) { char *p = "x"; long x; x = p; return x == 0; }' 'static int r(char *p) { return p; } int main(void) { return r("x") == 0; }' 'static char *r(void) { return 5; } int main(void) { return r() == 0; }' 'enum e { A }; static int h(enum e v) { return v; } int main(void) { char *p = "x"; return h(p); }'; do n=$((n + 1)); printf '%s\n' "$body" > intptr$n.c; "$CICILI" -fsyntax-only intptr$n.c 2>&1 | head -1; done)" "intptr1.c:1: error: incompatible pointer to integer conversion passing 'char *' to parameter of type 'int'
intptr2.c:1: error: incompatible integer to pointer conversion passing 'int' to parameter of type 'char *'
intptr3.c:1: error: incompatible pointer to integer conversion initializing 'int' with an expression of type 'const char *'
intptr4.c:1: error: incompatible pointer to integer conversion assigning to 'long' from 'char *'
intptr5.c:1: error: incompatible pointer to integer conversion returning 'char *' from a function with result type 'int'
intptr6.c:1: error: incompatible integer to pointer conversion returning 'int' from a function with result type 'char *'
intptr7.c:1: error: incompatible pointer to integer conversion passing 'char *' to parameter of type 'enum e'"
check "... and in C++, a call that no overload fits by its count or by an integer and a pointer, in clang++'s words, another misfit in the words of the road after the overloads, and a call through a pointer of another count (0.302)" "$(n=0; for body in 'static int f(int a, int b) { return a + b; } int main() { return f(1, 2, 3); }' 'static int g(char *p) { return p == 0; } int main() { return g(5); }' 'static int f(int a, int b = 2) { return a * b; } int main() { return f(); }' 'static int f(int a, int b) { return a + b; } int main() { int (*g)(int, int) = f; return g(1); }' 'struct S { int (*op)(int); }; static int one(int a) { return a; } int main() { S s = {one}; return s.op(1, 2); }' 'static int f(int a, int b) { return a + b; } static int f(char *p) { return p != 0; } int main() { return f(5); }' 'static long f(long v) { return v; } int main() { int x = 3; return (int)f(&x); }' 'struct S { int a; }; static int f(int v) { return v; } int main() { S s = {1}; return f(s); }'; do n=$((n + 1)); printf '%s\n' "$body" > callpp$n.cpp; "$ROOT/bin/cicilang++" -c callpp$n.cpp -o callpp$n.o 2>&1 | head -1; done)" "callpp1.cpp:1: error: no matching function for call to 'f'
callpp2.cpp:1: error: no matching function for call to 'g'
callpp3.cpp:1: error: no matching function for call to 'f'
callpp4.cpp:1: error: too few arguments to function call, expected 2, have 1
callpp5.cpp:1: error: too many arguments to function call, expected 1, have 2
callpp6.cpp:1: error: no matching function for call to 'f'
callpp7.cpp:1: error: no matching function for call to 'f'
callpp8.cpp:1: error: no conversion from 'S' to 'int'"
check "the verdict is the driver's own line (0.302): an error that cocolog reports past the inputs fails the build, where the verdict's text in cocolog's trace of the goals left to run made it end with exit 0, no output file and no word" "$(mkdir -p fakecoco && printf '#!/bin/sh\necho "ERROR: ?-: a report raised an error"\necho "ERROR:   then _G236=:=0->write('"'"'cicilang: ok'"'"');write('"'"'cicilang: '"'"'),write(_G236),write('"'"' error(s)'"'"')"\necho "false."\n' > fakecoco/cocolog && chmod +x fakecoco/cocolog && printf 'int main(void) { return 0; }\n' > fakeok.c && COCOLOG="$PWD/fakecoco" "$CICILI" --no-kb fakeok.c -o fakeok > /dev/null 2>&1; echo "exit $?")" "exit 1"
# A NAME USED BEFORE ANY DECLARATION OF IT (1.1.2; the Ambitious program's finding 43): a call of a function that the file
# defines further down was lowered by the later definition's type, where clang refuses it, and so were a name used as a value
# before its declaration and an enumerator before its enum; a name that nothing declares was refused in the words of a form
# not done -- each refused in clang's words at the line of its use, at C17 and at C23, and a unit so refused is not kept
printf 'static inline int from_hdr(int x) { return x * 3; }\n' > undeclhdr.h
check "a name used before any declaration of it is refused in clang's words at the line of its use (1.1.2, finding 43): a call of a function defined further down, static and not, of a K&R definition, in sizeof, a statement expression, a list and a conditional, over a tag of its name; a function's name, an object's address and an enumerator used as values, through parentheses, in typeof and in a body; the first of two; a call after another function's own declaration; a call before the #include of its header; a call after an instance's C text was read; a later block's enumerator; a parameter's bound before the parameter" "$(n=0; for body in 'int g0;\nstatic int f(void) { return later(2, 3); }\nstatic int later(int a, int b) { return a + b; }\nint main(void) { return f(); }' 'int g0;\nint f(void) { return later(2); }\nint later(int a) { return a; }\nint main(void) { return f(); }' 'int g0;\nint f(void) { return knr(1, 2); }\nint knr(a, b) int a; int b; { return a + b; }\nint main(void) { return f(); }' 'int g0;\nunsigned long f(void) { return sizeof(later(1)); }\nint later(int a) { return a; }\nint main(void) { return (int)f(); }' 'int g0;\nint f(void) { return ({ int t = later(2); t; }); }\nint later(int a) { return a; }\nint main(void) { return f(); }' 'int g0;\nint f(void) { int a[2] = { 1, later(2) }; return a[1]; }\nint later(int a) { return a; }\nint main(void) { return f(); }' 'int g0;\nint f(int c) { return c ? later(1) : 0; }\nint later(int a) { return a; }\nint main(void) { return f(1); }' 'struct later { int a; };\nstatic int f(void) { return later(1); }\nstatic int later(int a) { return a; }\nint main(void) { return f(); }' 'int g0;\nstatic int (*fp)(int) = later;\nstatic int later(int a) { return a + 1; }\nint main(void) { return fp(1); }' 'int g0;\nstatic int *p = &later_var;\nstatic int later_var = 4;\nint main(void) { return *p; }' 'int g0;\nstatic int f(void) { return B; }\nenum { A = 1, B = 2 };\nint main(void) { return f(); }' 'int g0;\nstatic int f(void) { return (later)(1); }\nstatic int later(int a) { return a; }\nint main(void) { return f(); }' 'int g0;\nstatic void f(void) { __typeof__(later) *q = 0; (void)q; }\nstatic int later(int a) { return a; }\nint main(void) { f(); return 0; }' 'int (*fp)(int);\nstatic void set(void) { fp = later; }\nstatic int later(int a) { return a + 7; }\nint main(void) { set(); return fp(1); }' 'int g0;\nstatic int f(void) { return second(1); }\nstatic int g(void) { return first_v; }\nstatic int second(int a) { return a; }\nstatic int first_v = 2;\nint main(void) { return f() + g(); }' 'static int f(void) { extern int g(int); return g(1); }\nstatic int h(void) { return g(2); }\nint g(int a) { return a * 10; }\nint main(void) { return f() + h(); }' 'int g0;\nstatic int f(void) { return from_hdr(2); }\n#include "undeclhdr.h"\nint main(void) { return f(); }' '#include <vector.pl>\nstatic int f(void) { vector<int> v = [1]; return (int)size(v) + later(1); }\nstatic int later(int a) { return a; }\nint main(void) { return f(); }' 'int g0;\nstatic int f(void) { return B; }\nstatic int g(void) { enum { A = 1, B = 2 }; return A; }\nint main(void) { return f() + g(); }' 'int g0;\nstatic int lead(int a[out], int out) { return a[0] + out; }\nint out = 13;\nint main(void) { int b[1] = { 1 }; return lead(b, 1); }'; do n=$((n + 1)); printf '%b\n' "$body" > undecl$n.c; "$CICILI" -std=c17 -fsyntax-only undecl$n.c 2>&1 | head -1; done)" "undecl1.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undecl2.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undecl3.c:2: error: call to undeclared function 'knr'; ISO C99 and later do not support implicit function declarations
undecl4.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undecl5.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undecl6.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undecl7.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undecl8.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undecl9.c:2: error: use of undeclared identifier 'later'
undecl10.c:2: error: use of undeclared identifier 'later_var'
undecl11.c:2: error: use of undeclared identifier 'B'
undecl12.c:2: error: use of undeclared identifier 'later'
undecl13.c:2: error: use of undeclared identifier 'later'
undecl14.c:2: error: use of undeclared identifier 'later'
undecl15.c:2: error: call to undeclared function 'second'; ISO C99 and later do not support implicit function declarations
undecl16.c:2: error: call to undeclared function 'g'; ISO C99 and later do not support implicit function declarations
undecl17.c:2: error: call to undeclared function 'from_hdr'; ISO C99 and later do not support implicit function declarations
undecl18.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undecl19.c:2: error: use of undeclared identifier 'B'
undecl20.c:2: error: use of undeclared identifier 'out'"
check "... and at C23, where a call's words are a use's (1.1.2)" "$(n=0; for body in 'int g0;\nstatic int f(void) { return later(2, 3); }\nstatic int later(int a, int b) { return a + b; }\nint main(void) { return f(); }' 'int g0;\nstatic int (*fp)(int) = later;\nstatic int later(int a) { return a + 1; }\nint main(void) { return fp(1); }'; do n=$((n + 1)); printf '%b\n' "$body" > undecl23_$n.c; "$CICILI" -std=c23 -fsyntax-only undecl23_$n.c 2>&1 | head -1; done)" "undecl23_1.c:2: error: use of undeclared identifier 'later'
undecl23_2.c:2: error: use of undeclared identifier 'later'"
check "a name that nothing declares is refused in clang's words at its line (1.1.2): a call, a value, an assignment's left side, printf with no <stdio.h>, a call at C23; an enumerator called keeps the words of a call of no function" "$(n=0; for body in 'int main(void) {\n  int x = 1;\n  return nowhere(x);\n}' 'int main(void) {\n  int x = 1;\n  return x + nothing;\n}' 'int main(void) {\n  nothing = 1;\n  return 0;\n}' 'int main(void) {\n  printf("x");\n  return 0;\n}' 'enum { B = 1 };\nint main(void) {\n  return B(1);\n}'; do n=$((n + 1)); printf '%b\n' "$body" > nodecl$n.c; "$CICILI" -std=c17 -fsyntax-only nodecl$n.c 2>&1 | head -1; done; printf '%b\n' 'int main(void) {\n  int x = 1;\n  return nowhere(x);\n}' > nodecl6.c; "$CICILI" -std=c23 -fsyntax-only nodecl6.c 2>&1 | head -1)" "nodecl1.c:3: error: call to undeclared function 'nowhere'; ISO C99 and later do not support implicit function declarations
nodecl2.c:3: error: use of undeclared identifier 'nothing'
nodecl3.c:2: error: use of undeclared identifier 'nothing'
nodecl4.c:2: error: call to undeclared function 'printf'; ISO C99 and later do not support implicit function declarations
nodecl5.c:3: error: not lowered yet: call(id('B')) (function main)
nodecl6.c:3: error: use of undeclared identifier 'nowhere'"
check "a unit so refused is not kept: a second build is refused again, and the file put right builds and runs (1.1.2)" "$(printf 'int g0;\nstatic int f(void) { return later(2); }\nstatic int later(int a) { return a; }\nint main(void) { return f(); }\n' > undeclkb.c; "$CICILI" -c undeclkb.c -o undeclkb.o 2>&1 | head -1; "$CICILI" -c undeclkb.c -o undeclkb.o 2>&1 | head -1; sleep 1; printf 'int g0;\nstatic int later(int a);\nstatic int f(void) { return later(2); }\nstatic int later(int a) { return a; }\nint main(void) { return f(); }\n' > undeclkb.c; "$CICILI" undeclkb.c -o undeclkb && ./undeclkb; echo "exit $?")" "undeclkb.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undeclkb.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
exit 2"
# THE AMBITIOUS PROGRAM'S FINDINGS (0.290): a macro file's header under a relative -I with the program in another directory; an
# output file whose directory is not there; a header that was not read to its end, and a file that an #include of the program
# does not find, named under the build's error
check "a macro file's NAME.pl.h is found under a relative -I when the program is in another directory (0.290)" "$(mkdir -p rinc rsrc && echo 'rel_unused(x).' > rinc/rel.pl && echo 'int abs(int);' > rinc/rel.pl.h && printf '#include <rel.pl>\nint main(void) { return abs(-7) - 7; }\n' > rsrc/main.c && "$CICILI" -I rinc rsrc/main.c -o relinc 2>&1 && ./relinc; echo "exit $?")" "exit 0"
check "an output file whose directory is not there is refused by its path, before the build, and the errors are counted (0.290)" "$("$CICILI" -c "$R/run/forty2.c" -o no/such/dir/forty2.o 2>&1; echo "exit $?")" "no/such/dir/forty2.o: error: unable to open the output file: no such directory 'no/such/dir'
cicilang: 1 error(s)
exit 1"
check "a header whose read stopped is named under the build's error, at its #include (0.290)" "$(printf 'int y_of_h;\nint x = ;\nint z_of_h;\n' > stop.h; printf '#include %s\nint main(void) { return z_of_h; }\n' '"stop.h"' > usestop.c; "$CICILI" -fsyntax-only usestop.c 2>&1 | head -2)" "usestop.c:2: error: use of undeclared identifier 'z_of_h'
usestop.c:1: note: the read of the header ./stop.h stopped at its line 2: what it declares after that line is not known"
check "a file that an #include of the program does not find is named under the build's error, and one in a group that is skipped is not (0.290)" "$(printf '#include %s\n#if 0\n#include %s\n#endif\n#include %s\nint main(void) { return nope_value(); }\n' '"nope.h"' '"skipped.h"' '<nope/sys.h>' > usenope.c; "$CICILI" -fsyntax-only usenope.c 2>&1; echo "exit $?"; printf '#include %s\nint main(void) { return 0; }\n' '"nope.h"' > passnope.c; "$CICILI" -fsyntax-only passnope.c 2>&1; echo "exit $?")" "usenope.c:6: error: call to undeclared function 'nope_value'; ISO C99 and later do not support implicit function declarations
usenope.c:1: note: 'nope.h' file not found: nothing that it declares is known
usenope.c:5: note: 'nope/sys.h' file not found: nothing that it declares is known
cicilang: 1 error(s)
exit 1
exit 0"
case $(uname -s) in Linux)   # glibc's headers: <limits.h> holds <sys/cdefs.h>, whose raw read threw; <getopt.h> two headers that were read in part
check "no header of the C library is named under an error that is not its own (0.290)" "$(printf '#include <stdio.h>\n#include <limits.h>\n#include <getopt.h>\n#include <netdb.h>\nint main(void) { return nope_value(); }\n' > nonote.c; "$CICILI" -fsyntax-only nonote.c 2>&1; echo "exit $?")" "nonote.c:5: error: call to undeclared function 'nope_value'; ISO C99 and later do not support implicit function declarations
cicilang: 1 error(s)
exit 1" ;;
esac
case $(uname -m) in arm64|aarch64) AJ=b ;; *) AJ=jmp ;; esac   # the machine's jump (0.247: an Apple silicon Mac has no `jmp')
check "GNU's asm goto is lowered, a callbr (0.231), and an asm output that carries a pointer is refused by name (0.215)" "$(printf 'int main(void) {\n  asm goto("'"$AJ"' %%l0" :::: out);\n  return 1;\nout:\n  return 0;\n}\n' > asmgoto.c; "$CICILI" -c asmgoto.c > asmgoto.out 2>&1; echo "asm goto: exit $?"; head -1 asmgoto.out; printf 'int main(void) {\n  int x = 0, *p = &x;\n  asm("" : "=r"(p));\n  return *p;\n}\n' > asmptr.c; "$CICILI" -fsyntax-only asmptr.c 2>&1 | head -1)" "asm goto: exit 0
asmptr.c:3: error: not lowered yet: asm_pointer_output (function main)"
check "an asm goto whose jump would run a cleanup -- a defer, a C++ destructor -- is refused by name, as clang refuses it (0.231)" "$(printf 'int f(int k) {\n  {\n    defer(k) { (void)k; }\n    asm goto("" :::: out);\n  }\n  return 1;\nout:\n  return 0;\n}\nint main(void) { return f(1); }\n' > asmdefer.c; "$CICILI" -c asmdefer.c 2>&1 | head -1; printf 'struct N { int v; ~N(); };\nN::~N() {}\nint f(int x) {\n  { N n{x}; asm goto("" :::: out); }\n  return 1;\nout:\n  return 0;\n}\nint main() { return f(1); }\n' > asmdtor.cpp; "$ROOT/bin/cicilang++" -c asmdtor.cpp 2>&1 | head -1)" "asmdefer.c:4: error: not lowered yet: asm_goto_over_defer(out) (function f)
asmdtor.cpp:4: error: not lowered yet: asm_goto_over_defer(out) (function f)"
check "a syntax error names the file and the line" "$(printf 'int f(void) { return ; ; }\nint h( { }\n' > bad.c; "$CICILI" -c bad.c 2>&1 | head -1)" "bad.c:2: error: syntax error: could not read this item (gave up near line 2)"
check "an identifier's characters past ASCII by the level (0.221): C17 takes the euro sign and a middle dot, C23 does not, C99 no combining mark" "$(printf 'int a\342\202\254b = 1;\n' > euro.c; printf 'int \302\267x = 1;\n' > mdot.c; printf 'int x\314\201 = 1;\n' > comb.c; "$CICILI" -std=c17 -fsyntax-only euro.c mdot.c 2>&1; echo "c17 $?"; "$CICILI" -std=c23 -fsyntax-only euro.c 2>&1 | head -1; "$CICILI" -std=c23 -fsyntax-only mdot.c 2>&1 | head -1; "$CICILI" -std=c99 -fsyntax-only comb.c 2>&1 | head -1)" "c17 0
euro.c:1: error: character <U+20AC> not allowed in an identifier
mdot.c:1: error: character <U+00B7> not allowed at the start of an identifier
comb.c:1: error: character <U+0301> not allowed in an identifier"
check "__STDC_VERSION__ by the level (0.221): C99's, C11's, C17's and C23's" "$(printf 'long v = __STDC_VERSION__;\n' > ver.c; for s in c99 c11 c17 c23; do "$CICILI" -std=$s -E ver.c | grep -o '[0-9][0-9]*[lL]'; done | tr '\n' ' ')" "199901L 201112L 201710L 202311L "   # a number as written since 0.228, as clang's -E writes it
check "no -std= is ignored (0.257): clang's old names take their levels; C2y, a value clang does not name and a level of the other language are refused, in clang's words" "$(for s in c1x gnu9x iso9899:201x iso9899:2024; do "$CICILI" -std=$s -E ver.c | grep -o '[0-9][0-9]*[lL]'; done | paste -s -d ' ' -; for s in c2y foo c++20; do "$CICILI" -std=$s -E ver.c 2>&1; done; printf 'int main() { return 0; }\n' > stdok.cpp; "$ROOT/bin/cicilang++" -std=c17 -fsyntax-only stdok.cpp 2>&1)" "201112L 199901L 201112L 202311L
cicilang: error: unsupported C standard '-std=c2y' (C99 to C23)
cicilang: error: invalid value 'foo' in '-std=foo'
cicilang: error: invalid argument '-std=c++20' not allowed with 'C'
cicilang++: error: invalid argument '-std=c17' not allowed with 'C++'"
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
# THE FILE THAT A MACRO FILE LOADS (0.282): a macro file may load another by a directive, as ccllib's <set.pl> loads
# tree.pl, and a change of the loaded file reaches the next build -- a unit kept in the store, its IR there and a C++
# file's kept IR name it with the macro file (ccl_macro_loads/2). Until 0.282 they named the macro file alone, and both
# builds were served what they had kept. A third build, with no change, is served
mkdir -p mlib/mload && echo 'mload_inner(int(1)).' > mlib/mload/inner.pl
printf ':- ensure_loaded(library(mload/inner)).\nmload_value(_, R) :- mload_inner(R).\n' > mouter.pl
printf '#include <stdio.h>\n#include "mouter.pl"\nint main(void) { printf("%%d\\n", mload_value(0)); return 0; }\n' > mload.c
cp mload.c mload.cpp; rm -f "$HOME"/.cicilang/cpp/ir/mload.cpp-*.ll
mlc() { COCOLOG_LIBRARY="$D/mlib:$COCOLOG_LIBRARY" "$CICILI" "$@"; }
mlp() { CICILANG_NO_IR_CACHE= COCOLOG_LIBRARY="$D/mlib:$COCOLOG_LIBRARY" "$ROOT/bin/cicilang++" "$@"; }
ml1=$(mlc mload.c -o ml1 2>&1 && ./ml1; mlp mload.cpp -o mp1 2>&1 && ./mp1)
echo 'mload_inner(int(2)).' > mlib/mload/inner.pl; touch -t 203001010000 mlib/mload/inner.pl
ml2=$(mlc mload.c -o ml2 2>&1 && ./ml2; mlp mload.cpp -o mp2 2>&1 && ./mp2)
ml3=$(mlc -v mload.c -o ml3 2>&1 | grep -ac 'served mload.c from the store'; mlp -v mload.cpp -o mp3 2>&1 | grep -ac 'served mload.cpp from the IR cache')
check "the file that a macro file loads: its change reaches the next build, in C and in C++ (0.282)" "$(echo $ml1 / $ml2 / $ml3)" "1 1 / 2 2 / 1 1"
# A FILE THAT AN #include INSIDE AN ITEM PUTS IN PLACE (0.310): its text is the unit's (pp_splice_include/4), and its change
# reaches the next build -- the unit kept in the store, its IR there and a C++ file's kept IR name it ('$spliced_files'/1) --,
# in the program's own header, whose enum's rows its own read puts in place, and in the file. A round changes one file: a
# round that changed both was seen through the file's alone. A last build, with no change, is served. And a function's
# body that an #include gives in the program's own header: in C its raw read stops there (the reader's clause of a block's
# tok(pp)), and the preprocessed read that names the body's file takes the header; a raw read that went past it named no
# such file, and the body's change was served the old build
printf '7\n' > splv.def; printf 'A,\nB,\n' > splh.def
printf '#ifndef SPLH_H\n#define SPLH_H\nenum {\n#include "splh.def"\nNH };\n#endif\n' > splh.h
printf '#include <stdio.h>\n#include "splh.h"\nstatic const int v[] = {\n#include "splv.def"\n};\nint main(void) { printf("%%d %%d\\n", v[0], (int)NH); return 0; }\n' > splice.c
cp splice.c splice.cpp; rm -f "$HOME"/.cicilang/cpp/ir/splice.cpp-*.ll "$HOME"/.cicilang/cpp/ir/splbody.cpp-*.ll
spp() { CICILANG_NO_IR_CACHE= "$ROOT/bin/cicilang++" "$@"; }
sp1=$("$CICILI" splice.c -o sp1 2>&1 && ./sp1; spp splice.cpp -o spq1 2>&1 && ./spq1)
printf 'A,\nB,\nC,\n' > splh.def; touch -t 203001010000 splh.def
sp2=$("$CICILI" splice.c -o sp2 2>&1 && ./sp2; spp splice.cpp -o spq2 2>&1 && ./spq2)
printf '8\n' > splv.def; touch -t 203001010000 splv.def
sp3=$("$CICILI" splice.c -o sp3 2>&1 && ./sp3; spp splice.cpp -o spq3 2>&1 && ./spq3)
sp4=$("$CICILI" -v splice.c -o sp4 2>&1 | grep -ac 'served splice.c from the store'; spp -v splice.cpp -o spq4 2>&1 | grep -ac 'served splice.cpp from the IR cache')
printf '#ifndef SPLB_H\n#define SPLB_H\nstatic int splb(void) {\n    int s = 0;\n#include "splb_body.inc"\n    return s;\n}\n#endif\n' > splb.h; printf 's += 1;\n' > splb_body.inc
printf '#include <stdio.h>\n#include "splb.h"\nint main(void) { printf("%%d\\n", splb()); return 0; }\n' > splbody.c; cp splbody.c splbody.cpp
sb1=$("$CICILI" splbody.c -o sb1 2>&1 && ./sb1; spp splbody.cpp -o sbq1 2>&1 && ./sbq1)
printf 's += 2;\n' > splb_body.inc; touch -t 203001010000 splb_body.inc
sb2=$("$CICILI" splbody.c -o sb2 2>&1 && ./sb2; spp splbody.cpp -o sbq2 2>&1 && ./sbq2)
check "a file that an #include inside an item puts in place, in its own header and in the file, a body's in its own header: its change reaches the next build, in C and in C++ (0.310)" "$(echo $sp1 / $sp2 / $sp3 / $sp4 / $sb1 / $sb2)" "7 2 7 2 / 7 3 7 3 / 8 3 8 3 / 1 1 / 1 1 / 2 2"
# AN #include PUT IN PLACE WHERE AN ITEM NEEDS IT (0.310; pp_top_inner/0): right after `=', between digraphs, in a
# parameter list and in a bound, and a file that a #pragma once has run put in place once; and in the program's own
# header, among a struct's members, among member declarators and among init declarators, where the raw read stops and the
# preprocessed read puts the text in place (the reader's clauses of a tok(pp)). Each as C and as C++, each number clang's
printf '{ 1, 2, 3 }\n' > ip_rows.inc; printf '4, 5, 6\n' > ip_flat.inc; printf 'int a, int b\n' > ip_params.inc; printf '5\n' > ip_n.inc
printf '#pragma once\n1, 2,\n' > ip_once.inc; printf 'int x;\nint y;\n' > ip_fields.inc; printf 'a, b\n' > ip_names.inc; printf 'a3 = 1,\n' > ip_first.inc
printf '#ifndef IP_M_H\n#define IP_M_H\nstruct im {\n#include "ip_fields.inc"\n};\n#endif\n' > ip_m.h
printf '#ifndef IP_D_H\n#define IP_D_H\nstruct id { int\n#include "ip_names.inc"\n; };\n#endif\n' > ip_d.h
printf '#ifndef IP_I_H\n#define IP_I_H\nstatic const int\n#include "ip_first.inc"\nb3 = 2;\n#endif\n' > ip_i.h
printf '#include <stdio.h>\n#include "ip_m.h"\n#include "ip_d.h"\n#include "ip_i.h"\nstatic const int t[] =\n#include "ip_rows.inc"\n;\nstatic const int dg[] = <%%\n#include "ip_flat.inc"\n%%>;\nstatic int add(\n#include "ip_params.inc"\n) { return a + b; }\nstatic int arr[\n#include "ip_n.inc"\n];\nstatic const int po[] = {\n#include "ip_once.inc"\n#include "ip_once.inc"\n};\nint main(void) { printf("%%d %%d %%d %%d %%d %%d %%d %%d %%d\\n", (int)(sizeof t / sizeof t[0]), t[2], dg[2], add(2, 3), (int)(sizeof arr / sizeof arr[0]), (int)(sizeof po / sizeof po[0]), (int)sizeof(struct im), (int)sizeof(struct id), a3 + b3); return 0; }\n' > inplace.c
cp inplace.c inplace.cpp
check "an #include put in place after =, between digraphs, in a parameter list and a bound, once under #pragma once, and among an own header's members, member declarators and init declarators, as C and as C++ (0.310)" "$("$CICILI" inplace.c -o ipc 2>&1 && ./ipc; "$ROOT/bin/cicilang++" inplace.cpp -o ipp 2>&1 && ./ipp)" "3 3 6 5 5 2 8 8 3
3 3 6 5 5 2 8 8 3"
# A DIAGNOSTIC OF A ROW THAT AN #include PUTS IN PLACE NAMES THE #include'S LINE (0.310; pp_reline_key/2): the row's
# tokens stand there, in the program's file, where they named their own file's line under the program's file's name
printf 'int main(void) {\n    int s = 0;\n#include "ipbad.inc"\n    return s;\n}\n' > ipbad.c; printf 's += undeclared_y;\n' > ipbad.inc; cp ipbad.c ipbad.cpp
check "a diagnostic of a row that an #include puts in place names the #include's line, in C and in C++ (0.310)" "$("$CICILI" -c ipbad.c -o ipbad.o 2>&1 | head -1 | cut -d: -f1-2; "$ROOT/bin/cicilang++" -c ipbad.cpp -o ipbadp.o 2>&1 | head -1 | cut -d: -f1-2)" "ipbad.c:3
ipbad.cpp:3"
# ONE BUILD AT A TIME OVER THE STORE (0.240): four builds at once over one fresh store take KB.lock in turn -- without it
# three died of a bus error and the store was left so damaged that every later build failed -- and one more build over
# that store after them runs; no lock is left
pk="$D/kbpar"
for n in hello forty2 owners btree; do ( CICILANG_KB="$pk" "$CICILI" "$R/run/$n.c" -o "par_$n" > "par_$n.log" 2>&1 < /dev/null ) & done; wait
par=$(for n in hello forty2 owners btree; do if [ -x "par_$n" ]; then echo "$n built"; else echo "$n failed"; fi; done | tr '\n' ' ')
after=$(CICILANG_KB="$pk" "$CICILI" "$R/run/hello.c" -o parlast 2>&1 && ./parlast; ls -d "$pk.lock" 2>/dev/null)
check "builds at once over one store take its lock in turn, the store sound after" "$par/$after" "hello built forty2 built owners built btree built /hello, cicilang"
if [ "$failures" -eq 0 ]; then echo "GREEN: driver"; else echo "RED: $failures failure(s)"; exit 1; fi
