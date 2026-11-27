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
check "the calling conventions and layouts of x86-64, Linux's aarch64 and Apple's arm64 are clang's" "$(for t in x86_64-linux-gnu aarch64-linux-gnu arm64-apple-macos; do "$CICILI" --target=$t -std=c23 -S -emit-llvm "$R/link/abi_targets.c" -o at_ours.ll > at.log 2>&1 && clang --target=$t -std=c23 -S -emit-llvm -w "$R/link/abi_targets.c" -o at_clang.ll && for w in ours clang; do awk -f "$ROOT/test/abisig.awk" at_$w.ll | sort -u > at_$w.sig; grep '^@sizes' at_$w.ll | sed 's/^@sizes = [a-z_ ]*global //; s/, align [0-9]*$//' >> at_$w.sig; done && cmp -s at_ours.sig at_clang.sig && echo "$t $(wc -l < at_ours.sig | tr -d ' ')"; done | tr '\n' ' ')" "x86_64-linux-gnu 65 aarch64-linux-gnu 65 arm64-apple-macos 65 "
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
check "two units over <memory.pl> share the program's pool: a handle one made, cloned in the other (1.6.5)" "$("$CICILI" "$R/link/sp_a.c" "$R/link/sp_b.c" -o spab 2>&1 && ./spab)" "a 5 1
b 17
count 2 1"   # the review's r15: through 1.6.4 each unit had its own pool, the linker kept one unit's `unique', and the other's call aborted
check "... in the other order, and in C++ (1.6.5)" "$("$CICILI" "$R/link/sp_b.c" "$R/link/sp_a.c" -o spba 2>&1 && ./spba; "$ROOT/bin/cicilang++" "$R/link/sp_a.c" "$R/link/sp_b.c" -o sppp 2>&1 && ./sppp)" "a 5 1
b 17
count 2 1
a 5 1
b 17
count 2 1"
check "the pool of shared_ptr<int> and its lock are linkonce_odr globals, the program's and not each unit's (1.6.5)" "$("$CICILI" -S -emit-llvm "$R/link/sp_b.c" -o spb.ll 2>&1 && grep -c -e '^@shared_ptr_int_pool = linkonce_odr global' -e '^@shared_ptr_int_pool_lock = linkonce_odr global' spb.ll)" "2"
lpout=$("$CICILI" "$R/lit_noplace.c" -o litnp 2>&1); lpcode=$?
check "a list literal where no place gives it a type, a conditional's branch, is refused by name (0.263)" "$(echo "$lpout" | sed "s|$R/||g"; echo "exit $lpcode")" "lit_noplace.c:8: error: not lowered yet: list_literal_with_no_type_given (function main)
lit_noplace.c:8: note: expanded from macro 'vector' on int
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
# A VERBOSE TRAP UNDER -g (1.6.10): the trap's place is in an artificial function named by its two strings, inlined at the
# call's line and column, the function made once a name in the unit, as clang 22's DWARF has it (clang 19 is the first to know
# the builtin; the gates' clang is older)
check "-g: a verbose trap's place is in its artificial function __clang_trap_msg\$CATEGORY\$MESSAGE, inlined at the call's line and column, one function for two calls of its strings, a quote of the message in its name, as clang 22's (1.6.10)" "$(printf 'static int check(int v) {\n  if (v > 9) __builtin_verbose_trap("probe", "too big");\n  return v + 1;\n}\nstatic int again(int v) { if (v < 0) __builtin_verbose_trap("probe", "too big"); return v; }\nstatic int quote(int v) { if (v > 99) __builtin_verbose_trap("probe", "say \\"hi\\""); return v; }\nint main(int argc, char **argv) { (void)argv; return check(argc) + again(argc) + quote(argc) - 5; }\n' > dbgtrap.c; "$CICILI" -g -c dbgtrap.c -o dbgtrap.o && "$DD" --debug-info dbgtrap.o | awk '/DW_TAG_inlined_subroutine/ { s = 1; next } /DW_TAG_subprogram/ { p = 1; next } p && /DW_AT_name/ && /__clang_trap_msg/ { k++ } /DW_TAG_/ { p = 0 } s && /DW_AT_abstract_origin/ { n = $0; sub(/^[^"]*"/, "", n); sub(/"\)[^)]*$/, "", n) } s && /DW_AT_call_line/ { l = $2; gsub(/[()]/, "", l) } s && /DW_AT_call_column/ { c = $2; gsub(/[()]/, "", c); print n, l, c; s = 0 } END { print k + 0, "subprogram" }')" "__clang_trap_msg\$probe\$too big 2 14
__clang_trap_msg\$probe\$too big 5 38
__clang_trap_msg\$probe\$say \"hi\" 6 39
2 subprogram"
# A TRAP ENDS ITS BLOCK, A DEBUG TRAP DOES NOT (1.6.10): `llvm.trap' does not return, and the lowering's block ends in
# `unreachable' after it, as after `__builtin_unreachable()', so a phi takes no arm that ends there; after `llvm.debugtrap' the
# program goes on. Of two arms that both end, the value is `poison', in a block that nothing reaches: a phi of no entry is
# LLVM's too, so the program alone does not tell them apart
check "a trap's call ends its block in unreachable, a verbose trap's too; a debug trap's goes on; a conditional whose two arms trap makes no phi of no entry (1.6.10)" "$(printf 'int main(int argc, char **argv) {\n  (void)argv;\n  if (argc > 5) __builtin_trap();\n  if (argc > 6) __builtin_verbose_trap("c", "m");\n  if (argc > 7) __builtin_debugtrap();\n  int z = argc > 8 ? (__builtin_trap(), 1) : (__builtin_trap(), 2);\n  return z;\n}\n' > irtrap.c; "$CICILI" -S -emit-llvm irtrap.c -o irtrap.ll && awk '/call void @llvm\.trap\(\)/ { getline n; print "trap", (n ~ /^ *unreachable/ ? "ends" : "goes on") } /call void @llvm\.debugtrap\(\)/ { getline n; print "debugtrap", (n ~ /^ *unreachable/ ? "ends" : "goes on") } / = phi [^ ]+ *$/ { e++ } END { print "empty phi", e + 0 }' irtrap.ll | tr '\n' ' ')" "trap ends trap ends debugtrap goes on trap ends trap ends empty phi 0 "
# A CALL THAT DOES NOT RETURN ENDS ITS BLOCK (1.6.15): a function declared not to return -- glibc's `exit' and `abort', a
# program's `_Noreturn' one -- is called, and the block ends in `unreachable' after the call, as clang's does; the safe part
# ends the path there too (the lowering's topic), so an owner still live at the call is no leak
check "a call of a function that does not return ends its block in unreachable, as clang's (1.6.15)" "$(printf '#include <stdlib.h>\n_Noreturn static void die(int c) { exit(c); }\nint f(int x) { if (x > 0) return x; if (x < -5) abort(); if (x == -1) die(2); exit(3); }\nint main(void) { return f(1) - 1; }\n' > nr.c && "$CICILI" -S -emit-llvm nr.c -o nr.ll && clang -S -emit-llvm -O0 nr.c -o nrc.ll && for f in nr nrc; do awk '/call void @(exit|abort|die)/ { getline n; if (n ~ /unreachable/) u++ } END { printf "%d ", u + 0 }' $f.ll; done)" "4 4 "
# A FUNCTION DECLARED NOT TO RETURN THAT RETURNS (1.6.17; C17 6.7.4/8): a return of it is refused at its line, a dead one too,
# in clang's words, and its end that a path reaches at the line of the body's last statement -- clang's is the closing
# brace's, which the reader keeps under -g alone; a switch whose cases end, a goto, a longjmp, a call of a function whose
# body returns never (clang warns there, reading no body), an if and a conditional whose two arms end, and the loops that do
# not end leave no path to the end. Through 1.6.16 none was refused
nr_pre='#include <stdlib.h>\n#include <setjmp.h>\nstatic jmp_buf env;'
check "a function declared not to return that returns is refused in clang's words: a return at its line, an end at its body's last statement (1.6.17)" "$(n=0; for body in '_Noreturn void a(void) { exit(1); return; }' '_Noreturn void a(void) { while (1) { } return; }' '_Noreturn int a(void) { return 1; }' '_Noreturn void a(int x) { if (x) { return; } exit(0); }' '_Noreturn void a(void) { for (;;) { break; } }' '_Noreturn void a(void);\nvoid a(void) { }' '__attribute__((noreturn)) void a(int x) {\n    if (x)\n        exit(1);\n}' '_Noreturn void a(int x) {\n    char *p = malloc(4);\n    if (!p) exit(1);\n    p[0] = (char)x;\n    free(p);\n}' '_Noreturn void a(int x) {\n    while (x > 0) {\n        x--;\n    }\n}' '_Noreturn int a(void) { exit(1); }' '_Noreturn void a(int x) { switch (x) { case 0: exit(0); default: abort(); } }' '_Noreturn void a(void) { goto x; x: exit(0); }' '_Noreturn void a(void) { longjmp(env, 1); }' 'static void g(void) { exit(3); }\n_Noreturn void a(void) { g(); }' '_Noreturn void a(int x) { if (x) exit(1); else abort(); }' '_Noreturn void a(int x) { do { } while (1); }' '_Noreturn void a(int x) { x ? exit(1) : abort(); }'; do n=$((n + 1)); printf '%b\n%b\nint main(void) { return 0; }\n' "$nr_pre" "$body" > nr$n.c; o=$("$CICILI" -std=c17 -fsyntax-only nr$n.c 2>&1 | head -1); if [ -n "$o" ]; then echo "$o"; else echo "nr$n.c: ok"; fi; done)" "nr1.c:4: error: function 'a' declared 'noreturn' should not return
nr2.c:4: error: function 'a' declared 'noreturn' should not return
nr3.c:4: error: function 'a' declared 'noreturn' should not return
nr4.c:4: error: function 'a' declared 'noreturn' should not return
nr5.c:4: error: function declared 'noreturn' should not return
nr6.c:5: error: function declared 'noreturn' should not return
nr7.c:5: error: function declared 'noreturn' should not return
nr8.c:8: error: function declared 'noreturn' should not return
nr9.c:5: error: function declared 'noreturn' should not return
nr10.c: ok
nr11.c: ok
nr12.c: ok
nr13.c: ok
nr14.c: ok
nr15.c: ok
nr16.c: ok
nr17.c: ok"
# A LOOP WHOSE STATE DOES NOT SETTLE IN EIGHT PASSES (1.6.19): the walk of a loop's body goes on while a pass changes what the
# next one finds, eight passes at most; a loop that does not settle in eight is refused by name at its line -- eight own
# pointers that pass memory on, one a pass, need nine --, and seven, which settle in the eighth pass, are taken
lsout=$("$CICILI" -fsyntax-only "$R/loop_unsettled.c" 2>&1); lscode=$?
lsout7=$("$CICILI" -fsyntax-only "$R/loop_settled7.c" 2>&1); lscode7=$?
check "a loop whose state does not settle in eight passes is refused by name; one that settles in eight is taken (1.6.19)" "$(echo "$lsout" | sed "s|$R/||g"; echo "exit $lscode"; echo "$lsout7"; echo "exit $lscode7")" "loop_unsettled.c:8: error: not lowered yet: loop_state_unsettled (function main)
cicilang: 1 error(s)
exit 1

exit 0"
check "an unknown argument is an error, as clang says it" "$("$CICILI" --frobnicate x.c 2>&1)" "cicilang: error: unknown argument: '--frobnicate'"
check "no input files is an error" "$("$CICILI" -c 2>&1)" "cicilang: error: no input files"
check "the tie: a broken tie is refused in clang's shape" "$("$CICILI" -fsyntax-only "$R/safe/tie_arg.c" 2>&1 | head -1 | sed "s|$R/||")" "safe/tie_arg.c:4: error: value not within its tie: 'b' in call(id(gap),[id(a),id(b)]) (function main)"
check "a slot with no owner behind it is refused, in clang's shape" "$(printf '#include <stdlib.h>\nstruct s { char *q; } g;\nint main(void) { char *p = malloc(8); g.q = malloc(8); free(p); return 0; }\n' > untied.c; "$CICILI" -fsyntax-only untied.c 2>&1 | head -1)" "untied.c:3: error: no owner behind: 'g.q' in assign(=,member(id(g),q),call(id(malloc),[int(8)])) (function main)"
check "a plain pointer never consumed is refused; one freed is not" "$(printf '#include <stdlib.h>\nint main(void) { char *p = malloc(8); char *r = malloc(8); free(p); return 0; }\n' > loose.c; "$CICILI" -fsyntax-only loose.c 2>&1 | head -1)" "loose.c:2: error: plain pointer not consumed: 'r' in return(int(0)) (function main)"
check "a record where another type is needed is refused by name at its line (0.286): an assignment, an initializer, an argument and a result of another struct's type, a number where a struct is needed and a struct where a number is; a unary - and ~ over a struct, in clang's words; a struct with no tag is named so (0.288); each site in clang's words, the value's type as written (1.6.26)" "$(n=0; for body in 'static void f(struct A a, struct B b) { a = b; (void)a; }' 'static void f(struct B b) { struct A a = b; (void)a; }' 'static long f(struct B b) { return use(b); }' 'static struct A f(struct B b) { return b; }' 'static long f(void) { return use(5); }' 'static long f(struct A a) { long k = a; return k; }' 'static struct A f(struct A a) { return -a; }' 'static struct A f(struct A a) { return ~a; }' 'typedef struct { long w[1]; } U; static long f(U u) { return use(u); }'; do n=$((n + 1)); printf 'struct A { long w[1]; };\nstruct B { long w[1]; };\nstatic long use(struct A a) { return a.w[0]; }\n%s\nint main(void) { return 0; }\n' "$body" > conv$n.c; "$CICILI" -fsyntax-only conv$n.c 2>&1 | head -1; done)" "conv1.c:4: error: assigning to 'struct A' from incompatible type 'struct B'
conv2.c:4: error: initializing 'struct A' with an expression of incompatible type 'struct B'
conv3.c:4: error: passing 'struct B' to parameter of incompatible type 'struct A'
conv4.c:4: error: returning 'struct B' from a function with incompatible result type 'struct A'
conv5.c:4: error: passing 'int' to parameter of incompatible type 'struct A'
conv6.c:4: error: initializing 'long' with an expression of incompatible type 'struct A'
conv7.c:4: error: invalid argument type 'struct A' to unary expression
conv8.c:4: error: invalid argument type 'struct A' to unary expression
conv9.c:4: error: passing 'U' to parameter of incompatible type 'struct A'"
check "... and in C++, where a class is named by its own name (0.286)" "$(printf 'struct A { long w[1]; };\nstruct B { long w[1]; };\nint main() {\n  A a = {{1}};\n  B b = {{2}};\n  a = b;\n  return 0;\n}\n' > convpp.cpp; "$ROOT/bin/cicilang++" -c convpp.cpp -o convpp.o 2>&1 | head -1)" "convpp.cpp:6: error: no conversion from 'B' to 'A'"
check "a pointer where a struct is needed is refused by name at its line (0.291): a text and a struct's address handed to a struct parameter, and a pointer given back as a struct, where each went to LLVM's parser; each site in clang's words, a literal by its array's type, and clang's hint to remove the & (1.6.26)" "$(n=0; for body in 'static long f(void) { return use("abc"); }' 'static long f(struct A a) { return use(&a); }' 'static struct A f(const char *p) { return p; }'; do n=$((n + 1)); printf 'struct A { long w[1]; };\nstatic long use(struct A a) { return a.w[0]; }\n%s\nint main(void) { return 0; }\n' "$body" > ptrrec$n.c; "$CICILI" -fsyntax-only ptrrec$n.c 2>&1 | head -1; done)" "ptrrec1.c:3: error: passing 'char[4]' to parameter of incompatible type 'struct A'
ptrrec2.c:3: error: passing 'struct A *' to parameter of incompatible type 'struct A'; remove &
ptrrec3.c:3: error: returning 'const char *' from a function with incompatible result type 'struct A'"
check "a floating value where a pointer is needed, and a pointer where a floating value is, are refused by name at the line (0.288): an argument each way and a cast each way, the casts in clang's words (1.6.14), the arguments too (1.6.26)" "$(n=0; for body in 'static void f(double d) { usep(d); }' 'static void f(char *q) { used(q); }' 'static double f(char *q) { return (double)q; }' 'static void f(double d) { usep((char *)d); }'; do n=$((n + 1)); printf 'static void usep(const char *p) { (void)p; }\nstatic void used(double d) { (void)d; }\n%s\nint main(void) { return 0; }\n' "$body" > fpp$n.c; "$CICILI" -fsyntax-only fpp$n.c 2>&1 | head -1; done)" "fpp1.c:3: error: passing 'double' to parameter of incompatible type 'const char *'
fpp2.c:3: error: passing 'char *' to parameter of incompatible type 'double'
fpp3.c:3: error: pointer cannot be cast to type 'double'
fpp4.c:3: error: operand of type 'double' cannot be cast to a pointer type"
check "C's sites of a value of no conversion, in clang's words (1.6.26; C17 6.5.16.1/1, 6.5.2.2/2, 6.8.6.4/3): the value's typedef as written with its (aka ...), a parameter's typedef, an assignment and an initializer of a typedef's value, a result and an initializer of a struct with no tag, and a pointer and a floating value each way at a return, an assignment and an initializer, an array by its array's type, and a record returned by memory" "$(n=0; for src in 'struct A { long w[1]; };\ntypedef int I;\nstatic long use(struct A a) { return a.w[0]; }\nstatic long f(I x) { return use(x); }\nint main(void) { return 0; }' 'struct A { long w[1]; };\nstruct B { long w[1]; };\ntypedef struct A TA;\nstatic long use(TA a) { return a.w[0]; }\nstatic long f(struct B b) { return use(b); }\nint main(void) { return 0; }' 'struct A { long w[1]; };\ntypedef int I;\nint main(void) { struct A a; I x = 1; a = x; return 0; }' 'struct A { long w[1]; };\ntypedef struct { int k; } V;\nstatic struct A g(V v) { return v; }\nint main(void) { return 0; }' 'struct A { long w[1]; };\ntypedef struct { int k; } V;\nint main(void) { V v = {1}; struct A a = v; return 0; }' 'static double f(char *q) { return q; }\nint main(void) { return 0; }' 'static void f(char *q) { double d; d = q; (void)d; }\nint main(void) { return 0; }' 'static void f(double d) { char *p = d; (void)p; }\nint main(void) { return 0; }' 'struct A { long w[1]; };\nstatic long use(struct A a) { return a.w[0]; }\nstatic long f(void) { char b[4] = "abc"; return use(b); }\nint main(void) { return 0; }' 'struct A { long w[4]; };\nstruct B { long w[4]; };\nstatic struct A f(struct B b) { return b; }\nint main(void) { return 0; }'; do n=$((n + 1)); printf "$src\n" > site$n.c; "$CICILI" -fsyntax-only site$n.c 2>&1 | head -1; done)" "site1.c:4: error: passing 'I' (aka 'int') to parameter of incompatible type 'struct A'
site2.c:5: error: passing 'struct B' to parameter of incompatible type 'TA' (aka 'struct A')
site3.c:3: error: assigning to 'struct A' from incompatible type 'I' (aka 'int')
site4.c:3: error: returning 'V' from a function with incompatible result type 'struct A'
site5.c:3: error: initializing 'struct A' with an expression of incompatible type 'V'
site6.c:1: error: returning 'char *' from a function with incompatible result type 'double'
site7.c:1: error: assigning to 'double' from incompatible type 'char *'
site8.c:1: error: initializing 'char *' with an expression of incompatible type 'double'
site9.c:3: error: passing 'char[4]' to parameter of incompatible type 'struct A'
site10.c:3: error: returning 'struct B' from a function with incompatible result type 'struct A'"
check "C++: a floating value cast to a pointer, and a pointer cast to a floating type, in clang++'s words by the cast's spelling (1.6.26; [expr.cast]/4, [expr.static.cast], [expr.reinterpret.cast], [expr.const.cast]): a C-style, a static, a reinterpret, a const and a functional cast, through a typedef and an alias, of a float, a long double and a const double" "$(n=0; for src in 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)((int *)d); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(static_cast<int *>(d)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(reinterpret_cast<int *>(d)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(const_cast<int *>(d)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(P(d)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(IP(d)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)((IP)d); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)((double)q); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(static_cast<double>(q)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(reinterpret_cast<double>(q)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(double(q)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)(D(q)); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)((float)q); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)((int *)ld); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)((int *)cd); return 0; }' 'typedef int *IP;\nusing P = int *;\ntypedef double D;\nint main() { double d = 1.0; float f = 1.0f; long double ld = 1.0L; const double cd = 2.0; int x = 0; int *q = &x; (void)((void *)d); return 0; }'; do n=$((n + 1)); printf "$src\n" > fpcast$n.cpp; "$ROOT/bin/cicilang++" -c fpcast$n.cpp -o fpcast$n.o 2>&1 | head -1; done)" "fpcast1.cpp:4: error: cannot cast from type 'double' to pointer type 'int *'
fpcast2.cpp:4: error: cannot cast from type 'double' to pointer type 'int *'
fpcast3.cpp:4: error: reinterpret_cast from 'double' to 'int *' is not allowed
fpcast4.cpp:4: error: const_cast from 'double' to 'int *' is not allowed
fpcast5.cpp:4: error: cannot cast from type 'double' to pointer type 'P' (aka 'int *')
fpcast6.cpp:4: error: cannot cast from type 'double' to pointer type 'IP' (aka 'int *')
fpcast7.cpp:4: error: cannot cast from type 'double' to pointer type 'IP' (aka 'int *')
fpcast8.cpp:4: error: C-style cast from 'int *' to 'double' is not allowed
fpcast9.cpp:4: error: static_cast from 'int *' to 'double' is not allowed
fpcast10.cpp:4: error: reinterpret_cast from 'int *' to 'double' is not allowed
fpcast11.cpp:4: error: functional-style cast from 'int *' to 'double' is not allowed
fpcast12.cpp:4: error: functional-style cast from 'int *' to 'D' (aka 'double') is not allowed
fpcast13.cpp:4: error: C-style cast from 'int *' to 'float' is not allowed
fpcast14.cpp:4: error: cannot cast from type 'long double' to pointer type 'int *'
fpcast15.cpp:4: error: cannot cast from type 'double' to pointer type 'int *'
fpcast16.cpp:4: error: cannot cast from type 'double' to pointer type 'void *'"
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
check "... and in C++, a call that no overload fits by its count or by an integer and a pointer, in clang++'s words, a struct for an int as the overloads' words too (1.6.28), and a call through a pointer of another count (0.302)" "$(n=0; for body in 'static int f(int a, int b) { return a + b; } int main() { return f(1, 2, 3); }' 'static int g(char *p) { return p == 0; } int main() { return g(5); }' 'static int f(int a, int b = 2) { return a * b; } int main() { return f(); }' 'static int f(int a, int b) { return a + b; } int main() { int (*g)(int, int) = f; return g(1); }' 'struct S { int (*op)(int); }; static int one(int a) { return a; } int main() { S s = {one}; return s.op(1, 2); }' 'static int f(int a, int b) { return a + b; } static int f(char *p) { return p != 0; } int main() { return f(5); }' 'static long f(long v) { return v; } int main() { int x = 3; return (int)f(&x); }' 'struct S { int a; }; static int f(int v) { return v; } int main() { S s = {1}; return f(s); }'; do n=$((n + 1)); printf '%s\n' "$body" > callpp$n.cpp; "$ROOT/bin/cicilang++" -c callpp$n.cpp -o callpp$n.o 2>&1 | head -1; done)" "callpp1.cpp:1: error: no matching function for call to 'f'
callpp2.cpp:1: error: no matching function for call to 'g'
callpp3.cpp:1: error: no matching function for call to 'f'
callpp4.cpp:1: error: too few arguments to function call, expected 2, have 1
callpp5.cpp:1: error: too many arguments to function call, expected 1, have 2
callpp6.cpp:1: error: no matching function for call to 'f'
callpp7.cpp:1: error: no matching function for call to 'f'
callpp8.cpp:1: error: no matching function for call to 'f'"
check "C++: a call whose argument fits no candidate by its type is the overloads' words (1.6.28; [conv], [over.best.ics]): a plain struct for a scalar, a floating value and a pointer for each other, a pointer to another type, an integer and another enumeration for an enumeration -- two of them built and read the wrong bits, and the rest had the lowering's words -- after what fits and builds, first: a base's pointer, a void pointer, an added const, a class's conversion" "$(n=0; for src in 'enum E { A, B };
static int f(E e) { return e; }
int main() { return f(B) - 1; }' 'static int g(int v) { return v; }
static int f(int (*p)(int)) { return p(1); }
int main() { return f(g) - 1; }' 'template <class T> struct W { T v; };
static int f(W<int> *p) { return p->v; }
int main() { W<int> w = {0}; return f(&w); }' 'struct B {}; struct D : B {};
static int f(B *p) { return p != 0; }
int main() { D d; return f(&d); }' 'static int f(void *p) { return p != 0; }
int main() { int x = 0; return f(&x); }' 'static int f(int *p) { return p != 0; }
int main() { void *v = 0; return f((int *)v) + f(static_cast<int *>(v)); }' 'static int f(const int *p) { return p != 0; }
int main() { int x = 0; return f(&x); }' 'struct S { operator int() const { return 3; } };
static int f(int v) { return v; }
int main() { S s; return f(s); }' 'struct S { int a; };
static int f(int v) { return v; }
int main() { S s = {1}; return f(s); }' 'static int f(int *p) { return p != 0; }
int main() { char c[4] = {0}; return f(c); }' 'static int f(const char *p) { return p != 0; }
int main() { double d = 1; return f(d); }' 'static double f(double v) { return v; }
int main() { int x = 0; return (int)f(&x); }' 'static int f(long *p) { return p != 0; }
int main() { int x = 0; return f(&x); }' 'enum E { A };
static int f(E e) { return e; }
int main() { return f(1); }' 'enum E { A }; enum F { B };
static int f(E e) { return e; }
int main() { return f(B); }'; do n=$((n + 1)); printf "$src\n" > misfit$n.cpp; "$ROOT/bin/cicilang++" -c misfit$n.cpp -o misfit$n.o 2>&1 | head -1; done)" "misfit9.cpp:3: error: no matching function for call to 'f'
misfit10.cpp:2: error: no matching function for call to 'f'
misfit11.cpp:2: error: no matching function for call to 'f'
misfit12.cpp:2: error: no matching function for call to 'f'
misfit13.cpp:2: error: no matching function for call to 'f'
misfit14.cpp:3: error: no matching function for call to 'f'
misfit15.cpp:3: error: no matching function for call to 'f'"
check "C++: a pointer to another type and a floating value for a pointer, at an initializer, an assignment and a return, in clang++'s words (1.6.28; [conv.ptr]): each built, but the floating value, the lowering's no conversion -- after what C++ takes, first: a base's pointer, a void pointer, an added const, a cast" "$(n=0; for src in 'struct B {}; struct D : B {};
int main() { D d; B *b = &d; void *v = b; const B *cb = b; return v != cb; }' 'int main() { int x = 0; long *p = (long *)&x; return p != 0; }' 'int main() { char c[4] = {0}; int *p = c; return p != 0; }' 'int main() { char c[4] = {0}; char *q = c; int *p = 0; p = q; return p != 0; }' 'static int *f(char *q) { return q; }
int main() { return f(0) != 0; }' 'int main() { double d = 1; int *p = &d; return *p; }' 'int main() { int *p = 0; double d = 2; p = d; return 0; }'; do n=$((n + 1)); printf "$src\n" > ptrsite$n.cpp; "$ROOT/bin/cicilang++" -c ptrsite$n.cpp -o ptrsite$n.o 2>&1 | head -1; done)" "ptrsite3.cpp:1: error: cannot initialize a variable of type 'int *' with an lvalue of type 'char[4]'
ptrsite4.cpp:1: error: incompatible pointer types assigning to 'int *' from 'char *'
ptrsite5.cpp:1: error: cannot initialize return object of type 'int *' with an lvalue of type 'char *'
ptrsite6.cpp:1: error: cannot initialize a variable of type 'int *' with an rvalue of type 'double *'
ptrsite7.cpp:1: error: assigning to 'int *' from incompatible type 'double'"
check "C++: a qualified call of one function with another count, in clang++'s words by its count, its defaults and its ellipsis (1.6.26): a C function through std:: and ::, a namespace's, one a using names, a static member's -- each was the overloads' no matching function --, an overload set and a bare name as the overloads', a template's misfit by name, and a pointer's count alone" "$(n=0; for src in '#include <cstdio>\nint main() { return std::printf(); }' '#include <cstdio>\nint main() { return std::puts(); }' '#include <cstdio>\nint main() { return std::puts("a", "b"); }' '#include <cstring>\nint main() { return (int)std::strcmp("a"); }' 'namespace n { void f(int); }\nint main() { n::f(); }' 'extern "C" void f(int);\nnamespace n { using ::f; }\nint main() { n::f(); }' 'void f(int a);\nint main() { ::f(); }' 'namespace n { void f(int a, int b); }\nint main() { n::f(1); }' 'namespace n { void f(int a, ...); }\nint main() { n::f(); }' 'namespace n { void f(int a, int b = 2); }\nint main() { n::f(); }' 'namespace n { void f(int a, int b = 2); }\nint main() { n::f(1, 2, 3); }' 'namespace n { void f(int a = 1); }\nint main() { n::f(1, 2); }' 'namespace n { void f(int, int = 2); }\nint main() { n::f(); }' 'namespace n { void f(); }\nint main() { n::f(1); }' 'namespace n { void f(int a); }\nint main() { n::f(1, 2); }' 'namespace n { void f(int a, int b, ...); }\nint main() { n::f(1); }' 'namespace n { void f(int a); void f(double); }\nint main() { n::f(); }' 'void f(int);\nint main() { f(); }' 'namespace n { template <class T> void f(T); }\nint main() { n::f(); }' 'struct S { static int g(int a, int b = 1); };\nint main() { return S::g(); }' 'struct S { static int g(int a, ...); };\nint main() { return S::g(); }' 'struct S { static int g(int a); static int g(double); };\nint main() { return S::g(); }' 'struct S { static int g(int a, int b = 1, int c = 2); };\nint main() { return S::g(1, 2, 3, 4); }' 'static int h(int a, int b) { return a + b; }\nint main() { int (*p)(int, int) = h; return p(1); }'; do n=$((n + 1)); printf "$src\n" > qcount$n.cpp; "$ROOT/bin/cicilang++" -c qcount$n.cpp -o qcount$n.o 2>&1 | head -1; done)" "qcount1.cpp:2: error: too few arguments to function call, at least argument '__format' must be specified
qcount2.cpp:2: error: too few arguments to function call, single argument '__s' was not specified
qcount3.cpp:2: error: too many arguments to function call, expected single argument '__s', have 2 arguments
qcount4.cpp:2: error: too few arguments to function call, expected 2, have 1
qcount5.cpp:2: error: too few arguments to function call, expected 1, have 0
qcount6.cpp:3: error: too few arguments to function call, expected 1, have 0
qcount7.cpp:2: error: too few arguments to function call, single argument 'a' was not specified
qcount8.cpp:2: error: too few arguments to function call, expected 2, have 1
qcount9.cpp:2: error: too few arguments to function call, at least argument 'a' must be specified
qcount10.cpp:2: error: too few arguments to function call, at least argument 'a' must be specified
qcount11.cpp:2: error: too many arguments to function call, expected at most 2, have 3
qcount12.cpp:2: error: too many arguments to function call, expected at most single argument 'a', have 2 arguments
qcount13.cpp:2: error: too few arguments to function call, expected at least 1, have 0
qcount14.cpp:2: error: too many arguments to function call, expected 0, have 1
qcount15.cpp:2: error: too many arguments to function call, expected single argument 'a', have 2 arguments
qcount16.cpp:2: error: too few arguments to function call, expected at least 2, have 1
qcount17.cpp:2: error: no matching function for call to 'f'
qcount18.cpp:2: error: no matching function for call to 'f'
qcount19.cpp:2: error: no matching function for call to 'f'
qcount20.cpp:2: error: too few arguments to function call, at least argument 'a' must be specified
qcount21.cpp:2: error: too few arguments to function call, at least argument 'a' must be specified
qcount22.cpp:2: error: no matching function for call to 'g'
qcount23.cpp:2: error: too many arguments to function call, expected at most 3, have 4
qcount24.cpp:2: error: too few arguments to function call, expected 2, have 1"
check "C++: a member function named with its class that none takes, in clang++'s words (1.6.26): one by its count inside its class and a base's, an overload set as the member set's, and a member that is not static called with no object -- which was called over a null this, or was undeclared('S.m') --, a static member by its defaults and a static set" "$(n=0; for src in 'struct S { int m(int a); int k() { return S::m(); } };\nint main() { return 0; }' 'struct S { int m(int a); int m(double); int k() { return S::m(); } };\nint main() { return 0; }' 'struct S { int m(int a); };\nint main() { return S::m(); }' 'struct S { int m(int a); };\nint main() { return S::m(1); }' 'struct B { int m(int a); }; struct S : B { int k() { return B::m(); } };\nint main() { return 0; }' 'struct S { static int g(int a, int b = 1); };\nint main() { return S::g(); }' 'struct S { static int g(int a); static int g(double); };\nint main() { return S::g(); }'; do n=$((n + 1)); printf "$src\n" > qmember$n.cpp; "$ROOT/bin/cicilang++" -c qmember$n.cpp -o qmember$n.o 2>&1 | head -1; done)" "qmember1.cpp:1: error: too few arguments to function call, single argument 'a' was not specified
qmember2.cpp:1: error: no matching member function for call to 'm'
qmember3.cpp:2: error: call to non-static member function without an object argument
qmember4.cpp:2: error: call to non-static member function without an object argument
qmember5.cpp:1: error: too few arguments to function call, single argument 'a' was not specified
qmember6.cpp:2: error: too few arguments to function call, at least argument 'a' must be specified
qmember7.cpp:2: error: no matching function for call to 'g'"
check "C++: a subscript over a plain struct, in clang++'s words by its left operand (1.6.26): it was named as a binary operator's operands, which 1.6.25's net found in the ccllib gate" "$(n=0; for src in 'struct S { int a; };\nint main() { S s{1}; return s[1]; }' 'struct S { int a; };\nint main() { S s{1}; return 1[s]; }' 'struct S { int a; };\nint main() { S s{1}; int *p = 0; return p[s]; }' 'struct S { int a; };\nstruct T { int b; };\nint main() { S s{1}; T t{2}; return s[t]; }'; do n=$((n + 1)); printf "$src\n" > subrec$n.cpp; "$ROOT/bin/cicilang++" -c subrec$n.cpp -o subrec$n.o 2>&1 | head -1; done)" "subrec1.cpp:2: error: type 'S' does not provide a subscript operator
subrec2.cpp:2: error: type 'int' does not provide a subscript operator
subrec3.cpp:2: error: no viable overloaded operator[] for type 'int *'
subrec4.cpp:3: error: type 'S' does not provide a subscript operator"
check "C++: the operand pairs of a built-in binary operator that no guess of the reader's makes, in clang++'s words (1.6.28; [expr.mul], [expr.add], [expr.shift], [expr.bit.and]): * and / over a pointer, the integer operators over a pointer or a floating value, a pointer and a floating value, an integer less a pointer -- they were type(unknown), LLVM's words or built -- after the pairs that C++ takes, first" "$(n=0; for src in 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p - q); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p + 1); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(d / 2); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(x %% 3); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(x * 2.0); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p * 2); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p / 2); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p %% 2); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p & 1); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p | 1); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p ^ 1); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p << 1); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(d %% 2); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(d & 1); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(d << 1); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(1 << d); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(2 - p); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p + 1.5); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(p - 1.5); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(1.5 + p); return 0; }' 'int main() { int x = 0; int *p = &x, *q = &x; double d = 1.0; (void)(d >> 1); return 0; }'; do n=$((n + 1)); printf "$src\n" > pairs$n.cpp; "$ROOT/bin/cicilang++" -c pairs$n.cpp -o pairs$n.o 2>&1 | head -1; done)" "pairs6.cpp:1: error: invalid operands to binary expression ('int *' and 'int')
pairs7.cpp:1: error: invalid operands to binary expression ('int *' and 'int')
pairs8.cpp:1: error: invalid operands to binary expression ('int *' and 'int')
pairs9.cpp:1: error: invalid operands to binary expression ('int *' and 'int')
pairs10.cpp:1: error: invalid operands to binary expression ('int *' and 'int')
pairs11.cpp:1: error: invalid operands to binary expression ('int *' and 'int')
pairs12.cpp:1: error: invalid operands to binary expression ('int *' and 'int')
pairs13.cpp:1: error: invalid operands to binary expression ('double' and 'int')
pairs14.cpp:1: error: invalid operands to binary expression ('double' and 'int')
pairs15.cpp:1: error: invalid operands to binary expression ('double' and 'int')
pairs16.cpp:1: error: invalid operands to binary expression ('int' and 'double')
pairs17.cpp:1: error: invalid operands to binary expression ('int' and 'int *')
pairs18.cpp:1: error: invalid operands to binary expression ('int *' and 'double')
pairs19.cpp:1: error: invalid operands to binary expression ('int *' and 'double')
pairs20.cpp:1: error: invalid operands to binary expression ('double' and 'int *')
pairs21.cpp:1: error: invalid operands to binary expression ('double' and 'int')"
check "C++: a const place that a call gives, assigned, in clang++'s words by the function's name (1.6.28; [expr.ass]/1): a span of const elements, an operator[] and a member that give a const reference, a free function's, a compound assignment -- C's read-only words -- after a place that is not const, first" "$(n=0; for src in 'struct V { int &operator[](int i) { static int x = 0; return x; } };
int main() { V v; v[0] = 7; return v[0] - 7; }' '#include <span>
int main() { int a[2] = {1, 2}; std::span<const int> c(a); c[0] = 7; return c[0]; }' 'struct V { const int &operator[](int i) const { static int x = 0; return x; } };
int main() { V v; v[0] = 7; return 0; }' 'struct V { const int &at(int i) const { static int x = 0; return x; } };
int main() { V v; v.at(0) = 7; return 0; }' 'static const int &g() { static int x = 0; return x; }
int main() { g() = 3; return 0; }' 'struct V { const int &at(int i) const { static int x = 0; return x; } };
int main() { V v; v.at(0) += 7; return 0; }' 'struct V { const int &at(int i) const { static int x = 0; return x; } };
int main() { V v; V *p = &v; p->at(0) = 7; return 0; }'; do n=$((n + 1)); printf "$src\n" > constret$n.cpp; "$ROOT/bin/cicilang++" -std=c++20 -c constret$n.cpp -o constret$n.o 2>&1 | head -1; done)" "constret2.cpp:2: error: cannot assign to return value because function 'operator[]' returns a const value
constret3.cpp:2: error: cannot assign to return value because function 'operator[]' returns a const value
constret4.cpp:2: error: cannot assign to return value because function 'at' returns a const value
constret5.cpp:2: error: cannot assign to return value because function 'g' returns a const value
constret6.cpp:2: error: cannot assign to return value because function 'at' returns a const value
constret7.cpp:2: error: cannot assign to return value because function 'at' returns a const value"
check "C++: what 1.6.27's broken copies of its rules needed, in clang++'s words (1.6.28): an enumerator named as an argument, through a using of its namespace and to a template, and a function of an anonymous namespace named with its enclosing one and with :: -- which a name that nothing declares took without the guard of an enumerator and of a namespace's key --, then a percent sign written twice before a conversion, and a set with a member template that a plain member's count fits" "$(n=0; for src in 'namespace n { enum C { red = 3 }; }
static int f(int v) { return v; }
int main() { using namespace n; return f(red) - 3; }' 'template <class T> int g(T v) { return (int)v; }
enum C { red = 3 };
int main() { return g(red) - 3; }' 'namespace app { namespace { int hidden(int x) { return x; } } }
int main() { return app::hidden(1) - 1; }' 'namespace { int g(int x) { return x; } }
int main() { return ::g(1) - 1; }' '#include <cstdio>
static void v() {}
int main() { printf("%%%%d %%s", v()); return 0; }' 'struct S { static int m(int v) { return v; } template <class T> static int m(T a, T b) { return 0; } };
int main() { return S::m("x"); }' 'struct S { int m(int v) { return v; } template <class T> int m(T a, T b) { return 0; } int k() { return S::m("x"); } };
int main() { S s; return s.k(); }'; do n=$((n + 1)); printf "$src\n" > needs8$n.cpp; "$ROOT/bin/cicilang++" -std=c++20 -c needs8$n.cpp -o needs8$n.o 2>&1 | head -1; done)" "needs85.cpp:3: error: cannot pass expression of type 'void' to variadic function; expected type from format string was 'char *'
needs86.cpp:2: error: no matching function for call to 'm'
needs87.cpp:1: error: no matching member function for call to 'm'"
check "C++: a static member function's body names no this, no member that is not static and calls no member function that is not static, in clang++'s words (1.6.28; [class.static.mfct]/2, [expr.prim.this]/3, [expr.prim.id.general]/4): bare, named with its class or a base, defined out of its class, a member object and a pointer member called, a template's -- each built, the call with a null this -- after what C++ takes, first: an object's member, a static member, an unevaluated operand, a lambda's and a local class's own members, a pointer to member, a base's static member, an empty one's too" "$(n=0; for src in 'struct S { int m(int v) { return v; } static int k(S &s) { return s.m(1); } static int j() { S s; return S::k(s); } };
int main() { return S::j() - 1; }' 'struct S { static int n(int v) { return v; } static int k() { return S::n(1) + n(0); } };
int main() { return S::k() - 1; }' 'struct S { int m(int v) { return v; } int k() { return S::m(1); } };
int main() { S s; return s.k() - 1; }' 'struct S { int a = 1; static int k() { return sizeof(a); } };
int main() { return S::k() - 4; }' 'struct S { static int n; static int k() { return n + S::n; } };
int S::n = 1;
int main() { return S::k() - 2; }' 'struct S { int a = 1; static int k() { auto l = [](S &s) { return s.a; }; S s; return l(s); } };
int main() { return S::k() - 1; }' 'struct S { int a = 1; static int k() { struct L { int b = 2; int g() { return b + this->b; } }; L l; return l.g(); } };
int main() { return S::k() - 4; }' 'struct S { int a = 1; static int k() { return decltype(a)(1); } };
int main() { return S::k() - 1; }' 'struct S { int a = 1; static int k() { S s; return s.a + sizeof(S::a); } };
int main() { return S::k() - 5; }' 'template <class T> struct W { T a{}; int m() { return 1; } static int k() { W w; return w.m(); } };
int main() { return W<int>::k() - 1; }' 'struct S { int m() { return 1; } static int k() { return (&S::m != nullptr) ? 1 : 0; } };
int main() { return S::k() - 1; }' 'struct B { static int m(int v) { return v; } };
struct S : B { static int k() { return S::m(1) + m(1) + B::m(1); } };
int main() { return S::k() - 3; }' 'struct E { static int m(int v) { return v; } };
template <class C> struct H : protected E { static int k(C c) { return m((int)c); } };
int main() { return H<char>::k(1) - 1; }' 'struct S { int m(int v) { return v; } static int k() { return S::m(1); } };
int main() { return S::k() - 1; }' 'struct S { int m(int v) { return v; } static int k() { return m(1); } };
int main() { return S::k() - 1; }' 'struct S { int a = 1; static int k() { return a; } };
int main() { return S::k() - 1; }' 'struct S { int a = 1; static int k() { return S::a; } };
int main() { return S::k() - 1; }' 'struct S { int a = 1; static int k() { return this->a; } };
int main() { return S::k() - 1; }' 'struct B { int m(int v) { return v; } };
struct S : B { static int k() { return B::m(1); } };
int main() { return S::k() - 1; }' 'struct S { int m(int v) { return v; } static int k(); };
int S::k() { return m(1); }
int main() { return S::k() - 1; }' 'struct S { struct F { int operator()(int v) const { return v; } } f; static int k() { return f(1); } };
int main() { return S::k() - 1; }' 'template <class T> struct W { T a; static int k() { return a; } };
int main() { return W<int>::k(); }' 'struct S { virtual int m() { return 1; } static int k() { return m(); } };
int main() { return S::k() - 1; }' 'struct S { int (*p)(int) = nullptr; static int k() { return p(1); } };
int main() { return S::k(); }' 'struct B { int m(int v) { return v; } };
struct S : B { static int k() { return S::m(1); } };
int main() { return S::k() - 1; }'; do n=$((n + 1)); printf "$src\n" > statics$n.cpp; "$ROOT/bin/cicilang++" -std=c++20 -c statics$n.cpp -o statics$n.o 2>&1 | head -1; done)" "statics14.cpp:1: error: call to non-static member function without an object argument
statics15.cpp:1: error: call to non-static member function without an object argument
statics16.cpp:1: error: invalid use of member 'a' in static member function
statics17.cpp:1: error: invalid use of member 'a' in static member function
statics18.cpp:1: error: invalid use of 'this' outside of a non-static member function
statics19.cpp:2: error: call to non-static member function without an object argument
statics20.cpp:2: error: call to non-static member function without an object argument
statics21.cpp:1: error: invalid use of member 'f' in static member function
statics22.cpp:1: error: invalid use of member 'a' in static member function
statics23.cpp:1: error: call to non-static member function without an object argument
statics24.cpp:1: error: invalid use of member 'p' in static member function
statics25.cpp:2: error: call to non-static member function without an object argument"
check "C++: a lambda that captured no this, made in a member function, names no member of the class that is not static and calls none, in clang++'s words (1.6.29; [expr.prim.lambda.capture]/8): bare, with its class or a base, by this, and in a static member function's lambda the static function's words -- they were an undeclared name, a call with no object and the lowering's words -- after what C++ takes, first: a captured this by name, by reference and by copy, a static member, a parameter and a local of the name, an object handed in, an init-capture" "$(n=0; for src in 'struct S { int a = 1; int m() { return 1; } int k() { auto l = [this] { return m() + a + this->a + S::m(); }; return l(); } };
int main() { S s; return s.k() - 4; }' 'struct S { int a = 1; int m() { return 1; } int k() { auto l = [&] { return m() + a; }; return l(); } };
int main() { S s; return s.k() - 2; }' 'struct S { int a = 1; int m() { return 1; } int k() { auto l = [=] { return m() + a; }; return l(); } };
int main() { S s; return s.k() - 2; }' 'struct S { static int n() { return 1; } int k() { auto l = [] { return n() + S::n(); }; return l(); } };
int main() { S s; return s.k() - 2; }' 'struct S { int a = 1; int k() { auto l = [](int a) { return a; }; return l(2); } };
int main() { S s; return s.k() - 2; }' 'struct S { int a = 1; int k() { auto l = [] { int a = 3; return a; }; return l(); } };
int main() { S s; return s.k() - 3; }' 'struct S { int a = 1; int k() { auto l = [](S &s) { return s.a; }; return l(*this); } };
int main() { S s; return s.k() - 1; }' 'struct S { int a = 1; int k() { auto l = [x = a] { return x; }; return l(); } };
int main() { S s; return s.k() - 1; }' 'struct S { int m() { return 1; } int k() { auto l = [] { return m(); }; return l(); } };
int main() { S s; return s.k() - 1; }' 'struct S { int a = 1; int k() { auto l = [] { return a; }; return l(); } };
int main() { S s; return s.k() - 1; }' 'struct S { int m() { return 1; } int k() { auto l = [] { return S::m(); }; return l(); } };
int main() { S s; return s.k() - 1; }' 'struct S { int a = 1; int k() { auto l = [] { return this->a; }; return l(); } };
int main() { S s; return s.k() - 1; }' 'struct B { int m() { return 1; } };
struct S : B { int k() { auto l = [] { return B::m(); }; return l(); } };
int main() { S s; return s.k() - 1; }' 'struct S { int a = 1; static int k() { auto l = [] { return a; }; return l(); } };
int main() { return S::k() - 1; }' 'struct S { int m() { return 1; } static int k() { auto l = [] { return m(); }; return l(); } };
int main() { return S::k() - 1; }' 'struct S { int a = 1; static int k() { auto l = [] { return this->a; }; return l(); } };
int main() { return S::k() - 1; }'; do n=$((n + 1)); printf "$src\n" > nocap$n.cpp; "$ROOT/bin/cicilang++" -std=c++20 -c nocap$n.cpp -o nocap$n.o 2>&1 | head -1; done)" "nocap9.cpp:1: error: 'this' cannot be implicitly captured in this context
nocap10.cpp:1: error: 'this' cannot be implicitly captured in this context
nocap11.cpp:1: error: 'this' cannot be implicitly captured in this context
nocap12.cpp:1: error: 'this' cannot be implicitly captured in this context
nocap13.cpp:2: error: 'this' cannot be implicitly captured in this context
nocap14.cpp:1: error: invalid use of member 'a' in static member function
nocap15.cpp:1: error: call to non-static member function without an object argument
nocap16.cpp:1: error: invalid use of 'this' outside of a non-static member function"
check "C++: an enumeration given a pointer, and a member initializer of a scalar, in clang++'s words (1.6.29; [conv.ptr]/1, [class.base.init]/7): an assignment, an initializer, a return and a member's -- the enumeration's built, and a member's had an assignment's words -- after what C++ takes, first: an enumerator, a cast, members from their own types, a null pointer constant" "$(n=0; for src in 'enum E { A, B };
int main() { int x = 0; E e = A; e = B; int *p = &x; return e - 1 + (p != 0) - 1; }' 'enum E { A, B };
int main() { E e = (E)1; return e - 1; }' 'struct S { int v; double d; long l; S(int a) : v(a), d(a), l(a) {} };
int main() { S s(2); return s.v - 2; }' 'struct S { int *p; S() : p(0) {} };
int main() { S s; return s.p != 0; }' 'struct S { int *p; S() : p(nullptr) {} };
int main() { S s; return s.p != 0; }' 'enum E { A, B };
int main() { int x = 0; E e = A; e = &x; return 0; }' 'enum E { A, B };
int main() { int x = 0; E e = &x; return 0; }' 'enum class F : int { a };
int main() { int x = 0; F f = &x; return 0; }' 'enum E { A };
int main() { int v[2] = {0, 0}; E e = A; e = v; return 0; }' 'enum E { A, B };
static E f(int *p) { return p; }
int main() { int x = 0; return f(&x); }' 'struct S { int *p; int v; S(int a) : p(a), v(0) {} };
int main() { S s(1); return 0; }' 'struct S { int v; int *q; S(int *a) : v(a), q(0) {} };
int main() { int x; S s(&x); return 0; }' 'struct S { int *p; S(char *q) : p(q) {} };
int main() { char c[4]; S s(c); return 0; }' 'struct S { long v; S(int *q) : v(q) {} };
int main() { int x = 0; S s(&x); return 0; }' 'enum E { A, B };
struct S { E e; S(int *q) : e(q) {} };
int main() { int x = 0; S s(&x); return 0; }'; do n=$((n + 1)); printf "$src\n" > enumptr$n.cpp; "$ROOT/bin/cicilang++" -c enumptr$n.cpp -o enumptr$n.o 2>&1 | head -1; done)" "enumptr6.cpp:2: error: incompatible pointer to integer conversion assigning to 'E' from 'int *'
enumptr7.cpp:2: error: cannot initialize a variable of type 'E' with an rvalue of type 'int *'
enumptr8.cpp:2: error: cannot initialize a variable of type 'F' with an rvalue of type 'int *'
enumptr9.cpp:2: error: assigning to 'E' from incompatible type 'int[2]'
enumptr10.cpp:2: error: cannot initialize return object of type 'E' with an lvalue of type 'int *'
enumptr11.cpp:1: error: cannot initialize a member subobject of type 'int *' with an lvalue of type 'int'
enumptr12.cpp:1: error: cannot initialize a member subobject of type 'int' with an lvalue of type 'int *'
enumptr13.cpp:1: error: cannot initialize a member subobject of type 'int *' with an lvalue of type 'char *'
enumptr14.cpp:1: error: cannot initialize a member subobject of type 'long' with an lvalue of type 'int *'
enumptr15.cpp:2: error: cannot initialize a member subobject of type 'E' with an lvalue of type 'int *'"
check "C++: a const member function writes no member of a base that is not the primary one but a mutable one, in clang++'s words (1.6.29; [dcl.stc]/9, [class.this]/1): bare, through this, of that base's own base, of a virtual base -- a plain one's write built, and a mutable one was found nowhere -- after the mutable ones, first" "$(n=0; for src in 'struct A { int x = 0; virtual ~A() {} };
struct B { mutable int m = 0; int n = 0; };
struct C : A, B { void f() const { m = 1; } };
int main() { C c; c.f(); return c.m - 1; }' 'struct A { int x = 0; };
struct B { mutable int m = 0; int n = 0; };
struct C : A, B { void f() const { m = 2; this->m += 1; } };
int main() { C c; c.f(); return c.m - 3; }' 'struct A { int x = 0; };
struct B { int n = 0; mutable int m = 0; };
struct B2 : B {};
struct C : A, B2 { void f() const { m = 1; } };
int main() { C c; c.f(); return c.m - 1; }' 'struct V { int n = 0; mutable int m = 0; };
struct C : virtual V { void f() const { m = 1; } };
int main() { C c; c.f(); return c.m - 1; }' 'struct A { int x = 0; virtual ~A() {} };
struct B { mutable int m = 0; int n = 0; };
struct C : A, B { void f() const { n = 1; } };
int main() { C c; c.f(); return 0; }' 'struct A { int x = 0; };
struct B { mutable int m = 0; int n = 0; };
struct C : A, B { void f() const { this->n = 1; } };
int main() { C c; c.f(); return 0; }' 'struct A { int x = 0; };
struct B { int n = 0; mutable int m = 0; };
struct B2 : B {};
struct C : A, B2 { void f() const { n = 1; } };
int main() { C c; c.f(); return 0; }' 'struct V { int n = 0; mutable int m = 0; };
struct C : virtual V { void f() const { n = 1; } };
int main() { C c; c.f(); return 0; }'; do n=$((n + 1)); printf "$src\n" > mutbase$n.cpp; "$ROOT/bin/cicilang++" -c mutbase$n.cpp -o mutbase$n.o 2>&1 | head -1; done)" "mutbase5.cpp:3: error: cannot assign to non-static data member within const member function 'f'
mutbase6.cpp:3: error: cannot assign to non-static data member within const member function 'f'
mutbase7.cpp:4: error: cannot assign to non-static data member within const member function 'f'
mutbase8.cpp:2: error: cannot assign to non-static data member within const member function 'f'"
check "C++: a void value of an overloaded function, of a namespace's and of a member's, as an argument, is the overloads' words (1.6.29, which holds 1.6.27's record closed)" "$(n=0; for src in 'static void h(int) {}
static void h(double) {}
static int g(int a) { return a; }
int main() { return g(h(1)); }' 'static void h(int) {}
static void h(double) {}
static int g(int a) { return a; }
static int g(double a) { return 2; }
int main() { return g(h(1.0)); }' 'namespace n { void h(int) {} void h(double) {} }
static int g(int a) { return a; }
int main() { return g(n::h(1)); }' 'struct S { void h(int) {} void h(double) {} };
static int g(int a) { return a; }
int main() { S s; return g(s.h(1)); }'; do n=$((n + 1)); printf "$src\n" > voidov$n.cpp; "$ROOT/bin/cicilang++" -c voidov$n.cpp -o voidov$n.o 2>&1 | head -1; done)" "voidov1.cpp:4: error: no matching function for call to 'g'
voidov2.cpp:5: error: no matching function for call to 'g'
voidov3.cpp:3: error: no matching function for call to 'g'
voidov4.cpp:3: error: no matching function for call to 'g'"
check "C++: a builtin that is only called, named as an auto's initializer, in clang++'s words (1.6.29): it was auto(f) -- after a function's name, first" "$(n=0; for src in 'static void h() {}
int main() { auto f = h; f(); return 0; }' 'int main() { auto f = __builtin_trap; (void)f; return 0; }' 'int main() { auto f = __builtin_unreachable; (void)f; return 0; }' 'int main() { auto f = __builtin_debugtrap; (void)f; return 0; }'; do n=$((n + 1)); printf "$src\n" > bvalue$n.cpp; "$ROOT/bin/cicilang++" -c bvalue$n.cpp -o bvalue$n.o 2>&1 | head -1; done)" "bvalue2.cpp:1: error: builtin functions must be directly called
bvalue3.cpp:1: error: builtin functions must be directly called
bvalue4.cpp:1: error: builtin functions must be directly called"
check "C: a call of a function that GCC's error attribute marks, in clang's words (1.6.29): before and after the declarator, its __error__ spelling -- the attribute was dropped and the call built -- after a warning attribute and the function's name as a value, first" "$(n=0; for src in 'void f(void) __attribute__((warning("x")));
void f(void) {}
int main(void) { f(); return 0; }' 'void f(void) __attribute__((error("x")));
int main(void) { void (*p)(void) = f; (void)p; return 0; }' 'void f(void) __attribute__((error("do not call")));
int main(void) {
  f();
  return 0;
}' '__attribute__((__error__("no"))) int g(int);
int main(void) { return g(1); }' '__attribute__((error("x"))) void f(void);
int main(void) {
  f();
  return 0;
}'; do n=$((n + 1)); printf "$src\n" > errattr$n.c; "$CICILI" -c errattr$n.c -o errattr$n.o 2>&1 | head -1; done)" "errattr3.c:3: error: call to 'f' declared with 'error' attribute: do not call
errattr4.c:2: error: call to 'g' declared with 'error' attribute: no
errattr5.c:3: error: call to 'f' declared with 'error' attribute: x"
check "C++: a void value cast to a decltype type of a name names the type as written, in clang++'s words (1.6.30): a class's and a scalar's -- they named the type it gives -- after the casts of values, first" "$(n=0; for src in 'struct M { int a; };
int main() { M mm{2}; auto x = decltype(mm)(mm); return x.a - 2; }' 'int main() { int k = 0; auto x = decltype(k)(5); return x - 5; }' 'struct M { int a; };
static void f() {}
int main() { M mm{1}; auto x = decltype(mm)(f()); (void)x; return 0; }' 'static void f() {}
int main() { int k = 0; auto x = decltype(k)(f()); (void)x; return 0; }' 'static void f() {}
int main() { double d = 0; auto x = decltype(d)(f()); (void)x; return 0; }'; do n=$((n + 1)); printf "$src\n" > dcast$n.cpp; "$ROOT/bin/cicilang++" -c dcast$n.cpp -o dcast$n.o 2>&1 | head -1; done)" "dcast3.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'decltype(mm)' (aka 'M')
dcast4.cpp:2: error: functional-style cast from 'void' to 'decltype(k)' (aka 'int') is not allowed
dcast5.cpp:2: error: functional-style cast from 'void' to 'decltype(d)' (aka 'double') is not allowed"
check "C: a block's enumerator used after its block is a name that nothing declares, in clang's words (1.6.30; C17 6.2.1/4): in another function, after an inner block, an enum's named one -- each built with its value -- after a block's that shadows the file's and a case's, first" "$(n=0; for src in 'enum { B = 5 };
static int f(void) { enum { A = 1, B = 2 }; return B; }
int main(void) { return B + f() - 7; }' 'static int f(int x) { switch (x) { case 1: { enum { K = 3 }; return K; } } return 0; }
int main(void) { return f(1) - 3; }' 'static int f(void) { enum { A = 1, B = 2 }; return A; }
int main(void) { return B + f() - 3; }' 'static int f(void) { { enum { A = 1, B = 2 }; } return B; }
int main(void) { return f(); }' 'static int f(void) { enum E { A = 1 } e = A; return e; }
int main(void) { return A; }'; do n=$((n + 1)); printf "$src\n" > blkenum$n.c; "$CICILI" -fsyntax-only blkenum$n.c 2>&1 | head -1; done)" "blkenum3.c:2: error: use of undeclared identifier 'B'
blkenum4.c:1: error: use of undeclared identifier 'B'
blkenum5.c:2: error: use of undeclared identifier 'A'"
check "C: a library function that nothing declares, past the forty of 1.6.24, in clang's words and its header's note (1.6.30): math.h's, ctype.h's, stdlib.h's -- they had the words of a function that is no library's -- after a declared one, first" "$(n=0; for src in '#include <math.h>
int main(void) { return (int)log(1.0); }' 'int main(void) { return (int)log(1.0); }' 'int main(void) { return isdigit(48) ? 0 : 1; }' 'int main(void) { return (int)sqrt(4.0) - 2; }' 'int main(void) { return abs(-1) - 1; }' 'int main(void) { return toupper(97) - 65; }' 'int main(void) { return (int)floorf(1.5f) - 1; }' 'int main(void) { exit(0); }'; do n=$((n + 1)); printf "$src\n" > libfn$n.c; "$CICILI" -fsyntax-only libfn$n.c 2>&1 | head -1; done)" "libfn2.c:1: error: call to undeclared library function 'log' with type 'double (double)'; ISO C99 and later do not support implicit function declarations
libfn3.c:1: error: call to undeclared library function 'isdigit' with type 'int (int)'; ISO C99 and later do not support implicit function declarations
libfn4.c:1: error: call to undeclared library function 'sqrt' with type 'double (double)'; ISO C99 and later do not support implicit function declarations
libfn5.c:1: error: call to undeclared library function 'abs' with type 'int (int)'; ISO C99 and later do not support implicit function declarations
libfn6.c:1: error: call to undeclared library function 'toupper' with type 'int (int)'; ISO C99 and later do not support implicit function declarations
libfn7.c:1: error: call to undeclared library function 'floorf' with type 'float (float)'; ISO C99 and later do not support implicit function declarations
libfn8.c:1: error: call to undeclared library function 'exit' with type 'void (int) __attribute__((noreturn))'; ISO C99 and later do not support implicit function declarations"
check "C++: the address of a compound literal is refused in clang++'s words (1.6.31): a struct's, a scalar's, an array's, a const one's, a typedef's and an alias's with their (aka ...), a struct's written so, an argument's, a union's and an enumeration's -- each built -- after an array's that decays and a member's value, first" "$(n=0; for src in 'struct p { int x, y; };
int main() { int *a = (int[]){ 1, 2 }; return a[0] + ((p){ 1, 2 }).x - 2; }' 'struct p { int x, y; };
int main() { p *q = &(p){ 3, 4 }; return q->x; }' 'int main() { int *e = &(int){ 7 }; return *e; }' 'int main() { int (*a)[2] = &(int[2]){ 1, 2 }; return (*a)[0]; }' 'struct p { int x, y; };
int main() { const p *r = &(const p){ 5, 6 }; return r->y; }' 'struct p { int x, y; };
typedef struct p P;
int main() { P *q = &(P){ 3, 4 }; return q->x; }' 'struct p { int x, y; };
using U = p;
int main() { U *q = &(U){ 3, 4 }; return q->x; }' 'struct p { int x, y; };
int main() { struct p *q = &(struct p){ 3, 4 }; return q->x; }' 'int main() { long *l = &(long){ 9 }; return (int) *l; }' 'struct p { int x, y; };
static int s(const p *a) { return a->x; }
int main() { return s(&(p){ 1, 2 }); }' 'union u { int i; float f; };
int main() { u *q = &(u){ 3 }; return q->i; }' 'enum E { A, B };
int main() { E *e = &(E){ B }; return *e; }' 'struct p { int x, y; };
int main() { const struct p *q = &(const struct p){ 3, 4 }; return q->x; }' 'union u { int i; float f; };
int main() { union u *q = &(union u){ 3 }; return q->i; }'; do n=$((n + 1)); printf "$src\n" > caddr$n.cpp; "$ROOT/bin/cicilang++" -c caddr$n.cpp -o caddr$n.o 2>&1 | head -1; done)" "caddr2.cpp:2: error: taking the address of a temporary object of type 'p'
caddr3.cpp:1: error: cannot take the address of an rvalue of type 'int'
caddr4.cpp:1: error: taking the address of a temporary object of type 'int[2]'
caddr5.cpp:2: error: taking the address of a temporary object of type 'const p'
caddr6.cpp:3: error: taking the address of a temporary object of type 'P' (aka 'struct p')
caddr7.cpp:3: error: taking the address of a temporary object of type 'U' (aka 'p')
caddr8.cpp:2: error: taking the address of a temporary object of type 'struct p'
caddr9.cpp:1: error: cannot take the address of an rvalue of type 'long'
caddr10.cpp:3: error: taking the address of a temporary object of type 'p'
caddr11.cpp:2: error: taking the address of a temporary object of type 'u'
caddr12.cpp:2: error: cannot take the address of an rvalue of type 'E'
caddr13.cpp:2: error: taking the address of a temporary object of type 'const struct p'
caddr14.cpp:2: error: taking the address of a temporary object of type 'union u'"
check "C++: an unevaluated operand of a lambda that captured no this names a member, and this in a static member function's lambda stays refused (1.6.31): sizeof(this->a) there, an evaluated member, a decltype beside an evaluated one -- after sizeof(a) in a static member function's lambda, first" "$(n=0; for src in 'struct S { long a; static int f() { auto g = [] { return (int) sizeof(a); }; return g(); } };
int main() { return S::f() - 8; }' 'struct S { long a; static int f() { auto g = [] { return (int) sizeof(this->a); }; return g(); } };
int main() { return S::f() - 8; }' 'struct S { long a; int f() { auto g = [] { return (int) a; }; return g(); } };
int main() { S s{}; return s.f(); }' 'struct S { long a; int f() { auto g = [] { decltype(a) z = a; return (int) z; }; return g(); } };
int main() { S s{}; return s.f(); }'; do n=$((n + 1)); printf "$src\n" > luneval$n.cpp; "$ROOT/bin/cicilang++" -c luneval$n.cpp -o luneval$n.o 2>&1 | head -1; done)" "luneval2.cpp:1: error: invalid use of 'this' outside of a non-static member function
luneval3.cpp:1: error: 'this' cannot be implicitly captured in this context
luneval4.cpp:1: error: 'this' cannot be implicitly captured in this context"
check "C++: the forms that catch 1.6.28's broken copies (1.6.32): decltype and alignof of a member in a static member function's body, unevaluated, and a base's conversion function, which fits a scalar parameter, first; a pointer to another pointer type for a pointer to a pointer, and a namespace's object beside its extern C block's function of its name, each refused" "$(n=0; for src in 'struct S { long a; static int f() { decltype(a + 1) z = 1; return (int) z; } };
int main() { return S::f() - 1; }' 'struct S { long a; static int f() { return (int) alignof(decltype(a)); } };
int main() { return S::f() - 8; }' 'struct B { operator int() const { return 3; } };
struct D : B {};
static int f(int v) { return v; }
int main() { D d; return f(d) - 3; }' 'static int f(int **p) { return p != 0; }
int main() { char *c = 0; return f(&c); }' 'namespace n { extern "C" { int t(); } int t; }
int main() { return 0; }'; do n=$((n + 1)); printf "$src\n" > bcopy$n.cpp; "$ROOT/bin/cicilang++" -c bcopy$n.cpp -o bcopy$n.o 2>&1 | head -1; done)" "bcopy4.cpp:2: error: no matching function for call to 'f'
bcopy5.cpp:1: error: redefinition of 't' as different kind of symbol"
check "C++: a header of the program's own whose name clashes inside it is refused at the header's line, the header named, in clang++'s words (1.6.32, 1.6.42; 1.6.28's broken copies) -- through 1.6.41 the header kept its first kind and the file's own declaration of the other kind was refused at its line, and before 1.6.32 a header's later kind was taken and the file built" "$(printf 'int t(void);\nint t;\n' > kindh.h; printf '#include "kindh.h"\nint t;\nint main() { return 0; }\n' > kindh1.cpp; "$ROOT/bin/cicilang++" -c kindh1.cpp -o kindh1.o 2>&1 | grep error | head -1)" "./kindh.h:2: error: redefinition of 't' as different kind of symbol"
check "C: a bracketed attribute's error and unavailable are read in their own scope alone, as clang reads them (1.6.33): gnu::error, its __error__ and __gnu__ spellings, clang::unavailable and _Clang's, each a call refused -- after the same words with no scope or another one, which clang ignores and which were each a call refused, first" "$(n=0; for src in '[[error("boom")]] void f(void);
void f(void) {}
int main(void) { f(); return 0; }' '[[clang::error("boom")]] void f(void);
void f(void) {}
int main(void) { f(); return 0; }' '[[unavailable("no")]] void f(void);
void f(void) {}
int main(void) { f(); return 0; }' '[[gnu::unavailable("no")]] void f(void);
void f(void) {}
int main(void) { f(); return 0; }' '[[gnu::error("boom")]] void f(void);
int main(void) { f(); return 0; }' '[[gnu::__error__("boom")]] void f(void);
int main(void) { f(); return 0; }' '[[__gnu__::error("boom")]] void f(void);
int main(void) { f(); return 0; }' '[[clang::unavailable("no")]] void f(void);
int main(void) { f(); return 0; }' '[[_Clang::unavailable]] void f(void);
int main(void) { f(); return 0; }'; do n=$((n + 1)); printf "$src\n" > scattr$n.c; "$CICILI" -std=c23 -c scattr$n.c -o scattr$n.o 2>&1 | head -1; done)" "scattr5.c:2: error: call to 'f' declared with 'error' attribute: boom
scattr6.c:2: error: call to 'f' declared with 'error' attribute: boom
scattr7.c:2: error: call to 'f' declared with 'error' attribute: boom
scattr8.c:2: error: 'f' is unavailable: no
scattr9.c:2: error: 'f' is unavailable"
check "C++: a void value through a local's or a member's pointer or reference to a function, as an argument, in clang++'s words (1.6.27): a bare name's overloading takes no candidate, where the lowering worded it as a parameter's initialization, and a qualified name's and an ellipsis's keep their words" "$(n=0; for src in 'static void h() {}
static int g(int a) { return a; }
int main() { void (*fp)() = h; return g(fp()); }' 'static void h() {}
static int g(int a) { return a; }
int main() { void (&fr)() = h; return g(fr()); }' 'static void h() {}
static int g(int a) { return a; }
struct S { void (*p)(); };
int main() { S s{h}; return g(s.p()); }' 'static void h() {}
static int g(int a) { return a; }
static int g(double a) { return 2; }
int main() { void (*fp)() = h; return g(fp()); }' 'static void h() {}
namespace n { int g(int a); }
int main() { void (*fp)() = h; return n::g(fp()); }' '#include <cstdio>
static void h() {}
int main() { void (*fp)() = h; std::printf("x", fp()); return 0; }'; do n=$((n + 1)); printf "$src\n" > voidptr$n.cpp; "$ROOT/bin/cicilang++" -c voidptr$n.cpp -o voidptr$n.o 2>&1 | head -1; done)" "voidptr1.cpp:3: error: no matching function for call to 'g'
voidptr2.cpp:3: error: no matching function for call to 'g'
voidptr3.cpp:4: error: no matching function for call to 'g'
voidptr4.cpp:4: error: no matching function for call to 'g'
voidptr5.cpp:3: error: cannot initialize a parameter of type 'int' with an rvalue of type 'void'
voidptr6.cpp:3: error: cannot pass expression of type 'void' to variadic function"
check "C++: a void value through printf's ellipsis has the format's type in clang++'s words (1.6.27): its conversion by its place, a length, a width and a precision, a star's int, at printf's, fprintf's and snprintf's places of the format, and none past the conversions" "$(n=0; for src in '#include <cstdio>
static void f() {}
int main() { std::printf("%%d", f()); return 0; }' '#include <cstdio>
static void f() {}
int main() { std::printf("%%s %%ld", "a", f()); return 0; }' '#include <cstdio>
static void f() {}
int main() { printf("%%f %%p", 1.0, f()); return 0; }' '#include <cstdio>
static void f() {}
int main() { char b[8]; std::snprintf(b, 8, "%%u", f()); return 0; }' '#include <cstdio>
static void f() {}
int main() { std::fprintf(stderr, "%%c", f()); return 0; }' '#include <cstdio>
static void f() {}
int main() { std::printf("%%5.2hd %%zu %%llx", 1, (unsigned long)2, f()); return 0; }' '#include <cstdio>
static void f() {}
int main() { std::printf("%%*d %%Lf", 3, 4, f()); return 0; }' '#include <cstdio>
static void f() {}
int main() { std::printf("x", f()); return 0; }'; do n=$((n + 1)); printf "$src\n" > voidfmt$n.cpp; "$ROOT/bin/cicilang++" -c voidfmt$n.cpp -o voidfmt$n.o 2>&1 | head -1; done)" "voidfmt1.cpp:3: error: cannot pass expression of type 'void' to variadic function; expected type from format string was 'int'
voidfmt2.cpp:3: error: cannot pass expression of type 'void' to variadic function; expected type from format string was 'long'
voidfmt3.cpp:3: error: cannot pass expression of type 'void' to variadic function; expected type from format string was 'void *'
voidfmt4.cpp:3: error: cannot pass expression of type 'void' to variadic function; expected type from format string was 'unsigned int'
voidfmt5.cpp:3: error: cannot pass expression of type 'void' to variadic function; expected type from format string was 'int'
voidfmt6.cpp:3: error: cannot pass expression of type 'void' to variadic function; expected type from format string was 'unsigned long long'
voidfmt7.cpp:3: error: cannot pass expression of type 'void' to variadic function; expected type from format string was 'long double'
voidfmt8.cpp:3: error: cannot pass expression of type 'void' to variadic function"
check "C++: what 1.6.26's broken copies of its rules needed, in clang++'s words (1.6.27): a member template named with its class that none takes, a set of a plain member and a template, a namespace's template and the global one called with no argument, an unavailable declaration whose name another namespace shares, and an unavailable definition among overloads" "$(n=0; for src in 'struct S { template <class T> int t(T a); int k() { return S::t(); } };
int main() { return 0; }' 'struct S { template <class T> static int g(T a); };
int main() { return S::g(1, 2); }' 'struct S { template <class T> static int g(T a); };
int main() { return S::g(); }' 'struct S {
  static int h(int a) { return a; }
  template <class T> static int h(T a, T b) { return (int)(a + b); }
};
int main() { return S::h(1, 2, 3); }' 'namespace n { template <class T> void f(T a) {} }
int main() { n::f(); }' 'template <class T> void f(T a) {}
int main() { ::f(); }' 'namespace a { int h() { return 1; } }
namespace b { int h() __attribute__((unavailable("no"))); }
int main() { return b::h(); }' '[[clang::unavailable("y")]] int g(int) { return 1; }
int g(double) { return 2; }
int main() { return g(1); }'; do n=$((n + 1)); printf "$src\n" > need$n.cpp; "$ROOT/bin/cicilang++" -c need$n.cpp -o need$n.o 2>&1 | head -1; done)" "need1.cpp:1: error: no matching member function for call to 't'
need2.cpp:2: error: no matching function for call to 'g'
need3.cpp:2: error: no matching function for call to 'g'
need4.cpp:5: error: no matching function for call to 'h'
need5.cpp:2: error: no matching function for call to 'f'
need6.cpp:2: error: no matching function for call to 'f'
need7.cpp:3: error: 'h' is unavailable: no
need8.cpp:3: error: 'g' is unavailable: y"
check "C++: a functional cast through a class's typedef of a pointer to a floating type, its words by the cast's spelling and the target by its type, where clang++ spells the typedef, 'D' (aka 'double') (1.6.27, Not done)" "$(printf 'struct S { typedef double D; static int f(int *q) { return (int)D(q); } };\nint main() { return 0; }\n' > tcall.cpp; "$ROOT/bin/cicilang++" -c tcall.cpp -o tcall.o 2>&1 | head -1)" "tcall.cpp:1: error: functional-style cast from 'int *' to 'double' is not allowed"
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
nodecl4.c:2: error: call to undeclared library function 'printf' with type 'int (const char *, ...)'; ISO C99 and later do not support implicit function declarations
nodecl5.c:3: error: not lowered yet: call(id('B')) (function main)
nodecl6.c:3: error: use of undeclared identifier 'nowhere'"
check "C++: a name that nothing declares, in clang++'s words (1.6.27): a call, a value, an operand, a member's body, a place, an argument and sizeof's operand are use of undeclared identifier, which was undeclared(nowhere) and sizeof(id(nowhere)), and a qualified name no member named in a namespace, the global one, a nested one and std -- std::ref with no <functional> among them, as libc++ 23 has it -- and a template's argument, which was cannot_deduce at no line" "$(n=0; for src in 'int main() { return nowhere(1); }' 'int main() { return nowhere; }' 'int main() { int x = nowhere + 1; return x; }' 'struct S { int k() { return nowhere(2); } };
int main() { return 0; }' 'int main() { nowhere = 3; return 0; }' 'int f(int a) { return a; }
int main() { return f(nowhere); }' 'int main() { return sizeof(nowhere); }' 'namespace n { int f(); }
int main() { return n::nowhere(); }' 'int main() { return ::nowhere(); }' 'namespace a { namespace b { int f(); } }
int main() { return a::b::nowhere(); }' '#include <cstdio>
int main() { return std::nothere(1); }' '#include <utility>
int main() { int c = 1; auto r = std::ref(c); return r; }' 'template <class T> int t(T a) { return a; }
int main() { return t(nowhere); }'; do n=$((n + 1)); printf "$src\n" > undecl$n.cpp; "$ROOT/bin/cicilang++" -c undecl$n.cpp -o undecl$n.o 2>&1 | head -1; done)" "undecl1.cpp:1: error: use of undeclared identifier 'nowhere'
undecl2.cpp:1: error: use of undeclared identifier 'nowhere'
undecl3.cpp:1: error: use of undeclared identifier 'nowhere'
undecl4.cpp:1: error: use of undeclared identifier 'nowhere'
undecl5.cpp:1: error: use of undeclared identifier 'nowhere'
undecl6.cpp:2: error: use of undeclared identifier 'nowhere'
undecl7.cpp:1: error: use of undeclared identifier 'nowhere'
undecl8.cpp:2: error: no member named 'nowhere' in namespace 'n'
undecl9.cpp:1: error: no member named 'nowhere' in the global namespace
undecl10.cpp:2: error: no member named 'nowhere' in namespace 'a::b'
undecl11.cpp:2: error: no member named 'nothere' in namespace 'std'
undecl12.cpp:2: error: no member named 'ref' in namespace 'std'
undecl13.cpp:2: error: use of undeclared identifier 'nowhere'"
check "a unit so refused is not kept: a second build is refused again, and the file put right builds and runs (1.1.2)" "$(printf 'int g0;\nstatic int f(void) { return later(2); }\nstatic int later(int a) { return a; }\nint main(void) { return f(); }\n' > undeclkb.c; "$CICILI" -c undeclkb.c -o undeclkb.o 2>&1 | head -1; "$CICILI" -c undeclkb.c -o undeclkb.o 2>&1 | head -1; sleep 1; printf 'int g0;\nstatic int later(int a);\nstatic int f(void) { return later(2); }\nstatic int later(int a) { return a; }\nint main(void) { return f(); }\n' > undeclkb.c; "$CICILI" undeclkb.c -o undeclkb && ./undeclkb; echo "exit $?")" "undeclkb.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
undeclkb.c:2: error: call to undeclared function 'later'; ISO C99 and later do not support implicit function declarations
exit 2"
# THE OPERANDS THAT AN OPERATOR TAKES (1.6.1; C17 6.5.3.3/1, 6.5.5/2, 6.5.6/2 and /3, 6.5.7/2, 6.5.10/2 to 6.5.12/2): each
# form that C refuses is refused in clang's words at its line -- a pointer, a floating value, a record or an array where
# an operator takes an integer or an arithmetic value, two pointers added, an integer less a pointer, two pointers to
# incompatible types subtracted, the compound assignments of the same pairs, and `-', `+' and `~' over a pointer and `~'
# over a floating value. Through 1.6.0 each was lowered over the operands' bits with no word
ops_pre='struct P { int x; };\nint main(void) { int k = 3, a[3] = { 1, 2, 3 }; double d = 2.5; char c = 1; const char *s = "x"; int *p = &k, *q = &k; char *r = 0; struct P sp = { 1 }; void (*fp)(void) = 0;'
check "an operator over operands that C refuses is refused in clang's words at the line of the operator (1.6.1): a shift by a pointer, a pointer in a shift, a product, a quotient, a remainder and a bit operation, two pointers added, an integer less a pointer, two pointers to incompatible types subtracted, a pointer and a double, a double in a remainder, a shift and a bit operation, a unary -, ~ and + over a pointer, ~ over a double, the compound assignments, an array, a char shifted by a pointer, a function pointer and a struct" "$(n=0; for body in 'int x = 1 << s;' 'long x = (long)(p << 1);' 'long x = (long)(p >> k);' 'long x = (long)(p * 2);' 'long x = (long)(2 * p);' 'long x = (long)(p / 2);' 'long x = (long)(p % 2);' 'long x = (long)(p & 1);' 'long x = (long)(p | 1);' 'long x = (long)(p ^ 1);' 'long x = (long)(p + q);' 'long x = (long)(1 - p);' 'long x = (long)(p - r);' 'long x = (long)(p + d);' 'double x = d % 2;' 'double x = d << 1;' 'int x = 1 & d;' 'long x = (long)-p;' 'long x = (long)~p;' 'double x = ~d;' 'long x = (long)+p;' 'p *= 2;' 'p <<= 1;' 'p += q;' 'p -= d;' 'long x = (long)(a * 2);' 'long x = (long)(a % 2);' 'long x = (long)(c << s);' 'long x = (long)(fp * 2);' 'int x = sp * 2;' 'int x = sp + 1;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$ops_pre" "$body" > ops$n.c; "$CICILI" -std=c17 -fsyntax-only ops$n.c 2>&1 | head -1; done)" "ops1.c:3: error: invalid operands to binary expression ('int' and 'const char *')
ops2.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops3.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops4.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops5.c:3: error: invalid operands to binary expression ('int' and 'int *')
ops6.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops7.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops8.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops9.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops10.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops11.c:3: error: invalid operands to binary expression ('int *' and 'int *')
ops12.c:3: error: invalid operands to binary expression ('int' and 'int *')
ops13.c:3: error: 'int *' and 'char *' are not pointers to compatible types
ops14.c:3: error: invalid operands to binary expression ('int *' and 'double')
ops15.c:3: error: invalid operands to binary expression ('double' and 'int')
ops16.c:3: error: invalid operands to binary expression ('double' and 'int')
ops17.c:3: error: invalid operands to binary expression ('int' and 'double')
ops18.c:3: error: invalid argument type 'int *' to unary expression
ops19.c:3: error: invalid argument type 'int *' to unary expression
ops20.c:3: error: invalid argument type 'double' to unary expression
ops21.c:3: error: invalid argument type 'int *' to unary expression
ops22.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops23.c:3: error: invalid operands to binary expression ('int *' and 'int')
ops24.c:3: error: invalid operands to binary expression ('int *' and 'int *')
ops25.c:3: error: invalid operands to binary expression ('int *' and 'double')
ops26.c:3: error: invalid operands to binary expression ('int[3]' and 'int')
ops27.c:3: error: invalid operands to binary expression ('int[3]' and 'int')
ops28.c:3: error: invalid operands to binary expression ('char' and 'const char *')
ops29.c:3: error: invalid operands to binary expression ('void (*)(void)' and 'int')
ops30.c:3: error: invalid operands to binary expression ('struct P' and 'int')
ops31.c:3: error: invalid operands to binary expression ('struct P' and 'int')"
# A COMMA, A CONDITIONAL, AN ASSIGNMENT, A STEP AND A MEMBER OF A VALUE ARE NO LVALUES IN C (1.6.13; C17 6.5.2.3/3,
# 6.5.15, 6.5.16/3, 6.5.17, 6.5.2.4 and 6.5.3.1; ccl_c_no_lvalue/1): an assignment to one, a step of one and its address
# are refused in clang's words at the line, by the lowering and by the check's address. Through 1.6.12 the lowering
# took `(c ? a : b) = 5' -- the conditional's place is C++'s -- the check refused `int *p = &(c ? a : b);' as a plain
# pointer never consumed, and the rest were refused by name, `not lowered yet: lvalue(comma(...))'
nlv_pre='struct S { int m; }; struct S h(void) { struct S s = { 1 }; return s; }\nint main(int argc, char **argv) { (void)argv; int a = 1, b = 2; struct S s1 = { 1 }, s2 = { 2 }; (void)s1; (void)b;'
check "a comma, a conditional, an assignment, a step and a member of a value are no lvalues in C (1.6.13): an assignment to one, a step of one and its address are refused in clang's words at the line" "$(n=0; for body in '(argc > 0 ? a : b) = 5;' '(a, b) = 5;' '(a = 1) = 2;' '++(++a);' '(argc > 0 ? a : b)++;' '(a, b) += 1;' '--(a = 1);' '(a++)--;' '(argc > 0 ? s1 : s2).m = 5;' '(a, s2).m = 5;' 'h().m = 5;' 'int *p = &(argc > 0 ? a : b); (void)p;' 'int *p = &(a, b); (void)p;' 'int *p = &(a = 1); (void)p;' 'int *p = &++a; (void)p;' 'int *p = &(a++); (void)p;' 'int *p = &(a, s2).m; (void)p;' 'int *p = &h().m; (void)p;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$nlv_pre" "$body" > nlv$n.c; "$CICILI" -std=c17 -fsyntax-only nlv$n.c 2>&1 | head -1; done)" "nlv1.c:3: error: expression is not assignable
nlv2.c:3: error: expression is not assignable
nlv3.c:3: error: expression is not assignable
nlv4.c:3: error: expression is not assignable
nlv5.c:3: error: expression is not assignable
nlv6.c:3: error: expression is not assignable
nlv7.c:3: error: expression is not assignable
nlv8.c:3: error: expression is not assignable
nlv9.c:3: error: expression is not assignable
nlv10.c:3: error: expression is not assignable
nlv11.c:3: error: expression is not assignable
nlv12.c:3: error: cannot take the address of an rvalue of type 'int'
nlv13.c:3: error: cannot take the address of an rvalue of type 'int'
nlv14.c:3: error: cannot take the address of an rvalue of type 'int'
nlv15.c:3: error: cannot take the address of an rvalue of type 'int'
nlv16.c:3: error: cannot take the address of an rvalue of type 'int'
nlv17.c:3: error: cannot take the address of an rvalue of type 'int'
nlv18.c:3: error: cannot take the address of an rvalue of type 'int'"
# A CONST-QUALIFIED PLACE IS NO MODIFIABLE LVALUE IN C (1.6.22; C17 6.3.2.1/1, 6.5.16/2, 6.5.2.4/1 and 6.5.3.1/1;
# ir_c_const_place/2): an assignment, a compound assignment and a step of one are refused in clang's words at the line --
# the variable that makes the place const named, through a member, an element and `->', a const member by itself, a
# struct with one assigned whole by the member, any other place read-only -- and a store through a const pointer to a
# plain object, a member that is not const and a pointer to const given a new target stay. Through 1.6.21 each built
cst_pre='struct S { int x; }; struct C { const int x; int y; };\nint main(void) { int b = 1; (void)b;'
check "a const-qualified place is no modifiable lvalue in C (1.6.22): an assignment, a compound assignment and a step of one are refused in clang's words" "$(n=0; for body in 'const int a = 1; a = 2;' 'const int a = 1; a += 2;' 'const int a = 1; a++;' 'const int a = 1; --a;' 'const int *p = &b; *p = 3;' 'const int *p = &b; p[0] = 3;' 'const int arr[2] = {1, 2}; arr[0] = 3;' 'const struct S s = {1}; s.x = 2;' 'struct S t = {1}; const struct S *p = &t; p->x = 2;' 'struct C s = {1, 2}; s.x = 3;' 'struct C s = {1, 2}, u = {3, 4}; s = u;' 'int *const cp = &b; cp = 0;' 'int *const cp = &b; *cp = 4; struct C s = {1, 2}; s.y = 5; const int *p = &b; p = &s.y; (void)p;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$cst_pre" "$body" > cst$n.c; o=$("$CICILI" -std=c17 -fsyntax-only cst$n.c 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "cst$n.c: builds"; done)" "cst1.c:3: error: cannot assign to variable 'a' with const-qualified type 'const int'
cst2.c:3: error: cannot assign to variable 'a' with const-qualified type 'const int'
cst3.c:3: error: cannot assign to variable 'a' with const-qualified type 'const int'
cst4.c:3: error: cannot assign to variable 'a' with const-qualified type 'const int'
cst5.c:3: error: read-only variable is not assignable
cst6.c:3: error: read-only variable is not assignable
cst7.c:3: error: cannot assign to variable 'arr' with const-qualified type 'const int[2]'
cst8.c:3: error: cannot assign to variable 's' with const-qualified type 'const struct S'
cst9.c:3: error: cannot assign to variable 'p' with const-qualified type 'const struct S *'
cst10.c:3: error: cannot assign to non-static data member 'x' with const-qualified type 'const int'
cst11.c:3: error: cannot assign to variable 's' with const-qualified data member 'x'
cst12.c:3: error: cannot assign to variable 'cp' with const-qualified type 'int *const'
cst13.c: builds"
# AN OPERATOR'S VALUE IS NO LVALUE IN C EITHER (1.6.22; C17 6.5.3.2 to 6.5.14; ccl_c_rvalue_form/1): an assignment to a
# binary or a unary operator's value, a step of one and its address are refused in clang's words, an assignment to a cast
# in its own, a member of two structs' operator gives `invalid operands', where it was `lvalue(bin(...))', and `->' over a
# struct or an int is clang's `member reference type ... is not a pointer', where it was `not_a_pointer(...)'
opv_pre='struct S { int m; };\nint main(void) { int a = 1, b = 2; struct S s1 = { 1 }, s2 = { 2 }; (void)s1; (void)s2; (void)b;'
check "an operator's value is no lvalue in C (1.6.22): an assignment to one, a step of one, its address, a member of two structs' operator and -> over no pointer are refused in clang's words" "$(n=0; for body in '(a + b) = 3;' '(a * b) += 1;' '-a = 1;' '(!a)++;' '--(~a);' 'int *q = &(a + b); (void)q;' 'int *q = &-a; (void)q;' 'int **q = &(&a); (void)q;' '(int)a = 1;' 'int *q = &(int)a; (void)q;' 'a = (s1 * s2).m;' 'a = (s1 + s2).m;' 'a = s1->m;' 's1->m = 2;' 'a = a->m;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$opv_pre" "$body" > opv$n.c; "$CICILI" -std=c17 -fsyntax-only opv$n.c 2>&1 | head -1; done)" "opv1.c:3: error: expression is not assignable
opv2.c:3: error: expression is not assignable
opv3.c:3: error: expression is not assignable
opv4.c:3: error: expression is not assignable
opv5.c:3: error: expression is not assignable
opv6.c:3: error: cannot take the address of an rvalue of type 'int'
opv7.c:3: error: cannot take the address of an rvalue of type 'int'
opv8.c:3: error: cannot take the address of an rvalue of type 'int *'
opv9.c:3: error: assignment to cast is illegal, lvalue casts are not supported
opv10.c:3: error: cannot take the address of an rvalue of type 'int'
opv11.c:3: error: invalid operands to binary expression ('struct S' and 'struct S')
opv12.c:3: error: invalid operands to binary expression ('struct S' and 'struct S')
opv13.c:3: error: member reference type 'struct S' is not a pointer; did you mean to use '.'?
opv14.c:3: error: member reference type 'struct S' is not a pointer; did you mean to use '.'?
opv15.c:3: error: member reference type 'int' is not a pointer"
# C++: A SCALAR PRVALUE HAS NO ADDRESS AND IS NO PLACE, AND A CONSTEXPR VARIABLE'S INITIALIZER IS A CONSTANT (1.6.22;
# [expr.unary.op]/3, [expr.ass]/1, [expr.pre.incr]/1, [dcl.constexpr]/10; cpp_scalar_prvalue_call/2, cpp_constexpr_folds/4):
# `h() = 4', `h() += 1', a step of `h()' and `&h()' over `int h()' are refused in clang++'s words, and a constexpr
# variable whose fold calls a function that is not constexpr or reaches a trap; a reference's call is a place, and a fold
# that holds stays. Through 1.6.21 the assignment and the step ran on a temporary, the address was `plain pointer not
# consumed', and the constexpr variables ran their initializers at run time
cpv_pre='int h() { return 3; }\nint &hr() { static int v; return v; }\nconstexpr int f(int x) { return x > 0 ? x : (__builtin_trap(), 0); }'
check "C++: a scalar prvalue has no address and is no place, and a constexpr variable's initializer is a constant (1.6.22), in clang++'s words" "$(n=0; for body in 'int main() { h() = 4; return 0; }' 'int main() { h() += 1; return 0; }' 'int main() { h()++; return 0; }' 'int main() { --h(); return 0; }' 'int main() { int *p = &h(); return *p; }' 'constexpr int g = h();\nint main() { return g; }' 'constexpr int g = f(-1);\nint main() { return g; }' 'constexpr int g = f(2);\nint main() { hr() = 4; ++hr(); int *p = &hr(); return *p + g - h(); }'; do n=$((n + 1)); printf '%b\n%b\n' "$cpv_pre" "$body" > cpv$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c cpv$n.cpp -o cpv$n.o 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "cpv$n.cpp: builds"; done)" "cpv1.cpp:4: error: expression is not assignable
cpv2.cpp:4: error: expression is not assignable
cpv3.cpp:4: error: expression is not assignable
cpv4.cpp:4: error: expression is not assignable
cpv5.cpp:4: error: cannot take the address of an rvalue of type 'int'
cpv6.cpp:4: error: constexpr variable 'g' must be initialized by a constant expression
cpv7.cpp:4: error: constexpr variable 'g' must be initialized by a constant expression
cpv8.cpp: builds"
# C++: A BUILT-IN OPERATOR OVER A PLAIN STRUCT, AND `*' OVER AN INTEGER, IN THE PROGRAM'S OWN CODE ARE REFUSED IN CLANG++'S
# WORDS (1.6.22; [expr.unary.op], [expr.arith.conv]; cpp_builtin_op_words/4), as C's lowering words them, and `->' over a
# plain struct; they were `no_operator(...)', `deref_of_arithmetic(...)' and `not_a_pointer(...)', and `!s' reached LLVM's
# parser. A struct read by its members stays
bop_pre='struct S { int m; };\nint main() { S s = {1};'
check "C++: a built-in operator over a plain struct, and * over an integer, are refused in clang++'s words (1.6.22)" "$(n=0; for body in 'return *s;' 'S t = -s; return t.m;' 'return !s;' 'return (s + 1).m;' 'int x = 1; return *x;' 'return s->m;' 'S t = s; return t.m + (s.m > 0 ? 1 : 0);'; do n=$((n + 1)); printf '%b\n  %s }\n' "$bop_pre" "$body" > bop$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c bop$n.cpp -o bop$n.o 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "bop$n.cpp: builds"; done)" "bop1.cpp:3: error: indirection requires pointer operand ('S' invalid)
bop2.cpp:3: error: invalid argument type 'S' to unary expression
bop3.cpp:3: error: invalid argument type 'S' to unary expression
bop4.cpp:3: error: invalid operands to binary expression ('S' and 'int')
bop5.cpp:3: error: indirection requires pointer operand ('int' invalid)
bop6.cpp:3: error: member reference type 'S' is not a pointer; did you mean to use '.'?
bop7.cpp: builds"
# C++: A MEMBER'S INITIALIZER THAT NO CONSTRUCTOR TAKES IS CLANG++'S `no matching constructor for initialization of 'M''
# (1.6.22), at clang++'s line; it was `not lowered yet: member_not_constructed(m, 'M', 2)'
check "C++: a member's initializer that no constructor takes is refused in clang++'s words (1.6.22)" "$(printf 'struct M { int v; M(int x) : v(x) {} };\nstruct N {\n  M m;\n  N() : m(1, 2) {}\n};\nint main() { N n; return n.m.v; }\n' > mnc.cpp; "$ROOT/bin/cicilang++" -std=c++17 -c mnc.cpp -o mnc.o 2>&1 | head -1)" "mnc.cpp:4: error: no matching constructor for initialization of 'M'"
# ... AND A REFUSAL IN THE BODY OF THE PROGRAM'S FUNCTION TEMPLATE HAS THE BODY'S WORDS (1.6.22, dr_inner_worded/2), at the
# template's line, where it was `not lowered yet: instance_refused('mk.M', void_cast_class(functional, 'M'))'
check "C++: a refusal in a function template's body has the body's words (1.6.22)" "$(printf 'void f() {}\nstruct M { int v; M(int x) : v(x) {} };\ntemplate <class T0> T0 mk() { return T0(f()); }\nint main() { M m = mk<M>(); return m.v; }\n' > tinst.cpp; "$ROOT/bin/cicilang++" -std=c++17 -c tinst.cpp -o tinst.o 2>&1 | head -1)" "tinst.cpp:3: error: no matching conversion for functional-style cast from 'void' to 'M'"
# C++: A CONDITION OVER A PLAIN STRUCT IS NO BOOL (1.6.22; [conv]/4; cpp_cond_bool/2, cpp_logic_bool/5): an if's, a loop's,
# a conditional's and an operand of && and ||, in clang++'s words, where they reached LLVM's parser; `!s' has the unary
# operator's words, and a free operator&& that takes the operands is called
check "C++: a condition over a plain struct is refused in clang++'s words, the operands of && and || too, and a free operator&& is called (1.6.22)" "$(n=0; for body in 'if (s) return 1;' 'while (s) return 1;' 'return s ? 1 : 2;' 'for (; s; ) return 1;' 'do { } while (s);' 'return !s;' 'return s && 1;' 'return 1 || s;'; do n=$((n + 1)); printf 'struct S { int a; };\nint main() {\n  S s{1};\n  %s\n  return 0;\n}\n' "$body" > cnd$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c cnd$n.cpp -o cnd$n.o 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "cnd$n.cpp: builds"; done; printf 'struct S { int a; };\nbool operator&&(S x, int y) { return x.a > y; }\nint main() { S s{3}; return (s && 1) ? 7 : 0; }\n' > cndfree.cpp; "$ROOT/bin/cicilang++" -std=c++17 cndfree.cpp -o cndfree 2>&1 && ./cndfree; echo "exit $?")" "cnd1.cpp:4: error: value of type 'S' is not contextually convertible to 'bool'
cnd2.cpp:4: error: value of type 'S' is not contextually convertible to 'bool'
cnd3.cpp:4: error: value of type 'S' is not contextually convertible to 'bool'
cnd4.cpp:4: error: value of type 'S' is not contextually convertible to 'bool'
cnd5.cpp:4: error: value of type 'S' is not contextually convertible to 'bool'
cnd6.cpp:4: error: invalid argument type 'S' to unary expression
cnd7.cpp:4: error: value of type 'S' is not contextually convertible to 'bool'
cnd8.cpp:4: error: value of type 'S' is not contextually convertible to 'bool'
exit 7"
# C++: A CONST-QUALIFIED PLACE IS NO MODIFIABLE LVALUE (1.6.23; [expr.ass]/1; cpp_const_assign/2), in clang++'s words, which
# are clang's: a const variable, a place through a pointer to const, a const member, a member of a const object, a
# reference to const, a step and a compound assignment; a constructor's member initializers, a const global's, a static
# member's and a static local's dynamic initialization, and a pointer to const given a new target build
cq_pre='struct S { int m; const int x; S() : m(0), x(1) {} };\nint h() { return 3; }\nconst int g = h();\nint main() {\n  int x = 0;\n  const int a = 1;\n  const int *p = &x;\n  S s;\n  const S s2;\n  const int &cr = x;\n'
check "C++: a const-qualified place is no modifiable lvalue, in clang++'s words, and what initializes one builds (1.6.23)" "$(n=0; for body in 'a = 2;' '*p = 3;' 's.x = 2;' 's2.m = 1;' 'cr = 5;' '++a;' 'a += 1;' 'p = &x + 0; return *p + s.x + g + a + cr - 5;'; do n=$((n + 1)); printf "$cq_pre  %s\n  return 0;\n}\n" "$body" > cq$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 cq$n.cpp -o cq$n 2>&1 | head -1); if [ -n "$o" ]; then echo "$o"; else ./cq$n; echo "cq$n: exit $?"; fi; done)" "cq1.cpp:11: error: cannot assign to variable 'a' with const-qualified type 'const int'
cq2.cpp:11: error: read-only variable is not assignable
cq3.cpp:11: error: cannot assign to non-static data member 'x' with const-qualified type 'const int'
cq4.cpp:11: error: cannot assign to variable 's2' with const-qualified type 'const S'
cq5.cpp:11: error: cannot assign to variable 'cr' with const-qualified type 'const int &'
cq6.cpp:11: error: cannot assign to variable 'a' with const-qualified type 'const int'
cq7.cpp:11: error: cannot assign to variable 'a' with const-qualified type 'const int'
cq8: exit 0"
# C++: A CONSTEXPR VARIABLE WHOSE EVALUATION REACHES __builtin_unreachable() IS REFUSED (1.6.23; [expr.const]/5; the
# evaluator's trap, cpp_eval_reduce/3), at file scope and in a block, in clang++'s words; it was answered as nothing
check "C++: a constexpr variable whose evaluation reaches __builtin_unreachable() is refused in clang++'s words (1.6.23)" "$(printf 'constexpr int f(int x) { if (x < 0) __builtin_unreachable(); return x; }\nconstexpr int g = f(-1);\nint main() { return g; }\n' > unr1.cpp; "$ROOT/bin/cicilang++" -std=c++17 -c unr1.cpp -o unr1.o 2>&1 | head -1; printf 'int main() {\n  constexpr int f2 = [](int x) { if (x < 0) __builtin_unreachable(); return x; }(-1);\n  return f2;\n}\n' > unr2.cpp; "$ROOT/bin/cicilang++" -std=c++17 -c unr2.cpp -o unr2.o 2>&1 | head -1)" "unr1.cpp:2: error: constexpr variable 'g' must be initialized by a constant expression
unr2.cpp:2: error: constexpr variable 'f2' must be initialized by a constant expression"
# C: POINTERS OF INCOMPATIBLE TYPES ARE REFUSED IN CLANG'S WORDS (1.6.23; C17 6.5.16.1/1; ir_ptr_clash/4), as clang 20 and
# later refuse them: a pointee of another type, a nested pointer's, an array's, a struct's, a function's; a qualifier that
# is discarded, at any level, the sign of an integer pointee, a void pointer, an enumeration's own integer type and a
# wide literal for its typedef's pointer are taken, as clang warns of them or says nothing; and each of the four sites
check "C: pointers of incompatible types are refused in clang's words, at the four sites, and what clang only warns of builds (1.6.23)" "$(n=0; for body in 'char *cp = 0; int *ip = cp; (void)ip;' 'char *cp = 0; unsigned char *up = cp; (void)up;' 'int *a = 0; unsigned *b = a; (void)b;' 'const char *c = 0; char *d = c; (void)d;' 'char **pp = 0; const char **qq = pp; (void)qq;' 'int **ii = 0; unsigned **uu = ii; (void)uu;' 'void *v = 0; int *w = v; (void)w;' 'char arr[4]; int *ap = arr; (void)ap;' 'int (*fp)(int) = 0; void (*gp)(void) = fp; (void)gp;' 'struct A { int a; } sa; struct B { int b; } *bp = &sa; (void)bp;' 'int k = 0; long *lp = &k; (void)lp;' 'int *p1 = 0; char *c3; c3 = p1; (void)c3;' 'int (*a6)[3] = 0; int (*a7)[4] = a6; (void)a7;' 'enum E { E0 } *ep = 0; unsigned *u8 = ep; (void)u8;' 'const unsigned short *w16 = u"ab"; (void)w16;' 'long l = 0; use(&l);' 'char cc = 0; return *ret(&cc);'; do n=$((n + 1)); printf '#include <stddef.h>\nvoid use(int *q) { (void)q; }\nint *ret(char *c) { return (int *)c; }\nint main(void) {\n  %s\n  return 0;\n}\n' "$body" > ipc$n.c; o=$("$CICILI" -fsyntax-only ipc$n.c 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "ipc$n.c: builds"; done; printf 'int *ret2(char *c) { return c; }\nint main(void) { return 0; }\n' > ipret.c; "$CICILI" -fsyntax-only ipret.c 2>&1 | head -1)" "ipc1.c:5: error: incompatible pointer types initializing 'int *' with an expression of type 'char *'
ipc2.c: builds
ipc3.c: builds
ipc4.c: builds
ipc5.c: builds
ipc6.c:5: error: incompatible pointer types initializing 'unsigned int **' with an expression of type 'int **'
ipc7.c: builds
ipc8.c:5: error: incompatible pointer types initializing 'int *' with an expression of type 'char[4]'
ipc9.c:5: error: incompatible function pointer types initializing 'void (*)(void)' with an expression of type 'int (*)(int)'
ipc10.c:5: error: incompatible pointer types initializing 'struct B *' with an expression of type 'struct A *'
ipc11.c:5: error: incompatible pointer types initializing 'long *' with an expression of type 'int *'
ipc12.c:5: error: incompatible pointer types assigning to 'char *' from 'int *'
ipc13.c:5: error: incompatible pointer types initializing 'int (*)[4]' with an expression of type 'int (*)[3]'
ipc14.c: builds
ipc15.c: builds
ipc16.c:5: error: incompatible pointer types passing 'long *' to parameter of type 'int *'
ipc17.c: builds
ipret.c:1: error: incompatible pointer types returning 'char *' from a function with result type 'int *'"
# C++: A NAME OF THE FILE SCOPE DECLARED AGAIN AS ANOTHER KIND OF SYMBOL IS REFUSED (1.6.24; cpp_kind_clashes/1), in
# clang++'s words: an object and a function, an enumerator, a typedef, an `extern "C"' block's object, a function template;
# a namespace's name, a class's tag, two overloads and an object declared again build
check "C++: a name of the file scope declared again as another kind of symbol is refused in clang++'s words, and what C++ takes builds (1.6.24)" "$(n=0; for pair in 'int t(void);|int t;' 'enum { u = 1 };|int u(void);' 'typedef int w;|int w(void);' 'extern "C" { int c1; }|int c1(int);' 'template <class T> T tp(T x) { return x; }|int tp;' 'int v;|typedef int v;' 'namespace a { int t2; }|int t2();' 'struct s3 { int m; };|int s3(int);' 'int o(int);|double o(double);' 'int x9;|extern int x9;'; do n=$((n + 1)); printf '%s\n%s\nint main() { return 0; }\n' "${pair%%|*}" "${pair#*|}" > kind$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c kind$n.cpp -o kind$n.o 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "kind$n.cpp: builds"; done)" "kind1.cpp:2: error: redefinition of 't' as different kind of symbol
kind2.cpp:2: error: redefinition of 'u' as different kind of symbol
kind3.cpp:2: error: redefinition of 'w' as different kind of symbol
kind4.cpp:2: error: redefinition of 'c1' as different kind of symbol
kind5.cpp:2: error: redefinition of 'tp' as different kind of symbol
kind6.cpp:2: error: redefinition of 'v' as different kind of symbol
kind7.cpp: builds
kind8.cpp: builds
kind9.cpp: builds
kind10.cpp: builds"
check "C++: a name of the file scope or of a namespace declared again as another kind of symbol, through the program's own header and through two blocks of a namespace, in clang++'s words (1.6.28; [basic.scope.declarative]/4, [namespace.def]/2): each built -- after what C++ takes, first: a pair in two namespaces, a struct's tag and an object, a header's declaration and the file's definition" "$(printf 'int t(void);\n' > kind1.h; printf 'int t;\n' > kind2.h; printf 'struct q { int a; };\n' > kind3.h; printf 'int u(int);\n' > kind4.h; printf '#include "kind1.h"\n' > kind5.h; printf 'extern "C" { int t(void); }\n' > kind6.h; n=0; for src in 'namespace n { int t; }
namespace m { int t(); }
int main() { return 0; }' '#include "kind3.h"
int q;
int main() { return 0; }' '#include "kind4.h"
int u(int a) { return a; }
int main() { return u(0); }' '#include "kind1.h"
int t;
int main() { return 0; }' '#include "kind2.h"
int t(void);
int main() { return 0; }' 'namespace n { int t(); }
namespace n { int t; }
int main() { return 0; }' 'namespace n { int t; }
namespace n { int t(); }
int main() { return 0; }' 'namespace n { int t; int t(); }
int main() { return 0; }' 'namespace n { namespace in { int t; } int t(); }
int main() { return 0; }' 'namespace n { enum E { t }; }
namespace n { int t(); }
int main() { return 0; }' '#include "kind5.h"
int t;
int main() { return 0; }' '#include "kind6.h"
int t;
int main() { return 0; }'; do n=$((n + 1)); printf "$src\n" > kind$n.cpp; "$ROOT/bin/cicilang++" -c kind$n.cpp -o kind$n.o 2>&1 | head -1; done)" "kind4.cpp:2: error: redefinition of 't' as different kind of symbol
kind5.cpp:2: error: redefinition of 't' as different kind of symbol
kind6.cpp:2: error: redefinition of 't' as different kind of symbol
kind7.cpp:2: error: redefinition of 't' as different kind of symbol
kind8.cpp:1: error: redefinition of 't' as different kind of symbol
kind10.cpp:2: error: redefinition of 't' as different kind of symbol
kind11.cpp:2: error: redefinition of 't' as different kind of symbol
kind12.cpp:2: error: redefinition of 't' as different kind of symbol"
# C: A LIBRARY FUNCTION THAT NOTHING DECLARES HAS CLANG'S WORDS AND ITS NOTE OF THE HEADER (1.6.24; dr_lib_fn/3), the
# type as clang 23 spells it; a name that clang does not know so has a call's words
check "C: a library function that nothing declares is refused in clang's words, with the header in a note (1.6.24)" "$(n=0; for c in 'printf("x")' 'exit(0)' 'double d = sqrt(2.0); (void)d' 'puts("x")'; do n=$((n + 1)); printf 'int main(void) {\n  %s;\n  return 0;\n}\n' "$c" > lib$n.c; "$CICILI" -fsyntax-only lib$n.c 2>&1 | grep -v '^cicilang:'; done)" "lib1.c:2: error: call to undeclared library function 'printf' with type 'int (const char *, ...)'; ISO C99 and later do not support implicit function declarations
lib1.c:2: note: include the header <stdio.h> or explicitly provide a declaration for 'printf'
lib2.c:2: error: call to undeclared library function 'exit' with type 'void (int) __attribute__((noreturn))'; ISO C99 and later do not support implicit function declarations
lib2.c:2: note: include the header <stdlib.h> or explicitly provide a declaration for 'exit'
lib3.c:2: error: call to undeclared library function 'sqrt' with type 'double (double)'; ISO C99 and later do not support implicit function declarations
lib3.c:2: note: include the header <math.h> or explicitly provide a declaration for 'sqrt'
lib4.c:2: error: call to undeclared function 'puts'; ISO C99 and later do not support implicit function declarations"
# C: A TYPE THAT A TYPEDEF NAMES HAS CLANG'S `(aka ...)' (1.6.24; ir_type_aka/2, dr_aka_close/2) where the words are clang's:
# a void value, a const place, a pointer of an incompatible type and a pointer for an integer; a struct with no tag is its
# typedef's name, and a typedef of a struct `'S' (aka 'struct S')'
check "C: a type that a typedef names has clang's (aka ...) where the words are clang's: a void value, a const place, the conversions of an integer and a pointer (1.6.24)" "$(n=0; for body in 'J j = f();' 'S s = f();' 'P p = f();' 'str q = f();' 'IP ip = f();' 'I *ip2 = f();' 'size_t n = f();' 'int8_t e = f();' 'const I ci = f();' 'const I c = 1; c = 2;' 'I *p = 0; char *c = 0; p = c;' 'I k; I *p = &k; long n2; n2 = p;'; do n=$((n + 1)); printf '#include <stddef.h>\n#include <stdint.h>\ntypedef int I;\ntypedef I J;\ntypedef struct S S;\nstruct S { int a; };\ntypedef struct { int b; } P;\ntypedef const char *str;\ntypedef I *IP;\nvoid f(void);\n%s\n  %s\n  return 0;\n}\n' 'int main(void) {' "$body" > aka$n.c; o=$("$CICILI" -std=c17 -fsyntax-only aka$n.c 2>&1 | grep -m1 'error:' | sed 's/^\(aka[0-9]*\.c:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "aka$n.c: builds"; done)" "aka1.c:12: error: initializing 'J' (aka 'int') with an expression of incompatible type 'void'
aka2.c:12: error: initializing 'S' (aka 'struct S') with an expression of incompatible type 'void'
aka3.c:12: error: initializing 'P' with an expression of incompatible type 'void'
aka4.c:12: error: initializing 'str' (aka 'const char *') with an expression of incompatible type 'void'
aka5.c:12: error: initializing 'IP' (aka 'int *') with an expression of incompatible type 'void'
aka6.c:12: error: initializing 'I *' (aka 'int *') with an expression of incompatible type 'void'
aka7.c:12: error: initializing 'size_t' (aka 'unsigned long') with an expression of incompatible type 'void'
aka8.c:12: error: initializing 'int8_t' (aka 'signed char') with an expression of incompatible type 'void'
aka9.c:12: error: initializing 'const I' (aka 'const int') with an expression of incompatible type 'void'
aka10.c:12: error: cannot assign to variable 'c' with const-qualified type 'const I' (aka 'const int')
aka11.c:12: error: incompatible pointer types assigning to 'I *' (aka 'int *') from 'char *'
aka12.c:12: error: incompatible pointer to integer conversion assigning to 'long' from 'I *' (aka 'int *')"
# ... AND IN C++, a typedef's and an alias's, a class's alias `'TC' (aka 'C')', a reference to const by its own type
check "C++: a type that a typedef or an alias names has clang++'s (aka ...) in a void value's and a const place's words (1.6.24)" "$(n=0; for body in 'I i = f();' 'U u = f();' 'TC t = f();' 'const I c = 1; c = 2;' 'I x = 0; const I &r = x; r = 2;'; do n=$((n + 1)); printf 'typedef int I;\nusing U = long;\nstruct C {};\ntypedef C TC;\nvoid f();\n%s\n  %s\n  return 0;\n}\n' 'int main() {' "$body" > akp$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c akp$n.cpp -o akp$n.o 2>&1 | grep -m1 'error:' | sed 's/^\(akp[0-9]*\.cpp:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "akp$n.cpp: builds"; done)" "akp1.cpp:7: error: cannot initialize a variable of type 'I' (aka 'int') with an rvalue of type 'void'
akp2.cpp:7: error: cannot initialize a variable of type 'U' (aka 'long') with an rvalue of type 'void'
akp3.cpp:7: error: no viable conversion from 'void' to 'TC' (aka 'C')
akp4.cpp:7: error: cannot assign to variable 'c' with const-qualified type 'const I' (aka 'const int')
akp5.cpp:7: error: cannot assign to variable 'r' with const-qualified type 'const I &' (aka 'const int &')"
# C: AN OBJECT OF THE FILE SCOPE DECLARED AGAIN WITH ANOTHER TYPE (1.6.24; C17 6.7/4; ccl_redef_obj_type/8) is clang's
# `redefinition of 'x' with a different type', `redeclaration of' for a later `extern': another integer, an array of
# another bound, another pointee, another qualifier, a pointer's own, each spelled; an array's bound left out and a function's prototype
# left out build, and so does the same type
check "C: an object of the file scope declared again with another type is refused in clang's words, and the compatible ones build (1.6.24)" "$(n=0; for pair in 'int x;|long x;' 'extern int x;|long x;' 'int x = 1;|long x;' 'typedef int I; I x;|long x;' 'int x;|unsigned x;' 'int x[2];|int x[3];' 'int *x;|char *x;' 'extern int x;|extern long x;' 'int x[3] = {1, 2, 3};|extern int x[2];' 'const int x;|int x;' 'volatile int x;|int x;' 'int *const x;|int *x;' 'int *const a[2];|int *a[2];' 'char *x;|unsigned char *x;' 'int *volatile x;|char *x;' 'int *restrict x;|char *x;' 'int x[];|int x[3];' 'extern int x[];|int x[3];' 'int x;|int x;' 'int (*x)(int);|int (*x)();' 'char *const x = 0;|extern char *const x;'; do n=$((n + 1)); printf '%s\n%s\nint main(void) { return 0; }\n' "${pair%%|*}" "${pair#*|}" > rdo$n.c; o=$("$CICILI" -std=c17 -fsyntax-only rdo$n.c 2>&1 | grep -m1 'error:' | sed 's/^\(rdo[0-9]*\.c:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "rdo$n.c: builds"; done)" "rdo1.c:2: error: redefinition of 'x' with a different type: 'long' vs 'int'
rdo2.c:2: error: redefinition of 'x' with a different type: 'long' vs 'int'
rdo3.c:2: error: redefinition of 'x' with a different type: 'long' vs 'int'
rdo4.c:2: error: redefinition of 'x' with a different type: 'long' vs 'I' (aka 'int')
rdo5.c:2: error: redefinition of 'x' with a different type: 'unsigned int' vs 'int'
rdo6.c:2: error: redefinition of 'x' with a different type: 'int[3]' vs 'int[2]'
rdo7.c:2: error: redefinition of 'x' with a different type: 'char *' vs 'int *'
rdo8.c:2: error: redeclaration of 'x' with a different type: 'long' vs 'int'
rdo9.c:2: error: redeclaration of 'x' with a different type: 'int[2]' vs 'int[3]'
rdo10.c:2: error: redefinition of 'x' with a different type: 'int' vs 'const int'
rdo11.c:2: error: redefinition of 'x' with a different type: 'int' vs 'volatile int'
rdo12.c:2: error: redefinition of 'x' with a different type: 'int *' vs 'int *const'
rdo13.c:2: error: redefinition of 'a' with a different type: 'int *[2]' vs 'int *const[2]'
rdo14.c:2: error: redefinition of 'x' with a different type: 'unsigned char *' vs 'char *'
rdo15.c:2: error: redefinition of 'x' with a different type: 'char *' vs 'int *volatile'
rdo16.c:2: error: redefinition of 'x' with a different type: 'char *' vs 'int *restrict'
rdo17.c: builds
rdo18.c: builds
rdo19.c: builds
rdo20.c: builds
rdo21.c: builds"
# C++: A CONST MEMBER FUNCTION'S WRITE OF A MEMBER (1.6.24; [class.this]/1, [dcl.stc]/9; cpp_const_assign/2): the member,
# a compound assignment, a step, an element, a member of it, through `this', a base's; a `mutable' member, a write through
# a pointer member or a reference member, a static member and a non-const member function's writes build; a const member
# is refused in any member function
check "C++: a const member function's write of a member is refused in clang++'s words, a mutable one's, a pointer's and a reference's build (1.6.24)" "$(n=0; for body in 'void C::g() const { m = 1; } void C::h() {}' 'void C::g() const { m += 1; } void C::h() {}' 'void C::g() const { ++m; } void C::h() {}' 'void C::g() const { m++; } void C::h() {}' 'void C::g() const { a[1] = 1; } void C::h() {}' 'void C::g() const { s.q = 1; } void C::h() {}' 'void C::g() const { this->m = 1; } void C::h() {}' 'void C::g() const { bm = 1; } void C::h() {}' 'void C::g() const { k = 1; bk = 2; *p = 3; r = 4; st = 5; } void C::h() { m = 1; a[0] = 2; s.q = 3; bm = 4; }' 'void C::h() { cm = 1; } void C::g() const {}' 'void C::g() const { cm = 1; } void C::h() {}'; do n=$((n + 1)); printf 'struct P { int q; };\nstruct B { int bm = 0; mutable int bk = 0; };\nstruct C : B { int m = 0; mutable int k = 0; int a[2] = {0, 0}; P s{0}; int *p = nullptr; int &r; static int st; const int cm = 0;\n  C(int &x) : r(x) {}\n  void g() const;\n  void h();\n};\nint C::st = 0;\n%s\nint main() { int x = 0; C c(x); c.g(); c.h(); return 0; }\n' "$body" > cmf$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c cmf$n.cpp -o cmf$n.o 2>&1 | grep -m1 'error:' | sed 's/^\(cmf[0-9]*\.cpp:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "cmf$n.cpp: builds"; done)" "cmf1.cpp:9: error: cannot assign to non-static data member within const member function 'g'
cmf2.cpp:9: error: cannot assign to non-static data member within const member function 'g'
cmf3.cpp:9: error: cannot assign to non-static data member within const member function 'g'
cmf4.cpp:9: error: cannot assign to non-static data member within const member function 'g'
cmf5.cpp:9: error: cannot assign to non-static data member within const member function 'g'
cmf6.cpp:9: error: cannot assign to non-static data member within const member function 'g'
cmf7.cpp:9: error: cannot assign to non-static data member within const member function 'g'
cmf8.cpp:9: error: cannot assign to non-static data member within const member function 'g'
cmf9.cpp: builds
cmf10.cpp:9: error: cannot assign to non-static data member 'cm' with const-qualified type 'const int'
cmf11.cpp:9: error: cannot assign to non-static data member 'cm' with const-qualified type 'const int'"
# C++: A CONSTEXPR POINTER IS A CONST POINTER (1.6.24; [dcl.constexpr]/10; ccl_constexpr_fold/2): the const that came
# with the marker is the pointer's, an array's elements' and a pointer to a function's; it was the pointee's, and an
# assignment built
check "C++: a constexpr pointer is a const pointer, its elements' too, refused in clang++'s words where it is assigned (1.6.24)" "$(n=0; for body in 'constexpr const char *m = "x"; int main() { m = "y"; return 0; }' 'int g; constexpr int *p = nullptr; int main() { p = &g; return 0; }' 'constexpr const char *ns[] = {"a", "bc"}; int main() { ns[0] = "z"; return 0; }' 'constexpr int (*fp)(int) = nullptr; int h(int); int main() { fp = h; return 0; }' 'constexpr const char *m = "x"; int main() { const char *q = m; return q[0] == 120 ? 0 : 1; }'; do n=$((n + 1)); printf '%s\n' "$body" > cxp$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c cxp$n.cpp -o cxp$n.o 2>&1 | grep -m1 'error:' | sed 's/^\(cxp[0-9]*\.cpp:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "cxp$n.cpp: builds"; done)" "cxp1.cpp:1: error: cannot assign to variable 'm' with const-qualified type 'const char *const'
cxp2.cpp:1: error: cannot assign to variable 'p' with const-qualified type 'int *const'
cxp3.cpp:1: error: cannot assign to variable 'ns' with const-qualified type 'const char *const[2]'
cxp4.cpp:1: error: cannot assign to variable 'fp' with const-qualified type 'int (*const)(int)'
cxp5.cpp: builds"
# C++: AN INTEGER AND A POINTER DO NOT CONVERT IMPLICITLY (1.6.24; [conv.ptr]/1; cpp_int_ptr_check/3), in the program's own
# assignments and scalar initializers, in clang++'s words: a pointer, an array, a function or a string literal for an
# integer, an integer, a bool or an enumerator for a pointer, an lvalue's address named; a bool from a pointer, a literal 0,
# nullptr, NULL, a cast and a difference build
check "C++: an integer and a pointer do not convert implicitly at an assignment or an initializer, in clang++'s words, and what C++ takes builds (1.6.24)" "$(n=0; for body in 'long n; n = q; (void)n;' 'long n = q; (void)n;' 'int *p; p = 5; (void)p;' 'int *p = 5; (void)p;' 'char c[2]; long n; n = c; (void)n;' 'int *p; p = x; (void)p;' 'long n; n = f; (void)n;' 'long n = "abc"; (void)n;' 'int *p = false; (void)p;' 'enum E { E0 }; E e = E0; int *p; p = e; (void)p;' 'bool b; b = q; int *p; p = 0; p = nullptr; p = NULL; int *p2 = 0L; long n; n = (long)q; n = q - q; (void)b; (void)p; (void)p2; (void)n;'; do n=$((n + 1)); printf '#include <cstddef>\nint f();\nint main() {\n  int x = 1; int *q = &x;\n  %s\n  return 0;\n}\n' "$body" > ipc$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c ipc$n.cpp -o ipc$n.o 2>&1 | grep -m1 'error:' | sed 's/^\(ipc[0-9]*\.cpp:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "ipc$n.cpp: builds"; done)" "ipc1.cpp:5: error: incompatible pointer to integer conversion assigning to 'long' from 'int *'
ipc2.cpp:5: error: cannot initialize a variable of type 'long' with an lvalue of type 'int *'
ipc3.cpp:5: error: incompatible integer to pointer conversion assigning to 'int *' from 'int'
ipc4.cpp:5: error: cannot initialize a variable of type 'int *' with an rvalue of type 'int'
ipc5.cpp:5: error: assigning to 'long' from incompatible type 'char[2]'
ipc6.cpp:5: error: incompatible integer to pointer conversion assigning to 'int *' from 'int'; take the address with &
ipc7.cpp:5: error: assigning to 'long' from incompatible type 'int ()'
ipc8.cpp:5: error: cannot initialize a variable of type 'long' with an lvalue of type 'const char[4]'
ipc9.cpp:5: error: cannot initialize a variable of type 'int *' with an rvalue of type 'bool'
ipc10.cpp:5: error: incompatible integer to pointer conversion assigning to 'int *' from 'E'
ipc11.cpp: builds"
# C++: A SECOND DEFINITION AT FILE SCOPE (1.6.24; [basic.def.odr]/1; cpp_redef_walk/3), in clang++'s words: a function of
# one list of adjusted parameter types, an object defined twice, one declared again with another type, a class, a union,
# an enumeration and a scoped one with two bodies; what C++ takes builds -- a declaration and its definition, overloads,
# an object's `extern' declaration
check "C++: a second definition at file scope is refused in clang++'s words, and declarations and overloads build (1.6.24)" "$(n=0; for pair in 'int f() { return 1; }|int f() { return 2; }' 'int x = 1;|int x = 2;' 'int x;|int x;' 'int x;|long x;' 'static int f() { return 1; }|int f() { return 2; }' 'inline int f() { return 1; }|inline int f() { return 1; }' 'typedef int I;|int f(I a) { return a; } int f(int b) { return b; }' 'int x[2];|int x[3];' 'extern "C" { int g() { return 1; } }|int g() { return 2; }' 'struct S { int m; };|struct S { int m; };' 'const int c = 1;|const int c = 2;' 'int f(int *a) { return 1; }|int f(int a[]) { return 2; }' 'int f(const int a) { return a; }|int f(int a) { return a; }' 'enum E { A };|enum E { B };' 'extern int x;|extern long x;' 'int f(signed a) { return 1; }|int f(int a) { return 2; }' 'int f(int (*g)(int)) { return 1; }|int f(int g(int)) { return 2; }' 'inline int v = 1;|inline int v = 1;' 'enum class E2 { A };|enum class E2 { A };' 'extern int x;|int x;' 'int f(int a) { return a; }|int f(long a) { return 1; }' 'int f();|int f() { return 1; }' 'struct S;|struct S { int m; };' 'int f(int *const *a) { return 1; }|int f(int **a) { return 2; }' 'int f(int &a) { return 1; }|int f(const int &a) { return 2; }' 'signed x;|extern int x;'; do n=$((n + 1)); printf '%s\n%s\nint main() { return 0; }\n' "${pair%%|*}" "${pair#*|}" > rdf$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c rdf$n.cpp -o rdf$n.o 2>&1 | grep -m1 'error:' | sed 's/^\(rdf[0-9]*\.cpp:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "rdf$n.cpp: builds"; done)" "rdf1.cpp:2: error: redefinition of 'f'
rdf2.cpp:2: error: redefinition of 'x'
rdf3.cpp:2: error: redefinition of 'x'
rdf4.cpp:2: error: redefinition of 'x' with a different type: 'long' vs 'int'
rdf5.cpp:2: error: redefinition of 'f'
rdf6.cpp:2: error: redefinition of 'f'
rdf7.cpp:2: error: redefinition of 'f'
rdf8.cpp:2: error: redefinition of 'x' with a different type: 'int[3]' vs 'int[2]'
rdf9.cpp:2: error: redefinition of 'g'
rdf10.cpp:2: error: redefinition of 'S'
rdf11.cpp:2: error: redefinition of 'c'
rdf12.cpp:2: error: redefinition of 'f'
rdf13.cpp:2: error: redefinition of 'f'
rdf14.cpp:2: error: redefinition of 'E'
rdf15.cpp:2: error: redeclaration of 'x' with a different type: 'long' vs 'int'
rdf16.cpp:2: error: redefinition of 'f'
rdf17.cpp:2: error: redefinition of 'f'
rdf18.cpp:2: error: redefinition of 'v'
rdf19.cpp:2: error: redefinition of 'E2'
rdf20.cpp: builds
rdf21.cpp: builds
rdf22.cpp: builds
rdf23.cpp: builds
rdf24.cpp: builds
rdf25.cpp: builds
rdf26.cpp: builds"
# C++: A RETURN'S INTEGER AND POINTER (1.6.25; cpp_return_int_ptr/1): the return object's words, an lvalue's or an rvalue's;
# a literal 0, nullptr, a cast, an auto result and a bool result build
check "C++: a return of a pointer for an integer result, or of an integer for a pointer, is refused in clang++'s words (1.6.25)" "$(n=0; for body in 'long f1(int *q) { return q; }' 'int *f2(int x) { return x; }' 'int *f3() { return 0; }' 'int *f4() { return nullptr; }' 'long f5(int *q) { return (long)q; }' 'auto f6(int *q) { return q; }' 'bool f8(int *q) { return q; }' 'long f9(char *s) { return "ab"; }' 'struct S { long v; long get(int *q) const { return q; } };'; do n=$((n + 1)); printf '%s\nint main() { return 0; }\n' "$body" > rti$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c rti$n.cpp -o x$n.o 2>&1 | grep -m1 'error:' | sed 's/^\(rti[0-9]*\.cpp:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "rti$n.cpp: builds"; done)" "rti1.cpp:1: error: cannot initialize return object of type 'long' with an lvalue of type 'int *'
rti2.cpp:1: error: cannot initialize return object of type 'int *' with an lvalue of type 'int'
rti3.cpp: builds
rti4.cpp: builds
rti5.cpp: builds
rti6.cpp: builds
rti7.cpp: builds
rti8.cpp:1: error: cannot initialize return object of type 'long' with an lvalue of type 'const char[3]'
rti9.cpp:1: error: cannot initialize return object of type 'long' with an lvalue of type 'int *'"
# C: A JUMP INTO A CLEANUP'S SCOPE (1.6.25; ck_jump_bypass/3, ck_switch_defers/2): a forward goto past the cleanup's
# variable and a case label after it, a nested block's too, in clang's words at the goto's and the label's lines; a jump
# out of the scope and C's jump past a plain initialization build
check "C: a jump into a cleanup's scope is refused in clang's words, a goto's and a case label's, and what C takes builds (1.6.25)" "$(n=0; for body in 'if (argc > 5) goto in; { int s __attribute__((cleanup(fr))) = 4; in: return s; }' 'switch (argc) { case 1: { int s __attribute__((cleanup(fr))) = 4; (void)s; case 2: return 0; } } return 1;' 'switch (argc) { case 1: { int s __attribute__((cleanup(fr))) = 4; (void)s; return 2; } case 2: return 0; } return 1;' 'if (argc > 5) goto out; { int s __attribute__((cleanup(fr))) = 4; if (s > argc) goto out; } out: return 0;' 'if (argc > 5) goto in; { int k = 4; in: return k; }'; do n=$((n + 1)); printf 'static void fr(int *p) { (void)p; }\nint main(int argc, char **argv) {\n  (void)argv;\n  %s\n}\n' "$body" > jcl$n.c; o=$("$CICILI" -std=c17 -fsyntax-only jcl$n.c  2>&1 | grep -m1 'error:' | sed 's/^\(jcl[0-9]*\.c:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "jcl$n.c: builds"; done)" "jcl1.c:4: error: cannot jump from this goto statement to its label
jcl2.c:4: error: cannot jump from switch statement to this case label
jcl3.c: builds
jcl4.c: builds
jcl5.c: builds"
# C++: A JUMP PAST A LOCAL WITH A DESTRUCTOR OR AN INITIALIZER ([stmt.dcl]/3; 1.6.25): a forward goto and a case label,
# clang++'s words; a local with no initializer, a jump out of its scope and a backward goto build
check "C++: a jump past a local's destructor or its initialization is refused in clang++'s words, and a jump out or back builds (1.6.25)" "$(n=0; for body in 'if (argc > 5) goto in; { D d; in: return 0; }' 'switch (argc) { case 1: { D d; case 2: return 0; } } return 1;' 'if (argc > 5) goto in; { int x = 1; in: return x; }' 'switch (argc) { case 1: int x = 1; (void)x; case 2: return 0; } return 1;' 'if (argc > 5) goto out; { D d; if (argc > 6) goto out; } out: return 0;' 'switch (argc) { case 1: { D d; return 1; } case 2: return 0; } return 1;' 'if (argc > 5) goto in; int y; { int x; in: x = 2; y = x; return y; }' 'int n = 0; again: int k = n + 1; n = k; if (n < 3) goto again; return n;'; do n=$((n + 1)); printf 'struct D { ~D() {} };\nint main(int argc, char **) {\n  %s\n}\n' "$body" > jcp$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c jcp$n.cpp -o x$n.o 2>&1 | grep -m1 'error:' | sed 's/^\(jcp[0-9]*\.cpp:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "jcp$n.cpp: builds"; done)" "jcp1.cpp:3: error: cannot jump from this goto statement to its label
jcp2.cpp:3: error: cannot jump from switch statement to this case label
jcp3.cpp:3: error: cannot jump from this goto statement to its label
jcp4.cpp:3: error: cannot jump from switch statement to this case label
jcp5.cpp: builds
jcp6.cpp: builds
jcp7.cpp: builds
jcp8.cpp: builds"
# C: A BLOCK'S `extern' DECLARATION (1.6.25; ccl_redef_block_externs/4): of another type than the file's object, or
# than another block's, clang's words, a later file-scope declaration held to it; the same type and a bound builds
check "C: a block's extern declaration of another type than its object's is refused in clang's words, and the same type builds (1.6.25)" "$(n=0; for pair in 'long x;|void f(void) { extern int x; (void)x; }' 'void f(void) { extern long x; (void)x; }|int x;' 'int x;|void f(void) { extern int x; (void)x; }' 'void f(void) { extern int x; (void)x; }|void g(void) { extern long x; (void)x; }' 'int x;|void f(void) { { extern long x; (void)x; } }' 'int x;|void f(void) { long x = 1; { extern long x; (void)x; } }' 'static int x;|void f(void) { extern int x; (void)x; }' 'int a[];|void f(void) { extern int a[3]; (void)a; }'; do n=$((n + 1)); printf '%s\n%s\nint main(void) { return 0; }\n' "${pair%%|*}" "${pair#*|}" > bex$n.c; o=$("$CICILI" -std=c17 -fsyntax-only bex$n.c  2>&1 | grep -m1 'error:' | sed 's/^\(bex[0-9]*\.c:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "bex$n.c: builds"; done)" "bex1.c:2: error: redeclaration of 'x' with a different type: 'int' vs 'long'
bex2.c:2: error: redefinition of 'x' with a different type: 'int' vs 'long'
bex3.c: builds
bex4.c:2: error: redeclaration of 'x' with a different type: 'long' vs 'int'
bex5.c:2: error: redeclaration of 'x' with a different type: 'long' vs 'int'
bex6.c:2: error: redeclaration of 'x' with a different type: 'long' vs 'int'
bex7.c: builds
bex8.c: builds"
# C: THE LANGUAGE'S OWN `defer' KEEPS THE DEFER RULE'S WORDS (1.6.25): clang knows no such form, and its words are the rule's,
# a goto's and a case label's
check "C: a jump over the language's own defer keeps the defer rule's words, a goto's and a case label's (1.6.25)" "$(n=0; for body in 'if (argc > 5) goto in; { char *s = malloc(4); defer(s) { free(s); } in: return 0; }' 'switch (argc) { case 1: { char *s = malloc(4); defer(s) { free(s); } case 2: return 0; } } return 1;'; do n=$((n + 1)); printf '#include <stdlib.h>\nint main(int argc, char **argv) {\n  (void)argv;\n  %s\n}\n' "$body" > jdf$n.c; o=$("$CICILI" -std=c17 -fsyntax-only jdf$n.c 2>&1 | grep -m1 'error:'); [ -n "$o" ] && echo "$o" || echo "jdf$n.c: builds"; done)" "jdf1.c:4: error: goto over a defer (or a local with a destructor) to label 'in' in goto(in) (function main)
jdf2.c:4: error: goto over a defer (or a local with a destructor) to label 'case 2' in case(int(2),return(4,int(0))) (function main)"
# C: A K&R DEFINITION (1.6.25; ccl_knr_check/3): at C23, which removed it, clang's `unknown type name 'a''; before C23
# a name of its list that no declaration follows, clang's implicit int words; a list whose names each are declared builds
check "C: a K&R definition is refused at C23 and a parameter of no declaration since C99, in clang's words (1.6.25)" "$(n=0; for std in c23 c17; do for body in 'int f(a) int a; { return a; }' 'int f(a, b) int a; char *b; { return a + (b != 0); }' 'int f(a) { return a; }' 'int f(a, b) int b; { return a + b; }'; do n=$((n + 1)); printf '%s\nint main(void) { return 0; }\n' "$body" > knr$n.c; o=$("$CICILI" -std=$std -fsyntax-only knr$n.c  2>&1 | grep -m1 'error:' | sed 's/^\(knr[0-9]*\.c:[0-9]*\):[0-9]*:/\1:/; s/ \[-W[a-z-]*\]$//'); [ -n "$o" ] && echo "$o" || echo "knr$n.c: builds"; done; done)" "knr1.c:1: error: unknown type name 'a'
knr2.c:1: error: unknown type name 'a'
knr3.c:1: error: unknown type name 'a'
knr4.c:1: error: unknown type name 'a'
knr5.c: builds
knr6.c: builds
knr7.c:1: error: parameter 'a' was not declared, defaults to 'int'; ISO C99 and later do not support implicit int
knr8.c:1: error: parameter 'a' was not declared, defaults to 'int'; ISO C99 and later do not support implicit int"
# C: A CALL OF A FUNCTION MARKED UNAVAILABLE (1.6.25; ccl_unavailable_note/2, ir_unavailable_call/1): clang's words, its
# message, and the note of the declaration, a use of its name too, C23's bracketed spelling of clang's too; GCC's warning attribute and an unavailable function never
# used build
check "C: a call of a function marked unavailable is refused in clang's words with its note, and what clang takes builds (1.6.25)" "$(n=0; for body in 'void g(void) __attribute__((unavailable));\nint main(void) {\n  g();\n  return 0;\n}' 'void h(void) __attribute__((unavailable("gone")));\nint main(void) {\n  h();\n  return 0;\n}' '__attribute__((unavailable("old"))) int q(int);\nint main(void) {\n  return q(1);\n}' 'void k(void) __attribute__((warning("careful")));\nvoid k(void) {}\nint main(void) {\n  k();\n  return 0;\n}' 'void m(void) __attribute__((noreturn, unavailable("x")));\nint main(void) { return 0; }' 'void g(void) __attribute__((unavailable));\nint main(void) {\n  void (*p)(void) = g;\n  return p != 0;\n}' 'void g(void) __attribute__((unavailable));\nvoid g(void) {}\nint main(void) { return 0; }' '[[clang::unavailable]] void g(void);\nint main(void) {\n  g();\n  return 0;\n}'; do n=$((n + 1)); printf "$body\n" > unav$n.c; o=$("$CICILI" -std=c23 -fsyntax-only unav$n.c 2>&1 | grep -E ': (error|note):' | sed 's/^\(unav[0-9]*\.c:[0-9]*\):[0-9]*:/\1:/'); [ -n "$o" ] && echo "$o" || echo "unav$n.c: builds"; done)" "unav1.c:3: error: 'g' is unavailable
unav1.c:1: note: 'g' has been explicitly marked unavailable here
unav2.c:3: error: 'h' is unavailable: gone
unav2.c:1: note: 'h' has been explicitly marked unavailable here
unav3.c:3: error: 'q' is unavailable: old
unav3.c:1: note: 'q' has been explicitly marked unavailable here
unav4.c: builds
unav5.c: builds
unav6.c:3: error: 'g' is unavailable
unav6.c:1: note: 'g' has been explicitly marked unavailable here
unav7.c: builds
unav8.c:3: error: 'g' is unavailable
unav8.c:1: note: 'g' has been explicitly marked unavailable here"
# C++: A FREE FUNCTION MARKED UNAVAILABLE (1.6.25; ir_unavailable_call/1 over a name that no overload keys): a call and a use
# of its name, in clang++'s words with the note; one never used builds
check "C++: a free function marked unavailable is refused in clang++'s words where it is called or named (1.6.25)" "$(n=0; for body in 'void g() __attribute__((unavailable("old")));\nint main() {\n  g();\n  return 0;\n}' '[[clang::unavailable]] int q(int);\nint main() {\n  int (*p)(int) = q;\n  return p != nullptr;\n}' 'void g() __attribute__((unavailable));\nvoid g() {}\nint main() { return 0; }'; do n=$((n + 1)); printf "$body\n" > unavp$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++17 -c unavp$n.cpp -o x$n.o 2>&1 | grep -E ': (error|note):' | sed 's/^\(unavp[0-9]*\.cpp:[0-9]*\):[0-9]*:/\1:/'); [ -n "$o" ] && echo "$o" || echo "unavp$n.cpp: builds"; done)" "unavp1.cpp:3: error: 'g' is unavailable: old
unavp1.cpp:1: note: 'g' has been explicitly marked unavailable here
unavp2.cpp:3: error: 'q' is unavailable
unavp2.cpp:1: note: 'q' has been explicitly marked unavailable here
unavp3.cpp: builds"
check "C++: a member function, a static one, an overload and a namespace's function marked unavailable, clang's and GCC's spellings, in clang++'s words with the note of the declaration (1.6.26): a member's mark after its declarator was dropped, and an overload's and a member's callee is the desugaring's name" "$(n=0; for src in 'struct S { int g() __attribute__((unavailable("gone"))); int h() { return 1; } };\nint main() { S s; return s.g(); }' 'struct S { static int k() __attribute__((__unavailable__("old"))); };\nint main() { return S::k(); }' 'struct B { [[clang::unavailable("x")]] int m() const; };\nint main() { const B b{}; return b.m(); }' 'int f(int) __attribute__((unavailable));\nint f(double d) { return (int)d; }\nint main() { return f(1); }' 'namespace n { int h() __attribute__((unavailable("no"))); }\nint main() { return n::h(); }'; do n=$((n + 1)); printf "$src\n" > unavpp$n.cpp; "$ROOT/bin/cicilang++" -c unavpp$n.cpp -o unavpp$n.o 2>&1 | head -1; done)" "unavpp1.cpp:2: error: 'g' is unavailable: gone
unavpp2.cpp:2: error: 'k' is unavailable: old
unavpp3.cpp:2: error: 'm' is unavailable: x
unavpp4.cpp:3: error: 'f' is unavailable
unavpp5.cpp:2: error: 'h' is unavailable: no"
# C: A FLEXIBLE ARRAY MEMBER GIVEN A LITERAL (1.6.25; ir_flex_count/2): its bytes and its terminator, `[4 x i8] c"abc\00"',
# as clang lays it; the run of test/c/run/flexinit.c cannot tell the terminator from the zero after it
check "C: a flexible array member given a literal holds its bytes and its terminator in the IR, as clang lays it (1.6.25)" "$(printf 'struct T { short k; char s[]; };\nstruct T w = {2, "abc"};\nint main(void) { return w.s[3]; }\n' > flx.c; "$CICILI" -emit-llvm -c flx.c && grep '^@w = ' flx.ll | grep -c '\[4 x i8\] c"abc\\00"')" "1"
# A VOID VALUE IS NO VALUE (1.6.14; C17 6.3.2.2/1): an initializer, an assignment, an argument, a return, an operand, a
# condition, a cast, an argument through an ellipsis, a member's item, a step, an indirection, an address, a subscript and
# a switch over one are refused in clang's words at the line, and so are the operands beside them that C refuses: a switch
# over a floating value, a pointer or a struct, a subscript of a double, of an int, an indirection of an int, a call's value
# assigned, stepped or its address taken, an atomic's compound with one, and two structs compared. Through 1.6.13 each void
# value went to LLVM's parser at no line of the program, `void type only allowed for function results', the forms beside
# were lowered as their conversions' integers or refused by name, and `h() = 4' ran
vv_pre='struct S { int m; }; void f(void) {} int g(int v) { return v; } int vf(int, ...); int h(void) { return 3; }\nint main(int argc, char **argv) { (void)argv; int z = 1, a[2] = { 1, 2 }; double d = 1.5; int *p = &z; struct S s = { 1 }; (void)a; (void)d; (void)p; (void)s; (void)argc;'
check "a void value where a value is taken, and the operands beside it, are refused in clang's words at the line (1.6.14)" "$(n=0; for body in 'int x = f(); (void)x;' 'z = f();' 'g(f());' 'return f();' 'z = f() + 1;' 'z = f() == 0;' 'z += f();' 'z = !f();' 'z = -f();' 'if (f()) z = 2;' 'z = f() ? 1 : 2;' 'z = f() && 1;' 'z = (int)f();' 'vf(1, f());' 'struct S t = { f() }; (void)t;' 'void w;' 'f()++;' 'z = *f();' 'int *q = &f(); (void)q;' 'z = a[f()];' 'switch (f()) { default: break; }' 'int x = z ? f() : 1; (void)x;' 'int *q = f(); (void)q;' 'struct S t = f(); (void)t;' 'switch (d) { default: break; }' 'switch (p) { default: break; }' 'switch (s) { default: break; }' 'z = a[d];' 'z = z[0];' 'z = *z;' 'h() = 4;' 'h()++;' 'int *q = &h(); (void)q;' '_Atomic int at = 0; at += f();' 'z = s == s;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$vv_pre" "$body" > vv$n.c; "$CICILI" -std=c17 -fsyntax-only vv$n.c 2>&1 | head -1; done)" "vv1.c:3: error: initializing 'int' with an expression of incompatible type 'void'
vv2.c:3: error: assigning to 'int' from incompatible type 'void'
vv3.c:3: error: passing 'void' to parameter of incompatible type 'int'
vv4.c:3: error: returning 'void' from a function with incompatible result type 'int'
vv5.c:3: error: invalid operands to binary expression ('void' and 'int')
vv6.c:3: error: invalid operands to binary expression ('void' and 'int')
vv7.c:3: error: invalid operands to binary expression ('int' and 'void')
vv8.c:3: error: invalid argument type 'void' to unary expression
vv9.c:3: error: invalid argument type 'void' to unary expression
vv10.c:3: error: statement requires expression of scalar type ('void' invalid)
vv11.c:3: error: used type 'void' where arithmetic or pointer type is required
vv12.c:3: error: invalid operands to binary expression ('void' and 'int')
vv13.c:3: error: operand of type 'void' where arithmetic or pointer type is required
vv14.c:3: error: argument type 'void' is incomplete
vv15.c:3: error: initializing 'int' with an expression of incompatible type 'void'
vv16.c:3: error: variable has incomplete type 'void'
vv17.c:3: error: cannot increment value of type 'void'
vv18.c:3: error: indirection requires pointer operand ('void' invalid)
vv19.c:3: error: cannot take the address of an rvalue of type 'void'
vv20.c:3: error: array subscript is not an integer
vv21.c:3: error: statement requires expression of integer type ('void' invalid)
vv22.c:3: error: initializing 'int' with an expression of incompatible type 'void'
vv23.c:3: error: initializing 'int *' with an expression of incompatible type 'void'
vv24.c:3: error: initializing 'struct S' with an expression of incompatible type 'void'
vv25.c:3: error: statement requires expression of integer type ('double' invalid)
vv26.c:3: error: statement requires expression of integer type ('int *' invalid)
vv27.c:3: error: statement requires expression of integer type ('struct S' invalid)
vv28.c:3: error: array subscript is not an integer
vv29.c:3: error: subscripted value is not an array, pointer, or vector
vv30.c:3: error: indirection requires pointer operand ('int' invalid)
vv31.c:3: error: expression is not assignable
vv32.c:3: error: expression is not assignable
vv33.c:3: error: cannot take the address of an rvalue of type 'int'
vv34.c:3: error: invalid operands to binary expression ('_Atomic(int)' and 'void')
vv35.c:3: error: invalid operands to binary expression ('struct S' and 'struct S')"
# ... AND C'S CASTS AND CALLS BESIDE IT (1.6.14; C17 6.5.4/2, 6.5.2.2/6): thirty-six bodies -- a cast's type is void or a
# scalar and its operand a scalar, in clang's order and words, GNU's union cast of a member's type; a pointer and a floating
# value convert to neither; a void value to a function with no prototype; the conditions of for, while and do. Through 1.6.13
# `(_Bool)s' and `(int)u' built, a void operand went to LLVM's parser, and the rest were `no conversion from'
cc_pre='struct S { int m; }; union U { int i; }; void f(void) {} enum E { E0 }; typedef int *IP; typedef int I; int k(); int k2() { return 0; } int (*kp)();\nint main(void) { int z = 1; struct S s = { 1 }; union U u = { 1 }; int *p = &z; double d = 1.5; char c = 0; (void)z; (void)s; (void)u; (void)p; (void)d; (void)c;'
check "C's casts and calls beside a void value are refused in clang's words at the line (1.6.14): a cast's type and operand by clang's order, GNU's union casts, a call with no prototype" "$(n=0; for body in 'int *q = (int *)f(); (void)q;' 'struct S t = (struct S)f(); (void)t;' '_Bool b = (_Bool)f(); (void)b;' 'double e = (double)f(); (void)e;' 'enum E e = (enum E)f(); (void)e;' 'int *q = (IP)f(); (void)q;' 'I i = (I)f(); (void)i;' 'for (; f(); ) break;' 'while (f()) break;' 'do { } while (f());' 'z = (f(), f()) + 1;' 'z = -(void)z;' 'z = (void)z ? 1 : 2;' 'z = f() || 1;' 'z = !(void)z;' 'z = ~f();' 'z = +f();' 'long l = (long)f(); (void)l;' 'z = (z ? f() : f()) + 1;' 'k(f());' 'z = k2(f());' 'z = kp(f());' 'k(1, f());' 'z = (int)s;' 'struct S t = (struct S)1; (void)t;' 'p = (int *)s;' 'd = (double)s;' 'z = (int)u;' 'enum E e = (enum E)s; (void)e;' '_Bool b = (_Bool)s; (void)b;' 'z = (int)(struct S){ 1 };' 'p = (int *)d;' 'd = (double)p;' 'union U v = (union U)c; (void)v;' 'union U v = (union U)f(); (void)v;' 'struct S t = (struct S)u; (void)t;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$cc_pre" "$body" > cc$n.c; "$CICILI" -std=c17 -fsyntax-only cc$n.c 2>&1 | head -1; done)" "cc1.c:3: error: operand of type 'void' where arithmetic or pointer type is required
cc2.c:3: error: used type 'struct S' where arithmetic or pointer type is required
cc3.c:3: error: operand of type 'void' where arithmetic or pointer type is required
cc4.c:3: error: operand of type 'void' where arithmetic or pointer type is required
cc5.c:3: error: operand of type 'void' where arithmetic or pointer type is required
cc6.c:3: error: operand of type 'void' where arithmetic or pointer type is required
cc7.c:3: error: operand of type 'void' where arithmetic or pointer type is required
cc8.c:3: error: statement requires expression of scalar type ('void' invalid)
cc9.c:3: error: statement requires expression of scalar type ('void' invalid)
cc10.c:3: error: statement requires expression of scalar type ('void' invalid)
cc11.c:3: error: invalid operands to binary expression ('void' and 'int')
cc12.c:3: error: invalid argument type 'void' to unary expression
cc13.c:3: error: used type 'void' where arithmetic or pointer type is required
cc14.c:3: error: invalid operands to binary expression ('void' and 'int')
cc15.c:3: error: invalid argument type 'void' to unary expression
cc16.c:3: error: invalid argument type 'void' to unary expression
cc17.c:3: error: invalid argument type 'void' to unary expression
cc18.c:3: error: operand of type 'void' where arithmetic or pointer type is required
cc19.c:3: error: invalid operands to binary expression ('void' and 'int')
cc20.c:3: error: argument type 'void' is incomplete
cc21.c:3: error: argument type 'void' is incomplete
cc22.c:3: error: argument type 'void' is incomplete
cc23.c:3: error: argument type 'void' is incomplete
cc24.c:3: error: operand of type 'struct S' where arithmetic or pointer type is required
cc25.c:3: error: used type 'struct S' where arithmetic or pointer type is required
cc26.c:3: error: operand of type 'struct S' where arithmetic or pointer type is required
cc27.c:3: error: operand of type 'struct S' where arithmetic or pointer type is required
cc28.c:3: error: operand of type 'union U' where arithmetic or pointer type is required
cc29.c:3: error: operand of type 'struct S' where arithmetic or pointer type is required
cc30.c:3: error: operand of type 'struct S' where arithmetic or pointer type is required
cc31.c:3: error: operand of type 'struct S' where arithmetic or pointer type is required
cc32.c:3: error: operand of type 'double' cannot be cast to a pointer type
cc33.c:3: error: pointer cannot be cast to type 'double'
cc34.c:3: error: cast to union type from type 'char' not present in union
cc35.c:3: error: cast to union type from type 'void' not present in union
cc36.c:3: error: used type 'struct S' where arithmetic or pointer type is required"
# ... AND AN OPERAND READ AS A VALUE IS NAMED BY ITS UNQUALIFIED TYPE (1.6.14; C17 6.3.2.1/2): twenty-two bodies -- a
# condition's, `?:''s, a unary operator's, `*''s, a cast's and a switch's operand of a `const', `volatile' or `_Atomic' type,
# named as clang names it, and a binary operator's, which keeps its qualifiers; Apple's block pointer under `*' and `[]',
# spelled `void (^)(void)', no pointer to either. Through 1.6.13 a unary operator's and a condition's words kept `const'
check "an operand read as a value is named by its unqualified type, a block pointer is no pointer (1.6.14)" "$(n=0; for body in 'const struct S cs = { 1 }; if (cs) z = 2;' 'const struct S cs = { 1 }; z = cs ? 1 : 2;' 'const struct S cs = { 1 }; z = cs && 1;' 'const struct S cs = { 1 }; z = -cs;' 'const struct S cs = { 1 }; z = ~cs;' 'const double cd = 1; switch (cd) { default: break; }' 'const struct S cs = { 1 }; while (cs) break;' 'const int cx = 1; z = *cx;' 'const struct S cs = { 1 }; z = !cs;' 'const struct S cs = { 1 }; z = (int)cs;' 'const double cd = 1; int *q = (int *)cd; (void)q;' 'const struct S cs = { 1 }; z = cs + 1;' 'const struct S cs = { 1 }; z = +cs;' 'const struct S cs = { 1 }; z = cs == cs;' 'const int *const cp = 0; z = cp * 2;' '_Atomic(int) ax = 1; z = *ax;' '_Atomic(double) ad = 1; switch (ad) { default: break; }' 'volatile struct S vs = { 1 }; z = -vs;' 'void (^b)(void) = 0; *b;' 'void (^b)(void) = 0; z = b[0] != 0;' 'int (^b)(int) = 0; z = 1[b];' 'void (^const b)(void) = 0; *b;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$cc_pre" "$body" > cq$n.c; "$CICILI" -std=c17 -fsyntax-only cq$n.c 2>&1 | head -1; done)" "cq1.c:3: error: statement requires expression of scalar type ('struct S' invalid)
cq2.c:3: error: used type 'struct S' where arithmetic or pointer type is required
cq3.c:3: error: invalid operands to binary expression ('const struct S' and 'int')
cq4.c:3: error: invalid argument type 'struct S' to unary expression
cq5.c:3: error: invalid argument type 'struct S' to unary expression
cq6.c:3: error: statement requires expression of integer type ('double' invalid)
cq7.c:3: error: statement requires expression of scalar type ('struct S' invalid)
cq8.c:3: error: indirection requires pointer operand ('int' invalid)
cq9.c:3: error: invalid argument type 'struct S' to unary expression
cq10.c:3: error: operand of type 'struct S' where arithmetic or pointer type is required
cq11.c:3: error: operand of type 'double' cannot be cast to a pointer type
cq12.c:3: error: invalid operands to binary expression ('const struct S' and 'int')
cq13.c:3: error: invalid argument type 'struct S' to unary expression
cq14.c:3: error: invalid operands to binary expression ('const struct S' and 'const struct S')
cq15.c:3: error: invalid operands to binary expression ('const int *const' and 'int')
cq16.c:3: error: indirection requires pointer operand ('int' invalid)
cq17.c:3: error: statement requires expression of integer type ('double' invalid)
cq18.c:3: error: invalid argument type 'struct S' to unary expression
cq19.c:3: error: indirection requires pointer operand ('void (^)(void)' invalid)
cq20.c:3: error: subscripted value is not an array, pointer, or vector
cq21.c:3: error: subscripted value is not an array, pointer, or vector
cq22.c:3: error: indirection requires pointer operand ('void (^)(void)' invalid)"
check "a function and an extern object that a block declares are in scope there, another unit defining them (1.6.14)" "$("$CICILI" "$R/link/blockfn_main.c" "$R/link/blockfn_def.c" -o blockfn 2>&1 && ./blockfn)" "42 7"
check "a struct or a union where C takes a scalar is refused in clang's words at its line (1.6.1, the forms beside): after !, beside && and ||, as the condition of ?:, if, while, do and for, under ++ and --, and under a unary -" "$(n=0; for body in 'int x = !sp;' 'int x = sp ? 1 : 0;' 'sp++;' 'int x = sp && 1;' 'int x = 1 || sp;' 'if (sp) return 1;' 'while (sp) { }' 'do { } while (sp);' 'for (; sp; ) { }' '--sp;' 'union U { int i; } u = { 1 }; if (u) return 1;' 'int x = -sp;'; do n=$((n + 1)); printf '%b\n    %s\n    return 0; }\n' "$ops_pre" "$body" > opr$n.c; "$CICILI" -std=c17 -fsyntax-only opr$n.c 2>&1 | head -1; done)" "opr1.c:3: error: invalid argument type 'struct P' to unary expression
opr2.c:3: error: used type 'struct P' where arithmetic or pointer type is required
opr3.c:3: error: cannot increment value of type 'struct P'
opr4.c:3: error: invalid operands to binary expression ('struct P' and 'int')
opr5.c:3: error: invalid operands to binary expression ('int' and 'struct P')
opr6.c:3: error: statement requires expression of scalar type ('struct P' invalid)
opr7.c:3: error: statement requires expression of scalar type ('struct P' invalid)
opr8.c:3: error: statement requires expression of scalar type ('struct P' invalid)
opr9.c:3: error: statement requires expression of scalar type ('struct P' invalid)
opr10.c:3: error: cannot decrement value of type 'struct P'
opr11.c:3: error: statement requires expression of scalar type ('union U' invalid)
opr12.c:3: error: invalid argument type 'struct P' to unary expression"
# ... and C's alone: C++'s pairs are not asked (ir_binary_operands/7), since a type that the desugaring gives is not
# always the program's -- test/cpp/run/autoptrdiff.cpp holds libc++ 22's form, and unaryplus.cpp C++'s `+'
# A NAME THAT THE PROGRAM DECLARES IS NO MACRO'S (1.6.2): a header of the program's own, included before <functional.pl>,
# whose function is named as one of its macros, names the program's function at the build that reads the header and at
# the build that the store serves the header's read to -- the store serves a header of the program's own only where no
# macro file came before it (ccl_inst_context/1), and the file gets a newer time between the two builds
check "a function of a header of the program's own, included before <functional.pl> and named as one of its macros, is the program's, at the build that reads the header and at the build that the store serves its read to (1.6.2)" "$(printf 'static int greater(int a, int b) { return a - b; }\n' > pn_hdr.h; printf '#include <stdio.h>\n#include "pn_hdr.h"\n#include <functional.pl>\nint main(void) { printf("%%d %%d\\n", greater(7, 3), less(1, 2)); return 0; }\n' > pn_main.c; "$CICILI" pn_main.c -o pn1 && ./pn1; touch -d "@$(( $(date +%s) + 5 ))" pn_main.c; "$CICILI" pn_main.c -o pn2 && ./pn2)" "4 1
4 1"
# THE GLOBAL MACROS YIELD AS WELL (1.6.9, the owner's rule: "Yes user implemented should win over ccllib's macros"):
# a program's own println, of its file or of a header of its own, is the program's, at the build that reads the
# header and at the build that the store serves its read to; clang's build of the same file prints the same line
check "... and a program's own function named as a global macro (println), of its file or of a header of its own, is the program's, at both builds, the owner's rule (1.6.9)" "$(printf '#include <stdio.h>\nstatic void println(const char *s) { printf("mine %%s\\n", s); }\nint main(void) { println("x"); return 0; }\n' > pn_std.c; "$CICILI" pn_std.c -o pn3 2>&1 && ./pn3; printf '#include <stdio.h>\nstatic void println(const char *s) { printf("own %%s\\n", s); }\n' > pn_std.h; printf '#include "pn_std.h"\nint main(void) { println("y"); return 0; }\n' > pn_std2.c; "$CICILI" pn_std2.c -o pn4 2>&1 && ./pn4; touch -d "@$(( $(date +%s) + 5 ))" pn_std2.c; "$CICILI" pn_std2.c -o pn5 2>&1 && ./pn5)" "mine x
own y
own y"
# A GLOBAL MACRO'S CALL BEFORE THE PROGRAM'S OWN DECLARATION OF ITS NAME (1.6.9): the macro took the call, and the
# program's println below it was not called, with no word -- `early' and `own late', where clang refuses the call; it is
# refused in clang's words at its line, at C17 and at C23, as 1.1.2 refuses a call of a function defined further down,
# and so is a macro file's macro that takes an argument unread (0.264's road, ccl_unread_call//3) where the program's
# own text declares its name further on. A
# name that a header of the system declares further on is no program's: the global clone before glibc's <sched.h> is
# the macro's still, as everywhere a header of the system names it
check "... and a call of a global macro by a name that the program's own text declares further on is refused in clang's words at its line, at C17 and at C23, a macro file's macro that takes an argument unread too; one by a name that a header of the system declares further on is the macro's (1.6.9)" "$(printf '#include <stdio.h>\nstatic void show(void) { println("early"); }\nstatic void println(const char *s) { printf("own %%s\\n", s); }\nint main(void) { show(); println("late"); return 0; }\n' > pn_late.c; "$CICILI" -std=c17 -fsyntax-only pn_late.c 2>&1 | head -1; "$CICILI" -std=c23 -fsyntax-only pn_late.c 2>&1 | head -1; printf '#include <stdio.h>\n#include <unread.pl>\nint main(void) { int s = 0; loop(i, 4, s += i); printf("%%d\\n", s); return 0; }\nstatic void loop(void) { }\n' > pn_unread.c; "$CICILI" -I "$R/run" -std=c17 -fsyntax-only pn_unread.c 2>&1 | head -1; printf '#define _GNU_SOURCE\n#include <stdio.h>\n#include <stdlib.h>\nstruct pt { int x; };\nstatic void use(void) { struct pt a = { 4 }; own struct pt *b = clone(&a); printf("%%d\\n", b->x); free(b); }\n#include <sched.h>\nint main(void) { use(); return 0; }\n' > pn_sched.c; "$CICILI" pn_sched.c -o pn6 2>&1 && ./pn6)" "pn_late.c:2: error: call to undeclared function 'println'; ISO C99 and later do not support implicit function declarations
pn_late.c:2: error: use of undeclared identifier 'println'
pn_unread.c:3: error: call to undeclared function 'loop'; ISO C99 and later do not support implicit function declarations
4"
# THE TRAPS' REFUSALS (1.6.10): a trap's call of another count, an argument of the verbose trap that is no constant string
# or holds a `$', and a trap or __builtin_unreachable taken as a value are refused in clang's words at their line, in C and in
# C++ -- each was `undeclared'; a constant object's name, which clang's evaluator reads, is its initializer's since 1.6.39 (its
# checks below). C++'s are built with -c: its -fsyntax-only stops after the reader
check "the traps' refusals in clang's words at their line (1.6.10): __builtin_trap and __builtin_debugtrap of an argument, __builtin_verbose_trap of one and of three, of an integer, of a plain array and of a \$, a trap and __builtin_unreachable taken as a value; in C++ an argument and a value -- a constant array and a constexpr pointer by name, refused by name until 1.6.39, build, as clang's do (the checks of 1.6.39 below)" "$(n=0; for body in 'int main(void) { __builtin_trap(1); return 0; }' 'int main(void) { __builtin_debugtrap(2); return 0; }' 'int main(void) { __builtin_verbose_trap("m"); return 0; }' 'int main(void) { __builtin_verbose_trap("c", "m", "x"); return 0; }' 'int main(void) { __builtin_verbose_trap("c", 0); return 0; }' 'static char m[] = "x";\nint main(void) { __builtin_verbose_trap("c", m); return 0; }' 'int main(void) { __builtin_verbose_trap("c", "costs $5"); return 0; }' 'int main(void) { void (*f)(void) = __builtin_trap; (void)f; return 0; }' 'int main(void) { void (*f)(void) = &__builtin_debugtrap; (void)f; return 0; }' 'int main(void) { void (*f)(void) = __builtin_unreachable; (void)f; return 0; }' 'static const char m[] = "x";\nint main(void) { __builtin_verbose_trap("c", m); return 0; }'; do n=$((n + 1)); printf '%b\n' "$body" > trapr$n.c; "$CICILI" -std=c17 -fsyntax-only trapr$n.c 2>&1 | head -1; done; n=0; for body in 'int main() { __builtin_trap(1); }' 'int main() { void (*f)() = __builtin_trap; (void)f; }' 'constexpr const char *m = "x";\nint main() { __builtin_verbose_trap("c", m); }'; do n=$((n + 1)); printf '%b\n' "$body" > trapp$n.cpp; "$ROOT/bin/cicilang++" -std=c++20 -c trapp$n.cpp -o trapp$n.o 2>&1 | head -1; done)" "trapr1.c:1: error: too many arguments to function call, expected 0, have 1
trapr2.c:1: error: too many arguments to function call, expected 0, have 1
trapr3.c:1: error: too few arguments to function call, expected 2, have 1
trapr4.c:1: error: too many arguments to function call, expected 2, have 3
trapr5.c:1: error: argument to __builtin_verbose_trap must be a pointer to a constant string
trapr6.c:2: error: argument to __builtin_verbose_trap must be a pointer to a constant string
trapr7.c:1: error: argument to __builtin_verbose_trap must not contain \$
trapr8.c:1: error: builtin functions must be directly called
trapr9.c:1: error: builtin functions must be directly called
trapr10.c:1: error: builtin functions must be directly called
trapp1.cpp:1: error: too many arguments to function call, expected 0, have 1
trapp2.cpp:1: error: builtin functions must be directly called"
# THE STREAMS AS C++'S (1.6.3): `cin >> a >> b' chains, a character is read after the white space before it, as C++'s
# skipws, and `while (cin >> x)' ends where the input does, the stream failed after it -- the ccllib gate's programs
# read no input, so this check gives cin its own; clang++'s build of the same program over std::cin prints the line
check "cin >> a >> b chains, cin >> c >> d reads characters after the white space, and while (cin >> x) ends at the end of the input, the stream failed (1.6.3)" "$(printf '#include <stdio.h>\n#include <iostream.pl>\nint main(void) {\n  int a = 0, b = 0, x = 0, n = 0, sum = 0;\n  char c = 0, d = 0;\n  cin >> a >> b;\n  cin >> c >> d;\n  while (cin >> x) { sum += x; n++; }\n  printf("%%d [%%c][%%c] %%d %%d %%d\\n", a + b, c, d, sum, n, fail(cin));\n  return 0;\n}\n' > sio.c; "$CICILI" sio.c -o sio && printf '3 4\n p\tq\n1 2 3\n' | ./sio)" "7 [p][q] 6 3 1"
# THE AMBITIOUS PROGRAM'S FINDINGS (0.290): a macro file's header under a relative -I with the program in another directory; an
# output file whose directory is not there; a header that was not read to its end, and a file that an #include of the program
# does not find, named under the build's error
check "a macro file's NAME.pl.h is found under a relative -I when the program is in another directory (0.290)" "$(mkdir -p rinc rsrc && echo 'rel_unused(x).' > rinc/rel.pl && echo 'int abs(int);' > rinc/rel.pl.h && printf '#include <rel.pl>\nint main(void) { return abs(-7) - 7; }\n' > rsrc/main.c && "$CICILI" -I rinc rsrc/main.c -o relinc 2>&1 && ./relinc; echo "exit $?")" "exit 0"
check "an output file whose directory is not there is refused by its path, before the build, and the errors are counted (0.290)" "$("$CICILI" -c "$R/run/forty2.c" -o no/such/dir/forty2.o 2>&1; echo "exit $?")" "no/such/dir/forty2.o: error: unable to open the output file: no such directory 'no/such/dir'
cicilang: 1 error(s)
exit 1"
check "a header of the program's own whose read stopped stops the build at its line, in the file's own words (0.290, 1.6.36) -- it was named in a note under the build's error, at its #include, as a library header's still is; clang says ./stop.h:2:9: error: expected expression" "$(printf 'int y_of_h;\nint x = ;\nint z_of_h;\n' > stop.h; printf '#include %s\nint main(void) { return z_of_h; }\n' '"stop.h"' > usestop.c; "$CICILI" -fsyntax-only usestop.c 2>&1 | grep -v '^In file included from' | head -2)" "./stop.h:2: error: syntax error: could not read this item (gave up near line 2)
cicilang: 1 error(s)"
# AN #include OF THE PROGRAM THAT FINDS NO FILE STOPS THE BUILD AT ITS LINE, AND ONE THAT NAMES NO FILE IS REFUSED (1.6.22;
# dr_missing_include/2, pp_do_include/6), in clang's words; the first was passed over, named in a note under a later error
# (0.290), and the second dropped with no word
check "an #include of the program that finds no file stops the build at its line, in clang's words, one in a group that is skipped is not looked for, and one that names no file is refused (1.6.22)" "$(printf '#include %s\n#if 0\n#include %s\n#endif\n#include %s\nint main(void) { return nope_value(); }\n' '"nope.h"' '"skipped.h"' '<nope/sys.h>' > usenope.c; "$CICILI" -fsyntax-only usenope.c 2>&1; echo "exit $?"; printf '#if 0\n#include %s\n#endif\nint main(void) { return 0; }\n' '"skipped.h"' > passnope.c; "$CICILI" -fsyntax-only passnope.c 2>&1; echo "exit $?"; printf '#include \\"x.h\\"\nint main(void) { return 0; }\n' > badinc.c; "$CICILI" -fsyntax-only badinc.c 2>&1; echo "exit $?")" "usenope.c:1: fatal error: 'nope.h' file not found
cicilang: 1 error(s)
exit 1
exit 0
badinc.c:1: error: expected \"FILENAME\" or <FILENAME>
cicilang: 1 error(s)
exit 1"
# ... AND -E STOPS AT ITS FILE'S OWN #include THAT FINDS NO FILE OR NAMES NONE (1.6.24; pp_e_top_file/1, dr_pp_thrown/2), as
# clang -E does; a header's is passed over still
check "-E stops at its file's own #include that finds no file or names none, in clang's words (1.6.24)" "$("$CICILI" -E usenope.c 2>&1 > /dev/null; echo "exit $?"; "$CICILI" -E badinc.c 2>&1 > /dev/null; echo "exit $?"; "$CICILI" -E passnope.c > /dev/null 2>&1; echo "exit $?")" "usenope.c:1: fatal error: 'nope.h' file not found
exit 1
badinc.c:1: error: expected \"FILENAME\" or <FILENAME>
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
mkdir -p hdrnames/inc; printf 'static int leaky(void) {\n    char *p = (char *) 0;\n    p = (char *) __builtin_malloc(4);\n    return p != 0;\n}\n' > hdrnames/leak.h; printf 'static int setc(void) {\n    const int x = 1;\n    x = 2;\n    return x;\n}\n' > hdrnames/inc/cst.h
printf '#include "leak.h"\nint main(void) { return leaky(); }\n' > hdrnames/a.c; printf '#include "inc/cst.h"\nint main(void) { return setc(); }\n' > hdrnames/b.c
check "C: an error in a function of the program's own header names the header and its line, as clang does (1.6.36): the check's in ./leak.h and the lowering's in ./inc/cst.h -- each was the user's file with the header's line" "$(cd hdrnames && for f in a b; do "$CICILI" -c $f.c -o $f.o 2>&1 | grep -v '^In file included from' | head -1 | cut -d: -f1-3; done)" "./leak.h:4: error
./inc/cst.h:3: error"
printf 'static int bad2(void) { return 1 +; }\n' > hdrnames/syn.h; printf '#include "syn.h"\nstatic int f2(void) { return 2; }\n' > hdrnames/outer.h
printf '#include "syn.h"\nint main(void) { return bad2(); }\n' > hdrnames/c.c; printf '#include "outer.h"\nint main(void) { return f2(); }\n' > hdrnames/d.c
check "C: a header of the program's own that no read takes stops the build at its line (1.6.36), included by the file and by another such header -- each was an undeclared call at the user's line, where clang says ./syn.h:1:35: error: expected expression" "$(cd hdrnames && for f in c d; do "$CICILI" -c $f.c -o $f.o 2>&1 | grep -v '^In file included from' | head -1; done)" "./syn.h:1: error: syntax error: could not read this item (gave up near line 1)
./syn.h:1: error: syntax error: could not read this item (gave up near line 1)"
printf 'int x;\nstruct bag { foo items; int n; };\n' > hdrnames/unk.h; printf '#include "unk.h"\nint main(void) { struct bag b = { 0 }; (void) b; return x; }\n' > hdrnames/e.c
check "C: a type name that nothing declares in a header of the program's own is refused at the header's line, under its name (1.6.36), as clang refuses it" "$(cd hdrnames && "$CICILI" -c e.c -o e.o 2>&1 | grep -v '^In file included from' | head -1)" "./unk.h:2: error: unknown type name 'foo'"
check "C: an error in a header is led by the includes that brought it, the outermost first, as clang leads its own (1.6.37): a stopped header that a header of the file includes, clang's two lines, and the check's error in ./leak.h -- each error stood alone" "$(cd hdrnames && "$CICILI" -c d.c -o d.o 2>&1 | head -2; "$CICILI" -c a.c -o a.o 2>&1 | head -1)" "In file included from d.c:1:
In file included from ./outer.h:1:
In file included from a.c:1:"
check "C: a type name that nothing declares is refused at its declaration's line in clang's words (1.6.36): a global, a parameter, a pointer result, a typedef, a member of a struct on the struct's line and a local struct's pointer member -- the first two were not lowered yet: typedef(foo) at no line, the member no_member's words, and the other three were built" "$(n=0; for src in 'foo g;
int main(void) { return 0; }' 'static int f(foo a) { (void) a; return 0; }
int main(void) { return f(0); }' 'static foo *mk(void) { return 0; }
int main(void) { return mk() != 0; }' 'typedef foo bar;
int main(void) { return 0; }' 'struct bag { foo items; int n; };
int main(void) { struct bag b = { 0 }; (void) b; return 0; }' 'int main(void) {
    struct { foo *p; } s = { 0 };
    (void) s;
    return 0;
}'; do n=$((n + 1)); printf "$src\n" > unktype$n.c; "$CICILI" -std=c23 -c unktype$n.c -o unktype$n.o 2>&1 | head -1; done)" "unktype1.c:1: error: unknown type name 'foo'
unktype2.c:1: error: unknown type name 'foo'
unktype3.c:1: error: unknown type name 'foo'
unktype4.c:1: error: unknown type name 'foo'
unktype5.c:1: error: unknown type name 'foo'
unktype6.c:2: error: unknown type name 'foo'"
check "C: a type name that nothing declares in a block's declaration is clang's use of an undeclared identifier (1.6.37), a pointer's, an object's and a for's own -- a for's was not lowered yet: typedef(widget), the others unknown type name -- and a block's tag's member keeps unknown type name" "$(n=0; for src in 'int main(void) {
    widget *x = 0;
    (void) x;
    return 0;
}' 'int main(void) {
    widget y;
    (void) y;
    return 0;
}' 'int main(void) {
    for (widget i = 0; i < 2; i++) {}
    return 0;
}' 'int main(void) {
    struct { widget *p; } s = { 0 };
    (void) s;
    return 0;
}'; do n=$((n + 1)); printf "$src\n" > blkunk$n.c; "$CICILI" -std=c23 -c blkunk$n.c -o blkunk$n.o 2>&1 | head -1; done)" "blkunk1.c:2: error: use of undeclared identifier 'widget'
blkunk2.c:2: error: use of undeclared identifier 'widget'
blkunk3.c:2: error: use of undeclared identifier 'widget'
blkunk4.c:2: error: unknown type name 'widget'"
check "C: a compound literal of a block, read after the block, is a borrow of a dead object, its words naming it a compound literal (1.6.37) -- it was built" "$(printf 'int main(void) { int *p; { p = &(int){ 1 }; } return *p; }\n' > cldead.c; "$CICILI" -c cldead.c -o cldead.o 2>&1 | head -1)" "cldead.c:1: error: use of a borrow after its owner was consumed: 'p' in borrowed_from('a compound literal') (function main)"
# A VERBOSE TRAP'S STRING THROUGH A CONSTANT OBJECT'S NAME (1.6.39): a constant array of characters and a constant pointer to
# characters of the file are read as their initializers, as clang's evaluator reads them; they were `not lowered yet:
# verbose_trap_string(m)'
check "-g: a verbose trap's strings through a constant object's name, a constant array's and a constant pointer's, and one moved by a constant, as clang 23's (1.6.39)" "$(printf 'static const char m[] = "my message";\nconst char *const k = "other";\nint main(int argc, char **argv) {\n  if (argc > 5) __builtin_verbose_trap("cat", m);\n  if (argc > 6) __builtin_verbose_trap(k, m + 3);\n  return 0;\n}\n' > vtobj.c; "$CICILI" -g -S -emit-llvm vtobj.c -o vtobj.ll 2>&1 | head -1; grep -o '__clang_trap_msg[^"]*' vtobj.ll | sort -u)" '__clang_trap_msg$cat$my message
__clang_trap_msg$other$message'
# ... AND A FUNCTION'S, KEYED BY ITS ADDRESS (1.6.39, ir_trap_key/2): a local constant array that hides a global of its name and
# a static local are read as clang reads them; a global array that is not constant is refused in clang's words
check "-g: a verbose trap's string through a local constant array that hides a global and through a static local, as clang 23's, and a global array that is not constant refused in clang's words (1.6.39)" "$(printf 'static const char m[] = "g";\nint f(int argc) { const char m[] = "f local"; if (argc > 5) __builtin_verbose_trap("c", m); return 0; }\nint main(int argc, char **argv) {\n  char m[] = "plain";\n  static const char s[] = "static local";\n  if (argc > 5) __builtin_verbose_trap("c", s);\n  return f(argc) + (int)sizeof m - 6;\n}\n' > vtloc.c; "$CICILI" -g -S -emit-llvm vtloc.c -o vtloc.ll 2>&1 | head -1; grep -o '__clang_trap_msg[^"]*' vtloc.ll | sort -u; printf 'static char n[] = "x";\nint main(int argc, char **argv) {\n  if (argc > 5) __builtin_verbose_trap("c", n);\n  return 0;\n}\n' > vtplain.c; "$CICILI" -c vtplain.c -o vtplain.o 2>&1 | head -1)" '__clang_trap_msg$c$f local
__clang_trap_msg$c$static local
vtplain.c:3: error: argument to __builtin_verbose_trap must be a pointer to a constant string'
# A DEAD BRANCH'S LIMITS (1.6.39, ir_dead_branch/3): clang's code generation emits a branch that holds a label, and one whose
# condition does not fold, so a call of a function that GCC's error marks in either is refused in its words
check "C: GCC's error attribute in a branch that clang's code generation emits -- one with a label, one whose condition does not fold --, in clang's words (1.6.39)" "$(n=0; for src in '__attribute__((error("never call"))) void f(void);
int main(int argc, char **argv) { if (0) { lbl: f(); } if (argc > 9) goto lbl; return 0; }' '__attribute__((error("never call"))) void f(void);
int main(int argc, char **argv) {
  if (argc > 3) f();
  return 0;
}'; do n=$((n + 1)); printf "$src\n" > deadbr$n.c; "$CICILI" -c deadbr$n.c -o deadbr$n.o 2>&1 | head -1; done)" "deadbr1.c:2: error: call to 'f' declared with 'error' attribute: never call
deadbr2.c:3: error: call to 'f' declared with 'error' attribute: never call"
# AN `extern inline' WITHOUT GCC'S gnu_inline IS C99'S EXTERNAL DEFINITION (1.6.39, ccl_gnu_inline_item/3): defined again, it is
# refused in clang's words (1.6.41, ccl_redef_words/5) -- a GNU mode's own where the `extern inline' definition is the first, the
# plain words under -std=c17 and where it is the second
check "C: an extern inline function without gnu_inline, defined again, is refused in clang's words: a GNU mode's where it is the first definition, the plain ones under -std=c17 and where it is the second (1.6.39, 1.6.41)" "$(printf '#include <stdio.h>\nextern inline int k(int x) { return x + 1; }\nint k(int x) { return x + 2; }\nint main(void) { printf("%%d\\n", k(1)); return 0; }\n' > einl.c; printf 'int k(int x) { return x + 2; }\nextern inline int k(int x) { return x + 1; }\nint main(void) { return k(1); }\n' > einl2.c; "$CICILI" -c einl.c -o einl.o 2>&1 | head -1; "$CICILI" -std=c17 -c einl.c -o einl.o 2>&1 | head -1; "$CICILI" -c einl2.c -o einl2.o 2>&1 | head -1)" "einl.c:3: error: redefinition of a 'extern inline' function 'k' is not supported in C99 mode
einl.c:3: error: redefinition of 'k'
einl2.c:2: error: redefinition of 'k'"
# ... AND A READ'S NOTES END WITH ITS WALK (1.6.41): of two files in one build, the second's plain definitions defined again are
# the plain words, though the first defined an `extern inline' function of the name
check "C: a read's notes of extern inline definitions end with its walk: a second file's plain redefinition keeps the plain words (1.6.41)" "$(printf 'extern inline int k(int x) { return x + 1; }\nint use_k(void) { return k(1); }\n' > eia.c; printf 'int k(int x) { return x; }\nint k(int x) { return x + 2; }\n' > eib.c; "$CICILI" -c eia.c eib.c 2>&1 | grep error | head -1)" "eib.c:2: error: redefinition of 'k'"
# GCC'S weak ACROSS TWO UNITS (1.6.40): a strong definition of the other unit is the one that the link takes, a function's and
# an object's, and a weak declaration that the other unit defines is no null address, as clang's link has them
# ... AND A DECLARATOR'S OWN ATTRIBUTE IS ITS OWN (1.6.40, ccl_gattr_take/2): the specifiers' reach each declarator, one after
# a declarator reaches that one alone
check "C: GCC's weak and section of the specifiers reach each declarator, a declarator's own that one alone, in the IR (1.6.40)" "$(printf 'int v __attribute__((weak)) = 1, u = 3;\n__attribute__((section("sx"))) int a = 1, b = 2;\nint main(void) { return v + u + a + b - 7; }\n' > wdecl.c; "$CICILI" -S -emit-llvm wdecl.c -o wdecl.ll 2>&1 | head -1; grep '^@[uvab] =' wdecl.ll | sort)" '@a = global i32 1, section "sx"
@b = global i32 2, section "sx"
@u = global i32 3
@v = weak global i32 1'
check "C: GCC's weak across two units -- the other unit's strong definitions of a function and an object win, and a weak declaration it defines is called -- as clang's (1.6.40)" "$(printf '#include <stdio.h>\n__attribute__((weak)) int f(void) { return 1; }\n__attribute__((weak)) int v = 1;\n__attribute__((weak)) int g(void);\nint main(void) { printf("%%d %%d %%d\\n", f(), v, g ? g() : 0); return 0; }\n' > weaka.c; printf 'int f(void) { return 2; }\nint v = 5;\nint g(void) { return 9; }\n' > weakb.c; "$CICILI" weaka.c weakb.c -o weakab 2>&1 | head -2; ./weakab)" "2 5 9"
# A VOID VARIABLE OF A typeof OR decltype TYPE NAMES THE TYPE AS WRITTEN (1.6.41; ccl_typeof_here/2's spelled operand,
# ir_typeof_words/2, cpp_decl_pieces/6): `typeof' and `__typeof__' alike in C, `decltype' in C++, a call over calls among them,
# and a pointer to such a type builds, as clang's and clang++'s do
check "C and C++: a void variable of a typeof or decltype type names the type as written, in clang's words -- typeof and __typeof__, a call over calls, decltype in C++ -- and a pointer to one builds (1.6.41)" "$(printf 'void f(void);\nint main(void) {\n  typeof(f()) x;\n  return 0;\n}\n' > tyv1.c; printf 'int g(int);\nvoid h(int, int);\nint main(void) {\n  __typeof__(h(1, g(2))) w;\n  return 0;\n}\n' > tyv2.c; printf 'void f(void);\nint main(void) {\n  typeof(f()) *p = 0;\n  __typeof__(f()) *q = p;\n  return p == q ? 0 : 1;\n}\n' > tyv3.c; printf 'void f();\nint main() {\n  decltype(f()) z;\n  return 0;\n}\n' > tyv4.cpp; "$CICILI" -std=c23 -c tyv1.c -o tyv1.o 2>&1 | head -1; "$CICILI" -c tyv2.c -o tyv2.o 2>&1 | head -1; "$CICILI" -std=c23 tyv3.c -o tyv3 2>&1 | head -1; ./tyv3; echo "exit $?"; "$ROOT/bin/cicilang++" -c tyv4.cpp -o tyv4.o 2>&1 | head -1)" "tyv1.c:3: error: variable has incomplete type 'typeof (f())' (aka 'void')
tyv2.c:4: error: variable has incomplete type 'typeof (h(1, g(2)))' (aka 'void')
exit 0
tyv4.cpp:3: error: variable has incomplete type 'decltype(f())' (aka 'void')"
# THE VERBOSE TRAP'S ARGUMENTS AS ITS `const char *' PARAMETERS (1.6.42; ir_trap_param/1): a value that no `const char *'
# takes is refused in clang 23's words of a call's argument, before the trap's own words -- in C a wide, UTF-16 and UTF-32
# literal by its array's type, an integer, a pointer, an array, a struct and a floating value, a name that nothing declares;
# a cast of a wide literal keeps the trap's own words, and C17's u8 literal, a plain one, builds
check "C: the verbose trap's arguments as its const char * parameters, in clang 23's words: wide literals by their arrays, an integer, a pointer, an array, a struct, a floating value, a wide pointer moved, a cast of a wide literal, an undeclared name, and a u8 literal that builds (1.6.42)" "$(n=0; for body in 'int main(void) { __builtin_verbose_trap("c", L"wide"); return 0; }' 'int main(void) { __builtin_verbose_trap("c", u"x"); return 0; }' 'int main(void) { __builtin_verbose_trap("c", U"x"); return 0; }' 'int main(void) { __builtin_verbose_trap(L"cat", "m"); return 0; }' 'int main(void) { __builtin_verbose_trap("c", 5); return 0; }' '#include <stddef.h>\nconst wchar_t *w = L"x";\nint main(void) { __builtin_verbose_trap("c", w); return 0; }' 'const int iv[2] = { 1, 2 };\nint main(void) { __builtin_verbose_trap("c", iv); return 0; }' 'struct S { int a; };\nstruct S st;\nint main(void) { __builtin_verbose_trap("c", st); return 0; }' 'int main(void) { __builtin_verbose_trap("c", 1.5); return 0; }' 'int main(void) { __builtin_verbose_trap("c", L"ab" + 1); return 0; }' 'int main(void) { __builtin_verbose_trap("c", (const char *) L"x"); return 0; }' 'int main(void) { __builtin_verbose_trap("c", nosuch); return 0; }' 'int main(int argc, char **argv) { if (argc > 5) __builtin_verbose_trap(u8"c", "m"); return 0; }'; do n=$((n + 1)); printf '%b\n' "$body" > vta$n.c; o=$("$CICILI" -std=c17 -fsyntax-only vta$n.c 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "vta$n.c: built"; done)" "vta1.c:1: error: incompatible pointer types passing 'int[5]' to parameter of type 'const char *'
vta2.c:1: error: incompatible pointer types passing 'unsigned short[2]' to parameter of type 'const char *'
vta3.c:1: error: incompatible pointer types passing 'unsigned int[2]' to parameter of type 'const char *'
vta4.c:1: error: incompatible pointer types passing 'int[4]' to parameter of type 'const char *'
vta5.c:1: error: incompatible integer to pointer conversion passing 'int' to parameter of type 'const char *'
vta6.c:3: error: incompatible pointer types passing 'const wchar_t *' (aka 'const int *') to parameter of type 'const char *'
vta7.c:2: error: incompatible pointer types passing 'const int[2]' to parameter of type 'const char *'
vta8.c:3: error: passing 'struct S' to parameter of incompatible type 'const char *'
vta9.c:1: error: passing 'double' to parameter of incompatible type 'const char *'
vta10.c:1: error: incompatible pointer types passing 'int *' to parameter of type 'const char *'
vta11.c:1: error: argument to __builtin_verbose_trap must be a pointer to a constant string
vta12.c:1: error: use of undeclared identifier 'nosuch'
vta13.c: built"
# ... AND IN C++ (1.6.42) in clang++ 23's words, `cannot initialize a parameter of type 'const char *' with an lvalue of
# type 'const wchar_t[2]'', an lvalue or an rvalue, a class's `no viable conversion'; a null pointer constant passes, to
# the trap's own words; C++20's u8 literal is char8_t's and
# C++17's a plain one, which builds. Built with -c: C++'s -fsyntax-only stops after the reader
check "C++: the verbose trap's arguments as its const char * parameters, in clang++ 23's words: an integer, a wide pointer, an array, a class, a wide pointer moved, wide, UTF-8 and UTF-16 literals, a floating value, a bool, an undeclared name, an enumerator; 0 and nullptr pass to the trap's own words, and C++17's u8 literal builds (1.6.42)" "$(n=0; for body in 'int main() { __builtin_verbose_trap("c", 5); }' '#include <stddef.h>\nconst wchar_t *w = L"x";\nint main() { __builtin_verbose_trap("c", w); }' 'const int iv[2] = { 1, 2 };\nint main() { __builtin_verbose_trap("c", iv); }' 'struct S { int a; };\nS st;\nint main() { __builtin_verbose_trap("c", st); }' 'int main() { __builtin_verbose_trap("c", L"ab" + 1); }' 'int main() { __builtin_verbose_trap("c", L"x"); }' 'int main() { __builtin_verbose_trap("c", u8"x"); }' 'int main() { __builtin_verbose_trap("c", 1.5); }' 'int main() { __builtin_verbose_trap("c", false); }' 'int main() { __builtin_verbose_trap("c", nosuch); }' 'enum E { E1 = 1 };\nint main() { __builtin_verbose_trap("c", E1); }' 'int main() { __builtin_verbose_trap(u"c", "m"); }' 'int main() { __builtin_verbose_trap("c", 0); }' 'int main() { __builtin_verbose_trap("c", nullptr); }'; do n=$((n + 1)); printf '%b\n' "$body" > vtb$n.cpp; o=$("$ROOT/bin/cicilang++" -std=c++20 -c vtb$n.cpp -o vtb.o 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "vtb$n.cpp: built"; done; o=$("$ROOT/bin/cicilang++" -std=c++17 -c vtb7.cpp -o vtb.o 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "vtb7.cpp at C++17: built")" "vtb1.cpp:1: error: cannot initialize a parameter of type 'const char *' with an rvalue of type 'int'
vtb2.cpp:3: error: cannot initialize a parameter of type 'const char *' with an lvalue of type 'const wchar_t *'
vtb3.cpp:2: error: cannot initialize a parameter of type 'const char *' with an lvalue of type 'const int[2]'
vtb4.cpp:3: error: no viable conversion from 'S' to 'const char *'
vtb5.cpp:1: error: cannot initialize a parameter of type 'const char *' with an rvalue of type 'const wchar_t *'
vtb6.cpp:1: error: cannot initialize a parameter of type 'const char *' with an lvalue of type 'const wchar_t[2]'
vtb7.cpp:1: error: cannot initialize a parameter of type 'const char *' with an lvalue of type 'const char8_t[2]'
vtb8.cpp:1: error: cannot initialize a parameter of type 'const char *' with an rvalue of type 'double'
vtb9.cpp:1: error: cannot initialize a parameter of type 'const char *' with an rvalue of type 'bool'
vtb10.cpp:1: error: use of undeclared identifier 'nosuch'
vtb11.cpp:2: error: cannot initialize a parameter of type 'const char *' with an rvalue of type 'E'
vtb12.cpp:1: error: cannot initialize a parameter of type 'const char *' with an lvalue of type 'const char16_t[2]'
vtb13.cpp:1: error: argument to __builtin_verbose_trap must be a pointer to a constant string
vtb14.cpp:1: error: argument to __builtin_verbose_trap must be a pointer to a constant string
vtb7.cpp at C++17: built"
# C++: A HEADER OF THE PROGRAM'S OWN AS THE FILE'S RUN KEPT IT (1.6.42; cpp_live_units/2, cpp_kind_in/2): a clash in it and a
# second definition in it, or beside the file's, are refused at the header's line, the header named, in clang++ 23's words,
# one included in an `extern "C"' block too;
# a guarded header and a `#pragma once' one included twice, a header in a header, and a header's dead arms -- in a namespace
# and in an `extern "C"' block too -- build, as
# clang++'s do; an unguarded header included twice is refused
check "C++: a clash and a second definition in a header of the program's own, or beside the file's, refused at the header's line in clang++'s words, one in an extern \"C\" block too; guarded, #pragma once, nested headers and dead arms, a namespace's and an extern \"C\" block's among them, build; an unguarded header included twice refused (1.6.42)" "$(printf '#ifndef KH_H\n#define KH_H\nint f(int x);\nint f;\n#endif\n' > kh.h; printf '#include "kh.h"\nint main() { return 0; }\n' > kh.cpp; printf 'int f(int x) { return x; }\nint f(int y) { return y + 1; }\n' > rd.h; printf '#include "rd.h"\nint main() { return f(1); }\n' > rd.cpp; printf 'int t(void);\n' > kd.h; printf 'int t;\n#include "kd.h"\nint main() { return 0; }\n' > kd.cpp; printf 'int g(int x) { return x; }\n' > rd3.h; printf 'int g(int y) { return y; }\n#include "rd3.h"\nint main() { return g(1); }\n' > rd3.cpp; printf 'inline int nf(int x) { return x; }\n' > nh.h; printf '#include "nh.h"\n#include "nh.h"\nint main() { return nf(0); }\n' > nh.cpp; printf 'int ef(int x);\nint ef;\n' > ec.h; printf 'extern "C" {\n#include "ec.h"\n}\nint main() { return 0; }\n' > ec.cpp; for f in kh rd kd rd3 nh; do "$ROOT/bin/cicilang++" -c $f.cpp -o $f.o 2>&1 | grep error | head -1; done; "$ROOT/bin/cicilang++" -c ec.cpp -o ec.o 2>&1 | head -2; printf '#ifndef G_H\n#define G_H\ninline int gf(int x) { return x; }\nint gv = 3;\n#endif\n' > gh.h; printf '#include "gh.h"\n' > ggh.h; printf '#include "ggh.h"\n#include "gh.h"\n#include "ggh.h"\nint main() { return gf(gv) - 3; }\n' > gh.cpp; printf '#pragma once\ninline int pf(int x) { return x; }\n' > ph.h; printf '#include "ph.h"\n#include "ph.h"\nint main() { return pf(0); }\n' > ph.cpp; printf '#ifndef A_H\n#define A_H\n#if 0\nint af(int x) { return x + 1; }\n#else\nint af(int x) { return x; }\n#endif\n#endif\n' > ah.h; printf '#include "ah.h"\n#include "ah.h"\nint main() { return af(0); }\n' > ah.cpp; printf '#ifndef NS_H\n#define NS_H\nnamespace n {\n#if 0\nint t;\n#else\nint t(int x);\n#endif\n}\nextern "C" {\n#if 0\nint u;\n#else\nint u(int x);\n#endif\n}\n#endif\n' > nsh.h; printf '#include "nsh.h"\n#include "nsh.h"\nint n::t(int x) { return x; }\nextern "C" int u(int x) { return x; }\nint main() { return n::t(0) + u(0); }\n' > nsh.cpp; for f in gh ph ah nsh; do "$ROOT/bin/cicilang++" $f.cpp -o $f 2>&1 | head -1; ./$f; echo "$f: exit $?"; done)" "./kh.h:4: error: redefinition of 'f' as different kind of symbol
./rd.h:2: error: redefinition of 'f'
./kd.h:1: error: redefinition of 't' as different kind of symbol
./rd3.h:1: error: redefinition of 'g'
./nh.h:1: error: redefinition of 'nf'
In file included from ec.cpp:2:
./ec.h:2: error: redefinition of 'ef' as different kind of symbol
gh: exit 0
ph: exit 0
ah: exit 0
nsh: exit 0"
# C++: A CONST OBJECT WITH NO INITIALIZER (1.6.43; [dcl.init.general]/7; cpp_const_defaults/4, cpp_const_default/4): an
# object of a const scalar, pointer, enumeration or array of them type, of the file, a namespace or a block, static or not,
# is clang++'s `default initialization of an object of const type', and a constexpr one `constexpr variable must be
# initialized'; an extern declaration, a class with a user-provided default constructor or default member initializers and
# a pointer to const build. Built with -c: C++'s -fsyntax-only stops after the reader
check "C++: a const object with no initializer in clang++'s words -- a scalar, an array, a const pointer, an enumeration, a static bool, a nested namespace's, a namespace's extern \"C\" block's, a second declarator, a constexpr one, a block's and a block's static constexpr -- and the forms beside them that build (1.6.43)" "$(n=0; for body in 'const int x;\nint main() { return 0; }' 'const int T[3];\nconst int T[] = { 1, 2, 3 };\nint main() { return T[1] - 2; }' 'int *const p;\nint main() { return 0; }' 'enum E { A };\nconst E e;\nint main() { return 0; }' 'static const bool b;\nint main() { return 0; }' 'namespace n { namespace m { const double d; } }\nint main() { return 0; }' 'const int y = 1, z;\nint main() { return y; }' 'constexpr int k;\nint main() { return 0; }' 'int main() {\n  const unsigned u;\n  return 0;\n}' 'int main() {\n  static constexpr int w;\n  return 0;\n}' 'extern const int ex;\nstruct Q { Q() {} int a; };\nconst Q qq;\nstruct R { int a = 1; };\nconst R rr;\nconst char *s;\nint main() { const Q lq; const R lr; return 0; }' 'namespace n { extern "C" { const int c; } }\nint main() { return 0; }'; do n=$((n + 1)); printf '%b\n' "$body" > cdi$n.cpp; o=$("$ROOT/bin/cicilang++" -c cdi$n.cpp -o cdi.o 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "cdi$n.cpp: built"; done)" "cdi1.cpp:1: error: default initialization of an object of const type 'const int'
cdi2.cpp:1: error: default initialization of an object of const type 'const int[3]'
cdi3.cpp:1: error: default initialization of an object of const type 'int *const'
cdi4.cpp:2: error: default initialization of an object of const type 'const E'
cdi5.cpp:1: error: default initialization of an object of const type 'const bool'
cdi6.cpp:1: error: default initialization of an object of const type 'const double'
cdi7.cpp:1: error: default initialization of an object of const type 'const int'
cdi8.cpp:1: error: constexpr variable 'k' must be initialized by a constant expression
cdi9.cpp:2: error: default initialization of an object of const type 'const unsigned int'
cdi10.cpp:2: error: constexpr variable 'w' must be initialized by a constant expression
cdi11.cpp: built
cdi12.cpp:1: error: default initialization of an object of const type 'const int'"
# C++: A CALL OF A FUNCTION THAT GCC'S `error' MARKS (1.6.44; cpp_error_attr_units/2, ir_error_attr_call/1) is refused in
# clang++ 23's words, the function named as its back end names it, by its demangled symbol: a free function, a static
# member, a member, a nested class's, a const member's, a namespace's, an anonymous namespace's, an overload, the
# parameters' canonical types, an ellipsis, a definition, an extern "C" function by its bare name and a (void) list; a
# call that clang++ makes an invoke, a call in a dead branch, an overload that the mark leaves out and the function's
# address build
check "C++: a call of a function that GCC's error attribute marks, in clang++'s words by its demangled name -- free, static, member, nested, const, namespace, anonymous namespace, overload, the parameters' canonical types, an ellipsis, a definition, extern \"C\", (void), an array -- and an invoke, a dead branch, the other overload and the address that build (1.6.44)" "$(printf '%s\n' 'void f() __attribute__((error("do not call f")));' 'int g(int x) __attribute__((error("no g")));' 'struct S { static void m() __attribute__((error("no m"))); void n(int) __attribute__((error("no n"))); struct B { void z() __attribute__((error("z"))); }; void c(int) const __attribute__((error("c"))); };' 'namespace q { void h() __attribute__((error("no h"))); }' 'void o(int) __attribute__((error("o int")));' 'inline void o(double) {}' 'enum E { E1 };' 'void t(const char *, int *, unsigned, long long, char *const, const int, S &, const S &, int (*)(int), bool, unsigned long, E, signed char, long double, short, const char *const *) __attribute__((error("t")));' 'void va(int, ...) __attribute__((error("va")));' '__attribute__((error("def"))) inline int df(int x) { return x; }' 'struct D { ~D() {} };' 'extern "C" void k(int) __attribute__((error("k")));' 'void fv(void) __attribute__((error("fv")));' 'void ar(int a[3]) __attribute__((error("ar")));' > eah.h
n=0; for c in 'if (argc > 5) f();' 'if (argc > 5) g(1);' 'if (argc > 5) S::m();' 'S s; if (argc > 5) s.n(2);' 'S::B b; if (argc > 5) b.z();' 'const S s; if (argc > 5) s.c(1);' 'if (argc > 5) q::h();' 'if (argc > 5) an();' 'if (argc > 5) o(1);' 'S s; if (argc > 5) t(0, 0, 0, 0, 0, 0, s, s, 0, 0, 0, E1, 0, 0, 0, 0);' 'if (argc > 5) va(1, 2.0);' 'if (argc > 5) df(2);' 'if (argc > 5) k(1);' 'if (argc > 5) fv();' 'int buf[3]; if (argc > 5) ar(buf);' 'if (argc > 5) o(1.0); if (0) f(); void (*p)() = &an; (void)p; D d; if (argc > 5) f();'; do n=$((n + 1)); { echo '#include "eah.h"'; echo 'namespace { void an() __attribute__((error("an"))); }'; echo 'int main(int argc, char **argv) {'; echo "  $c"; echo '  return 0;'; echo '}'; } > eat$n.cpp; o=$("$ROOT/bin/cicilang++" -c eat$n.cpp -o eat.o 2>&1 | head -1); [ -n "$o" ] && echo "$o" || echo "eat$n.cpp: built"; done)" "eat1.cpp:4: error: call to 'f()' declared with 'error' attribute: do not call f
eat2.cpp:4: error: call to 'g(int)' declared with 'error' attribute: no g
eat3.cpp:4: error: call to 'S::m()' declared with 'error' attribute: no m
eat4.cpp:4: error: call to 'S::n(int)' declared with 'error' attribute: no n
eat5.cpp:4: error: call to 'S::B::z()' declared with 'error' attribute: z
eat6.cpp:4: error: call to 'S::c(int) const' declared with 'error' attribute: c
eat7.cpp:4: error: call to 'q::h()' declared with 'error' attribute: no h
eat8.cpp:4: error: call to '(anonymous namespace)::an()' declared with 'error' attribute: an
eat9.cpp:4: error: call to 'o(int)' declared with 'error' attribute: o int
eat10.cpp:4: error: call to 't(char const*, int*, unsigned int, long long, char*, int, S&, S const&, int (*)(int), bool, unsigned long, E, signed char, long double, short, char const* const*)' declared with 'error' attribute: t
eat11.cpp:4: error: call to 'va(int, ...)' declared with 'error' attribute: va
eat12.cpp:4: error: call to 'df(int)' declared with 'error' attribute: def
eat13.cpp:4: error: call to 'k' declared with 'error' attribute: k
eat14.cpp:4: error: call to 'fv()' declared with 'error' attribute: fv
eat15.cpp:4: error: call to 'ar(int*)' declared with 'error' attribute: ar
eat16.cpp: built"
# C++: A NULL POINTER CONSTANT FOR AN ARRAY PARAMETER (1.6.44; [dcl.fct]/5, [conv.ptr]/1; cpp_null_to_pointer/2): an
# array parameter is a pointer, which `0' initializes -- `ar(0)' of `int ar(int a[3])' was `no matching function for
# call to 'ar''
check "C++: a literal 0 for an array parameter, of a bound, of none and of const characters, builds and runs as clang++'s (1.6.44)" "$(n=0; for b in 'int ar(int a[3]) { return a ? 1 : 0; }\nint main() { return ar(0); }' 'int ar(int a[]) { return a ? 1 : 0; }\nint main() { return ar(0) + ar(nullptr); }' 'int ar(const char a[4]) { return a ? 1 : 0; }\nint main() { return ar(0); }'; do n=$((n + 1)); printf '%b\n' "$b" > nap$n.cpp; o=$("$ROOT/bin/cicilang++" nap$n.cpp -o nap$n 2>&1 | head -1); if [ -n "$o" ]; then echo "$o"; else ./nap$n; echo "nap$n: exit $?"; fi; done)" "nap1: exit 0
nap2: exit 0
nap3: exit 0"
# C++: AN UNNAMED NAMESPACE IN A HEADER OF THE PROGRAM'S OWN (1.6.44; cpp_anon_ns_items/3): its using-directive stands
# after the header's #include too, so that a function, an object and a class of it are found in the file, as clang++
# finds them -- each was `use of undeclared identifier' where the file had no unnamed namespace of its own
check "C++: a function, an object and a class of an unnamed namespace in the program's own header are found in the file, and a declaration there defined in the file's own, as clang++ builds and runs them (1.6.44)" "$(n=0; for b in 'namespace { int an() { return 3; } }|an()' 'namespace { int av = 3; }|av' 'namespace { struct AS { int v = 3; }; }|AS().v' 'namespace { int an(); }|an()'; do n=$((n + 1)); h=${b%%|*}; u=${b#*|}; printf '%s\n' "$h" > anh$n.h; { echo "#include \"anh$n.h\""; [ $n = 4 ] && echo 'namespace { int an() { return 3; } }'; echo "int main() { return $u - 3; }"; } > anf$n.cpp; o=$("$ROOT/bin/cicilang++" anf$n.cpp -o anf$n 2>&1 | head -1); if [ -n "$o" ]; then echo "$o"; else ./anf$n; echo "anf$n: exit $?"; fi; done)" "anf1: exit 0
anf2: exit 0
anf3: exit 0
anf4: exit 0"
if [ "$failures" -eq 0 ]; then echo "GREEN: driver"; else echo "RED: $failures failure(s)"; exit 1; fi
