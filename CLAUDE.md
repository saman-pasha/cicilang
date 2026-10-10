# cicilang -- how this repository is worked on

cicilang is a **Safe Modern C compiler to LLVM, written on cocolog**: a new implementation of Cicili's philosophy. It
reads C and C++, checks them and lowers them to LLVM IR; no C is ever emitted.

This file states the rules of the code as they hold now, by topic. One bullet is one rule: what the code does, the
predicates that do it, the standard's clause where one applies, the fixture that gates it, and why. The bullet ends
with the version that made the rule or last changed it. `HISTORY.md` keeps the record of every step: what it did, what
it found, its measurements and its gate numbers. `README.md` tells a user what runs; `DESIGN.md` gives the
architecture and the milestones. A step that changes a rule edits the rule here, in its topic, and writes its entry
in `HISTORY.md`.

At 0.129 the versions are: the module 0.129 (`ccl_p_version` in `module/cicilang.cicili`, `bin/cicilang --version`),
the reader 124 (`ccl_reader_version/1`, `library/ccl_syntax.pl`) and the lowering 70 (`ccl_lowering_version/1`,
`library/ccl_ir.pl`).

Build and prove, always in this order (or all of it, `sh test/gates.sh`):

```sh
CICILI=~/Projects/GitHub/cicili COCOLOG=~/Projects/GitHub/cocolog sh module/build.sh
sh test/reader.sh
sh test/compile.sh
sh test/driver.sh
sh test/objects.sh
sh proof/run.sh
sh test/libcxx.sh
sh test/cpp.sh
```

## Contents

- The owner's rules and how the work is done
- Where things are
- Build, prove and the gates
- The driver and the commands
- The lexers
- The preprocessor
- The C reader and the language's own forms
- The C++ reader
- Includes, summaries and the store
- Classes
- Templates
- Concepts and constraints
- Overload resolution
- Lambdas
- Constant evaluation
- Object layout and the ABI
- Exceptions, RTTI, coroutines, modules and contracts
- libc++: how the library is compiled
- The safe part
- The lowering
- Time and memory
- Findings about the neighbours and the instruments
- What runs
- Not done

## The owner's rules and how the work is done

### What cicilang is and what it leaves alone

- cicilang reads C and C++, checks them and lowers them to LLVM IR. It never emits C. `README.md` says what runs;
  `DESIGN.md` gives the architecture and the milestones M0 to M6. (from the start)
- The three neighbours are used, never edited. Cicili is the philosophy, the reference for what each form means, and
  the language of every native piece. cocolog is the host: every pass is its clauses, found through
  `COCOLOG_LIBRARY`. ZiguratIP is cocolog's store, reached only through cocolog. A limitation met in one of them is
  worked around here, written down as a finding, and raised with THAT repository's owner. (from the start)
- The compiler runs no clang and no LLVM binary (owner's rule). The preprocessor is cocolog's (`library/ccl_pp.pl`),
  and the back end is the embedded LLVM (`library(ccl_llvm)` over llvm-c). The link through `cc` (`c++` in C++) is
  the one system tool, because llvm-c has no linker. Only the gates and the benchmarks run clang: M0's proof, the ABI
  reference, the baselines. (M5)
- Nothing of the standard library is the compiler's own (owner's rule). The C freestanding headers in
  `library/include/` are the one exception. C++ compiles against libc++ as it ships: C++17 is the baseline, then
  C++20, C++23 and C++26. (0.41)
- The knowledge base is the user's, `~/.cicilang/KB` (`$CICILANG_KB`), never one per working directory (owner's rule,
  final after two turns). Every later C run, in any project and in the C gates, is served from it. (M4)

### The surface and the names

- The surface is four predicates (owner's rule): `cicilang_ast/2,3`, `cicilang_ir/2`, `cicilang_compile/3` and
  `cicilang_link/3`. They are defined over `ccl_read_file/3`, `ccl_ir_units/2`, `ccl_compile/3` and `ccl_link/3`. (M2)
- `bin/cicilang` takes clang's arguments: there are no new flags to learn (owner's rule). `-std` names the level of
  both languages. A flag it does not act on (`-W`, `-f`, `-pedantic`) is accepted and ignored.
  (from the start; `-D` and `-U` act since 0.112, `-g` since 0.128)
- cocolog has one namespace, so every predicate of the library has a prefix. `ccl_` is for the reader, the include
  layer, the inference, the global macros and the build. `pp_`, `cpp_`, `ck_`, `ir_` and `dr_` are for the
  preprocessor, the desugaring, the check, the lowering and the driver. Only the four doors are `cicilang_`. The C
  functions that the modules define are `ccl_` too. (from the start)
- The AST's functors (`unit`, `function`, `id`, `expr` ...) are bare, because they are data. Internals are quoted
  globals and facts: `'$ccl_…'`, `'$pp_…'`, `'$cpp_…'`, `'$ck_…'`, `'$ir_…'`, `'$dr_…'`. The objects layer in the
  module's Prolog half keeps its own surface (`object/1`, `new/3`, `::`) and tables (`'$object'/2`, `'$slot'/3`).
  (from the start)
- The repository and the language are `cicilang` (owner's rule): the commands, `module/cicilang.cicili` and
  `library(cicilang)`, the `CICILANG_KB`, `_INCLUDE`, `_LANG` and `_ME` variables, `~/.cicilang`, and the answer lines
  `cicilang: ok` and `cicilang: N error(s)`. The neighbour's names stay (Cicili, `$CICILI`, `cicili.lisp`, `sdk.cicili`,
  `.cicili`), and so does `ccl_`. A string that a fixture prints is data. The name was `cocolang` until 0.115; the owner
  renamed the repository to `cicilang`, and `~/.cocolang` moves to `~/.cicilang` by hand, the C store `KB` removed (a
  moved store sent the compile gate past 9 GB; a fresh one took 13 s). (0.100, 0.116)

### The owner's rules for the language and its passes

- Each addition to the language is an owner's rule, described in the language section: `name := expr;` and a pattern
  on its left, `name { members }` at file scope, `defer(a, b) { ... }`, a `.pl` file included as a macro file, and
  `#cocolog ... #end`. (from the start)
- The tie is written `x tie y` (owner's rule). `tie` is a contextual word, never a keyword, so `std::tie` and a C
  variable named `tie` keep their meaning. `<*>`, the old spelling, is no punctuator in either lexer. (0.109)
- `format`, `print`, `println` and `clone` are global macros in every file of the program, with no include (owner's
  rule). A library header read preprocessed does not get them (`ccl_lib_unit/1`): libc++ has a `format` of its own.
  (from the start, 0.99)
- Every pointer has an ownership path, or the program is refused (owner's rule). There is no warning channel: `untied`
  (no owner behind) and `unconsumed` (plain pointer not consumed) are errors, by the owner's decision after 0.14. (M3)
- An own array has a constant bound, or nothing (owner's rule). The one exception is a struct's last member, bounded by
  an earlier integer member: `own node *C[nc]`. (M3)
- The LLVM type travels with the value (owner's request). `ir_expr/4` answers the value, its C type and its LLVM type,
  and the consumers read the LLVM type instead of deriving it again. (2026-09-06)

### How the code is written

- A pattern is written once (owner's rule). Predicates of one shape are one predicate over a table or an argument:
  `ccl_binary//2` over `ccl_binop/2`, `ccl_unary_//3`, `ccl_cached/4`, `cpp_type_called/3`. The constant arithmetic
  is `ccl_const_eval/2`'s table alone, and `cpp_const_reduce/2` brings other forms to literals first. An `auto` result
  is found by ONE walk, `cpp_first_return_in/3`. (2026-09-06, 0.90, 0.104)
- A form that is not done is refused by name, never dropped. The desugaring calls `cpp_refuse(L, What)`, the lowering
  `ir_fail(What)`, and the check's last `ck_stmt` clause throws `not_lowered(F)` with `where(Fn, line(L))`. The
  diagnostic reads `not lowered yet: What`. (0.32)
- Every C++ form is desugared to the C that the check and the lowering take: `ccl_cpp_units/2`, run by
  `ccl_ir_units/2` before the check, the symbol table built again from its output. The lowering has C++ nodes only
  where C has no spelling: exceptions, coroutines, pointers to member. (0.33, 0.108)
- A name is looked up before it is given, at its arity AND at the DCG's: `N//K` is `N/(K+2)`. Else stray clauses fire
  on backtracking, with an error that names no line (`ccl_init_items//1` is `ccl_init_items/3`; `cpp_scalar_type/1`
  already existed). (0.93, 0.99)
- A predicate's helpers come after its last clause, never between its clauses: cocolog takes discontiguous clauses
  without a word. (0.103)
- Base clauses are exclusive: they cut. Two that both match `[]` make `findall/3` answer twice, and a constructor is
  emitted twice (`cpp_keep_defaults/3`, `cpp_args_fit/2`, `cpp_args_no_clash/2`). (0.66, 0.69)
- A comment ends the LINE: `%` in a cocolog clause, `#` in sh. Never rewrite a line that has a comment in its middle;
  one such edit commented out `ccl_declare(N, T)`, and another (0.117) put a comment in the middle of the first line of
  `cpp_enum_unsettled/4`, so that its goals after the `%` were no part of the clause and it failed on every call --
  three attempts to cure the symptom, which a probe around the neighbour predicate made look like a success elsewhere,
  failed before the clause was read as the file had it. A regression that no change explains is a mis-edit until proved
  otherwise: READ THE CLAUSE FROM THE FILE before building a theory. (0.58, 0.90, 0.117)
- A step that adds a token kind extends the spell-back (`ccl_pp_spell_tok/4`, `pp_spell/2`), so that the text of
  `cicilang++ -E` still reads back. (0.93)

### How a change is made and proved

- Nothing is claimed before its GREEN line. A rule is a check in a gate; a milestone is a proof that runs. Run the gate
  that the change touches. (from the start)
- A step that changes a rule every program reaches (the call passes, the overload acceptance, the reference binding)
  runs a pool of 40 to 50 fixtures that it can reach before the chain: `test/cpp/run/NAME.cpp` built over a warm
  cache and compared with `NAME.expect`, three at a time, ten to thirty minutes. It found 0.117's variable clash in
  `ir_args_/5` an hour before the chain would have. It is a net, not a gate: it claims nothing. (0.117)
- A step committed without its gates (on the owner's word), or before they finish, says so and claims nothing GREEN.
  The next commit carries the numbers. (0.91, 0.92, 0.110)
- Each form is cut down to a reduction of 10 to 40 lines. The reduction is built with clang or clang++ and with
  cicilang, and the outputs are compared line by line. Then it gets a fixture. (0.104, 0.108, 0.110)
- A library module is taken at once, not function by function (owner's rule, 2026-09-13): its whole surface in one
  step, in as many fixtures as the memory cap needs. (0.78)
- A fixture goes into `test/cpp/run/` only once it has been seen to pass. The gate globs that directory, and an
  unverified fixture can hang it. (0.92)
- The gates' time is cut by parallelism, never by fewer fixtures: each fixture names what it proves (on the owner's
  request, "7 hours is ridiculous"). (0.105)
- The overload rules interact: a change to one is worth no more than the gate it passes. A rule that breaks a fixture
  is reverted, and tried again only when it is measured alone. (0.68, 0.69)
- `HISTORY.md` keeps each step's entry: what it did and found, its measurements, its gate numbers. `CLAUDE.md` keeps
  only the rules that are true now, by topic; a step that changes a rule edits that rule in place. (0.112)

### Caps and guarded runs

- Every cocolog run has a memory cap AND a time cap, a small fixture included (owner's rule, "the one rule this
  repository does not bend"). The owner set 2800 MB for one run on the 16 GB Mac; the gates' pool sums all runs
  against 9000 MB and 14000 MB. (0.46, 0.71, 0.92, 0.105)
- A cap kills the whole process tree. cocolog is the command's grandchild, so a kill of the shell alone leaves it
  running. `timeout -s KILL` signals the process group it leads; `test/cpp.sh` uses `ccl_kill_tree`. (0.46, 0.93)
- The memory cap stays: a fixture too heavy for it is split, never the cap raised (owner's rule). Examples:
  `stdmapstring.cpp`, `stdmapstring2.cpp` and `stdmultimap.cpp`; `stdistream.cpp` and `stdistream2.cpp`;
  `stderaseif.cpp` and `stderaseifuset.cpp`. (0.78, 0.79, 0.99)
- One guarded run at a time. A watchdog sums every `cocolog ... query` on the box, and so does the pool
  (`ccl_cocolog_rss`), whose hard cap kills them all. A run beside a gate takes a cap of the sum, or watches its own
  process group and still counts against the gate. (0.46, 0.94, 0.108)
- A writer killed in the middle of a write can damage the store (`commit failed: the store refused it`). The store is
  a cache: `rm -rf ~/.cicilang/KB ~/.cicilang/KB.version` repairs it. (0.108)
- A background or pooled run reads `/dev/null`. cocolog's query loop reads its standard input: it waits on it, or eats
  the job lines queued behind it. (0.46, 0.106)
- A path in a query goal is single-quoted: a segment that starts with a digit is no atom
  (`cocolog: could not read the goal`). (0.46)
- Never edit a gate script while it runs: sh resumes at the old byte offset, which is now inside the new text. (0.105)
- sh has no local variables, so a helper that a pool job calls uses names that no job uses (`ccl_needs_met` uses
  `_nd_cond`, `_nd_f`, `_nd_r`). (0.107)

### Versions and rebuilds

- A change to `library/*.pl` needs no rebuild: the `.so` only wraps the library. A change to `module/cicilang.cicili`
  needs `sh module/build.sh`, and one to `module/ccl_llvm.cicili` needs `sh module/build-llvm.sh`. After a cocolog
  update, rebuild both: a `.so` reads the SDK's structs by their layout at build time. (from the start, 0.46, 0.108)
- Bump `ccl_reader_version/1` (`library/ccl_syntax.pl`) for every change to the grammar or to what a cached read holds:
  a unit in the store, a C++ summary, the AST beside it and its index (`cpp_index_name/2`, `ccl_flat_items/3`). Else
  the cache serves the old read, maybe a partial one, silently; reader check `k16` catches a grammar change.
  (0.71, 0.93)
- Bump `ccl_lowering_version/1` (`library/ccl_ir.pl`) for every change, however small, to what the check or the
  lowering emits. `dr_ir/3` serves any stored IR whose signature matches, and the signature folds this version.
  (0.103)
- A bump puts its number, its step's version and its reason at the head of the version fact's comment. (0.82, 0.89)
- The store's stamp `KB.version` is `Reader.Lowering`; a change of either starts the store afresh (`kb_prepare` in
  `bin/cicilang`, its twin `ccl_kb_prepare` in `test/config.sh`). A reader bump also makes every C++ summary cold.
  (M4, 0.105)

### Commits

- Commit and push only when the owner asks. (from the start)
- Every commit raises the version (owner's rule): the string in `ccl_p_version` (`module/cicilang.cicili`) becomes
  `0.N`, one more than the last commit's. Rebuild after it, because the `.so` carries it; `bin/cicilang --version`
  shows it. (from the start)
- The title is `0.N: ` and the step's title. Every commit ends with

      Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
      Claude-Session: https://claude.ai/code/session_01FUuQ3oBiKs3XpXAEHLCL1F

  and the push is `git push git@github.com:saman-pasha/cicilang.git main:main`; a session given another branch pushes
  there. (from the start, 0.101)
- Never commit build output or scratch: `library/*.so`, `module/*.c`, `module/*.o`, `module/sdk.cicili`,
  `module/ccl_uninames.h`, `proof/forty2`, `proof/*.o`, `KB/`, `*.log` (`.gitignore`). (from the start, 0.103)

## Where things are

```
CLAUDE.md                   this file: the rules as they stand, by topic
HISTORY.md                  the record of every step, verbatim, up to 0.111, and the entries from 0.112 on
README.md                   what cicilang is and what runs: the commands, the four predicates, the additions, C++
DESIGN.md                   the architecture, the neighbours' roles, the milestones M0 to M6
.gitignore                  the build output and the scratch that are never committed

bin/cicilang                the command: clang's arguments, one cocolog run of ccl_drive/2 over ~/.cicilang/KB
bin/cicilang++              cicilang for C++: CICILANG_LANG=cpp, --no-kb (in memory), every input C++, linked by c++

module/cicilang.cicili      library(cicilang), in Cicili. The C side: ccl_version/1, ccl_cocolog_version/1, the
                            native lexer ccl_lex_native/6, ccl_host_arch/1, ccl_host_os/1, ccl_uname_code. The
                            Prolog half: the four cicilang_ doors and the objects layer
module/ccl_llvm.cicili      library(ccl_llvm), the embedded LLVM over llvm-c: ccl_llvm_version/1, ccl_llvm_triple/1,
                            ccl_llvm_check/2, ccl_llvm_compile/3 (parse, verify, target, passes, object)
module/build.sh             writes ccl_uninames.h, transpiles cicilang.cicili, compiles library/cicilang.so
module/build-llvm.sh        transpiles ccl_llvm.cicili, compiles library/ccl_llvm.so against LLVM's C API
module/gen-uninames.pl      writes library/ccl_uninames.pl from Perl's Unicode::UCD
module/cicilang.c, ccl_llvm.c, ccl_uninames.h, sdk.cicili
                            made by the builds, never committed (sdk.cicili links to cocolog's lib/sdk.cicili)

library/ccl_syntax.pl       the DCG lexer (the specification and the fallback), the parser, the symbol table kept
                            while parsing, ccl_reader_version/1
library/ccl_pp.pl           the preprocessor in cocolog: directives, macros, built-ins; pp_predef/3 facts at its end
library/ccl_include.pl      #include: the inclusion path, the nested read, .pl macro files, #cocolog blocks, the
                            cycle guard, the KB cache, the header macro tables, the C++ summaries and their AST files
library/ccl_infer.pl        ccl_type_of/2, type resolution, sizes and layout, ccl_const_eval/2, the answer caches
library/ccl_format.pl       the global macros format, print, println and clone
library/ccl_cpp.pl          the C++ desugaring to C, ccl_cpp_units/2, run before the check
library/ccl_check.pl        the safe part: owners, moves, borrows, ties, loose pointers, own arrays
library/ccl_ir.pl           the lowering to LLVM IR text, ccl_ir_units/2; ccl_lowering_version/1
library/ccl_build.pl        ccl_compile/3 through the embedded LLVM, ccl_link/3 through cc or c++
library/ccl_driver.pl       ccl_drive/2: the command's steps, the diagnostics in clang's shape, the IR cache dr_ir/3
library/ccl_uninames.pl     the \N{NAME} table, generated: Unicode 15.0.0's names and aliases, loaded on the first \N{
library/cicilang.so, ccl_llvm.so
                            built by the two module scripts, never committed
library/include/            the compiler's own freestanding headers: each COCOLOG_LIBRARY directory's include/, after
                            libc++'s in C++, ahead of the C library's; guards _CICILANG_<NAME>_H, stdatomic.h's
                            __CCL_STDATOMIC_H
  complex.h                   the C library's, then I, CMPLX, CMPLXF, CMPLXL over __builtin_complex
  float.h                     the floating limits from the predefined macros
  iso646.h, stdalign.h, stdbool.h, stdnoreturn.h
                              the small C headers
  limits.h                    the limits from the predefined macros, then the C library's through #include_next
  stdarg.h                    va_list and va_* over __builtin_va_*; answers glibc's __need___va_list
  stdatomic.h                 C11 7.17 over the __c11_atomic_* builtins: atomic_* types, memory_order, atomic_flag
  stdbit.h                    C23's bit utilities over the bit builtins, the generic forms by _Generic
  stdckdint.h                 C23's ckd_add, ckd_sub, ckd_mul over the overflow builtins
  stddef.h                    size_t, ptrdiff_t, NULL, offsetof; nullptr_t and unreachable() at C23 only

test/config.sh              sourced by every gate: the neighbours, this library first on COCOLOG_LIBRARY, the store
test/gates.sh               every gate in one chain
test/parlib.sh              the memory-gated pool: ccl_pool, ccl_cocolog_rss, ccl_lpt_order, ccl_time_record
test/reader.pl, reader.sh   the reader's gate
test/compile.pl, compile.sh the compiler's gate
test/driver.sh              the command's gate
test/objects.sh             the objects layer's gate
test/cpp.pl, cpp.sh         the C++ gate
test/libcxx.sh              the library read: the asserted headers read whole, and the C++ cache's warm
test/readhdr.pl             one asserted header read whole at a level, in its own process
test/libcxx.pl              the library read's old one-process form; no gate runs it
test/warm.sh                a shim that runs test/libcxx.sh
test/census.pl, census.sh   where the reader stops in a header or in a flattened file, and what it read
test/c/                     the reader's fixtures: hello.c, rich.c, lexer.c, macros.c with macros.pl, pp.c ...
test/c/inc/                 the -I fixture: uses_box.c over box.h
test/c/link/                two files linked into one program; the ABI against clang-built code (abi_main.c,
                            abi_helper.c)
test/c/run/                 C programs built and run: NAME.c, NAME.expect, NAME.std; pp_defs.h, embed.txt, empty.txt
test/c/safe/                C programs the safe part refuses: NAME.c, NAME.expect
test/cpp/                   the C++ reader's fixtures and the refusals; hidem.cppm for modhidden.cpp
test/cpp/run/               C++ programs built and run: NAME.cpp, .expect, .flags, .stdin, .needs; bag.h, hunit.h,
                            basem.cppm and mathm.cppm (for modules.cpp), embed26.txt

proof/forty2.ll, run.sh     M0: hand-written IR through clang to a binary that prints a line and exits 42
proof/forty2                made by proof/run.sh, never committed
bench/btree/                the B-tree benchmark, run.sh: btree_cicilang.c (cicilang -O3), btree_c.c (clang -O3),
                            btree_rust.rs (Rust's BTreeSet)
bench/compile/              the compile-time benchmark, run.sh: cicilang++, clang++ and rustc on a hello and the
                            B-tree; pycparser_parse.py and shivyc_asm.py for two C front ends in Python
tutorials/01..03-*.pl       the objects layer's lessons; goal main, last line done
```

### Outside the repository

- `~/.cicilang/` is the user's cache. `KB` is the C store (`$CICILANG_KB` names another) and `KB.version` its stamp,
  `Reader.Lowering`. `cpp/` holds the C++ summaries, one `<name>-<fold>-<fold>.sum` per header and level, with
  `.ast.pl` (one `'$cpp_hdr_ast'(Name, Item)` clause per named item) and `.mac` (the header's macros) beside it.
  `fixture-times` and `header-times` keep the pool's timings, outside the `cpp/` that the library read wipes. (0.105)
- The neighbours' checkouts are `$CICILI` and `$COCOLOG`, by default `~/Projects/GitHub/<name>`. Nothing names
  ZiguratIP's checkout: it is reached only as cocolog's store. (from the start)
- The guard, watchdog, probe and trace scripts that `HISTORY.md` names (`scratchpad/guard.sh`, `watch.sh`, `gate.sh`,
  `probe.sh`, `trace.sh`, `fx.sh`, `ipfull.sh`) were session scratch and are not in the repository. (0.105)

## Build, prove and the gates

### Building

- `CICILI=~/Projects/GitHub/cicili COCOLOG=~/Projects/GitHub/cocolog sh module/build.sh` builds `library/cicilang.so`.
  It links cocolog's `lib/sdk.cicili` into `module/`, writes `module/ccl_uninames.h`, transpiles
  `module/cicilang.cicili` with Cicili (SBCL, `cicili.lisp --release`), and compiles the C with the compiler that
  cocolog's `tools/cc/env.sh` picks. (0.103)
- `sh module/build-llvm.sh` builds `library/ccl_llvm.so` over llvm-c. `LLVM=` names Homebrew's LLVM (the default) or
  Debian's and Ubuntu's `/usr/lib/llvm-NN`. It links `-lLLVM-C` where `libLLVM-C.*` is in `llvm-config --libdir`, else
  `-lLLVM`, with an rpath to that directory: the library's name is read off the disk, never assumed. (0.87)
- `perl module/gen-uninames.pl > library/ccl_uninames.pl` makes the `\N{NAME}` table from Perl's `Unicode::UCD`.
  Never edit the table by hand. (0.104)

### The chain

- `sh test/gates.sh` runs the reader, compile, driver and objects gates and the proof one after another, then the
  library read (`test/libcxx.sh`), then the C++ gate (`test/cpp.sh`). Each prints `== NAME: GREEN in N s` or
  `== NAME: RED (exit N) in N s`. The first RED stops the chain, by its exit status, never by a log read. A full pass
  prints `ALL GREEN`. (0.105)
- THE CHAIN RUNS OVER A LIBC++: `LLVM=/usr/lib/llvm-18 sh test/gates.sh` and `LLVM=/usr/lib/llvm-21 sh test/gates.sh` (or the
  last two gates alone at 21: `test/libcxx.sh`, `test/cpp.sh`; the C gates do not read libc++). The tree is read and linked
  (`ccl_cxx_dirs`); without `$LLVM` the newest installed one is, libc++ 22 on the Ubuntu box, which no gate has run. The
  library read wipes the HOME's summaries (`LX_HOME`), so give each pass a HOME of its own to keep both warm (the summaries
  are keyed by the header's path, so two trees never clash). (0.122, 0.126)
- `GATES_JOBS` (default 4) sets `LX_JOBS` and `CPP_JOBS`, the lanes of the two parallel phases. (0.105)
- By hand: build, then `test/reader.sh`, `test/compile.sh`, `test/driver.sh`, `test/objects.sh`, `proof/run.sh`; then
  `test/libcxx.sh` before `test/cpp.sh`. (0.105)
- A gate prints `SKIP` and exits 0 when it finds no `$COCOLOG/cocolog` or no `library/cicilang.so`, and the chain
  prints GREEN for it. A SKIP is no GREEN line: build first. (from the start)
- Only the two parallel phases have caps of their own. The four small gates and the proof run under an outside cap,
  as every cocolog run does. (0.105)
- `test/config.sh`, sourced by every gate, puts this checkout's `library/` at the front of `COCOLOG_LIBRARY` and keeps
  the caller's path behind it. It sets `CICILANG_KB` to `~/.cicilang/KB` unless the caller set it, and stamps that
  store (`ccl_kb_prepare`). (M4)
- The reader and compile gates run over `--embed "$CICILANG_KB"`, and the driver gate over it through `bin/cicilang`.
  The C++ gate, the library read and the census run `--local`. The objects gate runs `--local`, with a store of its
  own for an instance that outlives its process. (M4, M5)
- A gate program is loaded by `ensure_loaded/1` from a `query` (`reader_main`, `compile_main`, `cpp_main`,
  `readhdr_main`, `census_main`), never by `cocolog --embed ... run FILE goal`, which consults FILE into the store.
  (from the start)

### The C gates

- The reader gate. `test/reader.pl` runs 92 numbered checks, `k1` to `k92`, in one process over the user's store. It
  then reads five of Cicili's C files whole (`test/c/main.c`, `shared.c`, `macro.c`, `example/cimath.c`,
  `example/numpy_example.c`); a missing one is a SKIP. `test/reader.sh` adds a second process, which must read
  `hello.c` with its headers from the store in under 10 s. (0.93)
- Reader checks that guard rules of other sections: `k16` (a cached read equals a fresh one), `k59` and `k65`
  (`0xFFul`, `1u << 4`), `k81` (the tie), `k82` (`#cocolog`), `k83` (`pp.c` with `pp_defs.h`), `k84` (the native lexer
  gives the DCG's tokens on `test/c/lexer.c` and on real files), `k85` (the native lexer is in use), `k86` (the user's
  macros), `k87` to `k91` (C23 and C17 at their levels), `k92` (`__int128` is a type word, `test/c/run/int128.c`).
  (0.93, 0.117)
- The compile gate. `test/compile.pl`, one process over the user's store, reads, checks, lowers, compiles at `-O1`
  and links every `test/c/run/*.c` at its `NAME.std` level (`c_level`). It expects every `test/c/safe/*.c` refused.
  `test/compile.sh` runs each binary as `NAME arg1 arg2` against `NAME.expect`, and compares each refusal with
  `safe/NAME.expect`. There are 67 run and 43 safe fixtures at 0.129. (M2, M3, 0.57)
- The driver gate. `test/driver.sh` makes 28 checks of `bin/cicilang` over the user's store (the decimal ABI check is
  skipped where no gcc with decimal floating types is installed). They cover what `-o`,
  `-c`, `-S`, `-emit-llvm`, `-shared`, `-I`, `-ast-dump`, `-fsyntax-only` and `-g` make (the line table read back by
  `llvm-dwarfdump`, from `$PATH` or `$LLVM/bin`: the statements' lines and the file's name), and the diagnostics in
  clang's shape (`#warning` printed, `#error` with exit 1). They find `@ccl_drain_node` in `btree.c`'s IR, and pass
  structs by value both ways against clang-built code (`test/c/link/abi_main.c`, `abi_helper.c`; seven lines at 0.117,
  the last two for the SysV register budget, `budget_*` built by clang and `bud_*` by cicilang). The store must serve
  `hello.c` in under 10 s and redo only the changed one of two files. The gate follows the host: `_main:` and `.dylib`
  on Darwin, `main:` and `.so` elsewhere. The decimal floating types cross the ABI against gcc-built code both ways
  (`test/c/link/dec_main.c`, `dec_helper.c`: values, structs by value, a variadic call; clang has no decimal types).
  (M4, 0.93, 0.128, 0.129)
- The objects gate. `test/objects.sh` makes 29 checks of the objects layer, an instance that outlives its process
  among them. (from the start)
- The proof. `proof/run.sh` has clang turn `proof/forty2.ll` into a binary that prints `cicilang reaches C` and exits
  42. (M0)

### The library read and the warm: test/libcxx.sh

- `test/libcxx.sh` is one cold parallel pass. It wipes `$WARMHOME/.cicilang/cpp` (`LX_HOME`, else `$HOME`). It reads
  each asserted header at its level whole, each in its own `--local` process (`test/readhdr.pl`'s `readhdr_main`,
  with `CCL_HDR`, `CCL_STD`, `CCL_MIN`). It checks the item count against the list's minimum, a floor under libc++ 18's
  counts, and leaves the summaries written for the C++ gate. (0.105)
- The 23 asserted reads: `vector`, `string`, `iostream`, `map`, `set`, `unordered_map`, `unordered_set`, `optional`,
  `memory`, `functional`, `tuple` at C++17; `compare`, `vector`, `string`, `iostream`, `set`, `map`, `unordered_map`,
  `unordered_set`, `ranges` at C++20; `optional` and `string` at C++23; `optional` at C++26. A header at a level is a
  check of its own. (0.109)
- The same pass warms every other `#include <…>` of `test/cpp/*.cpp`, `test/cpp/run/*.cpp` and
  `$CICILI/test/cpp/*.cpp` (`ccl_union`), by a `-fsyntax-only` build (`ccl_warm`) at the including file's `.flags`
  level, else C++17. A missing Cicili checkout is named, because `<sstream>` and `<stdexcept>` then stay cold.
  `<algorithm>` and `<array>` are only warmed: nothing asserts their counts. (0.92, 0.105)
- `LX_SECS` (2400 s) caps each read and each warm through `timeout -s KILL`. A read with no verdict is
  `FAIL <h> at C++N: the read did not finish`. A failed warm, `FAILED to flatten`, counts as a failure. A pool killed
  at its hard cap is RED. (0.105)
- The phase IS the warm. A summary is keyed by the reader version and its deps' times, so a separate read under a
  fresh HOME was the same cold read done twice. `test/warm.sh` is a shim that runs it; `test/libcxx.pl`, the old
  one-process form (`at(H, Std)`), runs in no gate. (0.105)
- `test/census.sh` names where the reader stops: `sh test/census.sh '<vector>'` under a fresh HOME, or
  `sh test/census.sh flat.cpp` over the output of `cicilang++ -E`, read as the library's (no global macros) at
  `CCL_CENSUS_STD=N`. It prints WHOLE or PARTIAL, the stop and farthest lines with their tokens, and the AST's functors
  counted. (0.44, 0.99)

### The C++ gate: test/cpp.sh

- `test/cpp.sh` runs in this order: `test/cpp.pl` in one `--local` process; three checks of the command; every
  `test/cpp/run/*.cpp` as a pool job (443 at 0.129); `classes.cpp` and `templates.cpp` built and run; the refusals.
  (0.105)
- `test/cpp.pl` runs 43 numbered checks, `c1` to `c43`, then reads Cicili's six C++ files whole (`test/cpp/objects.cpp`,
  `emit_report.cpp`, `specialise.cpp`, `syntax.cpp`, `torch.cpp`, `torch-fragment.cpp`). `c34` checks the Itanium
  mangler on nine symbols, with no class registered. `unit_at(Std, Name, U)` sets `'$ccl_std'` for one read: `c22` to
  `c28` read `cxx20.cpp`, `c29` to `c33` `cxx23.cpp`, and `c35`, `c36` the run fixtures `cxx20cmp.cpp`, `cxx23b.cpp`,
  `cxx26.cpp`. `c37` adds three symbols to the mangler's check (a function type, an array, a repeated function type),
  `c38` the access control's and `mutable`'s reader forms (`accessctl.cpp`, `lambdamutable.cpp`), `c39` the braced
  range-for (`rangeforbraced.cpp`), `c40` the user-defined literal (`userliteral.cpp`), `c41` the conversion function
  defined out of its class (`convout.cpp`), `c42` the parenthesized functional cast and `using typename`
  (`parencast.cpp`, `usingtypename.cpp`) and `c43` the pack using-declaration `using Ts::operator()...;`
  (`overloaded.cpp`). `c37` also spells three symbols with `volatile`. (0.93, 0.117, 0.121)
- A numbered check reads the AST by its SHAPE, so a reader node that moves moves its check in the same step: `throw Err{t}`
  has read `throw(braced_temp(call(id('Err'), [id(t)])))` since 0.117 and `c20` expected the plain call until 0.119 -- a
  RED that only this gate can show, so a step that does not run it leaves the check stale. `test/cpp.pl` alone runs in 15
  s over a warm HOME: `CCL_TEST_ROOT` and `CCL_TEST_TMP` set, `cocolog --local query "ensure_loaded('test/cpp.pl'),
  cpp_main"`; without the two variables it answers `false.` and names no line. (0.119)
- The command's checks: `hello.cpp` built through `cicilang++` prints `hello, cicilang++`; a second build is served
  from the summaries in under 8 s; `cicilang++ -fsyntax-only classes.cpp` says nothing and exits 0. After the
  fixtures, `classes.cpp` builds and exits 34, and `templates.cpp` exits 10. (M5, 0.34, 0.35)
- The fixture builds assume a warm cache: a build that only reads summaries is safe in parallel, and a cold flatten
  under load is not. `CPP_JOBS=1` makes the gate serial. (0.105)
- `ccl_fixture NAME` builds with `NAME.flags`, capped at `CPP_FIXTURE_SECS` (2400 s) by `ccl_capped`. Past the cap,
  `ccl_kill_tree` kills the tree, and the verdict line itself reads `FAIL NAME.cpp: TIMEOUT after N s`, so no diff
  hides it. It runs the binary on `NAME.stdin` or `/dev/null`, compares with `NAME.expect`, and writes its verdict to
  `$RES/NAME.res`. (0.93, 0.94, 0.105)
- The verdicts are collected in alphabetical order. A missing one is `FAIL NAME.cpp: no verdict`. A skip is counted,
  neither ok nor failure. A pool killed at its hard cap is RED. (0.95, 0.105)
- Each refusal is built with `-c` and must fail with `not lowered yet: What`:

  | Fixture (`test/cpp/`) | What | Since |
  |---|---|---|
  | `coro.cpp` | `no_member(get_return_object` | 0.108 |
  | `concept_fail.cpp` | `constraint_not_satisfied` | 0.42 |
  | `constrained_fail.cpp` | `constraint_not_satisfied` | 0.93 |
  | `lambda_const.cpp` | `assign_to_capture(n)` | 0.117 |
  | `access_data.cpp` | `access(private,'Account',balance)` | 0.117 |
  | `access_method.cpp` | `access(private,'Account',audit)` | 0.117 |
  | `access_protected.cpp` | `access(protected,'Base',tweak)` | 0.117 |
  | `access_ctor.cpp` | `access(private,'Single','$ctor')` | 0.117 |
  | `access_base.cpp` | `access(private,'Base',secret)` | 0.117 |
  | `abstract.cpp` | `pure_virtual` | 0.99 |
  | `modhidden.cpp` | `undeclared(hidden)` | 0.110 |
  | `diamond.cpp` | `virtual_base_by_two_paths` | 0.110 |
  | `basenodefault.cpp` | `base_constructor('B')` | 0.112 |
  | `access_inherit.cpp` | `access(private,'Derived',pub)` | 0.127 |
  | `access_protobj.cpp` | `access(protected,'Base',secret)` | 0.127 |
  | `access_memptr.cpp` | `access(private,'Account',balance)` | 0.127 |
  | `access_nested.cpp` | `access(private,'Outer','Secret')` | 0.127 |
  | `access_dtor.cpp` | `access(private,'Handle','$dtor')` | 0.127 |
  | `access_operator.cpp` | `access(private,'Money',operator(<))` | 0.127 |
  | `lambda_method.cpp` | `non_const_member_on_const(bump,'Counter')` | 0.127 |
  | `bind_const.cpp` | `binds_const(r)` | 0.127 |

  `deduced_this.cpp` (0.43) is gone: a class's `this auto` method builds since 0.117 (`deducethis.cpp`).

- `test/cpp/escape.cpp` must be refused by the safe part with `a borrow leaves the function`.
  `test/cpp/control.cpp` (a `try`) builds now, and only `test/cpp.pl` reads it. (0.100, 0.108)
- A gate that dies says so. Without a GREEN or RED line from `test/cpp.pl`, `test/cpp.sh` prints
  `RED: the gate did not finish (query exit N)` and the last 20 raw lines. `test/reader.sh` and `test/compile.sh`
  print `RED: the gate did not finish`. (0.85)

### The pool: test/parlib.sh

- `ccl_pool NMAX LAUNCH_MB HARD_MB` reads one shell line per job from its standard input. It starts a job only while
  fewer than NMAX run and the summed RSS of every `cocolog … query` on the box (`ccl_cocolog_rss`) is under
  LAUNCH_MB. It gates on memory because cocolog has no garbage collector and a build peaks in gigabytes. (0.105)
- Past HARD_MB the pool kills every cocolog query on the box with `pkill -9` and returns 1, a RED. The defaults are 4
  jobs, 9000 MB and 14000 MB: `CPP_JOBS`, `CPP_LAUNCH_MB`, `CPP_HARD_MB` in `test/cpp.sh`, and the `LX_` ones in
  `test/libcxx.sh`. (0.105)
- The pool tracks its children by PID with `kill -0`, because dash has no `jobs -r`. It matches `[c]ocolog`, never
  its own shell. Every job runs with `< /dev/null`: the pool's input is the job list, and a build once swallowed the
  lines queued behind it. (0.105, 0.106)
- The jobs run longest first. `ccl_lpt_order FILE` sorts lines by the recorded seconds of their first word, the
  unknown keys first. `ccl_time_record FILE KEY SECS` appends a line, and the last line per key wins. Only a passing
  build's or a good read's seconds are recorded, in `~/.cicilang/fixture-times` (`CPP_TIMES`) and
  `~/.cicilang/header-times` (`LX_TIMES`). (0.105, 0.106)

### Fixtures and their companion files

- `NAME.expect` is clang's or clang++'s output for the same program, then the `exit N` that the gate appends. For C it
  holds the binary's standard output and error; for C++, the build's own output (empty when clean), then the binary's
  standard output. `btree`'s comes from the C mirror `bench/btree/btree_cicilang.c`. Compare by hand the same way.
  (M2, 0.93)
- `NAME.flags` gives a C++ fixture its level (`-std=c++20`, `-std=c++23`, `-std=c++26`); without one it builds at
  C++17. `NAME.std` gives a C fixture its level (`-std=c23`); an ISO level before C23 (`-std=c17`) turns trigraphs on,
  as `bin/cicilang` does. (0.42, 0.57, 0.108)
- `NAME.stdin` is the input of a fixture that reads (`stdcin`, `stdcinld`, `stdget`, `stdgetline`, `stdistream`,
  `stdistream2`, `stdws`); the others read `/dev/null`. (0.75, 0.115)
- `NAME.needs` holds a preprocessor condition over the library's own macros. `ccl_needs_met` runs a four-line file
  that includes `<version>` through `cicilang++ -E` with the fixture's flags, and looks for a marker. When the box's
  library fails it, the verdict is `skip NAME.cpp: needs ...`, never a RED. Only `stdoptionalref.needs` exists
  (`__cpp_lib_optional >= 202506L`, since 0.123: libc++ 21.1.8 has no `optional<T &>`, it came with libc++ 22). (0.95, 0.107, 0.123)
- `test/c/safe/NAME.expect` holds the refusal, `ownership(Kind,Name)`. (M3)
- Inputs beside the fixtures are no fixtures: `test/c/run/pp_defs.h`, `embed.txt`, `empty.txt`; `test/cpp/run/bag.h`
  (`bag.cpp`, `member.cpp`), `hunit.h` (`headerunit.cpp`, `hdrinline.cpp`), `basem.cppm` and `mathm.cppm`
  (`modules.cpp`), `embed26.txt` (`cxx26.cpp`); `test/cpp/hidem.cppm` (`modhidden.cpp`). (0.93, 0.108, 0.110)
- A binary runs only if this run built it. Each gate builds into a fresh temporary directory; `test/cpp.sh` runs on
  a build status of 0, and `test/compile.sh` on its `built NAME` line. (from the start, 0.89)
- A check is its own clause, `kN :- check(Name, Goal).`, with a unique number, never a fact driven by `findall/3`:
  two clauses of one name both run on backtracking. Each check runs inside `\+ \+`, so a process peaks at its biggest
  check, not at the sum. (from the start, 0.46)
- A shape that only invalid C++ can write, or that the libc++ fixtures already measure, gets no fixture of its own.
  (0.64, 0.69)

### Reading a result

- A gate's time is wall clock (`date +%s`). Compare it only with a run whose window was awake (`pmset -g log` on a
  Mac). A number that must mean something is CPU time, or one fixture alone against a recorded number. (0.88)
- `TIMEOUT after N s` is a bound, not a value. (0.92)
- A version bump makes the caches cold: a reader bump every C++ summary, either bump the C store. The first run after
  one peaks far above the steady state, and a run killed at its cap writes no summary, so the next run is cold too.
  Re-run before believing a RED that comes with a bump. (0.61, 0.67, 0.105)

## The driver and the commands

### The commands

- `bin/cicilang` takes clang's arguments (owner's rule: no new flags to learn). It makes one options list and runs
  `ccl_drive/2` in ONE cocolog process: over `--embed $CICILANG_KB` (default `~/.cicilang/KB`) after `kb_prepare`, or
  `--local` under `--no-kb`. (M4, 0.108)
- `bin/cicilang++` is `bin/cicilang` with `CICILANG_LANG=cpp` (`lang(cpp)`), `CICILANG_ME=cicilang++` and `--no-kb`.
  (M5)

### Arguments

- `-c -S -emit-llvm -fsyntax-only -E -ast-dump -v -o -O0..-Oz -I` become `compile_only`, `assembly`, `emit_llvm`,
  `syntax_only`, `preprocess`, `ast`, `verbose`, `out(F)`, `opt(F)` (default `-O0`) and `include(D)`. Link flags pass as
  `link(F)`: `-l -L -shared -Wl, -framework -static -rdynamic -fPIC -pthread -m*`. (M4, 0.44)
- `-W -f* -pedantic`, an unknown `-std=` and an unknown `-g` form are accepted and ignored. Any other dash argument is
  `unknown argument`. `--version` prints the versions of cicilang, cocolog and LLVM; `-h` prints the help. (M4, 0.108)
- `-g` is the option `debug` (0.128): `-g`, `-g1` to `-g3`, `-ggdb` and its levels, `-gline-tables-only`,
  `-gline-directives-only`, `-gdwarf*`, `-gfull`, `-glldb` and `-gsce` all give LINE TABLES, the one level the lowering
  makes; `-g0` and `-ggdb0` give none, as clang. `dr_c` sets `'$ccl_debug'` to `file(AbsolutePath)` for the file
  (`dr_abs_path/2`, `absolute_file_name/2`), else `none`, and the IR cache's signature folds it (`dr_ir_sig/3`): an IR
  with line tables is another IR. The lowering's side is in The lowering topic. A debugger stops at a line and steps
  by statements (gdb: `main () at dbg1.c:9`); there are no variables, no types and no scopes below the function. The
  driver gate's `-g` check reads the line table back with LLVM's own `llvm-dwarfdump`. (0.128)
- `-D N`, `-DN=v`, `-D'F(x)=...'` and `-U N` are `define(Text)` and `undef(N)` options (0.112): the driver makes the
  list `'$pp_cmdline'` (`ccl_pp_cmdline/1`, the later of a -D and a -U of one name winning), and `pp_outer_macro/3`
  asks it before the predefined macros, so every file and every header's macro table made in the process reads them
  (`<assert.h>` under `-DNDEBUG`); a `-U` takes away a predefined macro and leaves a header free to define it. A run
  with either keeps no C store (`--local`: the store keys a header by its path), and a C++ summary's fold takes the
  list (`ccl_cmdline_key/1` in `ccl_sum_file/2`). The driver gate's `-D and -U` check. (0.112)
- `-std=` names the level of both languages:

  | Flag | Option |
  |---|---|
  | `c++17` `c++20` `c++23` `c++26` (and `gnu++`, `1z` `2a` `2b` `2c`) | `std(17)` ... `std(26)` |
  | `c23`, `gnu23`, `c2x`, `gnu2x` | `cstd(23)` |
  | `c17`, `c18`, `iso9899:2017`, `iso9899:2018` | `cstd(17)`, `trigraphs` |
  | `c11`, `iso9899:2011`; `c99`, `iso9899:1999` | `cstd(11)`; `cstd(99)`; `trigraphs` |
  | `gnu17`, `gnu18`; `gnu11`; `gnu99` | `cstd(17)`; `cstd(11)`; `cstd(99)` |

  The ISO C modes read trigraphs and the GNU modes do not, as clang. `-trigraphs` alone turns them on. A C++ level before
  17 is refused, and so are C89 and C90. (0.42, 0.57, 0.108)

### `ccl_drive/2`

- `ccl_drive/2` is `once(dr_drive(Inputs, Options))`. Why: cocolog's query loop asks for a second answer, and a stray
  choicepoint prints everything again. It sets `'$ccl_lang_forced'` and `'$ccl_lang'`, `'$ccl_std'` (default 17),
  `'$ccl_c_std'` (default 17) and `'$ccl_trigraphs'`, and asserts a `ccl_include_dir/1` per `-I`. (M4, 0.108)
- `.c` and the C++ extensions (`dr_cpp_ext`) go to `dr_c`; `.ll` compiles as IR; `.o`, `.a`, `.so` and `.dylib` go to
  the link. A missing input is `no such file or directory` (`dr_input`); it once compiled to `cicilang: ok`. (0.46,
  0.108)
- `-E` runs `dr_preprocess`: cocolog's own preprocessor standalone (`ccl_pp_file/3`; owner's rule: no clang), the tokens
  spelled back as text (`ccl_pp_spell/2`), into `-o`'s file or the answer. The text breaks its lines where the source's
  do, escapes a string's codes (`\NNN`), keeps every suffix, and spells a float past a double as `1e999`. (0.44, 0.99)
- Otherwise `dr_c` reads the file (`cicilang_ast/2`), and `-ast-dump` writes the AST. In C++ mode, `-fsyntax-only` only
  reads: no desugaring, check or lowering, so its success says nothing about them. In C it still checks and lowers
  (`dr_ir/3`). Then `dr_emit` writes the `.ll`, the assembly, the object, or a temporary object to link. (M5, 0.87)
- The link runs unless the run had errors, made no object, or stops before it (`-c -S -emit-llvm -fsyntax-only
  -ast-dump -E`; `dr_no_link`). Its output is `-o`'s file, else `a.out`. The run ends `cicilang: ok` or
  `cicilang: N error(s)`. (M4)
- A phase that merely fails names itself: `ccl_ir_units/2` throws `ir_fail(phase(desugaring | check | lowering))`,
  printed `not lowered yet: phase(...)`. Else the driver says only `the check or the lowering failed without saying
  why`. Under `'$cpp_trace'`, `ir_cpp_trace` prints each phase with the heap. (0.53)

### Diagnostics

- A diagnostic is clang's `file:line: error: what` (`dr_error/3`). `dr_report/2` hands the error term to
  `once(dr_diag/3)`, one clause per term; `once/1` because the callers' recovery fails after the report. An error on a
  macro-expanded line gets `note: expanded from macro ...` (`dr_remember_expansions/1`); an error inside a macro gets a
  note that names the macro's file (`dr_note_macro`). (M1b, M4)
- The user's own `#error` is an error (`dr_diag(F, pp_error(M), ...)`). Its `#warning` lines print after the read as
  `file:line: warning: text` (`dr_pp_warnings`) and count as no error. (0.93)
- One `awk` pass in `bin/cicilang` splits the answer. `: error: `, `: warning: ` and `: note: ` lines go to stderr. The
  `cicilang: ...` lines (but `cicilang: ok`) and `unit(...)` lines go to stdout. All else is DROPPED; under `-E` the
  text passes. (0.44, 0.93)
- The exit status is 0 on `cicilang: ok` and 1 on `cicilang: N error(s)`. Else it is 1, after up to three `ERROR` or
  `error` lines prefixed `cicilang: `. (M4)
- So a library debug `write` must start its line with `cicilang: `. A trace (`nb_setval('$cpp_trace', yes)`, or
  `CCL_IR_TRACE=1` for each emitted IR line) needs cocolog called directly. (0.90)

### Compile and link

- `cicilang_compile/3` goes through the embedded LLVM only, `library(ccl_llvm)` (owner's rule: no clang, no LLVM
  binary). Where it is not built, the error names `module/build-llvm.sh`. (M5)
- `cicilang_link/3` (`ccl_link/3`) runs `cc` in C or `c++` in C++ over the objects, the link flags and
  `ccl_link_libs/1`. A failed link is `link: ` with the linker's output. (M2, M5)
- `ccl_link_libs/1`: on Linux, ` -lc++` for C++ and ` -lm` for C; on macOS, nothing. Why: on Linux `c++` is g++, whose
  library is libstdc++, and glibc keeps `sqrt`, `creal` and `cabs` in libm. The C++ link names the library of the tree the
  program was READ from, ` -L<root>/lib -Wl,-rpath,<root>/lib -lc++` (`ccl_cxx_dirs`): two or three libc++ are installed side
  by side on the Ubuntu box (`/usr/lib/llvm-18`, `-21`, `-22`), chosen by `$LLVM`, and the headers of one with the library
  of another do not link. Without `$LLVM` the NEWEST tree is read, 22 here: the gates run with `LLVM=/usr/lib/llvm-18` and
  `LLVM=/usr/lib/llvm-21`. (0.93, 0.100, 0.122)

## The lexers

### Two lexers, one specification

- Two lexers turn a file into the same tokens, `tok(Kind, Value, Line)`. The DCG `ccl_lex//2` (`ccl_syntax.pl`) is the
  specification and the fallback. The native `ccl_lex_native(+Text, +Line0, +Mode, +Lang, -Tokens, -Rest)` in
  `module/cicilang.cicili` is the one that runs: C in Cicili, keyword tables and punctuators in C, `tok/3` built by
  `coco_make` behind `coco_m_machine`. Why: the DCG lexer was the cost floor of every read. (M1)
- `ccl_tokens/3` and `ccl_lex_atom/4` (the preprocessor's door) choose the lexer by `'$ccl_lexer'`, which
  `ccl_ensure_globals` sets once from a probe of `ccl_lex_native/6`. `library(ccl_syntax)` loaded alone lexes through
  the DCG. (M1)
- **A lexer rule changes in BOTH lexers.** Reader `k84` compares them token for token and rest for rest on
  `test/c/lexer.c` (both modes, both languages), `rich.c`, `cocolog.c`, `run/btree_del.c`, `test/cpp/classes.cpp`,
  `sys/cdefs.h` and `math.h`; `k85` checks that the native lexer runs. A new token form goes into `test/c/lexer.c`. (M1)
- `'$ccl_hash'` is the mode. In `line` mode (the reader's) a `#` line is one `tok(pp, Text, L)`, continuations joined.
  In `punct` mode (the preprocessor's) `#` and `##` are punctuators and a number is `tok(num, Spelling, L)`, so
  `200112L` pastes whole; a pp-number may start with a dot. (M5, 0.108)
- The DCG lexer writes `"`, `'` and `\` as 34, 39 and 92, never `0'"` or `0''`, which read badly in cocolog. (M1)

### Keywords and punctuators

- The keyword tables are the LANGUAGE's, never the level's: `ccl_keyword/1` is `ccl_c_keyword/1` plus, in C++,
  `ccl_cpp_keyword/1` (natively `ccl_lx_ckw`, `ccl_lx_cppkw`). In C, C23's new keywords arrive as identifiers and the
  grammar reads them at the level. `override` and `final` stay identifiers. Why: k84 compares the shared tables. (0.57)
- `concept requires co_await co_yield co_return consteval constinit char8_t` are C++ keywords in both lexers. (0.42)
- `<=>` is a punctuator in both lexers and both languages (`ccl_punct//1`, `ccl_lx_p3`). `::` lexes in C++ only. `:=`
  is a punctuator. (0.42)
- `tie` is an identifier, and `<*>` is no punctuator in either lexer; the grammar reads `tie` in context. (0.109)
- A `#cocolog` line takes every line up to the `#end` line, or the file's end, raw into one `tok(cocolog, Text, L)`
  (`ccl_cocolog_body//3`, `ccl_lx_cocolog`). (M1b)

### Integer literals

- Both lexers read `0b1011` (C23, C++14) and the digit separator `1'000'000` in every scan. The native lexer drops the
  separator from the value and the `strtod` text (`ccl_lx_puts_num`). The pp-number takes it (`ccl_pp_number//1`,
  `ccl_lx_pp_number`), else `1'000'` lexes as a char literal. Reader `k88`. (0.57)
- The suffixes `u`, `l`, `ll`, `ul` (any case, any order) give `tok(uint|long|ulong, N, L)` (`ccl_int_suffix//1`,
  `ccl_int_kind/4`; natively `ccl_lx_int_suffix`, `x->sfx` 0 to 3); `z` is a long. The parser makes `int(N)`,
  `uint(N)`, `long(N)`, `ulong(N)`. Reader `k59`. Why: `1L` was `int(1)`, and `%ld` read garbage. (0.43)
- C23's `wb` and `uwb` (any case, any base) give the kinds `bitint` and `ubitint` (`x->sfx` 4, 5). The parser makes
  `wb(N)`, a `_BitInt` of the value's width plus the sign, and `uwb(N)`. (0.93)
- An integer literal of 2^60 or more is `big(Atom)` in BOTH lexers (`ccl_lx_emit_int`, `ccl_lx_big`; `ccl_int_value/2`,
  `ccl_big_decimal/1`, `ccl_hex_int/2`, `ccl_bin_int/2`, `ccl_octal_int/2`). The atom is the decimal digits of a
  decimal literal, else `0x` and the lowercase hex digits, no leading zeros. `pp_norm` uses the same door. A reader of
  the atom takes it by its base, the constant evaluator too (`ccl_wide/2`). `test/c/run/bigint.c`, `bighex.c`. Why:
  cocolog's integers are 61-bit, and `9223372036854775807LL` was -1. (0.94, 0.112)
- A `big` literal is the first of `long` and `unsigned long` that holds it (`ccl_big_type/2` over `ccl_big_fits/3`), and
  it keys a template instance by its atom (`cpp_type_key`). A value past 64 bits, which only a fold makes (a 128-bit
  type's constant: `numeric_limits<__int128>::max()`), is the first of `__int128` and `unsigned __int128` that holds it,
  and a negative value is a `long` where it fits one; the lowering spells `int(big(A))` in that type (`ir_expr`). Before
  0.129 such a value was an `unsigned long`, lowered as an `i64` and cut to its low half. (0.94, 0.129)

### Floating literals

- `1.5f` is `tok(floatf, F, L)` and `1.5L` is `tok(floatl, F, L)`. The parser makes the casts they amount to,
  `cast(base([], [float]), float(F))` and `cast(base([], [long, double]), float(F))`; an `L` literal holds a double's
  value. `test/c/run/hexfloat.c`. Why: `sizeof`, `_Generic` and a template deduce the literal's own type. (0.108)
- Both lexers read hex floats (`0x1.8p1`, the binary exponent required) and a leading dot (`.5f`). (0.108)
- `f16`, `f32`, `f64`, `f128` and `bf16` (any case) are read in both lexers, and the literal stays a double. The
  native lexer reads the character after `b` again. (0.93)
- A float past the largest finite double is that double, at the parser's one float door (`ccl_primary_` through
  `ccl_finite_float/2`). Why: cocolog writes an infinity as `inf.0`, which its own reader refuses, so a summary's AST
  holding `__LDBL_MAX__` did not consult. (0.55)
- A DECIMAL FLOATING LITERAL (C23 6.4.4.2; 0.129) ends in `df`, `dd` or `dl` (or `DF`, `DD`, `DL`; `ccl_dec_suffix/3`, the
  native `ccl_lx_float_suffix` with `fsfx` 3 to 5) and is `tok(dec32 | dec64 | dec128, Text, L)`: its TEXT, as the lexers
  spell it for strtod (`0.1`, `1.0e5`, `.5`, the separators dropped; `ccl_float_value/3`), since no double holds 0.1. The
  parser makes `dec32(Text)`, `dec64(Text)`, `dec128(Text)`, and the lowering encodes the text exactly (the Lowering
  topic). `-E` spells it back with its suffix (`pp_dec_suffix/2`). Reader `k84` reads a line of them in both lexers.
  (0.129)

### Imaginary literals

- Both lexers read GNU's imaginary mark `i`, `I`, `j` or `J` after the suffix (`ccl_imag_mark//0`; natively
  `ccl_lx_imag_c`, `x->imag`). A floating one is `tok(imag, F, L)`, a `_Complex double` (`2.0i`); with an `f` it is
  `tok(imagf, F, L)`, a `_Complex float` (`1.5if`, `1.0fi`); with an `l` `tok(imagl, F, L)`, a `_Complex long double`
  (`1.0li`, `1.0il`; 0.112, as clang has it -- a `_Complex double` before). The parser makes `imag(F)`, `imagf(F)`,
  `imagl(F)`. (0.101, 0.112)
- An integer imaginary literal's suffix names its kind: `imagi`, `imagui`, `imagli`, `imaguli` (`ccl_int_tok//4`,
  `ccl_imag_kind/2`); a `_BitInt` suffix gives the int kinds. The parser makes `imagi(Specs, N)` (`ccl_imag_specs/3`):
  no suffix `int` up to INT_MAX, else `long`; `u` `unsigned` up to UINT_MAX, else `unsigned long`; `l` `long`; `ul`
  `unsigned long`; `big(A)` by `ccl_big_type/2`. `test/c/run/complex3.c`. (0.104)

### Strings, characters and escapes

- Both lexers read the prefixed literals (`ccl_lit_prefix//2`, `ccl_lx_string_k`): `u8"..."` is a plain `str` and
  `u8'c'` a `chr`; `L`, `u`, `U` give `wstr`, `u16str`, `u32str` (`wchr`, `u16chr`, `u32chr` for chars). The body is
  a plain string's UTF-8 bytes, which the lowering decodes. Reader `k91`. (0.93)
- A `u"..."` literal is UTF-16 ([lex.string]/10): a code point past U+FFFF is a surrogate pair, two `i16` units
  (`ir_wide_units/3`, `ir_utf16/2`), in the constant, in an array it initializes, in that array's bound
  (`ccl_utf16_count/2`) and in `sizeof` (`ccl_literal_bytes`); it was one unit that kept the low bits.
  `test/c/run/u16pairs.c`. (0.112)
- A raw string literal ([lex.string]/1; C++ only) is read by both lexers: `R"d(...)d"` and its prefixes `u8`, `L`, `u`,
  `U`, the body as it stands, no escape read, up to `)`, the delimiter, `"`; a newline in it is counted
  (`ccl_raw_prefix//1`, `ccl_raw_delim//1`, `ccl_raw_body//4`; `ccl_lx_raw_start`, `ccl_lx_raw`). In C, `R` is a name
  and a plain string follows. Reader `k84` over `test/c/lexer.c`. The preprocessor's line splitting does not know a
  raw string that spans lines. Why: libc++ 18's escaped-string writer (`<format>` at C++23, `std::print`) writes
  `R"(\')"`. (0.115)
- The escapes are C's, GNU's `\e`, `\xHH`, `\x{...}`, `\o{...}`, `\u{...}`, `\uXXXX`, `\UXXXXXXXX`, and `\NNN` with up
  to three octal digits (`ccl_escape//1`, `ccl_ucn//1`; `ccl_lx_escape`, `ccl_lx_ucn`). A code point goes into a string
  as UTF-8 (`ccl_utf8/3`, `ccl_lx_put_utf8`), into a char as itself. Why: `\101` read as `\1` then `01`. (0.43)

### `\N{NAME}`

- Both lexers read `\N{NAME}` ([lex.charset], C23 6.4.3), an EXACT match: UTF-8 in a string, the code point in a char
  or a wide char. The runs `ccl_uname_range(Prefix, Lo, Hi)` (names that end in hex digits, CJK UNIFIED
  IDEOGRAPH-4E00 and kin) are computed first. Aliases of the kinds clang takes (control, correction, alternate,
  figment) are names. `test/c/run/uniname.c`. (0.104)
- An abbreviation (`\N{NUL}`) or an unknown name is a lexical error in both lexers: `ccl_escape//1` and
  `ccl_lx_escape` refuse `N{`, so it never falls back to the letter `N`. (0.103)
- The DCG reads the name by `ccl_uname_value/2` (the runs, then `ccl_uname/2`); `ccl_uninames_ready/0` loads
  `library/ccl_uninames.pl` by `ensure_loaded/1` on the first `\N{`, found on `$COCOLOG_LIBRARY`, and remembers it in
  the global `'$ccl_uninames'`, never a clause (a clause persists under `--embed`). The native `ccl_lx_ucn` calls
  `ccl_uname_code`, raw C that binary-searches `module/ccl_uninames.h`. (0.103)
- The table is written once. `library/ccl_uninames.pl` is GENERATED, never edited: `perl module/gen-uninames.pl >
  library/ccl_uninames.pl` (Perl's `Unicode::UCD`), Unicode 15.0.0, 44,115 names (Hangul syllables computed), 119
  aliases, 16 runs. `module/build.sh` spells `module/ccl_uninames.h` from it (names in `LC_ALL=C` strcmp order, then the
  runs, alias kind comments stripped); the header is never committed. (0.104)

## The preprocessor

### The design

- **The preprocessor is cocolog's own** (owner's rule: no clang, no LLVM binary is run): `library/ccl_pp.pl`. (M5)
- `ccl_pp_file(+Path, -Tokens, -Files)` preprocesses a file standalone (the predefined macros and its own) into reader
  tokens and names every file it pulled (a summary's deps). `ccl_pp_macros/1` answers the run's own macros from
  `'$pp_names'`. `ccl_pp_parse/4` reads the tokens inside `ccl_with_file/2`. (M5)
- A run is a GENERATION: `pp_reset/0` bumps `'$pp_gen'`. A macro is `'$pp:<Name>'` = `mac(Gen, Params, codes(Cs),
  Tokens | none)`, `undef(Gen)` or `nomac(Gen, Inc)`; an older run's macro is not this run's. `Params` is `obj` or a
  list ending in `va(N)`. (M5)
- Each file is preprocessed inside `\+ \+` (`pp_include_file`); its output survives under `'$pp_out:K'`, and
  `pp_finish/2` splices it. Why: cocolog reclaims the heap on backtracking only. (0.46)
- The run lexes in `punct` mode, `line` after. `pp_finish/2` and `pp_normalize` turn `tok(num, ...)` back by `pp_norm`:
  a plain decimal by `ccl_int_value/2` (`big(Atom)` past 2^60), the rest by the lexer. (0.94)

### Lines

- `pp_source/2` makes `line(N, Atom)` once per process and path (`'$pp_src:<Path>'`, or `'$pp_srct:<Path>'` with
  trigraphs): lines by `atomic_list_concat/3`, continuations joined, comments removed, block-comment lines counted.
  Only a line with `/` or a final backslash is walked code by code (`pp_clean/3`). Why: a walk costs ~1 µs a
  character. (M5)
- Trigraphs are replaced before anything else (`pp_trigraphs`, `pp_tri`, `pp_trigraph/2`) when `'$ccl_trigraphs'` is
  `yes`: in the ISO modes before C23 and under `-trigraphs`, never in GNU modes or C23 (clang's rule).
  `test/c/run/trigraphs.c`. (0.108)
- Trailing blanks after a final backslash still splice ([lex.phases]/2 as clang reads it; `pp_ends_backslash`); a `//`
  comment ending in a backslash swallows the next line (`pp_join` before `pp_clean`). `test/c/run/splice.c`. (0.99)
- `pp_run/3` sends a `#` line to `pp_directive/6`; it lexes a text line (`pp_lex_line/3`) and expands it (`pp_toks/5`),
  pulling the next lines for a function-like macro's arguments. (M5)

### Directives and conditional groups

- A false group is skipped by its `#` lines alone (`pp_skip_group/4`, never lexing). `#elifdef` and `#elifndef` are
  read (`pp_cond_word`; `pp_defined_body/3` spells `defined(X)`). (0.43)
- A header that is one `#ifndef X ... #endif` is guarded (`pp_note_guard/2`): included again with X defined, it is
  nothing. `#pragma once` likewise; nesting past 120 is nothing. Why: the SDK includes `sys/cdefs.h` ten times. (M5)
- In a header's run an `#include` (literal, or through the macros) is preprocessed in place; a `.pl` is passed on as
  `tok(pp, ...)`; one found nowhere is nothing. `#include_next` searches past the includer's directory. `#pragma` is
  nothing but `once`; `_Pragma("...")` goes with its operand. (M5)
- `#line N "file"` (C 6.10.4) and GNU's `# N "file"` set the presumed line and file per file (`pp_presumed`,
  `'$pp_linemap'`) for `__LINE__` and `__FILE__`; a diagnostic names the physical place. (0.108)
- In the user's file `#error` throws `pp_error(L, Text)`, and `#warning` goes to `'$pp_warnings'`, printed by the
  driver after the read (`dr_pp_warnings`). In a header `#error` stops that file (`'$pp_errors'`, unread) and
  `#warning` is nothing. Why: a program's own `#error` compiled to `cicilang: ok`. (0.93)
- `#embed "f"` and `#embed <f>` (with `limit`, `prefix`, `suffix`, `if_empty`, and their `__x__` spellings) put the
  bytes as ints where the directive stood, in C and C++, file or header (`pp_do_embed`). The name resolves as an
  `#include`'s; a code past 255 goes in as UTF-8; a resource nowhere is a `pp_error`. Reader `k89`. (0.93)

### Macro expansion and `#if`

- Expansion follows the standard: an argument is expanded first unless `#` or `##` takes it (`pp_subst/4`); a paste is
  spelled and lexed again (`pp_paste_two/3`); GNU's `, ## __VA_ARGS__` drops the comma (`vamarker`); `__VA_OPT__`
  keeps or drops its group (`pp_va_group`); each token is `h(Token, HideSet)` (`pp_wrap/4`) at the invocation's line,
  so a macro never expands inside itself. A body is lexed on first use (`pp_macro/3`). Reader `k83`. (0.93)
- `#if` (`pp_eval/1`): `defined` and the built-ins (`pp_defined_pass/2`), the expansion, the built-ins again; a name
  left is 0 and `true` 1 (`pp_normalize`); then `ccl_cond_expr//1` and `ccl_const_eval/2`. What does not evaluate is
  false. The evaluation is C's `#if` arithmetic (C 6.10.1/4): `pp_eval_/1` sets `'$ccl_cv_pp'` around it, and every
  unsigned operation is done in `uintmax_t`, 64 bits (`ccl_cv_width/2`), so `#if ~0u == 0xFFFFFFFFFFFFFFFF` holds; the
  global is put back on success, failure and throw. `test/c/run/unsignedconst.c`. (M5, 0.128)
- Built-ins (`pp_builtin_answer/3`): `__has_include(_next)` resolve for real (`ccl_resolve_include/3`);
  `__has_builtin` and `__is_identifier` 1 (libc++'s other branch is an `#error`), but `__has_builtin(__builtin_common_type)`
  0 (`pp_no_builtin/1`, a table of the builtins this compiler does not model: libc++ 21 then flattens `common_type` on its own
  specializations, the ones libc++ 18 has, and not on clang's builtin class template; reader 118; 0.126); `__has_embed` 1
  found, 2 empty, 0 nowhere; `__has_c_attribute` (C only) the standard attributes' dates (`pp_c_attribute/2`); `__is_target_arch`,
  `_vendor`, `_os`, `_environment` per host; every other `__has_*` 0, the plainest path, the one the reader reads best.
  (0.93)

### The predefined macros

- The predefined macros are `pp_predef(Name, Table, Text)` facts, from the reference compiler's `-dM -E` per level,
  answered BY NAME on a miss (`pp_predef_macro/3`), never defined in bulk. Why: defining them cost 25 ms a run. (M5)
- The order: the level's table (C++ `pp_std_table/2`: `cpp26`, `cpp23`, `cpp20`, newest first; C `pp_c_std_table/2`:
  `c23`), `any`, the OS (`pp_os/1`), the arch (`pp_arch/1`), `cpp`. `__cplusplus` is 201703L, 202002L, 202302L or
  202400L. `__STDC_VERSION__` is 201710L (C11, C99 too), 202311L at C23 with the `__STDC_VERSION_*_H__` macros.
  (0.57, 0.93)
- The OS and the arch are the HOST's: the module's compile-time `ccl_host_os/1`, `ccl_host_arch/1` (`uname` only
  without it), cached in `'$pp_os'`, `'$pp_arch'`. `darwin` holds the Apple rows (`__APPLE__`, `__MACH__`,
  `TARGET_OS_*`); `linux` holds `__linux__`, `__gnu_linux__`, `__unix__`, `__ELF__`, `__PIE__` and kin. Why: Linux
  compiled as a Mac. (0.93)

### Configuration chosen through the macros

- NO EXCEPTIONS in libc++ (the owner's design): `__cpp_exceptions` and `__EXCEPTIONS` are not predefined, so libc++
  builds its `-fno-exceptions` configuration, where a throw aborts with a message. The program's own `throw` and `try`
  use libc++abi. (0.50, 0.108)
- NO RTTI in libc++: `__cpp_rtti` and `__GXX_RTTI` are not predefined. `any`, `exception_ptr`, `shared_ptr` and
  `function` change; the vtables do not, so control blocks match the shipped library. `shared_ptr::get_deleter` and
  `dynamic_pointer_cast` are absent. The program's own `typeid` and `dynamic_cast` use libc++abi. (0.86, 0.108)
- `__OPTIMIZE_SIZE__` is predefined in C++, so libc++ 21 compiles its scalar algorithms, not the vectorized ones
  behind `_LIBCPP_HAS_ALGORITHM_VECTOR_UTILS && !defined(__OPTIMIZE_SIZE__)` (vector types, generic lambdas, vector
  builtins). libc++ 18 reads it nowhere. (0.92)
- 128-BIT INTEGERS IN BOTH LANGUAGES: `__SIZEOF_INT128__` is predefined in C and in C++ (16; `pp_predef(..., any,
  '16')`, 0.129), so libc++ builds its int128 configuration: `is_integral<__int128>`, `make_unsigned`,
  `numeric_limits<__int128>`, `to_chars` and `from_chars` in 128 bits, `std::hash<__int128>`, `std::format` of one.
  From 0.112 to 0.128 C++ went without the macro, and libc++ in its `_LIBCPP_HAS_NO_INT128` configuration: its
  `__basic_format_arg_value` holds an `__int128_t` member, which nothing typed before `__int128` lowered (0.117). The
  configuration found three defects, mended in 0.129: a conditional over bit builtins had no type, a folded constant past
  64 bits was cut to 64, and every explicit specialization of a function template was ignored (each in its topic).
  Reader 124. `int128lib.cpp`, `int128fmt.cpp` (C++20). (0.112, 0.117, 0.129)
- `__has_extension(c_atomic)` and `__has_extension(datasizeof)` (0.112) answer 1, the two extensions answered
  (`pp_builtin_answer`; the second makes libc++ 18 take `__datasizeof(T)`, folded by the desugaring);
  `__has_feature(cxx_atomic)` and `__has_keyword(_Atomic)` stay 0. libc++ 18 then defines `_LIBCPP_HAS_C_ATOMIC_IMP`,
  declares `memory_order` and builds `<atomic>` on `_Atomic(T)` and `__c11_atomic_*`. `__ATOMIC_RELAXED` 0 to
  `__ATOMIC_SEQ_CST` 5 are clang's numbering. `test/cpp/run/stdatomic.cpp`. Why: with all three at 0 no implementation
  was defined. (0.100)
- The table is clang-shaped (`__clang__` 1) while `__has_attribute` and `__has_feature` answer 0, so glibc's
  `sys/cdefs.h` takes a branch neither compiler takes. (0.87)
- With `__has_builtin` 1, glibc's `<math.h>` writes `INFINITY`, `NAN`, `HUGE_VAL`, `isnan` and kin on `__builtin_*`,
  which the lowering answers. `test/c/run/complex2.c`. (0.101)
- `_FORTIFY_SOURCE` is 0, so `strcpy` stays a function, not `__builtin___strcpy_chk`. (M5)

### The user's file and the headers' macros

- `ccl_pp_top/3` (from `ccl_read_file_/3`) runs the user's file in TOP mode (`'$pp_top'`). A `#define` or `#undef`
  is done AND passed on as `tok(pp, Text, L)` (`pp_pass/4`). An `#include` is passed on for the parser (a cached unit,
  a `.pl` macro file, or `missing`), and its header joins `'$pp_hdrs'`, the last first. A `#cocolog ... #end` block is
  one `tok(cocolog, Text, L)` of the raw lines, read again from the file (`pp_cocolog_block/5`). The groups are
  decided, and every macro is expanded. A line that does not lex whole throws `lexical(N)`. Reader `k86`;
  `test/c/run/macros.c`, `test/c/run/pp.c`. (M5)
- A run is not re-entrant, so `ccl_pp_prescan/1` first sends each literal `#include`, and each C++ header-unit
  `import`, to `ccl_header_macros_ready/2` (the header by `ccl_include_read/2`, then `ccl_header_macros/2`). The
  table's kind is memoized per level in `'$ccl_hm:<Path>@<Level>'` (`ccl_hm_key/2`, `t` appended with trigraphs).
  (0.99, 0.110)
- A header's macro reaches the run BY NAME on first use (`pp_macro/3`, `pp_defined/1`). The run's own `'$pp:<Name>'`
  comes first; a miss is kept until the next include (`'$pp_ninc'`). Then `pp_outer_macro/3` asks the predefined
  macros (no header redefines one), then the headers, the last included first (`pp_header_macro/3`). Why:
  `<stdio.h>` brings 1200 macros, and a file uses a dozen. (M5)
- No table is parsed whole. `indexed` (C++): the `.mac` file beside the summary, `mnames([...])` lines of up to a
  hundred names, then `macro(N, Ps, text(A))` lines as written; `ccl_mac_lines/3` splits it, `ccl_hml_assert/3`
  asserts `'$ccl_hml'(Name, Path, raw(Line))`, and `pp_raw_macro/4` parses a line into a fresh term when asked.
  `store(Key)` (C): rows `'$ccl_hmacros:<Path>'(Name, Key, macro(...))` (`ccl_kb_macro/5`), a row per closure file
  under `'$dep'`, the index `'$ccl_hmeta'(Path, Key, meta(N, ND))` (`ccl_kb_macros_cached/2`). `list`: a table the
  store refused, in `'$ccl_hmlist:<Path>'`. (M5)
- `ccl_kb_remember_macros/3` replaces only this level's rows. Why: a C23 read retracted the C17 rows, and `macros.c`
  met `undeclared(EOF)` in the gate's order. (0.99)
- A table that no cache holds comes from one standalone run (`ccl_pp_file/3`, `ccl_pp_macros/1`), once per store; a
  header read preprocessed by `ccl_read_unit/3` stores its macros then. (M5)
- A C++ header unit's macros are the importer's ([module.import]/5): `pp_import_line/2` catches `import "h";`, `import
  <h>;` and `export import ...`; the macros are visible after the line, and the line goes on to the reader.
  `test/cpp/run/headerunit.cpp`. (0.110)

### The flattened text (`-E`)

- `cicilang++ -E f.cpp -o flat.cpp` (`dr_preprocess`) runs `ccl_pp_file/3` and spells the tokens back by
  `ccl_pp_spell/2`. A space separates two tokens, a newline comes where the line changes, and at most three blank
  lines stand for skipped lines. A string keeps `\"`, `\'`, `\\`, `\n`, `\t`, `\NNN` below 256 and `\u{...}` above.
  Why: the census reads the flattened text. (0.44)
- Every token spells back as the reader takes it (`ccl_pp_spell_tok/4`, `pp_spell/2`). The suffixes stay: `u`, `l`,
  `ul`, `wb`, `uwb`, `f`, `L`, and the imaginary `i`, `if`, `ui`, `li`, `uli` (`pp_imag_suffix/2`). A literal keeps
  its prefix (`pp_str_prefix/2`). A literal past 2^60 spells as its digits (`pp_int_codes/2`), and a float past a
  double as `1e999`. A `#cocolog` block spells whole. (0.108)

### The compiler's own headers

- **Nothing of the standard library is the compiler's own** (owner's rule): the C freestanding headers in
  `library/include` are the one exception; C++ compiles against libc++ as it is. (0.41)
- They sit in each `$COCOLOG_LIBRARY` directory plus `/include` (`ccl_own_include_dirs/1`): after libc++'s tree in C++,
  before `/usr/local/include` and the system's headers. The guard is `_CICILANG_<NAME>_H` (`__CCL_STDATOMIC_H`). (M2)
- `stddef.h`: LP64's `size_t`, `ptrdiff_t`, `wchar_t` (C only), `max_align_t`, `NULL` as `((void *)0)` in both
  languages (C++'s `NULL` reads as C's cast), `offsetof` over `__builtin_offsetof`; at C23 `nullptr_t` and
  `unreachable()`. (0.93)
- `stdarg.h`: `va_list` is `__builtin_va_list`, `va_start`, `va_arg`, `va_end`, `va_copy` the builtins; glibc's
  `__need___va_list` gets `__gnuc_va_list` alone, as from clang's header. `test/c/run/varargs.c`. (0.108)
- `limits.h` defines `_GCC_LIMITS_H_` and the limits from the predefined macros (`__INT_MAX__` and kin, the widths at
  C23), then takes the C library's own `limits.h` by `#include_next` where there is one. Why: glibc asks the
  compiler's header for them, so `INT_MAX` was undefined on Linux. (0.93)
- `float.h` (from the predefined macros), `stdbool.h` and `iso646.h` (C only), `stdalign.h`, `stdnoreturn.h`. (M2)
- `stdckdint.h` (C23 7.20): `ckd_add`, `ckd_sub`, `ckd_mul` over `__builtin_*_overflow`. `stdbit.h` (C23 7.18): the
  suffixed functions over the bit builtins, the generic forms through `_Generic`. (0.93)
- `stdatomic.h` (C11 7.17) over the `__c11_atomic_*` builtins, as clang's: the `atomic_*` typedefs through `_Atomic(T)`,
  `memory_order` over `__ATOMIC_*`, `atomic_flag`, every function and its `_explicit` form. `test/c/run/atomic.c`.
  Why: glibc has none, and clang's lives in a resource directory off the path. (0.99)
- `complex.h`: the C library's declarations by `#include_next`, then `_Complex_I`, `I`, `CMPLX`, `CMPLXF`, `CMPLXL`
  over `__builtin_complex`; `CMPLXL` casts to `long double` (0.112: it cast to `double`, and `long double` is x86_fp80).
  Why: glibc defines `CMPLX` for GCC only. `test/c/run/complex.c`, `complex4.c`. (0.100, 0.112)

## The C reader and the language's own forms

### The reader's door and the item loop

- `cicilang_ast(+File, -AST)` mirrors `phrase/2`: the whole file, else `error(syntax_error(cicilang_ast(File, line(L),
  near(Far))), _)`, L where the unread tokens start, Far the farthest line reached. `cicilang_ast/3` mirrors `phrase/3`.
  A lexical error is `syntax_error(cicilang_ast(File, lexical, line(L)))`. Reader `k69` to `k71`. (M1)
- `ccl_read_file/3` sets the language (`ccl_set_lang/1`), serves the store's read (`ccl_kb_cached/3`), else runs
  `ccl_pp_top/3` and `ccl_unit/3` inside `ccl_with_file/2` and stores a whole read. (M5)
- `ccl_unit/3` seeds the typedef names, resets `'$ccl_far'`, `'$ccl_macros'` and `'$ccl_expansions'`, registers the
  standard macros, empties the tables (`ccl_scope_init`) and reads the items with `ccl_externals//2`. (M1b)
- The item loop parses EACH ITEM inside `\+ \+` (`ccl_externals/4`). The item and the count of tokens left pass
  through `'$ccl_item'`, and `ccl_skip/3` recovers the position. Later items get the marker `genv`. A `clang -E` line
  marker `# N "file"` is dropped (`ccl_line_marker/1`). Why: cocolog reclaims the heap on backtracking only. (0.46)
- Every statement carries its line first: `expr(L, E)`, `if(L, C, T, E)`, `return(L, E)`. Reader `k77`. (M1)
- `ccl_p//1`, `ccl_kw//1`, `ccl_id//1` note the farthest line (`ccl_far/1`, `'$ccl_far'`, `ccl_farthest/1`) for the
  error's `near(F)`. (M1)
- A `#define`, `#undef` or `#include` comes from the preprocessor as `tok(pp, Text, L)`, read as the `directive/2` or
  `include/3` item. A `tok(pp, ...)` is skipped in a struct body, between declarators, among enumerators and in a
  block. (M5)

### The expression grammar

- **One rule reads the ten binary levels** (owner's rule, 2026-09-06: a pattern is written once).
  `ccl_binary(Min, E)` climbs precedence over `ccl_binop(Op, Level)`: `||` 1 to `* / %` 10, `<=>` 7.5 (below the
  relational, above the shifts). `ccl_lor` starts at 1, `ccl_shift` at 8 (a template argument's, so `>` closes it).
  Reader `k65`. Why: a cascade of one level per class cost thirty token matches a token; this costs eight. (2026-09-06)
- ONE look chooses the clause: `ccl_unary_(V, K, E)`, `ccl_primary_(K, V, E)`, `ccl_postfix_p(V, A, E)`, value or kind
  first for indexing. The assignment's left is read once, as a conditional expression. A cast's type name is tried once
  (`ccl_cast_expr`); `(T){...}` is `compound_lit/2` (`ccl_cast_rest`). (2026-09-06)
- `({ ... })` is `stmt_expr/1`. `__real__ z` and `__imag__ z` are `real_part/1` and `imag_part/1`; both words stay out
  of the typedef heuristic, so `__real__ z = 5.0;` is a statement. (0.101)
- `_Generic` is chosen AT THE READ (`ccl_generic_pick`). `ccl_type_of/2` types the controlling expression over the
  parser's table; it is decayed and its top-level qualifiers go (DR 481). `ccl_type_canon/2` matches it (typedefs
  resolved, `unsigned` = `unsigned int`, inner qualifiers kept), else `default` is taken. An expression that cannot be
  typed stays `generic/2`, which the lowering refuses. It is a primary, so `_Generic(...)(x)` calls the pick
  (<stdbit.h>). Reader `k90`. (0.93)
- `_Alignof(T)` and C23's `alignof(T)` are `alignof_type(T)`. (0.93)

### Declarators and types

- Declarators are parsed inside out and folded onto the base by `ccl_mk_type/4`, which drops the `constexpr` marker
  (`ccl_constexpr_fold`; a function's result loses its `const` too). (0.95)
- `auto a = x, b = y;` (C23 and C++) is one declaration per declarator, each initialized by an ASSIGNMENT-expression and
  deduced alone (`ccl_auto_more//3`, `ccl_auto_next//3`; a `'$splice'/1` in a block and at file scope). The clause
  commits after its `;`, so a form it cannot take (`auto a = 1, *p = &a;`) falls to the general declarators. Else the
  first initializer was read as an EXPRESSION, its comma took the second declarator for a comma expression, and the
  declaration named one variable (`not lowered yet: auto(q)`). `autodecl.cpp`. Why: `auto q = a / b, s = a - b;` over
  `std::complex`, and the idiom `auto it = v.begin(), e = v.end();`. (0.117)
- An init-declarator names what it declares ([dcl.decl]/1): `ccl_init_declarator` refuses an unnamed declarator, so
  `Loop()(1, 2);` is a call. Why: it read as a declaration of nothing initialized by `(1, 2)`, the call was dropped, and
  libc++'s `ranges::copy` copied nothing. `test/cpp/run/tempcallstmt.cpp`. (0.115)
- `ccl_sto_pick/2` picks the deciding storage word. Why: `static inline constexpr` lost `static`. (0.44)
- `__attribute__((...))` and `__asm("...")` are read and dropped (`ccl_gnu_attr`). `typeof`, `__typeof__`, `__typeof`
  and `typeof_unqual` are type specifiers at every level (`ccl_typeof//1`; `typeof_unqual(X)` is
  `typeof(unqual(X))`). `(^b)` is `block(Q, T)`. (0.93)
- A nullability word (`_Nonnull`, `_Nullable`, `_Null_unspecified`, `__nonnull` ...) is read and dropped, bare or with
  an argument list (`ccl_gnu_attr`). Why: glibc's `__nonnull(params)` arrives as `_Nonnull ( ( 1 ) )`; read bare, it
  stopped `<stdio.h>` at `fclose`, and `printf` was undeclared. (0.87)
- `__signed`, `__const`, `__volatile`, `__restrict`, `__inline` and their `__x__` forms ARE the words. A fact per
  spelling (`ccl_gnu_word/2`) and one rule (`ccl_gnu_spec`) route each as a type, a qualifier or a storage word. The
  grammar reads them, not the lexers. (0.71)
- `_BitInt(N)` is the specifier `bitint(N)` in C and C++, half a rank below the standard type of its width
  (`ccl_bitint_rank`), never promoted (`ccl_promote`; C23 6.3.1.1/2). (0.93)
- The usual arithmetic conversions answer an unqualified value (`ccl_usual/3` over `ccl_usual_/3`): an operand's
  `const` is not the result's. C++'s `char32_t` promotes to `unsigned int` and `wchar_t` to `int`, their underlying
  types ([conv.prom]/8; `ccl_promote`); `char16_t` and `char8_t` promote to `int` by rank. Fixture:
  `test/cpp/run/charpromote.cpp`. Why: libc++'s `common_reference` of `const char32_t &` and `const unsigned &` came out
  `const const char32_t`, and `ranges::less` over the grapheme table had no candidate. (0.112)
- An ENUM ranks and promotes as its underlying type, the written base or `int` ([conv.prom]/3-4, C23 6.3.1.1; `ccl_int_rank`,
  `ccl_promote` over `ccl_enum_underlying/2`): `e + 1` and `~e` are that type's arithmetic. Fixture: `promotion.cpp`. Why: an
  enum stayed itself through the conversions, so a promotion could not be told from a conversion (below). (0.127)
- `_Decimal32`, `_Decimal64` and `_Decimal128` are type words of the grammar's table, as `__int128` is
  (`ccl_gnu_word/2`; the lexers' keyword tables are the language's, and C23's new keywords arrive as identifiers), at
  every level as gcc reads them; they were read as typedef names (0.129).
- `__int128` is a type word (`ccl_gnu_word('__int128', '__int128')`, `ccl_basic_type`; `signed`/`unsigned` with it,
  `long` never): `ccl_builtin_typedef/2` gives `__int128_t` and `__uint128_t` their types, integer rank 6 above `long
  long`, size and alignment 16, LLVM `i128` (`ir_base`), Itanium `n` and `o`. Reader `k92` over `test/c/run/int128.c`.
  The decimal floating types are the Lowering's topic (0.129). (0.71, 0.93, 0.117)
- `_Thread_local` and `thread_local` (C++, C23) are the QUALIFIER `thread_local`, not storage; their clauses precede
  the storage clause, so `static _Thread_local` keeps both. Reader `k91`. (0.93)
- `_Alignas(E)`, and C23's and C++'s `alignas(E)`, on an object are the qualifier `aligned(E)`; in an attribute
  position they are dropped. `test/c/run/wstr_alignas.c`. (0.99)
- An alignment specifier changes the alignment, never the size (`ccl_size_align`): `sizeof x' of `_Alignas(16) int x'
  is 4, a member after an aligned member lies right after it, and an aligned array counts its elements at their own
  size. Why: rounded, `alignas(S) unsigned char buf[sizeof(S)]' had `sizeof buf' 192 for 24 bytes, and a loop over it
  wrote past the stack slot. `test/c/run/alignsize.c`. (0.112)
- `_Atomic(T)` (C11 6.7.2.4) is T's specifiers plus the qualifier `_Atomic`; a pointer or qualified T is `typeof(T)`
  (`ccl_atomic_spec`). (0.99)
- `typeof` is resolved (`ccl_resolve_base([typeof(X)], ...)`): a type as it is, an expression by `ccl_type_of/2`,
  `unqual` stripping top-level qualifiers. `typeof(K)` of an object is its expression (`ccl_typeof_type/1`). (0.93)
- A K&R definition (C 6.9.1/13) is read as its prototype (`ccl_knr_ids`, `ccl_knr_decls`, `ccl_knr_params`,
  `ccl_knr_adjust`): an undeclared parameter is `int`, an array a pointer, a `float` a `double`.
  `test/c/run/cforms.c`. (0.108)
- `a[static 3]`, `a[const static 3]` and `a[*]` parameters are the pointer they decay to. `_Bool` is a byte with C's
  conversion rules. (0.108)
- A C11 anonymous struct or union member is a hidden member `$anonK` (`ccl_anon_name`, C only), its members the
  holder's, reached through `ccl_anon_route`. (0.108)
- A label's body may be a declaration ([stmt.label], C23): `ccl_label_body` falls to `ccl_block_item`. (0.91)
- `__func__`, `__FUNCTION__`, `__PRETTY_FUNCTION__` name the enclosing function unless the program declares them
  (`ccl_func_name/1`). (0.108)

### Initializers and objects

- An unbounded array takes its bound from its initializer at the read (`ccl_sized_by_init`, C 6.7.9/22). A
  designator moves the position (`ccl_init_bound`). A string gives its length plus one, and a wide string its code
  points plus one (`ccl_utf8_count`). A pack expansion sizes nothing. `(T[]){...}` is sized by its items. Why: a
  global's `sizeof` was 0. (0.104, 0.108)
- Designated initializers work in arrays and nested (`[3] = x`, `.a.b = y`); a global's list is made positional
  (`ccl_init_norm`, C 6.7.9). `offsetof` folds through members, elements and anonymous members (`ccl_offsetof`).
  `test/c/run/designated.c`. (0.108)
- Tentative definitions are one object (C 6.9.2; `ir_flush_tentatives`). An array argument to a function without a
  prototype decays. (0.108)

### Typedef names and the symbol table

- A typedef name from a header the reader has not seen is known from its context: `name x`, `name *p` where no
  expression can stand, `(name *)`, `(name){`, `name *p = ...` in a block. A seed of standard names starts every unit
  (`ccl_seed_typedefs/1`). (M1)
- The file's typedef names are threaded as an Env and mirrored in `'$ccl_env'` with the bucket set `'$ccl_envs'`
  (`ccl_set_has/2`) for the casts deep in an expression. `ccl_env_sync/2` MERGES an item's new names and never
  replaces the global env; a deep rule passes `genv` (`ccl_env_member/2`). Why: a replace dropped C++'s class names.
  (0.44, 0.46)
- The table kept while parsing: `'$ccl_scope'` the OPEN frames of Name-Type, innermost first, `[]` at file scope
  (pushed by `ccl_compound`, and at a function's parameters only when `{` is next); `'$ccl_gscope'` the file scope;
  `'$ccl_typedefs'`; `'$ccl_tags'` (a C++ class without its bodies, `ccl_slim_members`) -- these three in 128 buckets
  each since 0.120 (the Tables topic of Time and memory); `'$ccl_enums'`. `library(ccl_infer)` answers over it
  (`ccl_type_of/2`, `ccl_resolve_type/2`, `ccl_size_of/2`, LP64). Reader `k25`. (M1b, 0.120)
- `ccl_declare/2` puts a name in the innermost open frame, else `ccl_gdeclare/1`; `ccl_declared/2` asks the open frames,
  then `ccl_gdeclared/2`; `ccl_scope/1` answers all frames, file scope last; `ccl_locals/1` the open ones;
  `ccl_scope_add/1` adds a list. Why: `nb_getval/2` copies, and a local must not copy the file scope. (M1b)
- `ccl_note_item/1` notes one item; a unit tree goes through the BULK noter `ccl_items_note/1`: difference lists, each
  table set once, the unit's own items before its includes' (`ccl_own_first`). Why: per item it was quadratic, and a
  unit's own definition shadows a header's declaration. (0.78)
- Answers are cached: `ccl_cached/4` for small values, `ccl_cached_named/4` with a global per name for large ones.
  `ccl_tables_changed/0` empties them wherever a table is written. A cached predicate is not re-entrant. (2026-09-06)
- An enumerator is of its ENUM's type in C++ ([dcl.enum]/5) and an `int` in C and for an unnamed enum (`ccl_type_of(id(N))`
  through `ccl_enumerator_type/3`): the table of values keeps each enumerator's enum beside its value, `'$t'(Name)-Tag`,
  and a scoped enum's tag as `'$s'(Tag)-1` (the parser's `ccl_declare_enumerators/2`, which declares the enumerator with
  that type, and the bulk noter's `ccl_collect_enum_tags/4`). A compound key never answers a lookup of a value by name,
  so every writer, save and restore of the table carries the two kinds of entry without a word, a summary's `enum/2`
  lines too (reader 121). A scoped enum converts to no arithmetic type (`ccl_scoped_enum/1`). An enumerator of an
  unscoped enum NESTED in a class, named through the class (`Shape::Circle`), is of the nested enum's type too
  (`cpp_enum_class_tag/3`, a `cpp_expr` clause before the class road, which folded it as an `int` static). Fixture: `enumtype.cpp`.
  Why: `h(Red)` called `h(int)` over `h(Color)`, `k(Fruit::Pear)` called `k(long)`, a template deduced an `int`, and
  `v.push_back(Green)` was refused (`undeclared(Green)`). (0.100, 0.127)
- `ccl_type_of/2` of a statement expression puts its declarations in scope for its last expression. (M1b)
- A typedef, tag or enum declared in a block joins the unit's one table in C (`ccl_collect_item(function)` through
  `ccl_stmt_typedefs`, by statement shape; two blocks that typedef one name must agree; `test/c/run/typedef_block.c`).
  In C++ a block's TYPEDEF does not (0.127): the bulk noter takes only the tags and enumerators of its type
  (`ccl_collect_typedef_types/5`), and the desugaring notes it for the statements of its own block and takes it out at
  the block's end, on success, failure and throw (`cpp_scoped_typedefs/2` over `ccl_tab_del/2`, which removes the NEWEST
  entry of the name, so the one it shadowed answers again). Fixture: `blocktypedef.cpp`. Why: one table holding every
  block's `using _Tp = ...;` made `_Tp` a KNOWN name to every rule that tells a template's own parameter by the tables
  not knowing it; 0.126 had worked round it twice (`cpp_callee_param_type/2`, `cpp_lambda_params/3`). (0.108, 0.127)
- The bulk noter skips a name that is no atom, a member defined out of its class (`ccl_collect_vars`:
  `Counter::made`; `ccl_collect_item`: `Shape::scale`). Why: it crashed `atom_concat`. (0.32)
- In C++ a tag's name is a type. `ccl_resolve_base([typedef(N)], ...)` asks `ccl_tag_type/4`, which tells the kind by
  the members' shape. A class resolves to its desugared struct (`ccl_tag_struct/2`, cached `'$ccl_ts:'`), so a tag
  noted twice resolves to the struct. (0.41)
- `ccl_resolve_base/3` leaves a template-id typedef raw (an `atom(N)` guard before the named cache). (0.35)
- In C++ an included unit's class, struct and enum class names join the includer's Env (`ccl_items_typedefs`), so
  `Name &s` parses. (0.41)

### C's language levels

- C's level is its own global, `'$ccl_c_std'` (`ccl_c_std/1`, default 17), since 17 and 23 are both languages'. The
  driver gives `cstd(N)`: `-std=c23|gnu23|c2x|gnu2x` 23; c17, c11, c99 and their GNU forms accepted; c89, c90 refused.
  A fixture names its level in `NAME.std` (`test/c/run/c23.c`, `c23b.c`, `c23pp.c`). (0.57)
- The grammar asks `ccl_c23//0`, and `ccl_c_or_cpp//0` for a form C23 took from C++ (C++ always, C from 23). Forms are
  READ at the level, never lexed at it. (0.57)
- At `-std=c23`: `bool` a specifier; `true`, `false`, `nullptr` primaries; `constexpr` is `const` plus the marker
  `constexpr`; `thread_local` the qualifier; `alignas(E)` on an object `aligned(E)`. Reader `k88`, `k90`. (0.99)
- At `-std=c23` a `const` object whose initializer folds is a CONSTANT, a `constexpr` one among them:
  `ccl_note_constants/2` adds it to `'$ccl_enums'`, so an array bound and a static assertion fold it. Reader `k87`.
  (0.57)
- From C23, C reads C++'s forms: `[[attributes]]` dropped; `enum E : unsigned char` (`ccl_enum_base//1`, `enum_base(T)`
  the first member); `auto x = e` deduced (`ccl_auto_decl/5`); `static_assert(e[, "msg"])` at file scope and in a
  block. `_Static_assert` is read in every C. (0.57)
- A static assertion is CHECKED where it folds, in C ONLY (`ccl_assert_holds/3` throws `static_assert_failed(Text)`).
  Why: C++ allows `static_assert(false)` in a branch no instantiation takes. (0.57) The fold is asked ONCE
  (`once(ccl_const_eval(E, V))`, 0.117): `sizeof` of a struct had alternatives (16, 0, 0, 0), the test `V =:= 0` failed
  on the first and backtracked into a 0, and `_Static_assert(sizeof(T) == 16, ...)` over `struct { char c; long v; }`
  failed since 0.57. `sizeof`, `sizeof_type` and `alignof_type` answer one value in `ccl_const_eval/2` now.
  `test/c/run/sizeofassert.c`. (0.117)

### The language's own forms

- **`name := expr;` is a declaration by inference** (owner's rule): `ccl_infer_decl/4,5` takes `ccl_type_of/2` of the
  right side, decays arrays and functions, strips top-level qualifiers, and builds `declaration(L, none, Base,
  [var(N, T, E)])`; `unknown` throws `cannot_infer(N, E)` with `here(File, L)`. A clause of `ccl_external`,
  `ccl_block_item`, `ccl_for_init`, before the others. Reader `k30` to `k36`. (M1b)
- **The left of `:=` may be a pattern** (owner's rule), `{ a, _, f: b, g: { c } } := e`. `ccl_pattern//1` reads it
  into `bind`, `skip`, `field` and `sub` terms. `ccl_destructure/4` makes one inferred declaration per binding: by
  position through `ccl_nth_member/4` (an array's element by index), by name through `ccl_member_access/6`. A
  `ccl_gensym` temporary comes first unless the right side is an `id/1`. The result is a `'$splice'/1`. The errors
  are `no_member(Field | position(I), Type)` and `cannot_infer(pattern, E)`. Reader `k37` to `k41`. (M1b)
- **`name { members }` at file scope is `typedef struct name { members } name;`** (owner's rule). A `ccl_external`
  clause on `ccl_id(N), ccl_peek(p, '{')` reads it, the members by `ccl_members//2`. The name joins the Env, and the
  item is a plain `typedef/2`. Reader `k47` to `k49`. (M1b)
- **`defer(a, b) { body }` is a statement** (owner's rule: scope-bound like Cicili's cleanup, a static cleanup chain,
  no runtime): `ccl_statement` takes `defer ( ids ) {` only, so a call named defer stays a call. `defer(Line,
  [id(V)...], block(...))` runs at every exit of its scope, LIFO, over the variables' values then. Reader `k72`,
  `k73`. (M2)
- `own` is a qualifier read in the specifiers, on the pointee as C has it: `own char *p` is `ptr([], base([own],
  [char]))`. `move(E)` is a node, read at the macro door (`ccl_call_or_macro/3`). Reader `k75`, `k76`. (M3)
- `own` is a keyword in both languages, so a C++ member or variable named `own` does not read: the qualifier takes it
  (found when a fixture of 0.121 used it, and renamed). (0.121)
- **`x tie y` is the tie** (owner's rule, and the spelling): x lives within y. `tie` is CONTEXTUAL, read only where a
  tie can stand and only before a name (`ccl_id(tie), ccl_id(Y)`), so `std::tie` and a C variable `tie` are untouched.
  `ccl_tie//2` reads it after a declarator (init-declarator, member, parameter, function definition before `{`),
  `ccl_tie_name//1` after the `:=` forms. (0.109)
- `ccl_add_tie/3` puts `tie(Y)` in the OUTERMOST qualifier list, through an array to its element and a function to its
  result; `ccl_tie_of/2` reads it. Only the check reads a tie. Reader `k81`. (0.109)

### Macros: `.pl` files, `#cocolog` blocks and the global macros

- **A `.pl` included is a macro file** (owner's rule): every predicate it defines is a macro. `name(a, b)` with
  `name/3` runs NOW as `name(ASTa, ASTb, R)`, and R replaces the call (`ccl_call_or_macro/3` in `ccl_postfix_p`). A
  statement R is unwrapped (`ccl_stmt_of/3`), and `ccl_add_lines/3` gives a short form the call's line. A list R is a
  `'$splice'/1`, spliced in blocks and at file scope (`ccl_splice/3`). A file-scope `name(args);` is its own
  `ccl_external` clause. `name(R) --> ...` is `dcg(name)`, called as `phrase(name(R), Args)`. Reader `k19` to `k24`.
  (M1b)
- The registry `'$ccl_macros'` holds `macro(CName, Pred, Arity | dcg)`; `ccl_macro_X` defines `X`
  (`ccl_macro_cname/2`). `ccl_load_macros/2` loads by `ensure_loaded/1` and records `'$ccl_macro_files'`;
  `ccl_pl_clauses/2` finds the heads by splitting the text and `term_to_atom/2` per clause, since `current_predicate/1`
  does not list consulted clauses. `ccl_with_file/2` saves and restores the registry. (M1b)
- A macro's error carries both places, `here(File, Line, in_macro(Pred, MacroFile))` on `macro_failed/2` and
  `macro_error/3` (`ccl_macro_file/2`). Each expansion is `expansion(Line, Name, Args)` in `'$ccl_expansions'`; the
  unit ends with `'$expansions'(List)`, and the driver adds `note: expanded from macro` (`dr_remember_expansions/1`).
  Reader `k28`, `k29`, `k79`, `k80`. (M1b)
- **`#cocolog ... #end` is a macro file in place** (owner's rule). The item `cocolog(L, Text)` calls
  `ccl_cocolog_block/2`. It writes `tmp_file(cocolog)-L.pl` and runs `ccl_load_macros/2`, the `#include "m.pl"` door,
  so a macro's error names that file. The text rides into the store; over the clause budget the file stays uncached.
  A cache hit loads nothing again, since the expansion happened at the read. Reader `k82`. (M1b)
- **`format`, `print`, `println` are global macros** (owner's rule), in `library/ccl_format.pl`.
  `ccl_standard_macros/0` registers that file at the start of every unit, found on `$COCOLOG_LIBRARY`. It never does
  inside a library header's read (`ccl_lib_unit/1`, `'$ccl_lib_unit'`). Why: libc++ calls a `format` of its own.
  (0.99)
- They are DCG macros. Rust's holes `{}`, `{0}`, `{name}`, `{{`, `}}` become printf conversions by `ccl_type_of/2`; a
  struct prints by its members. `print` is `printf`, `println` adds `\n`, `format` is `({ char *b; asprintf(&b, ...);
  b; })`, a malloc'd `char *`. An argument that cannot be formatted stops the read (`cannot_format(Expr)`). Reader
  `k42` to `k46`. (M1b)
- **`clone(p)` is a global macro** (owner's rule), `ccl_macro_clone/2`: `({ own T *c = malloc(sizeof(T)); *c = *p; c;
  })`, a fresh owner, so an own parameter takes the copy and `p` stays the caller's. It refuses a non-pointer
  (`cannot_clone`), a pointee with an own member (`cannot_clone_own_members`, `ccl_has_own_member/1`) and a file with
  no `malloc` (`clone_needs_malloc`). `test/c/run/clone.c`. (M3)

## The C++ reader

### The mode and the level

- The global `'$ccl_lang'` is `c` or `cpp`. `ccl_set_lang/1` takes it from the extension (`ccl_lang_of_file/2`: `.cpp
  .cc .cxx .C .hpp .hh .hxx .cppm .ccm .cxxm .ixx .mpp`). The driver's `lang(cpp)` forces it (`'$ccl_lang_forced'`), and
  `cicilang++` sets that through `CICILANG_LANG=cpp`. (M5, 0.108)
- Every C++ rule is guarded by `ccl_cpp//0` and stands BEFORE the C clause it extends, so a `.c` file reads as before.
  (M5)
- Every C++ form is read at every C++ level, except `a[i, j]`: a multi-index from C++23 only (`ccl_std_at_least/1` over
  `'$ccl_std'`, default 17). (0.42, 0.43)
- In a DCG body, `( A, ! ; B )` cuts the WHOLE clause. Use it only for a choice that decides the clause. An optional
  word is `( ccl_kw(inline) ; [] )`, with no cut. Why: a cut before `namespace` killed every inline function. (M5)
- `ccl_make_class` makes `class(K, N, Bases, Members)` of a C++ `class`, a class with bases, or a body with a member
  that is not data. A `union` stays `union(N, Ms)`, and a C++ `struct` of data only stays C's `struct(N, Ms)`. (M5)
- The bulk noter (`ccl_collect_item`) takes the items of `extern_c` and `namespace` under bare names, a `template`'s
  item, and a `class` as a tag. It skips a method defined out of its class. An alias or variable template is never a C
  typedef. (0.44)

### Names and template-ids

- `ccl_qname//3` reads `::a::b<args>::c` into an atom, `tmpl(N, Args)` or `scoped(Path, Last)`; a leading `::` puts
  `global` first. A segment may be `decltype(E)`, `operator(Op)` or `::template f<U>` (`ccl_qseg`, `ccl_qrest`).
  (M5, 0.44)
- `N <` starts a template-id when N is a known template (`ccl_known_template/1`: the set `'$ccl_tmpls'`, the list
  `'$ccl_templates'`). In a type context it also starts one when `ccl_targs_ahead//0` finds the matching `>` and a
  declarator-like token follows. The scan skips parentheses and stops at `;`, `{` or `}`. (M5, 0.44)
- `ccl_ensure_globals` seeds the templates with common standard library names and the compiler's template-shaped
  builtins (`__type_pack_element`, `__make_integer_seq` ...). Every template item adds its name (`ccl_note_template/1`).
  (M5)
- In template arguments, `ccl_op_open/1` makes `>` and `>>` closers; `>>` closes two, and `ccl_tclose//0` leaves one.
  `'$ccl_targ'` counts the depth, and parentheses reset it (`ccl_targ_save`, `ccl_targ_restore`). (0.44)
- A template argument is a type only where it names no declarator (`ccl_targ_type`: the name is `anon`). Else it is a
  full expression (`ccl_targ_expr`). `Ts...` is `pack(T)`. Why: libc++'s `pair` writes `__conditional_t<A::value &&
  B::value, ...>`, and `A::value &&` read as a reference. (0.44, 0.71)
- `typename T::x` is `typedef(Q)`. `ccl_qrest` reads `X<T>::template f<U>`, and `X<T>::template f` alone as a template
  template argument. `decltype(auto)` is `auto`. (0.44, 0.84)
- A member name takes template arguments by look-ahead (`x.f<T>()`) or after `template` (`x.template f<T>()`,
  `f.template operator()<I>()`; `ccl_member_name`). (0.84)

### Type or expression: the vexing parse

- A compound qualified name is a type (`ccl_cpp_type//3` in `ccl_specs`) only where `ccl_qname_typish/2` holds or a
  declarator follows (`ccl_declarator_follows`). Before `(` it is an expression: `S b(std::move(a));` declares no
  function. A plain name is left to the C heuristics, so `std::cout << x` is an expression. (0.44)
- `ccl_qname_typish/2` holds for a template-id whose template is no function's, for a last name known as a typedef or as
  such a template, and for a fixed list of type-like names (`string`, `size_t`, `value_type`, `iterator` ...). (0.44)
- A function template's name is a template, never a type. `ccl_note_if_fn_template` records it (`'$ccl_fn_templates'`,
  the set `'$ccl_ftmpls'`; a summary's `ftemplate(N)`), and `ccl_qname_typish` refuses it, its explicit template-id too.
  So `_Tp __t(std::move(__x))` and `T &r(std::forward<U>(v))` declare variables. (0.45, 0.84)
- `X<T>::f`, `v<T>` and `operator+<...>` are the declarator-id `name(Q)` only where a declarator may end
  (`ccl_declarator_id_end`) and outside a block (`\+ ccl_in_block`). So `(is_x<T>::value && y)` is no cast, and
  `traits::take(x);` in a body is a call. `test/cpp/run/qualstmt.cpp`. (0.44, 0.55)
- In a C++ parameter list, a lone undeclared name before `,` or `)` is an unnamed parameter of that type
  (`ccl_typedef_name(_, param, N)`). A declared object keeps the vexing parse. Why: libc++ 18's undeclared
  `memory_order` stopped the read of `<iostream>` silently. (0.93)
- That rule is for a PROTOTYPE, not for a body: the declarators of a block-level declaration are read with
  `'$ccl_blockdecl'` set (`ccl_block_declarators//3`, `ccl_blockdecl/0`; restored on success and on failure), and there
  an undeclared lone name is the argument of an object (0.117, reader 114). A class body is a complete-class context
  ([class.mem]/6), so `std::lock_guard <std::mutex> g(mu);` in a member function, with `mu` declared LATER in the class,
  was the declaration of a function `g` taking an unnamed parameter of the type `mu`, and the build stopped at `not
  lowered yet: typedef(mu)`. `mutexmember.cpp`.
- A name declared as a variable in an OPEN frame is no type name there ([basic.scope.hiding]; `ccl_local_variable/1`
  in the first `ccl_typedef_name` clause): a program's `const char *path` hides the filesystem's `path` that `<fstream>`
  brings, and `std::ofstream out(path);` is the variable's initializer, not a function declaration of a parameter of
  type `path`. Reader 112. (0.117)
- `(T())` and `(T(n))` are PARENTHESIZED FUNCTIONAL CASTS, never a cast to the function type `T ()` (`ccl_cast_expr`
  refuses a type of the shape `fn(_, _, _)`) and never a type-id with a named declarator: a type-id's declarator is
  ABSTRACT (`ccl_type_name//2` demands `N == anon`), so `(std::vector<int>(n))` is the temporary and
  `(std::vector<int>)(n)` the cast. Else the cast took the call for a type, found no operand after `)` and stopped the
  read: libc++ 18's `<thread>` writes `thread() : __t_((__libcpp_thread_t())) {}`, and the idiom `std::vector<int>
  r((std::istream_iterator<int>(in)), std::istream_iterator<int>())` is the vexing parse's own cure. Reader 114.
  `parencast.cpp`. (0.117)
- The compiler's traits are two FIXED lists: `ccl_builtin_type_name/1` gives `builtin_type(N, Args)`, and
  `ccl_builtin_trait/1` gives `call(id(N), [type(T) ...])`. Why fixed: libc++ has functions of the same spelling
  (`__is_overaligned_for_new(__align)`). (0.44, 0.45)
- `operator T()` is `method(L, Qs, T, operator(conv(T)), [], false, Body)`. `ccl_conv_type` reads specifiers and
  pointers only, since `int ()` would read as a function type. (0.44)

### Templates, packs and constraints

- In `template(L, TParams, Item)`, the type, pack and template parameters are type names for the whole item:
  `ccl_tparam` adds each to the global env, `ccl_tparams_enter/3` and `ccl_tparams_leave/1` wrap the item, and the leave
  removes them. `'$ccl_tmpl_depth'` and `ccl_note_if_template` make the item's own name a template in its body. (0.44)
- Parameters are `tparam(type | pack | template, N, Default)`, `tparam(vpack(T), N, none)` and, for a value,
  `tparam(T, N, Default)`. An unnamed one is `anon`. `typename T::x = 0` is a value (`ccl_tparam_end`). `template <int
  &...>` and `template <class...> class F = X` are read. (0.44)
- A VALUE template parameter's name hides a typedef or a template of that name for its item (`'$ccl_vparams'` frames
  pushed by `ccl_tparams_enter/3`, popped by `ccl_tparams_leave/1`; `'$ccl_vhead'` for the names of the head being read;
  `ccl_value_param/1` asked by `ccl_local_variable/1` and `ccl_known_template/1`). Why: the class-scope typedefs of
  every class read before stay in the env, an out-of-class member's body needs them; a `typedef int _Size;` in one of
  libc++'s classes made `bitset<_Size>` of `template <size_t _Size>` a TYPE argument, so no out-of-class member of
  `std::bitset` matched `bitset<16>` and its `set`, `flip`, `count` and `test` stayed declarations; `template <size_t
  __count, __enable_if_t< __count < _Dt, int> = 0>` of `<random>` read `__count <` as the algorithm's template-id.
  `valueparam.cpp`. (0.117)
- A template template parameter's name is a template inside its item only (`ccl_note_tt_param`, un-noted per item frame
  by `ccl_tparams_leave`). `ccl_skip_to_close` counts nested `<>` in its list. Why: `<variant>`'s `template <_Trait X,
  ...>` read as a constrained parameter. (0.45, 0.93)
- Packs and folds: `param(pack(T), N)`; `pack(X)` for an expansion in a template argument, a call argument, a base, an
  initializer item or a constructor initializer; `sizeof_pack(N)`; `fold(Op, dots, E)`, `fold(Op, E, dots)`,
  `fold(Op, A, dots, B)`. C++26's pack index is `pack_index(N, I)` as a type and `pack_index(A, I)` as an
  expression. (0.44, 0.93)
- A specialization `struct X<Args>` is `class(K, tmpl(X, Args), Bases, Members)` (`ccl_class_targs`). The noters skip a
  tag whose name is compound. (0.44)
- C++20: a concept is `concept(L, N, E)`, its name a template. A requires-clause on a head is `requires(E)` among the
  parameters (`ccl_add_requires`). A requires-expression is `requires_expr(Ps, Reqs)` of `type(T)`, `compound(E, C)`,
  `nested(E)` and `expr(E)`. (0.42)
- A constraint is primaries joined by `&&` and `||` (`ccl_constraint`; [temp.pre]), never a full expression. Why: a full
  expression took the `[[nodiscard]]` after a concept-id for a subscript. (0.84)
- A constrained type parameter (`template <C T>`, `C<A> T`, `ns::C T`; `ccl_tparam_c`) is a type parameter plus its
  concept-id as a `requires` entry. `ccl_gather_requires` conjoins the entries into ONE, last. A tag or a typedef is no
  concept (`ccl_concept_name`). (0.84, 0.93)
- A constrained `auto` keeps its concept as the qualifier `constrained(C, As)` (`ccl_specs`). The desugaring checks it
  where it deduces (`cpp_constrained_ok`). (0.93)
- A requires-clause on a member template's head and a trailing one (`requires(R)` in `ccl_method_quals`) are kept. On a
  lambda it is read and dropped. (0.84)

### Classes

- A class's name joins the global env at its declaration (`ccl_add_env/1`). Its body parses with the name on
  `'$ccl_class'` (`ccl_class_push`), so a constructor is known by it (`ccl_current_class`, through `ccl_class_bare`).
  (M5, 0.71)
- A class body is a complete-class context ([class.mem]/6). Before the members, `ccl_member_templates_ahead`
  (`ccl_scan_mts`, `ccl_scan_did`, `ccl_note_mt`) notes at the body's depth:
  - a member FUNCTION template (the declarator-id before `(`) as a template and a function template; a constructor or
    destructor template (the class's own name) as a template only, else `pair<...>` was no type;
  - a member CLASS template (a name after `struct`, `class` or `union`, with no `::` after it);
  - a member ALIAS template, and a class-scope alias, `using N =` or `typedef ... N;` (the name before `;`).

  Why: libc++ uses `__rehash<true>(__n)` and `_Context{...}` before it declares them. `test/cpp/run/aliasahead.cpp`.
  (0.81, 0.92, 0.99, 0.109)
- A class head's first name is the class's own only where no `::` follows it (`ccl_struct_body`). Why:
  `friend struct std::__segmented_iterator_traits;` made `std` a type name for the rest of `<ranges>`. (0.109)
- The members are `access(A)`, `method(L, Qs, Ret, Name, Params, Variadic, Body)`, `ctor(L, Qs, Params, Inits, Body)`,
  `dtor(L, Qs, Body)`, `member(T, N, Width)`, `template(L, TParams, M)` and `static_assert(L, E, Msg)`. A method's body
  is `pure`, `default` or `delete` for `= 0`, `= default` or `= delete` (`ccl_fn_body`). A class-scope
  `typedef` or `using x = T` is `typedef(L, Vars)`, and its name joins the global env, and so is `using typename
  Base<T>::name;` (a type brought from a base: the typedef `name` of `typename Base<T>::name`; libc++ 18's <charconv>
  `__traits` writes `using typename __traits_base<_Tp>::type;` and its members take `type &`; reader 114, 0.117). A
  struct declared inside is
  `nested(Base)`. A friend is `friend(L, Ms)`, `friend(L, [friend_class(Q)])` for `friend class X;`, `friend struct X;`
  and `friend X;` (a qualified name or a template-id too; kept since 0.117 for the access control) or `friend(L, [])`
  for `friend Ts...;`. The `friend_class(Q)` clause stands BEFORE the clause that reads a friend declaration as a
  member: after it, `friend class X;` was `nested(class(X, none))`, and no friend was noted.
  `using Base::Base;` is `using(L, name(Q))`. (0.44, 0.79, 0.93)
- A nested class defined out of its holder is `class(K, scoped(Path, N), Bases, Members)`, template arguments first:
  `class locale::facet`, `basic_ostream<_CharT, _Traits>::sentry` (`ccl_class_qual`, `ccl_class_qname`). (0.71, 0.72)
- An out-of-class constructor or destructor is `ctor_def` or `dtor_def` (`ccl_class_base/2`). A nested class's keeps
  its enclosing path: `ctor_def(L, scoped([tmpl(basic_ostream, ...)], sentry), ...)`. Its qualifiers hold the prefix's
  `inline`, `constexpr`, `consteval` and the hidden mark (`ccl_prefix_quals/2`, as a method's storage words did since
  0.79 and 0.112). Why: libc++ 18's `inline basic_ofstream<...>::basic_ofstream(const char *, ...)` is hidden from the
  ABI and defined in no library, and without the mark it looked shipped. Reader 112. (0.44, 0.73, 0.117)
- A member defined out of its class keeps `inline` among its storage words, and a trailing `const` as `const(Sto)`
  (`ccl_sto_quals`), which `cpp_sto_quals` reads. Why: `inline` marks a member libc++ hides from its ABI, and without
  `const` the const overload's body joined the other. (0.75, 0.79)
- A base is `base(Access, Q)`. `virtual`, on either side of the access word, makes `base(virtual(Access), Q)`
  (`ccl_bases`). (0.71, 0.72)
- `using Bs::operator()...;` in a class is `using(L, pack(Q))`, the pack form of a using-declaration (reader 115;
  `ccl_member_decl`, ahead of the clause that skips every other `using` to its `;`). A base clause that is a bare
  pack, `struct overloaded : Ts... {`, stays `base(Access, pack(Ts))`, the pack's name an atom. Reader check `c43`
  over `overloaded.cpp`. Why: C++17's `overloaded` idiom, and libc++ 18's `__all_overloads` of `std::variant`, which
  is written the same way. (0.121)
- After the parameters, `ccl_method_quals` keeps `const`, `refq(lvalue | rvalue)` ([dcl.fct]/6), `override`, `final`,
  `noexcept` and `requires(R)`, and `-> T` as `trailing(T)` with the result `auto`. (0.82, 0.93, 0.110)
- `explicit(cond)` is `explicit(E)`, never evaluated. `final`, `trivially_relocatable_if_eligible` and
  `replaceable_if_eligible` after a class's name are dropped (`ccl_class_head_words`). (0.84, 0.93)
- An enum's members start with `enum_base(T)` (`ccl_enum_base//1`, `ccl_enum_members/3`). A scoped enum without a
  written base gets `int` (`ccl_scoped_base/2`); an unscoped one gets only a written base. The mark tells
  `enum class __element_count : size_t { }` from an empty struct. An enumerator may carry attributes.
  `test/cpp/run/strongenum.cpp`. (0.55, 0.71)

### Attributes and qualifiers

- Attributes are read anywhere and dropped (`ccl_attrs`, `ccl_gnu_attr`, `ccl_skip_attr`), except four:
  - `alignas` on an object: the qualifier `aligned(E)` (C++'s, C23's `alignas`, C11's `_Alignas`);
  - `alignas` on a class, struct or union: `align_as(E)` at the END of the members (`ccl_attrs_align`,
    `ccl_align_members`), since the head holds `union_tag` and `enum_base`;
  - `[[no_unique_address]]` on a member;
  - `[[assume(e)]];`: the statement `assume(L, E)`.

  (0.89, 0.93, 0.99)
- `alignas(T)` is `alignof_type(T)` (`ccl_align_arg`: the type is tried once, only before `)`). (0.89)
- `[[no_unique_address]]` and `__no_unique_address__` (`ccl_nua_word`) set `'$ccl_nua'`, and `ccl_take_nua` takes it in
  `ccl_member_decl`. `ccl_members` clears it once per member, never the declarator, which drops an attribute and
  recurses. The mark rides in the bit-width slot. (0.89)
- C++ `constexpr` is `const` plus the marker `constexpr` (`ccl_specs`, before the qualifier clause).
  `ccl_constexpr_fold` in `ccl_mk_type`, every declarator's door, drops the marker; on a FUNCTION it drops the result's
  `const` too ([dcl.constexpr]). Why: libc++'s `constexpr ... &get(tuple &)` returned `const T &`, and `tuple_cat`
  refused. `test/cpp/run/constexprfn2.cpp`. (0.79, 0.95)
- `noexcept` is kept. `ccl_suffix_quals`, the one rule for `noexcept` and `throw(...)`, sets `'$ccl_nx'` per function
  suffix: yes for `noexcept`, `noexcept(e)` with any `e` but the literal `false`, and `throw()`; no for `throw(X)`
  (`ccl_nx_arg`). A free function's name joins `'$ccl_nothrow'` (`ccl_note_nx`, `ccl_nothrow/1`). A method keeps
  `noexcept` among its qualifiers. (0.110)
- A pointer to member is its own node ([dcl.mptr]): `memptr(C, Qs)` in the pointer list (`ccl_pointers`), and
  `memptr(C, Q, T)` once applied (`ccl_apply_pointers`). (0.86)
- Only a declarator that holds a pointer to member takes cv-, ref- and noexcept-qualifiers after its parameters
  ([dcl.fct]/1; `ccl_memptr_quals` -> `ccl_mptr_quals` -> `ccl_suffix_quals`), as `<functional>`'s `__strip_signature`
  writes. A method's `const` stays `ccl_method_quals`'s. Why: else every const method lost its mark, and a shipped
  symbol its `K`. (0.86, 0.88)

### Declarations, namespaces and modules

- `extern "C"` keeps its block, `extern_c(L, Items)` (`ccl_linkage_block`). `extern "C++"` is transparent: its items are
  spliced where it stood (`ccl_spliced` -> `'$splice'`). Why: as one item, libc++'s `<math.h>` put `namespace std` under
  the C marker. (0.71)
- A namespace is `namespace(L, N | inline(N), Items)`. `namespace A::B { }` and `namespace A::inline B { }` nest
  (`ccl_ns_segs//1`, `ccl_ns_nest/4`). A namespace alias is `using(L, namespace_alias(N, Q))`, which does nothing, since
  namespaces flatten. (0.100, 0.109)
- `using enum E` is `using(L, enum(Q))`; `using namespace N`, `using(L, namespace(Q))`; `using N::f;`,
  `using(L, name(Q))`. `using T = type;` is a `typedef` at file scope, in a class, in a block and in an init-statement.
  (0.42, 0.43, 0.79)
- `extern template ...;` is `extern_template(L, I)`, and `template class X<char>;` is `explicit_instantiation(L, I)`. A
  deduction guide is `deduction_guide(L, N, Ps, T)`, indexed as `$guide.<class>`, which class template argument
  deduction reads first. A function may end `= delete`, `= default` or `= delete("why")` (`ccl_var_init_fn`;
  `ccl_delete_reason` drops the reason). (0.44, 0.93, 0.108)
- A free function's trailing return type replaces its `auto` result (`ccl_trailing_ret`, `ccl_fn_quals`): always on a
  prototype, and on a definition unless it names `auto` (`decltype(auto)`, deduced from the first return;
  `ccl_mentions_auto/1`). A `decltype` over the parameters is the result of a definition too (0.127): the desugaring
  resolves it with the parameters declared (`cpp_decltype_ret/3`, at the item and at an instance's emission), and its
  SFINAE holds. A member keeps `trailing(T)`, which `cpp_trailing_rets` makes the result. `test/cpp/run/trailing.cpp`,
  `trailret.cpp`. Why (0.127): the definition's result was the first return's type DECAYED -- `auto first(V &v) ->
  decltype(v[0])` returned an `int` and `first(v) = 10` wrote into a temporary -- and `template <class T> auto call(const
  T &t, int) -> decltype(t.foo())` stayed a candidate for an `int`. (0.93, 0.110, 0.127)
- C++26 contracts go into the body at the read (`ccl_contracts_apart`, `ccl_contract_body`). `pre(e)` becomes
  `if (!e) contract_violation(pre, F, L)` at the start; `post(r: e)` becomes the same `post` check at every return, a
  named result a `$post` local. `contract_assert(e);` is `if (!e) contract_violation(assert, none, L)`. (0.108)
- C++20 modules: `module;` and `module :private;` are nothing. `export module M;` (dotted, or a partition `M:P`) is
  noted (`ccl_note_module`). `export` before an item or a braced group notes its names (`ccl_note_export`). `import
  <h>;` and `import "h";` are includes; `import M;` reads M's interface unit (`ccl_import`), else refuses
  `module_not_found(N)`. (0.108, 0.110)

### Expressions and statements

- Nodes: `ref(Q, T)`, `rref(Q, T)`, `ccast(K, T, E)`, `scoped(Path, N)`, `noexcept_expr(E)`, `alignof_type(T)` (also for
  `__alignof` and `__alignof__`), `typeid(X)` and `throw(E)`. `typename X::y()` is `construct(T, As)`. `void()`,
  `int{}`, `::new`, `::operator new`, `p.operator->()` and `operator""sv` are read. (0.32, 0.44, 0.86, 0.88)
- A USER-DEFINED LITERAL ([lex.ext]; C++ only) is `udl(Suffix, Literal)`: a literal followed by an identifier, `5_km`,
  `1500ms`, `"text"s`, `'a'_up` (`ccl_udl//2` after `ccl_primary_`, over `ccl_udl_base/1`: the integer, floating, string
  and character kinds). No valid program has a literal and an identifier side by side, and the tokens carry no column,
  so `5 _km` reads alike and the lexers stay as they were; the imaginary mark `i` after a number stays GNU's. The
  function is `operator(literal(Sfx))`, read after `operator ""` (`ccl_op_name`), the suffix an identifier or a keyword
  (`operator"" if` of `<complex>`). The preprocessor keeps the number and its suffix as two tokens (`pp_norm_toks/2`):
  `5_km` was a pp-number the lexer cut in two, and `pp_norm` turned a result that was not one token into zero. Reader
  check `c40`, `test/cpp/run/userliteral.cpp`. (0.117)
- A CONVERSION FUNCTION DEFINED OUT OF ITS CLASS (`S::operator int() const { ... }`, `X<E>::operator T() const { ... }`)
  is a `function` named `scoped(Path, operator(conv(T)))` with T as its result (the declaration-specifiers took the
  class's name for a result type); a conversion function's name holds a type (`ccl_conv_type`: specifiers and pointers
  only, since `int ()` is a function type). Reader check `c41`, `convout.cpp`. (0.117)
- `x.~T()` is `call(member(x, dtor(T)), [])`, and `p->~T()` is `call(arrow(p, dtor(T)), [])`. Template arguments after
  `T` are dropped (`ccl_dtor_targs`). (0.40, 0.93)
- `x.*pm` and `p->*pm` ([expr.mptr.oper]) are `memptr_get/2` and `memptr_arrow/2`, read from `.`, `->` and `*`. Neither
  lexer changes, so `k84` holds. (0.88)
- `new T(...)` and `new T{...}` are `new(T, As)`; `new T[n]` is `new_array(T, N)`; `new T[n](...)` and `new T[n]{...}`
  are `new_array_init(T, N, Items)`. Placement arguments are kept, `new_at(Ps, New)` (`ccl_new_node/3`). `new T` and `new
  (p) T` with no initializer are `new_default(T)`, default-initialization, apart from `new T()` and `new T{}`, `new(T,
  [])`, value-initialization (reader 122; the Constructors topic says what each does). (0.61, 0.71, 0.86, 0.127)
- A braced list stands as an argument (`ccl_args`), an assignment's right side ([expr.ass]/9; `ccl_assign_right`), a
  default argument (`ccl_param_default`), a subscript `a[{1, 2}]`, a designator's value `.b{2}` (`ccl_init_item`) and
  `return {a, b}`. (0.79, 0.84, 0.88, 0.93)
- `T{args}` after a type's name, a template-id or a qualified name is `braced_temp(call(T, Values))`, the call a
  temporary is made from, marked as braced (the EMPTY list stays `call(T, [])`, value-initialization): a class with an
  `initializer_list` constructor takes the list through it first (the Aggregates section). `ccl_type_of/2` types it as
  the call. A DESIGNATED list, `T{.a = 1, .b{2}}`, is `compound_lit(base([], [typedef(T)]), init(Items))` with its
  designators, which only an aggregate takes ([dcl.init.aggr]/3.1; `ccl_braced_temp`). `desiganon.cpp`. Else the
  designators were dropped: libc++'s `__parsed_specifications{.__std_ = ...}` (`std::format`) stored its first item into
  the anonymous union whole. (0.112, 0.117)
- A lambda is `lambda(Caps, Params, Ret | none, Body)`. Its captures (`ccl_lambda_cap`) are `cap(val, N)`,
  `cap(ref, N)`, `cap(default, '=' | '&')`, `cap(this)`, `cap(star_this)`, `cap(pack, N)`, `cap(init, N, E)` for
  `[n = e]` and `cap(init_ref, N, E)` for `[&n = e]`. `ccl_lambda_specs/1` keeps `mutable` among the captures (the
  desugaring reads it, 0.117) and drops `constexpr`, `consteval`, `static`, `noexcept(...)` and attributes, with or
  without a parameter list. (0.36, 0.43, 0.99, 0.112, 0.117)
- `if (T x = e)` and `while (T x = e)` are `block([Decl, if | while])` (`ccl_cond_decl`). `for (decl : range)` is
  `for_each(L, Decl, Range, S)`. `if constexpr` is `if_constexpr(L, C, T, E)`. (0.36, 0.42, 0.44)
- The range of a range-for may be a braced list ([stmt.ranged]; `ccl_range_expr//1`, `ccl_range_stmt/5`):
  `for (int v : {4, 9, 1, 7})`. The list is the backing array of the `initializer_list` it would make, a local array
  of the first item's type (decayed, unqualified as `:=` has it) in a block of its own, iterated as any array is. An
  untypable first item keeps the braced range, which the desugaring refuses by name. `test/cpp/run/rangeforbraced.cpp`
  (C++20), reader check `c39`. Why: a syntax error stopped the read of a program's `for (auto s : {"a", "b"})`.
  (0.117)
- An init-statement makes a block of the initializer and the statement: `if (init; c)`, `switch (init; e)`,
  `for (init; x : xs)` and `if constexpr (init; c)` ([stmt.if]; `ccl_init_stmt`, `ccl_init_stmt_items`). Why: libc++'s
  `if constexpr (using _SpecialAlg = ...; ...)` stopped the read of `<algorithm>`. (0.43, 0.91)
- An attribute before a statement is dropped, except `[[assume(e)]];`. A label's body may be a declaration
  (`ccl_label_body`). (0.42, 0.91)

### `auto` and structured bindings

- `ccl_auto_decl` deduces `auto` only from a settled type. It leaves `auto` to `cpp_decl_pieces` where the type is
  dependent (`ccl_dependent_type/1`: a `scoped/2`, `pack/1`, `pack_index/2` or free name), or where the initializer
  calls a function template's name (`ccl_auto_by_overload/1`). Why: the table holds a function template under its raw
  signature, so a deduction keyed an instance by free names. `test/cpp/run/autodep.cpp`. (0.49, 0.91)
- `ccl_free_name/1`: inside a template, any name the tables lack is a parameter's. Outside one, so is a name unknown as
  a typedef, a tag, a template or an env entry. The two branches stay apart, since a template's parameters are in the
  env during its item. Why: `auto q = std::make_unique<int>(7)` took `unique_ptr<_Tp>`. (0.60, 0.86)
- A structured binding is destructured at the read where its right side's type is settled (`ccl_bindings_decl` ->
  `ccl_destructure`, `ccl_bind_refs` for `auto &`). Else it is `bindings(L, Ref, Ns, E)`, its names declared `auto`
  (`ccl_bind_names`, `ccl_declare_autos`), also as a range-for's declaration (`ccl_range_decl`). Why: libc++'s
  `auto [__parent, __child] = __find_equal(__key)`. (0.44, 0.79)
- C++26's `if (auto [a, b] = e)` (`ccl_bind_cond`): a temporary `bindif…` holds `e`, `bindings(L, yes, Ns, id(Tmp))`
  binds into it, and the test is the temporary's. In an init-statement, the bindings clause of `ccl_for_init` comes
  FIRST, else `auto [c2]` read as an array. (0.93)

### Forms by level

- C++20: `co_return(L, E | none)` is a statement; `co_await(E)` and `co_yield(E)` are unary. `auto` is a type in a
  declaration (`auto f(auto x)`). A template lambda has `tparams(Ps)` first among its captures. (0.42)
- C++23: `if consteval` and `if ! consteval` are `if_consteval(L, no | yes, T, E)`. `this Self &self` is
  `param(this(T), N)` first (`ccl_param`; `ccl_declare_params` strips the mark). `a[i, j]` is `index(A, args(Is))`.
  `auto(x)` and `auto{x}` are `decay_copy(E)`. A label may end a block (`label(L, N, empty)`). (0.43)
- C++26: a second `_` in a block is renamed `_$k`, and the first keeps the name (`ccl_placeholder`). (0.93)

### What the reader drops

- The reader keeps each C++ form it reads, except the forms the bullets above name as dropped. The passes refuse by name
  what they cannot take (`not_lowered(F)`); they never drop a form. (0.32)

## Includes, summaries and the store

### Reading an include

- An `#include` is read where the parser meets it (`ccl_external` on its `tok(pp, ...)`). The item calls
  `ccl_include/2`, then `ccl_include_typedefs/3` (names into the includer's Env), `ccl_include_macros/1` and
  `ccl_include_scope/1` (`ccl_unit_note`). (M1)
- The node is `include(L, Spec, R)`. `Spec` is `system(N)`, `local(N)`, `next(Spec)`, or `path(P)` for a module's
  interface. `R` is `file(Path, raw | preprocessed | unreadable | summary, Unit)`, `macros(Path, Preds)`, `missing` or
  `cyclic(Path)`. `Unit` is `unit(Is)`, `partial(unit(Is), line(L), near(F))`, `summary(F)` or `none`. (M1, 0.45, 0.108)
- `ccl_include_read/2` tries the cycle guard (the global `'$ccl_reading'`, `ccl_reading/1`), the process cache
  (`ccl_unit_cached`), the store (`ccl_kb_cached/3`), then `ccl_read_unit/3`. It stores a read unless it is
  `unreadable`, a summary, or a C++ header read preprocessed. (M4)
- The process cache keys a unit by its path AND its level (`ccl_unit_key`: `'$ccl_unit:<Path>@<Level>'`, `t` appended
  in a trigraph mode), listed in `'$ccl_unit_paths'`. Why: `<stddef.h>` differs at C23, and one gate process builds
  both levels. (0.99, 0.108)
- A plain header is read raw first (`ccl_parse_file`). Only if raw stops does `ccl_pp_parse/4` preprocess THAT file; its
  macros are then remembered (`ccl_kb_remember_macros/3`). A lexical error makes the include `unreadable`. (M1, M5)
- A C++ library header (kind `system`, `next` included; `'$ccl_inc_kind'`) is never read raw. A valid summary serves it;
  else it is flattened and read once (`ccl_read_unit`). Why: raw, each of `<sstream>`'s headers failed and was
  preprocessed in turn. (M5)
- The flatten runs inside `ccl_lib_unit/1`, which sets `'$ccl_lib_unit'` (restored on success, failure and a throw), so
  `ccl_unit` registers no standard macro (`format`, `print`, `println`, `clone`). Why: libc++'s `<format>` calls its own
  `format(c, ctx)`. (0.99)
- A partial read is silent: `ccl_partial` gives `partial(U, line(L), near(F))`, and a library header's summary and AST
  hold what was read. `test/census.sh` on the flattened header (`cicilang++ -E`) names the stop. (0.44)
- `ccl_with_file/2` saves and restores around a nested read, on success, failure and a throw: `'$ccl_file'`,
  `'$ccl_env'`, `'$ccl_far'`, `'$ccl_macros'`, the tables (`'$ccl_scope'`, `'$ccl_gscope'`, `'$ccl_typedefs'`,
  `'$ccl_tags'`; the last three bucket by bucket, `ccl_tab_save/2` and `ccl_tab_restore/2`), `'$ccl_enums'` and
  `'$ccl_expansions'`. `ccl_tables_changed` follows the restore. (M1b, 0.120)
- A `.pl` include is a macro file (owner's rule): `ccl_load_macros/2` loads it, and the node is
  `macros(Path, [macro(CName, Pred, Arity | dcg) ...])`. (M1b)
- The program's own C++ header read whole gives its classes and templates to every includer (`cpp_register_header/1`),
  emitted `linkonce` (`cpp_linkonce/2`), so two units link (`test/cpp/run/bag.cpp`, `bag.h`). Its inline functions are
  emitted with the program, by `#include` and by `import` (`cpp_include_fns`, `cpp_header_fns`), unless it lies under
  `/usr/`, `/opt/`, `/Library/` or `/Applications/` (`cpp_system_path`). `test/cpp/run/hdrinline.cpp`. (0.41, 0.110)

### Resolution and the inclusion path

- `ccl_resolve_include/3` looks for a quoted name in the includer's directory first. Then it searches
  `ccl_include_path/1`: the `ccl_include_dir/1` facts (`-I`) and `$CICILANG_INCLUDE`; the `$COCOLOG_LIBRARY` directories
  (the shipped macro files); `ccl_toolchain_dirs/1`. `'$ccl_incpath'` caches it, and `ccl_include_path_reset/0`
  forgets it. (M1, M5)
- `ccl_toolchain_dirs/1` runs no tool (owner's rule: the embedded LLVM is the whole toolchain). It gives: in C++, ONE
  libc++ tree; each library directory's `include` (`library/include`); `/usr/local/include`; `/opt/homebrew/include`;
  the SDK directories (`ccl_sdk_dirs`: `$SDKROOT`, the Command Line Tools' and Xcode's SDKs, `/usr/include/<triplet>`,
  `/usr/include`). `ccl_existing_dirs` keeps the ones that exist. (M5, 0.87, 0.93)
- The libc++ tree is the first found (`ccl_cxx_dirs`): `$LLVM`, Homebrew's two, then Debian's `/usr/lib/llvm-NN` newest
  first (`ccl_debian_llvm_roots`), each with `/include/c++/v1`, then the SDK's. Why: two trees mix their wrappers (the
  SDK's `ctype.h` under LLVM's `cctype` trips an `#error`), and without Debian's roots `<cstdio>` flattened to nothing.
  (M5, 0.93)
- The multiarch directories (`ccl_multiarch_dirs`) precede `/usr/include`, as clang has them. Why: glibc's `bits/` and
  `sys/cdefs.h` live there, and without them `__THROW` and `__wur` stayed unexpanded. (0.87)
- `#include_next` searches past the directory the includer was found in (`ccl_resolve_include(next(_), ...)`,
  `ccl_dirs_after`). (M5)

### The C++ summary cache

- A flattened library header is summarized to `~/.cicilang/cpp/<base>-<f1>-<f2>.sum` (`ccl_sum_file/2`: two folds of
  `Path@Std`), one per C++ level, with its `.ast.pl` and `.mac` beside it. `cicilang++` runs `--no-kb`, so these files
  are the C++ cache. (M5, 0.42)
- A summary is one term per line (`ccl_sum_write/4`, `ccl_sum_chunks`): `sum(Path, key(V, cpp(Std)))`, a
  `dep(File, Time)` per file the preprocessor pulled, then `decl/2`, `typedef/2`, `tag/2` (bodies dropped,
  `ccl_sum_slim/2`), `enum/2`, `tname/1`, `template/1` and `ftemplate/1`. (M5, 0.45)
- `ccl_sum_valid/1` holds when the `.sum` and its `.ast.pl` exist, the version is `ccl_reader_version/1`, the level is
  `ccl_std/1`, and every dep's time is unchanged. Then the node is `file(Path, summary, summary(F))`. A hollow summary
  is read again. (0.106)
- Every consumer reads a summary where it would walk a unit: `ccl_include_typedefs`, `ccl_sum_note/1`,
  `ccl_collect_unit` and `dr_unit_deps`. Its terms are parsed once per process (`ccl_sum_terms/2`) and split once
  (`ccl_sum_load/7`). (M5)
- `ccl_sum_lines/2` parses a line with `term_to_atom/2` into a FRESH variable, since a bound term is compared, not
  unified. (M5)
- A term whose text passes 8000 characters goes to `<name>-<fold>.big.pl` beside the summary as
  `'$ccl_sum_big'(F, I, T)`, and its line is `big(I)` (`ccl_sum_line/3`); the reader consults that file and puts each
  term back in its place (`ccl_sum_bigs_in/3`), and a `big(I)` left with no clause makes the summary invalid. Why:
  cocolog's `term_to_atom/2` reads through an 8 KB buffer, and twelve `tag(...)` lines of `<vector>`'s summary
  (`basic_string` 56 KB, `tuple`, `vector`, `pair`) were dropped silently, so a summary-served run's tag table lacked
  them. (0.112)
- The `.mac` holds `mnames([...])` lines of at most 100 names, then one `macro(N, Ps, text(A))` line per macro as
  written. The lines become `'$ccl_hml'(Name, Path, raw(Line))` facts, parsed on first use (`pp_raw_macro/4`). (M5)
- The write order is fixed (`ccl_read_unit`): `ccl_sum_dir_ready` (`mkdir -p`); the AST (`ccl_ast_write`); only then the
  `.mac`, the `.big.pl` and, LAST, the `.sum`. `ccl_write_whole/2` writes a temporary name and renames it. A failed AST
  write is traced (`ast_not_written(Path)`) and leaves no summary. Why: the `.sum` is the validity key, and a valid one
  with no AST refused `template_without_body`. (0.100, 0.106)

### The AST beside the summary and the header index

- `ccl_ast_write` writes `'$cpp_hdr_ast'(Key, Item)` and `'$cpp_hdr_ast_ns'(Key, Path)` for each item that
  `cpp_index_name/2` names (`ccl_ast_lines`), a hundred items at a time inside `\+ \+` (`ccl_ast_chunks`). (0.45, 0.71)
- A flattened read is indexed into `'$cpp_hdr'(Name, Item)` facts (`cpp_index_header/1`). A summary-served one consults
  the `.ast.pl` (`cpp_load_ast/1`; `ensure_loaded/1` has no line limit). `cpp_hdr_item/2` answers from both, so a warm
  run needs no flatten. `cpp_hdr_load/1` registers a name's items on its first ask. (0.45, 0.78)
- `ccl_flat_items/3` gives `in(Path, Item)`. `extern "C"` items, and a namespace inside such a block, stand under `c`.
  An inline namespace's segment is `inline(N)`. `std::rel_ops` is not indexed: its names come only by a using-directive.
  An item declared by a namespace-qualified name stands in that namespace (`ccl_flat_quals`).
  `test/cpp/run/qualspec.cpp`. (0.61, 0.100, 0.112)
- `cpp_index_name/2` keys: a class or struct DEFINITION; a function, defined or declared (a function with NO parameter
  DELETED where it is declared is a declaration of its name too -- a poison pill: libc++ 21 writes `void iter_move() =
  delete;` where libc++ 18 wrote `void iter_move();`, and unindexed it made no namespace collision with the object
  `ranges::iter_move`, so the unqualified call in `__unqualified_iter_move` went to the OBJECT, whose `operator()` asks the
  same concept -- an endless recursion at the first `std::reverse_iterator` of C++20 and in every `std::print`;
  `reverseiter.cpp`, reader 120, 0.126); a template by
  `cpp_template_name/2` (a free operator template as `op.W.N`, a guide as `$guide.<class>`, a concept, an alias or
  variable template); a specialization by its template (`cpp_spec_name`); an `extern` global; an inline variable; a
  member or static data member defined out of its class, by the CLASS; a nested class's out-of-class constructor or
  destructor, by the ENCLOSING class; an `extern template`, by the template. (0.67, 0.71, 0.101, 0.108)
- Each indexed name's namespace path is kept (`'$cpp_hdr_ns'`, `'$cpp_hdr_ast_ns'`; `cpp_hdr_ns/2` unwraps
  `inline(N)`). Why: a name the header only declares is called by its mangled symbol. (0.61, 0.100)
- Where two namespaces declare one flattened name, the outermost keeps it bare. A deeper namespace's items are keyed
  `<suffix>.<name>` (`cpp_ns_quals`, `cpp_index_key`) and renamed (`cpp_qualify_item`); their bare uses inside go to
  the key (`cpp_qualify_body`). The keying follows the header's own items, so the index and the AST agree. (0.88,
  0.100)
- The suffix is the SHORTEST suffix of the namespace's named path that no other path declaring the name ends with
  (`cpp_ns_unique_suffix/3`, every declaring path listed, the outermost as `bare`): the innermost namespace where it is
  unique, as it mostly is. A name qualified relative to the item's namespace is made absolute there by C++'s search
  from the innermost enclosing namespace out ([namespace.qual]; `cpp_qualify_paths/4`, `cpp_abs_ns_path/5`), and
  `cpp_ns_key/3` tries the path's suffixes longest first. Why: libc++ declares `ranges::__transform::__fn` (the
  algorithm) and `ranges::views::__transform::__fn` (the view), both keyed `__transform.__fn`, so `views::transform(f)`
  met the algorithm's `operator()` (`arity_mismatch`) and `views::reverse` the algorithm's class (`no_operator('|')`).
  `nscollide3.cpp`. Reader version 107. (0.112)
- A member defined out of its class with `__attribute__((__visibility__("hidden")))` keeps the mark as `hidden(Sto)` in
  its storage slot (`ccl_hidden_note`, `ccl_external_rest`; `cpp_sto_quals` reads it as the qualifier `hidden`).
  `'$ccl_hidden'` is set as the attribute goes past and cleared at each item's start; an attribute that BEGINS an item,
  right after a template head, is dropped by the rule that re-enters `ccl_external`, which carries the mark in
  (`'$ccl_hidden_lead'`; reader version 108, 0.113). Reader version 107. (0.112)
- A float literal past a double is the largest finite double (`ccl_finite_float/2`). Why: cocolog writes an infinity as
  `inf.0`, which its reader refuses, and the whole `.ast.pl` would not consult. (0.55)

### The C store, `~/.cicilang/KB`

- The store is the user's (owner's rule): `~/.cicilang/KB`, or `$CICILANG_KB`. The first call is the initialization
  phase; it reads the C library and the OS's headers. Later calls, in any project, are served. Only C runs over it
  (`bin/cicilang`, the reader, compile and driver gates); `cicilang++`, the C++ gate, the libc++ read and the census run
  `--local`. (M4, 0.105)
- A file read whole is `'$ccl_ast'(Path, key(MTime, V), meta(What, Count, Deps))` plus one clause per item in its own
  predicate, `'$ccl_items:<Path>'(Key, Index, Item)` (`ccl_kb_items/2`). Why one per file: a writing process grows the
  store by the written predicate's row count. An include is stored as `ref(Path, How)` and relinked through
  `ccl_include_read/2`. `ccl_kb_ready/0` declares `'$ccl_ast'/3` and `'$ccl_hmeta'/3`. (M4)
- `ccl_kb_key/2` gives `key(MTime, V)`: `V` is the reader version for C17, `c(V, CS)` for another C level,
  `c(V, CS, trigraphs)` in a trigraph mode, `cpp(V, Std)` in C++. `time_file/2` is asked at every key. (0.93, 0.108)
- `ccl_kb_cached/3` serves a unit on the same key, every dep at its key, and the item count matching. An item over the
  clause budget (`resource_error(clause_length)`) leaves the file uncached (`ccl_kb_remember/3`). The user's file is
  stored as `top` only when it reads whole. (M4)
- A header's macro table is stored per level: `'$ccl_hmacros:<Path>'(Name, Key, macro(...))` rows, `'$dep'` rows, and
  the index `'$ccl_hmeta'(Path, Key, meta(N, ND))`. `ccl_kb_remember_macros/3` replaces only that level's rows. The
  process memo is `'$ccl_hm:<Path>@<Level>'` (`ccl_hm_key`). Why: a C23 read retracted the C17 rows. (0.99, 0.108)
- Per-process state is a global, never a clause: the units read, the cycle guard, the macro files loaded. Why: a dynamic
  predicate persists under `--embed`. (M4)
- `kb_prepare` (`bin/cicilang`) and its twin `ccl_kb_prepare` (`test/config.sh`) stamp `KB.version` as
  `Reader.Lowering`. A new stamp deletes the store. A store that a killed writer damaged is a cache: remove
  `~/.cicilang/KB` and `KB.version`. (M4, 0.108)
- THE STORE IS VACUUMED (0.128): `kb_prepare` counts the runs in `KB.runs` (read and written by the shell, no fork) and
  runs `cocolog --embed KB vacuum` every 64th run; `ccl_kb_prepare` vacuums before each gate, so a gate's numbers
  measure the change and not the store's history. Why: a process that writes a predicate rewrites all of it, and the
  dead rows of every edited file's read and IR stayed on disk until a version moved. A vacuum of a 25 MB store takes
  0.4 s. A missing or damaged store is not vacuumed (`data.bin` is asked first). (0.128)

### The IR cache

- `dr_ir/3` keeps a built file's IR as `'$ccl_ir:<Path>'(Index, Chunk)` (3500 characters, under the clause budget when
  quoted), indexed by `'$ccl_irmeta'(Path, Signature, Count)`. (M4)
- The signature folds the file's key, every header, macro file and summary its AST reaches (`dr_unit_deps/2`),
  `ccl_lowering_version/1`, the arch and the debug option (`'$ccl_debug'`: an IR with line tables is another IR,
  0.128). `dr_fold/4` makes two folds under 2^31, since cocolog is inexact past 2^52. A match is served (`-v`: `served
  F from the store`); a refused file stores nothing. (M4, 0.128)

### The versions

- `ccl_reader_version/1` (`library/ccl_syntax.pl`, now 124): bump it for any grammar change to what a read gives, and
  for any change to what the AST beside a summary holds (item or member terms, `cpp_index_name/2`,
  `cpp_template_name/2`, `ccl_flat_items/3`, the namespace keys). Keep the reason in its comment. Why: the store and the
  summaries are keyed by it, and a stale read is served silently (`sizeof(std::string)` read 40). (M1, 0.89, 0.112,
  0.117)
- A reader bump makes every summary cold; `test/libcxx.sh` rewrites them. `test/reader.pl`'s `k16` (a cached read is
  the same AST as a fresh one) goes RED on a grammar change without a bump. (0.93, 0.105)
- `ccl_lowering_version/1` (`library/ccl_ir.pl`, now 70): bump it whenever the check or the lowering changes what it
  emits, however small -- 0.120 bumped it for the ORDER of the drain functions alone. Why: `dr_ir/3` serves the old IR
  otherwise. Either bump starts the C store afresh. (M4, 0.103, 0.120)

## Classes

Every C++ form is desugared by `library/ccl_cpp.pl` into the C that the check and the lowering already have; no form
gets lowering of its own, so the safe part reads C++ as it reads C. `ccl_ir_units` runs `ccl_cpp_units/2` in cpp mode
between the first symbol-table build and the check, then builds the table again; a failure names `phase(desugaring)`.
The program's own functions take dotted names, which LLVM takes unquoted and no C name collides with (`cpp_mangle/4`,
`cpp_mangle_q/5`). A method is `C.m.<keys>`, a constructor `C.C.<keys>`, the destructor `C.dtor.0`, a static `C.N`.
`<keys>` are the parameters' type keys (`cpp_params_key/2`, `0` for none), so each overload by type has its own name.
An operator takes its word (`cpp_op_word/2`): `C.op.plus_assign.<keys>` as a member, `op.<word>.<arity>.<keys>` when
free. A const method adds `.c`, a ref-qualified one `.r` or `.rr` after it: each is another function
([over.match.funcs]). A member that a library header declares and the shipped library defines keeps its Itanium symbol
(`cpp_shipped_member`). A fixture below is `test/cpp/run/NAME.cpp` unless a path is given. (0.33, 0.41, 0.79, 0.82)

### Registration and members

- `cpp_register_units/1` registers every class before any body is walked, after noting the free functions
  (`cpp_note_fns`) and the structs named as bases (`cpp_note_bases`). A class is the fact
  `'$cpp_cls'(C, cls(Base, Data, Ms, Statics, Defaults, Slots))` (`cpp_class_put`, which writes the light record
  `'$cpp_clsl'(C, cls(Base, Data, Statics, Defaults, Slots))` beside it: `cpp_class_l/2`, for a lookup that does not want the
  members, Time and memory). Its methods, constructors,
  destructor, statics and free operators are declared under their mangled names at once (`cpp_declare_members`,
  `cpp_declare_statics`), so a rewritten call has a type while the walk goes on. (0.33, 0.44, 0.120)
- `cpp_register_class` splits out the hidden friends (`cpp_split_friends`) and registers them after the class.
  `cpp_register_class__` adds the inherited constructors, normalizes the members (`cpp_norm_members`), records
  `C() = default`, notes the nested names (`cpp_nested_names/3`) and the extras, registers the class in its own words
  (`cpp_in_class`), and the nested classes last (`cpp_nested_classes/3`). The extras (`cpp_register_class_extras`) are
  the member templates (`'$cpp_mt'`), member class templates, typedefs (`'$cpp_ctype'`), static initializers
  (`'$cpp_sinit'`) and class enumerators. (0.48, 0.79)
- A class item becomes `declare(L, base(Q, [struct(C, Data)]))` and functions (`cpp_item`). `Data` starts with
  `'$base'` (none for an empty base, which has no sub-object), then `'$vptr'` where the class introduces a table, then
  the data members. The statics follow, then a function per method with `this` first (`const C *` for a const method,
  `cpp_this_type`), a void function per constructor, and the destructor. The struct is in the tag table from
  registration (`ccl_note_tag`), so the members have types while the methods are walked. (0.41, 0.89)
- A data member's type is resolved in the class's own typedefs at registration (`cpp_member_types`): `pointer
  __begin_` is `int *`, which a call deduces from. A type that does not resolve stays as written (trace
  `member_type_unresolved`). (0.45)
- A bitfield keeps its width, folded in the class's words (`cpp_split_members` -> `cpp_bit_width`). Why: without it
  libc++'s string is 40 bytes where the shipped library's is 24. (0.75)
- An anonymous struct's members are the holder's own (`cpp_norm_members_`), written `struct(anon, Ns)` or, with default
  member initializers, `class(struct, anon, _, Ns)`: libc++'s compressed pair, `__vector_layout`. An anonymous union
  becomes one member `$anonK`, its names reached through a hop (`cpp_data_member/3`). `anon.cpp`, `anoninit.cpp`.
  (0.45, 0.53)
- A plain struct whose member or array element is a class is PROMOTED to a class (`cpp_struct_promotes`,
  `cpp_elem_class`, `'$cpp_promoted'`), in the program's headers too (`cpp_register_header`). So is a plain struct named
  as a base (`'$cpp_base_named'`, collected by `cpp_note_bases` before registration). A struct of plain members stays
  C's, its member types resolved in place (`cpp_plain_members`). Why: `struct Rec { std::string name; }` needs a
  constructor, a destructor and a copy. (0.84, 0.89)
- A plain struct bound to a base-clause type parameter is promoted where the instance names it
  (`cpp_promote_plain_bases/1` in `cpp_instance_body`, before the instance registers): in `template <class B> struct D :
  B` over `struct P { int x; }` the base clause names the PARAMETER, `cpp_note_bases` (which runs before any instance
  exists) noted `B`, and `D<P>` refused `base_not_registered(P, D.P)`. The base is registered as the class it is (a
  plain struct has no method, no table and no constructor to emit, and its struct stood in the output already). (0.117)
- `cpp_base_name/2` names a base: a class's own name, else the type it resolves to. An alias of an instance names the
  INSTANCE (`true_type`), a name the tag table resolves to a struct names that struct, and an ALIAS OF A CLASS names the
  class (`cpp_alias_class/2`, also in `cpp_note_bases_` for the promotion of a plain struct): `using ZA = Z; struct Y :
  ZA` and `typedef Z ZT; struct X : ZT` were refused `base_not_registered('ZA', 'Y')`. Else it refuses `base_shape(T)`,
  `base_arguments(N)`, `base_instance(N)` or `base_not_a_class(B)`. `baseparam.cpp`. (0.71, 0.117)
- `cpp_abstract_class/1` is the one test for an abstract class: a slot that nothing implements, or whose implementation
  is the pure declaration (`cpp_slot_pure`). An abstract class registers; a complete object of it refuses
  `pure_virtual(C)` (`cpp_not_abstract`), while a base sub-object of it is built ([class.abstract]/6; `cpp_base_ctor`:
  `make_shared`'s `__shared_weak_count`). `__is_abstract` asks the same test (0.112). `test/cpp/abstract.cpp`
  (refused), `abstracttrait.cpp`. (0.99, 0.112)
- A class declared and not defined (`class bad_alloc;`) is not registered (`cpp_index_name`, `cpp_lazy_class`), since
  it would hide the definition. A constructor declared and not defined is a declaration (`cpp_member_fns`), as a method
  and a destructor are. (0.46)
- Out of its class, `Shape::scale` and `Counter::~Counter` (`dtor_def/4`) are the class's own functions (`cpp_item`);
  a method's `const` comes from the storage slot (`cpp_sto_quals`). (0.33, 0.79)
- A plain library class's member bodies written out of the class (`inline ios_base::fmtflags ios_base::flags() const`)
  are indexed by the class's name, noted before the header's batch registers (`cpp_note_hdr_mdefs`) and merged by
  `cpp_lazy_class` (`cpp_member_defs`). Why: unindexed, they took the mangled road to a symbol libc++ hides. (0.73)
- `cpp_class_of_type/2` tests a TYPE and never looks through a reference. `cpp_class_of_type_of/2`, the class of an
  EXPRESSION, looks through references and `move`. Why: else the value-category rules fire on reference returns. (0.51)
- `ccl_members_of/2` answers a raw `class(...)` spec's data members, statics excluded and pointer members kept. (0.41)
- A failed registration or emission refuses by name, never leaving a class half-registered: `class_not_registered`,
  `class_not_emitted`, `instance_not_emitted`, `base_not_registered`, `members_not_split`, `member_types`,
  `members_not_normalized`, `class_extras`. The traces `item_member_fns`, `method_body_failed`, `method_ret_failed`,
  `ctor_body_failed`, `ctor_walk_failed(C, Body)`, `instantiate_failed` and `want` show where. (0.46, 0.71)

- A plain struct with a STATIC data member is promoted to a class (`cpp_struct_promotes/2`): a C struct has none, and
  laid out as C's the static took bytes and `const bool Holder::flags[3] = {...}` found no class. `classforms.cpp`.
  (0.112)
- USING-DECLARED METHODS ([namespace.udecl]/16; 0.121): `using Base::f;` and `using Bs::operator()...;` bring the
  base's overloads of a name into the class's own set, and the call road took the first class or base that had a
  method that fits -- so `f(2.0)` went to an `f(int)` where another `f(double)` of the set is the exact match, and
  libc++ 18's `__all_overloads<__overload<int, 0>, __overload<double, 1>>` (`std::variant`'s converting constructor,
  C++17's `overloaded` idiom) chose by position. `cpp_inherit_methods/5`, beside `cpp_inherit_ctors` in
  `cpp_register_class__`, gives the class a FORWARDER for each method and method template of the named base: the same
  name, qualifiers (`const`, `noexcept`, a ref-qualifier, a trailing type; a closure's `operator()` is const unless it
  is `mutable`), parameters and result, with a body that calls the base's by its qualified name over the base
  sub-object (`this->Base::f(args)`, never virtual) and hands each argument on as it came (`cpp_fwd_arg`: a forwarding
  reference by the cast `std::forward` is, any other rvalue reference and a value by `move`, an lvalue reference as it
  is, a pack as an expansion). The overload rules then see one set. A virtual name (the call must stay virtual), a
  static, deleted, defaulted, constrained or explicit-object member and a conversion function are left to the old
  road; a member the class declares itself with the same parameter types hides the base's ([namespace.udecl]/15,
  `cpp_fwd_hidden`). `p->A::operator()(x)` reads an operator after the qualifier (`cpp_qual_name`), and a later EMPTY
  base has no sub-object and no hop (`cpp_base_hops`). `usingbase.cpp`, `overloaded.cpp`. (0.121)
- A LOCAL CLASS ([class.local]; 0.121) -- a `struct` or `class` defined in a function body, named or not, with a
  member function, a constructor or a base (a struct of plain data stays C's) -- is a class of the unit under a name
  of its own, `Loc.local_7` (`cpp_local_class/6`, from `cpp_stmts`): registered and emitted where the walk meets it,
  as a closure's class is (`cpp_isolated`, `cpp_add_instance_items`), and the statements after it name it by that name
  (`cpp_rename_names` with the mark `'$deep'`, which reaches the template arguments of a qualified name too,
  `std::vector<Loc>`). An unnamed one is the type of its declaration (`cpp_subst_term/4`). One text is one class
  (`'$cpp_localcls'`, reset in `cpp_register_units`): the first-return walk of an `auto` result meets the class before
  the emission does (`cpp_first_return_in_`), and two functions' `Loc` are two classes. libc++ 18's `variant` assigns
  an alternative through an unnamed one: `struct { void operator()(true_type) const {...} ... } __impl{this,
  std::forward<_Arg>(__arg)};`. `localclass.cpp`. (0.121)

### Methods and calls

- A body is walked bottom up in the check's scopes (`cpp_method_body`, `cpp_stmt`, `cpp_expr`). A bare data member is
  `this->n`, an inherited one reached through `$base` or a later base's slot (`cpp_data_member/3`, `cpp_access`). A
  bare static const folds to its value; another static is `id('C.N')` (`cpp_expr(id)`). (0.33, 0.60)
- A qualified data member in a method, `C::m` with C the class or a base of it, is that member of `this`
  ([class.mfct.non.static]/2; `cpp_qualified_data_member/4`): the hops from the class down to C's sub-object
  (`cpp_base_hops`), then C's own hops to the member, never the class's own member of that name. A later base with
  storage is reached through its slot, and a lambda that captured `this` reaches it through the closure. Why: libc++
  18's `formatter<const _CharT *, _CharT>::format` reads `_Base::__parser_`. `qualmember.cpp`. (0.112)
- A member named through an object by its qualified name ([expr.ref]/7): `b.A::v` is the member v of b's A
  sub-object, a base's data member the class hides, and `b.A::f()`, `p->A::f()`, `this->Base<T>::f()` call A's f over
  that sub-object and never virtually (`cpp_qual_object`, `cpp_qual_member`, `cpp_qual_call`). The reader takes a
  qualified name after `.` and `->` (`ccl_member_qseg`). The qualifier names the object's class or a base of it, else
  it is refused by name. `qualobject.cpp`. (0.112)
- `o.m(a)` is `C.m.<keys>(&o, a)`, `p->m(a)` is `C.m.<keys>(p, a)`, and a bare `m(a)` in a method passes `this`. An
  inherited method takes the base's address. The defaults are filled (`'$cpp_dflt'`, `cpp_fill_defaults/3`). A
  method with a slot dispatches through the table, unless the object is a named value or its member
  (`cpp_static_object/1`). (0.33, 0.34)
- A default argument is kept raw and desugared where it is filled in, which is where C++ evaluates it
  (`cpp_fill_defaults/3`): `const _Allocator & __a = _Allocator()`. A member's default is desugared in its class
  (`cpp_default_ctx`): `__rep __new_rep = __short()`. More arguments than recorded defaults drop nothing
  (`cpp_drop(_, [], [])`), since a built call carries `this`. (0.63, 0.71, 0.76)
- A default argument belongs to the declaration: an out-of-class definition takes the declaration's defaults
  (`cpp_keep_defaults/3`, `cpp_member_params/3` in `cpp_mdef_take`). Why: `__grow_by_without_replace(a, b, c, d, 0)`.
  (0.66)
- `X<T>::f(args)` calls a static method with a null `this` (`cpp_call`'s `scoped(Path, M)` clause). Inside a class,
  `Base::f(args)` of a non-static method passes `this` through the base sub-objects, never virtually
  (`cpp_base_hops`). Why: basic_ios's `return ios_base::good();`. (0.44, 0.73)
- A member template called bare with explicit arguments passes `this`, a null one only where it is static
  (`cpp_static_member_template`). Why: `__lower_upper_bound_unique_impl<true>(__v)` inside `__tree`. (0.79)
- A static member function takes a null `this` (`cpp_static_method`). Named as a value it is a `this`-less thunk
  `<Name>.fn` (`cpp_static_thunk`), as libc++'s `find_first_of` takes `_Traits::eq`. `staticfn.cpp`,
  `stdstringfind.cpp`. (0.100)
- A STATIC MEMBER FUNCTION NAMED BARE AS A VALUE is that thunk too (`cpp_static_fn_value/3`, the identifier road of
  `cpp_expr`): `fn = prep;` in a member's body, `Buf{16, prep}` in a base's initializer, the name found in the class being
  walked, its bases (`cpp_static_fn_owner/3`) and the classes enclosing it, a closure's included. The static functions of a
  class are `'$cpp_sfn'(Class, Name)` facts written beside the light record (`cpp_class_put`), so a name that is no static
  function's costs one failed lookup per class. Only a STATIC function is a candidate for a name used as a value
  ([over.over]; a non-static member needs `&C::f`): libc++ 21's `__allocating_buffer` declares a member `__prepare_write(size_t)`
  beside the static `__prepare_write(__output_buffer &, size_t)` and hands the name to the base's constructor -- one static
  function, the thunk. SEVERAL static functions of the name are an overload set that waits for its target
  (`'$staticfn'(C, N)`, like `'$memaddr'`): `cpp_conv_to` chooses by the target's parameter keys, and the assignment, a
  member initialized from one and an argument all convert (`cpp_overload_marker/1`); a marker no target chose reaches the
  lowering and is refused by name (`expr('$staticfn'(...))`). It was `undeclared(prep)`. `staticfnval.cpp`. (0.100, 0.126)
- A bare call of a static member, a static method or a static member TEMPLATE, passes no object (`cpp_static_bare`).
  Why: a friend template walked in its class called `cur(i)` with an undeclared `this`. `friendtmpl.cpp`. (0.115)
- The CHOSEN function decides whether a bare call passes the object, never the name (`cpp_static_bare/3`, asked with the
  mangled name that `cpp_method_on_ptr` chose; `cpp_static_bare/2`, by name, only narrows what to try). Why:
  `vector<bool>` declares `void swap(vector &)` and `static void swap(reference, reference)`, and `swap(__v)` in
  `reserve` went out with a null `this` (a segmentation fault at the first `reserve` of any `vector<bool>`, a defect
  since 0.47). A static function still takes its unused `this`, so a wrong answer here costs nothing.
  `vectorbool.cpp`. (0.117)
- A method's body restores the function's result role (`'$cpp_ret'`) on success, failure and throw
  (`cpp_method_body_`). Why: a failed walk left it set, and `return 0;` in `main` went through `vector(size_type)`.
  (0.115)
- An explicit object parameter, `this Self &self`, becomes the qualifier `explicit_this(N, T)` (`cpp_norm_members/2`):
  the method takes `param(T, N)` first and its body has no implicit `this` (`cpp_declare_members`, `cpp_member_fns`).
  (0.43)
- DEDUCING THIS on a class's methods (C++23, 0.117; refused as `deduced_this(C)` from 0.43): `this auto &&self` invents
  `$A1` first among the member template's parameters (`cpp_this_auto/4`, `cpp_auto_members`); `template <class Self> ...
  this Self &&self` is a template wrapping a method with `explicit_this` (a `cpp_norm_members_` clause); `this const
  Node &self`, `this Node &self` and `this Node self` are plain. The object of the call is `'$cpp_obj_expr'` (set by
  `cpp_method_on/6` and `cpp_method_on_ptr/6`, `cpp_with_obj_expr/2`; `cpp_isolated` sets it aside):
  `cpp_member_holding` makes it the FIRST ARGUMENT of a candidate that has `explicit_this(N, T)`, whose first parameter
  is `param(T, N)`, so Self is deduced from the object as from any argument (an lvalue gives `D &`, a prvalue `D`, a
  derived object its DERIVED class, the CRTP's replacement), and `cpp_subst_quals` substitutes the qualifier. Its
  declared result is resolved by `cpp_method_ret` with the object parameter in scope (an `auto` result as the first
  return; a plain `std::string` result had been left as written). Operators (`operator()`, `[]`, `==`, `+=`) work. A
  captureless lambda with an explicit object parameter has no conversion to a function pointer, as in clang++
  ([expr.prim.lambda.closure]/8). `deducethis.cpp` (`-std=c++23`). (0.117)
- `cpp_object_arg/3` passes the object: a first parameter named `this` takes the address, any other the object itself
  (`B`, or `deref(P)`). On `std::move(x)` the object is x itself; the xvalue has chosen the `&&` overload. Why: libc++
  18's `__format_buffer::__out_it() &&` writes `std::move(__writer_).__out_it()`. `moveobj.cpp`. (0.43, 0.112)
- A call of a member that the class lacks refuses, which is the rejection a detection needs: `no_member(M, T)` for
  `o.f()`, `no_member(C, M, K)` for `X::f()` (`pointer_traits<P>::to_address`). A data member of function-pointer type
  is called through (`call(member(X, M), As)`), and named bare in a member function too (`this->f_`, base hops
  included): libc++ 18's `__output_buffer::__flush()` writes `__flush_(__ptr_, __size_, __obj_)`. `detect3.cpp`,
  `fnptrmember.cpp`. (0.51, 0.72, 0.88, 0.112)
- A data member whose class has `operator()` is callable, bare in its class (`this->f_`, base hops included) or through
  an object (`c.f(x)`, `cpp_call(member(...))`): its class's `operator()` over the member's address. `__scope_guard`'s
  `__func_()`, a range adaptor's held closure. `callable.cpp`, `pipefriend.cpp`. (0.66, 0.110)
- A namespace-scope object or a static data member of class type, called, calls its class's `operator()`
  (`cpp_callable_global`, `cpp_object_call`, `cpp_call`'s static-member clauses):
  `_IterOps<_RangeAlgPolicy>::__iter_move`. `autoobject.cpp`. (0.100, 0.109)
- A call through a cast to a reference calls the operand. Through a cast to a BASE's reference it calls the base's
  `operator()` on the base sub-object, through the slot when virtual (`cpp_call`'s `ccast` clause,
  `cpp_operand_class`, `cpp_base_operator_call`); `*this` is the class being walked. Why: `__map_value_compare` called
  itself until the stack overflowed. `basecastcall.cpp`. (0.94)
- `decay_copy(X)`, C++23's `auto(x)`, is `cast(T, X)` of the decayed type; a class value stays as it is, an lvalue
  with a destructor refused. `index(A, args(Is))` goes to the class's `operator[]`, else `subscript_arity(N)`. (0.43)
- A virtual call, and a method called bare inside its class, take their arguments through the passes a direct call
  does (`cpp_dispatch/6`, `cpp_dispatch_copied/6`, read off the method chosen): the conversion operator, a null pointer
  constant and a template's name (`cpp_ref_args_of`), then the copy and the converting constructor (`cpp_copies`,
  which the call wrapper runs only on a call by name). Why: libc++'s `basic_stringbuf::seekpos` writes
  `this->seekoff(__sp, ...)` and handed an fpos to an `off_type` (the `sext` of a struct, `std::quoted` over an
  `istringstream`), and a class taken by value went bitwise to a callee that destroys it. `dispatchargs.cpp`. (0.112)

### Operators

- `cpp_operator/5` tries in order: the class's member operator; a free operator through the free-function road
  (`cpp_free_operator_call`); an enumeration operand's free operator (`cpp_enum_operator_call`, 0.112); a rewritten
  comparison (`cpp_rewritten_cmp`). Where the member is not exact (`cpp_member_exact`), a free operator that the free
  road finds wins: `cout << "hello"`. A class or struct operand that no road answers refuses `no_operator(Op)`,
  except under `!`, `&&` and `||`, which convert contextually afterwards. Else the plain form stays. (0.94, 0.112)
- A unary operator on a class goes to its operator through `cpp_operator/5`: `deref`, `preinc`, `predec`, `postinc`,
  `postdec` (a postfix one passes `int(0)`), `not`, `neg`, `bitnot`. Why: libc++'s `addressof(*__first)`.
  `unaryops.cpp`. (0.47)
- `x->m` on a class object goes through its `operator->`, again until a pointer (`cpp_arrow_object`):
  `__h->__get_value()` on a `unique_ptr`. (0.79)
- An operator function's result type is resolved at its declaration and emission, as a plain function's is
  (`cpp_register_`, `cpp_item`): a friend inserter returns `std::ostream &`. (0.78)
- A conversion operator is named `op.conv_<key>` (`cpp_op_word/2`). An operator member template's instance is named
  `op.<word>`, so `operator()` is `op.call` (`cpp_instance_base/2`). (0.45, 0.48)

- An enumerator's type is its enum ([dcl.enum]/5) where the program writes an operator for that enum:
  `cpp_enum_operator_call` takes the enums the operator's parameters name first, an enumerator operand of one of them
  (`cpp_enumerator_of/2`, the tag table's `enumerator(N, _)`) is cast to the enum (`cpp_enum_args/3`), and the overload
  road chooses. The inference still types an enumerator as `int` (0.100). Why: `Red | Green` took the built-in.
  `enumop.cpp`. (0.112)
### Constructors and member initializers

- `cpp_ctor_body` builds a constructor's body in order: the first base's constructor over its place, each later base
  with storage in declaration order (`cpp_extra_inits`), the table pointer's store (`cpp_vptr_store`), each data member
  in order (`cpp_member_inits`), then the written body. (0.33, 0.88)
- A base takes its initializer by its name, its slot, or a class alias naming it (`cpp_alias_base_init`): `using
  __base = ...; : __base(in_place, ...)`. Arguments that no constructor takes refuse `base_constructor(B)`. (0.82,
  0.93)
- A base with user-declared constructors, none of which takes no argument, that no initializer names is refused,
  `base_constructor(B)` ([class.base.init]/9; `cpp_no_default_ctor/1`, for the first base, a later one and a
  diamond's shared one). A base with no constructor at all is left alone, as C++ leaves it. Such a base also deletes
  the class's implicit default constructor, which is then not made (`cpp_implicit_ctor_needed`). Why: the base was
  left unconstructed while the comment said refused. `basedefault.cpp`, `test/cpp/basenodefault.cpp`. (0.112)
- A data member is built from its `init(N, Args)`, else its default member initializer, else its default constructor
  (`cpp_member_inits`). A class with nothing to construct is left alone (`cpp_trivial_default`). A value of the
  member's own class copies bitwise: refused with a destructor (`copy_of_a_class_with_destructor`), nothing for an
  empty class. Anything else refuses `member_not_constructed(N, MC, NA)`. `member.cpp`. (0.41, 0.89)
- `m()` in a member initializer value-initializes ([dcl.init]/8): a scalar's zero, a class without a user-provided
  default constructor zero-filled (`cpp_zero_fill`) and then constructed (0.127, below), an array zeroed. A member of an
  empty class is never zero-filled (`cpp_zero_fill`, `cpp_value_init`): its byte is padding or no byte at all. Why:
  pair's `second()` was garbage, and a `memset` wrote outside libc++'s string. (0.75, 0.79, 0.89, 0.127)
- VALUE-INITIALIZATION ZEROES THE OBJECT FIRST where its class's default constructor is not user-provided ([dcl.init]/8;
  `cpp_value_zeroes/1` over `cpp_user_default_ctor/1`: a constructor the class writes, or a constructor template, that
  takes no argument is user-provided; the implicit one and `C() = default` in the class are not), then runs that
  constructor: `R()` and every temporary of no argument (`cpp_temp_zeroed/6`), `T t{}` of a non-aggregate class, a
  member's `m()` (`cpp_member_inits`, `cpp_value_init`), `new T()` and `new T{}` (calloc, `cpp_new_ctor/5`; a type with
  nothing to construct calloc'd, a scalar its zero, `cpp_new_zeroed/2`) and `new (p) T()` (a `memset`, then the
  constructor; `cpp_new_at/5`). `new T` and `new (p) T` alone, the reader's `new_default(T)`, default-initialize: the
  constructor, else the bytes as they are (`cpp_new_default/2`, `cpp_new_at(default, ...)`). Fixture: `valueinit.cpp`.
  Why: each ran the implicit constructor alone, so `struct R { int a; Q q; }` had a garbage `a` where clang++ gives 0,
  and `new int()` over reused memory was garbage. (0.127)
- A braced default member initializer value-initializes too: `T cur{};` as `m()` does; `int n{3};` on a scalar is its
  one item. Its scalar test resolves the type first (`cpp_scalar_member_type`): `size_t __size_{0};` names
  `typedef(size_t)`. An enumeration is a scalar type ([basic.types.general]/9; `cpp_scalar_type`): `__alignment
  __alignment_ : 3 {__alignment::__default}` is its one item. `scalarbrace.cpp`, `enumbits.cpp`. (0.108, 0.112)
- A braced default member initializer of a CLASS member list-initializes it ([dcl.init.list]/3; `cpp_member_inits`
  through `cpp_member_from` on `init(Items)`): an aggregate member by its items and its own defaults, a class through
  its constructors. Why: libc++ 18's format-spec parser holds `__code_point<_CharT> __fill_{}`, which refused
  `member_not_constructed`. `aggdefaults.cpp`. (0.112)
- A braced default member initializer of a PLAIN struct or union member, `U u = { { 1, 2 } };` or `P p{3, 4};`, assigns
  a compound literal of the member's type (`cpp_member_from/6` on `init(Items)` after `cpp_plain_aggregate/1`; the
  plain-member clause of `cpp_member_inits` asks it for a default initializer). Else the list reached the lowering as a
  bare braced expression: glibc's `PTHREAD_MUTEX_INITIALIZER` is `{ { 0, 0, 0, 0, 0, 0, 0, { 0, 0 } } }` over a union,
  and libc++'s `std::mutex` holds it as `__libcpp_mutex_t __m_ = _LIBCPP_MUTEX_INITIALIZER;`. `aggmemberinit.cpp`.
  (0.117)
- A PLAIN STRUCT OR UNION MEMBER INITIALIZED BY PARENTHESES from values that are not its own type is aggregate
  initialization ([dcl.init.general]/16.6.2.2, C++20): `: rep_(Short{7})` sets the first member of the union `Rep` from the
  value, as the braced list `{7}` would (`cpp_member_inits`' clause over `cpp_plain_aggregate/1`, `cpp_aggregate_args/2`,
  then `cpp_member_from/6`). One value of the member's own type, top-level qualifiers dropped, is its copy and keeps the old
  road; the value's type is the inference's, else the DESUGARED form's in the class being built (`cpp_aggregate_arg_type/2`),
  since `__short()` names a type nested in the class. Assigned, the value reached the lowering as `sext %struct.__short to
  %struct.__rep` and LLVM refused it: libc++ 21 (C++20 and later) writes `basic_string() : __rep_(__short())`, so every
  `std::string` of a program at `-std=c++20` met it. `unionparen.cpp` (`-std=c++20`). (0.126)
- A member of a NESTED class built from a prvalue of its own class, `p_(param_type(a, b))` with `param_type` the class's
  own member type, takes the class being built as the context of the argument's desugaring (`cpp_init_arg_class/2`): its
  short name is a name only there (`member_not_constructed` for libc++'s `uniform_int_distribution::__p_`).
  `nestedinit.cpp`. (0.117)
- A reference member is bound, never constructed or assigned: its initializer or default member initializer becomes
  `bind_ref(arrow(this, N), E)` (`cpp_member_inits`). The lowering stores the address in the slot (`ir_bind_ref/2`)
  and reads every use through it (`ir_ref_member/4`). An unbound one is left alone (trace `reference_member_unbound`).
  `__destroy_vector` holds a `vector &`. (0.61)
- `: first_{0}` for an ARRAY member is its braced list (`cpp_array_item/2`): a scalar item is the first element and the
  rest is zero, as the reader's one-item `init(first_, [0])` stands for `first_(0)` too. It was `lvalue(int(0))` for the
  program's own class and, for libc++'s `__bitset`, an uninitialized word. `arraybrace.cpp`. (0.117)
- An array member of objects is built, copied and moved element by element and destroyed in reverse
  (`cpp_member_from`, `cpp_value_init`, `cpp_member_dtor`); a plain array copies as bytes; `: cells()` zeroes it.
  `stdaggregate.cpp`. (0.84)
- A constructor's parameters are in scope while its member initializers are built (`cpp_ctor_fn`): `a_(a)` must type
  `a` to choose. `alloc.cpp`. (0.46)
- The class of a member initializer's argument is read through a `move`, and off the desugared form where the raw one
  cannot tell (`cpp_init_arg_class/2`, `cpp_arg_type`): `__rep_(std::move(__str.__rep_))`,
  `__alloc_(__alloc_traits::select_on_container_copy_construction(...))`. (0.47, 0.66)
- An initializer naming nothing the class has refuses `unknown_initializer(C, N)` (`cpp_inits_known`,
  `cpp_init_known`). One naming a template parameter, `_Base(__value)`, is substituted like a base clause (`cpp_subst`
  on `init(P, As)`). (0.100)
- A delegating constructor calls the other over `this` and initializes nothing else (`cpp_ctor_body`). It is known by
  the class's own name, the instance's or its template's (`cpp_own_name`, `'$cpp_inst'`). Why: else `__value_func`'s
  delegation was dropped and every `std::function` was empty. (0.79, 0.100)
- Inheriting constructors, `using Base::Base;` (`cpp_inherit_ctors`), give one constructor per constructor of the one
  base but the copy, the move and a deleted one: parameters named, defaults and `explicit` kept, initializer
  `init(Base, Args)`. The base's constructor templates come too (`cpp_named_params_t`, a pack forwarded). The base may
  be named through the class's alias (`cpp_alias_names_base`) or an alias template's head (`cpp_tmpl_head`): optional's
  storage chain, bind_front's `__perfect_forward`. (0.79, 0.82, 0.100)
- The constructor road (`cpp_ctor/3`) chooses in the class's words (`cpp_as_callee`). The class's own value takes its
  copy or move constructor, written or implicit, never another taking a class ([over.best.ics]; `cpp_own_value`). Then
  the written constructors whose arguments fit, a constructor template (never for the class's own value), the implicit
  copy or move, the arity alone (`cpp_args_no_clash`), and `C.C.0`. A constructor whose requires-clause fails is no
  candidate and is not instantiated (`cpp_method_viable`, 0.112). Why: `ostreambuf_iterator(ostream_type &)` took an
  iterator, and every stream fixture crashed. (0.83, 0.84, 0.112)
- The implicit default constructor `C.C.0` (`cpp_implicit_ctor`) is made where `cpp_implicit_ctor_needed/1` holds:
  default member initializers, a base or member (or array element) class with constructors, a polymorphic class, a
  diamond's holder. A written constructor or constructor template suppresses it ([class.default.ctor]/1) unless
  `C() = default` stands beside; a closure gets none (`cpp_closure_class`). Why: libc++ 18's `__compressed_pair` got
  one that built neither base. `ctortemplate.cpp`. (0.33, 0.93)
- C++ deletes the implicit default constructor where a member's class has constructors but no default one
  (`cpp_members_default`, `cpp_default_ctor_exists`); the class stays the aggregate it was written as:
  `__in_out_result` over an `ostreambuf_iterator`. (0.71)
- `C() = default;` beside other constructors records `'$cpp_default_ctor'(C)`: the default constructor EXISTS
  (`cpp_default_ctor_exists`) and builds the bases and members, or does nothing where nothing needs it
  (`cpp_trivial_default`). A constrained one counts only where its constraints hold in the class's words
  (`cpp_method_viable`, trace `default_ctor_unmet`; `defaultreq.cpp`, 0.112). Why: a holder of `coroutine_handle<>`
  never ran `__handle_ = nullptr`. `nesteddefault.cpp`. (0.63, 0.108, 0.112)
- The class emits its implicit default constructor and notes it there (`cpp_item`), so `cpp_use_member` never emits a
  second one, which LLVM refuses. Such a class is default-constructible to the traits (`cpp_constructible`): libc++ 18's
  `allocator() = default`. (0.84, 0.93)
- The implicit constructor and destructor are made IN THE CLASS (`cpp_in_class` around `cpp_implicit_ctor` and
  `cpp_implicit_dtor` in `cpp_item`), as its written members are: a default member initializer is written in the
  class's words ([class.mem]/7). Why: libc++ 18's view sentinels write `sentinel_t<_Base> __end_ =
  sentinel_t<_Base>();` over their own alias `_Base`; made outside the class, the implicit constructor named nothing
  and the instance was not emitted (`views::transform`, `take_while`, `keys`). `sentbase.cpp`. (0.113)
- The implicit default constructor has `this` and its parameters in scope while its member initializers are built
  (`cpp_implicit_ctor_`). Why: `member_not_constructed('__output_buffer.char', 3)`. `implicitthis.cpp`. (0.115)
- A class whose only constructors are `= default` and a converting template, `std::allocator`, is default-initialized
  with nothing to call (`cpp_trivial_default/1`) and copied by the implicit copy, never the template (`cpp_ctor`).
  (0.46)

### Destructors and the lifetime of temporaries

- A local of a class with a destructor gets `defer(L, [], block([expr(L, call(id('C.dtor.0'), [addr(id(N))]))]))`
  after its construction (`cpp_decl_pieces`); it runs at every exit of the scope, the last declared first. (0.33)
- `cpp_dtor_body` builds a destructor's body: the class's own table stores, the written body, each member's destructor
  in reverse order (an array's elements in reverse), the later bases' destructors in reverse, then the first base's. A
  class with no destructor of its own runs its base's on itself (`cpp_dtor/2`), the base lying at offset 0. (0.34, 0.41,
  0.88)
- An implicit destructor `C.dtor.0` is made where a member or array element has a destructor, or a virtual or diamond's
  shared base must be destroyed (`cpp_implicit_dtor_needed/1`, `cpp_implicit_dtor/3`). `cpp_own_dtor` counts it, so
  `delete`, a scope's defer and a table's slot find it. (0.41)
- An explicit destructor call, `x.~T()` or `p->~T()`, runs the destructor over the address, nothing for a class
  without one (`cpp_call`'s `dtor(_)` clauses). A program's container destroys an element so (`Bag::pop`) and stores
  with `d[n] = move(x)`. `bag.cpp`. (0.41)
- A temporary of a class with a destructor dies at the end of its statement, C++'s full expression. `cpp_stmt/3` wraps
  `cpp_stmt_/3` with a fresh `'$cpp_temps'`, where `cpp_temporary` registers and declares it. An expression or a
  declaration is followed by destructor calls in reverse construction order; any other statement is wrapped in a block
  of defers (`cpp_temp_scope`), which a `return` needs. `stdvectorown.cpp`. (0.62)
- A temporary in a loop's condition or step is built and destroyed at every evaluation ([class.temporary]/4;
  `cpp_cond_once/4`, `cpp_expr_once/4`): an expression whose walk registered temporaries becomes a statement expression
  of its own (`cpp_temps_around/5`) -- the temporaries declared, the value kept in `$cv` after a condition's contextual
  conversion to bool, the destructors run, the value last. Refused as `temporary_in_a_loop_condition` from 0.62, now
  only where the value has no type. `looptemp.cpp`. (0.62, 0.112)
- A local initialized by a prvalue of its class takes it through `cpp_ctor_args`, which keeps the prvalue for the
  caller's elision rather than failing after its walk: failing, the caller walked the initializer again, and `Tag t =
  plus(Tag(1), 5)` destroyed a second, never-built temporary. `prvalueinit.cpp`. (0.112)
- A function-local `static` object is initialized the first time control passes its declaration ([stmt.dcl]/3): at
  compile time where the evaluator constructs it (`cpp_fold_quietly/4`, which leaves no temporary registered behind a
  failed attempt), else under the Itanium guard -- `__cxa_guard_acquire` answers non-zero once, the constructor runs
  over the static's address (a prvalue elided into it), the destructor is registered with `__cxa_atexit` (itself the
  callback, the object its argument, a null DSO handle), and `__cxa_guard_release` marks it done. `localstatic.cpp`.
  (0.112)
- A prvalue that initializes another object of its class IS that object ([class.copy.elision]; `cpp_temp_elide/2`): a
  by-value class parameter (`cpp_copies_`), a `return`, a local from a prvalue of its class (no constructor looked
  for), a closure built member by member. Why: destroyed at both ends, a temporary double-freed (`bag.cpp`) and
  over-counted (`counter.cpp`). (0.62, 0.66, 0.101)
- A local array of objects is constructed element by element in order -- from its item, a prvalue of the class
  BEING the element (C++17's elision), else value-initialized through the default constructor -- and destroyed in
  reverse by one defer at the scope's end (`cpp_decl_pieces`' array clause, `cpp_elems_from/8`, `cpp_elem_from/6`,
  over `cpp_member_from`, `cpp_value_init` and `cpp_member_dtor`). Why: `std::string names[3] = {"ann", "bob"}` stored
  the literals' pointers into the strings' bytes. `localarray.cpp`. (0.112)
- A local array of ARRAYS of objects is built and destroyed the same way (0.117; `cpp_elem_class/2` peels the nested
  arrays, a nested braced item that is a prvalue of the element class is the element: `cpp_array_items` through
  `cpp_elem_from`), and so is a STATIC local array of objects: initialized the first time control passes the
  declaration under the Itanium guard, its destructors registered with `__cxa_atexit` through a wrapper
  `$cpp_sdtor.N` (appended to the unit by `cpp_ginit_items`, which stands without the initialization function
  when only wrappers exist). `localarray2.cpp`. (0.117)
- A temporary of a class with a destructor bound to a named reference lives as long as the reference
  ([class.temporary]/6; `cpp_ext_temp/5` in `cpp_decl_pieces`): it is a hidden local `$ext_K`, the prvalue elided into
  it, destroyed by a defer at the scope's end; never for an lvalue, a `move` or an xvalue call. Why: `const Tag &a =
  Tag(1)` dangled after its statement, and `Tag &&b = make(2)` was never destroyed. `lifeext.cpp`. (0.112)

### Temporaries and type names called

- `Counter(v)` and a functional cast to a class are temporaries in statement expressions (`cpp_temporary`), built where
  the evaluation order puts them. An aggregate's is a compound literal, or is built member by member where a member
  constructs (`cpp_aggregate_inits`): the tree's `_InsertReturnType{end(), false, _NodeHandle()}`. `C()` with nothing
  to construct is `compound_lit(T, init([]))`. `nested.cpp`. (0.33, 0.48, 0.83)
- A class's or tag's name called is a temporary only where it takes that many arguments (`cpp_class_takes/2`,
  `cpp_tag_takes/2`): any count with a constructor or a constructor template (`__bind`), at most one item per member
  for an aggregate, a cast or nothing for an empty tag, a cast or nothing for an enum. Why: libc++ has the tag
  `_Algorithm::__fill_n` and `std::__fill_n(first, n, value)` under one flattened name. An enum called with NO argument
  or an empty braced list is value-initialized, its zero (`cast(E, int(0))`, [dcl.init]/8; 0.117): `std::errc()` of
  `<charconv>` was `undeclared(errc)`. `enumvalue.cpp`. (0.58, 0.88, 0.117)
- A type's name called is one predicate, `cpp_type_call/3`: a class temporary or aggregate, one argument a cast, none
  the type's zero. It serves a class-scope typedef, a file-scope one (`false_type()`, `size_t(n)`), an alias
  template-id (`__make_unsigned_t<type>(0)`) and a typedef named through its class (`ios_base::fmtflags(0)`).
  `libcxxforms.cpp`. (0.60, 0.78)
- A bound type parameter called is one predicate, `cpp_type_called/3` in `cpp_subst`: `T(x)` a functional cast, `T()`
  of a builtin or pointer the type's zero (`*__s = _CharT()`), `T(a, b, ...)` the bound class's name called.
  `sizeof(id(T))` becomes `sizeof_type(T)`. (0.78, 0.90)
- `Guard<A, I>(a, i)` is a temporary of the instance (`cpp_call`'s `tmpl` clause) only where every argument is settled
  (`cpp_targs_settled/1`); an unfolded argument would name an instance by its spelling. (0.47)
- `typename X::y(args)`, the reader's `construct(T, As)`, goes through the type-call road; `void()` is `(void) 0`.
  (0.79, 0.81)
- A call whose callee is an object goes to its `operator()` over an address (`cpp_temp_call/3`). A temporary built in
  the same expression is called inside its block (`__destroy_vector(*this)()`), an aggregate temporary gets one
  (`_Algorithm()(a, b, c)`), and a call returning a class by value materializes a statement temporary
  (`g.key_comp()(3, 1)`). `(*p)(a)`, `fs[i](a)` and a call returning a reference use their own address
  (`cpp_addressable/1`). `tempcall.cpp`, `aggcall.cpp`. (0.55, 0.72, 0.80)
- The call of a temporary object takes the argument passes a call by name takes (`cpp_copies` on the four roads of
  `cpp_temp_call/3`; 0.121): `std::hash<std::string>{}("hello")` handed the literal's address to a `const string &`
  parameter and hashed the bytes of a pointer. `fwdmember.cpp`.

### Copies, moves and assignment

- A class with a destructor never copies bitwise, since two owners would free one buffer. It copies only through a
  copy or move constructor or an `operator=`, written or implicit. Else it refuses
  `copy_of_a_class_with_destructor(C)`, `assignment_to_a_class_with_destructor(C)` (unless the right side is a
  `move`), `class_with_destructor_by_value(C)` or `return_of_a_class_with_destructor(C)` (`'$cpp_ret'`,
  `cpp_method_body/5`). (0.41, 0.84)
- A local of a class with constructors is a `'$splice'` of its declaration and a constructor call over its address
  (`cpp_decl_pieces`, `cpp_ctor_args`), from `ctor(As)`, `init(Items)` (the `initializer_list` constructor first),
  nothing, or one value. A prvalue of the class is elided. An lvalue copies through the copy constructor, `move(x)`
  through the move one (`cpp_copy_ctor(C, ref | rref)`). A bitwise copy happens only where no constructor fits and
  the class has no destructor. (0.33, 0.66)
- The copy pass, `cpp_copies/2`, runs after every call expression, on the constructor call of a temporary
  (`cpp_temporary`, its temporaries register read again after it), of a local (`cpp_decl_pieces`, 0.112) and of a
  placement new (`cpp_new_at`), and on an operator's call (`cpp_operator`). It never runs on a member initializer's
  constructor call, where it looped. It makes the braced arguments, converting constructors, copy and move temporaries,
  slicing and elision. (0.79, 0.83, 0.112)
- `C(const C &) = default` and `C(C &&) = default` are MEMBERWISE ([class.copy.ctor]/14): `cpp_norm_members_` marks
  `memberwise(S, copy | move)` and `cpp_ctor_body` builds each member and the base from the source's, through its own
  copy or move. An empty base is named as the base (`cpp_base_src`: `ccast(static, ref(Base), id(S))`), else a base
  constructor taking the derived class was sought. `cpp_user_ctor` keeps the marker out of `cpp_trivial_class` and
  `cpp_note_nontrivial`. Why: `set(const set &)` was refused. (0.80, 0.89)
- The implicit copy and move constructors are made on demand, memberwise, by the constructor road for any class
  (`cpp_implicit_copy_ctor`, `'$cpp_implicit_copy'`). The name is noted when emitted, never before: a walk abandoned by
  a throw left `Rec.Rec.Rec_rr` undefined. A local's initializer makes one only for the program's own class without
  owners (`cpp_ctor_args`); a library class's special members come through its lazy road. (0.82, 0.84, 0.93)
- The implicit memberwise assignment ([class.copy.assign]; `cpp_implicit_assign`, `'$cpp_implicit_assign'`) serves a
  class with a destructor and no written `operator=`: each member through its own, a string through basic_string's,
  an array as bytes, the move form moving each. It is made once per class and kind, never for a class holding owners.
  (0.84)
- The implicit copy and move assignment exist unless a COPY or MOVE `operator=` is written ([class.copy.assign]/1;
  `cpp_written_copy_assign/1`): an `operator=` from another type does not suppress them. A value of the class itself
  assigned (`cpp_assign_from_own/3`, through a `move`) takes that road first, the exact match: memberwise for a class
  with a destructor, its bytes for one without. Why: libc++'s `back_insert_iterator` writes only `operator=(const
  value_type &)`, and `__out_it_ = std::move(__it)` (`basic_format_context::advance_to`) pushed a byte where it should
  copy the iterator: `std::format` printed `0200 and 0300`. `implicitassign.cpp`. (0.112)
- `a = b` on a class calls its `operator=`, copy or move by the value category. A value of another type assigned to a
  class without a destructor and without a fitting `operator=` converts through a converting constructor
  (`cpp_expr(assign('=', ...))`): `__f = erase(__f)`. An array assigned is its bytes (`memcpy`). (0.44, 0.80)
- A by-value parameter of a class with a destructor takes a temporary (`cpp_copies_`): the move constructor's for
  `std::move(x)` (`cpp_move_temp`), else the copy constructor's (`cpp_copy_temp`), else
  `class_with_destructor_by_value(C)`. The callee destroys it through a defer (`cpp_param_defers`). A class with
  neither constructor keeps the lowering's move, which nulls the source's owners. (0.44, 0.83)
- `return x` of a local of a class with a destructor moves out through the move constructor, else copies; `return
  std::move(x)` alike (`cpp_stmt_(return)`). A prvalue moves bitwise, as C++17 elides that copy. (0.44, 0.83)
- `move(X)` of a class value stays `move(X)` ([expr.xvalue]; `cpp_expr(move)`), since overload resolution reads its
  category; of a scalar it is the value. `std::move(x)` names an object, never a temporary to elide ([basic.lval];
  `cpp_decl_pieces`): elided, two unique_ptrs held one pointer. A reference parameter takes the object itself, its
  `move` stripped (`cpp_ref_args_of`). (0.83, 0.86)
- Copy-initialization from `std::move(x)` or from an xvalue cast, `static_cast<T &&>(x)`, keeps the move among the
  constructor's arguments ([dcl.init]/17.6.2; `cpp_ctor_args`, `cpp_xvalue_move/2`), so `cpp_ctor` chooses the MOVE
  constructor, written or implicit. Why: `M b = std::move(a)` chose the copy constructor, and the cast form was elided
  bitwise into a double free. `moveinit.cpp`, `stdvectorvector.cpp`. (0.112)
- A derived object passed to a by-value base parameter is sliced to its base sub-object (`cpp_copies_`). With no hops
  every base on the path is empty and only the type changes: `comma(A, compound_lit(Base, init([])))`, as libc++
  passes `__priority_tag<1>()` to `__priority_tag<0>`. (0.79, 0.89)

### Aggregates and braced initialization

- An aggregate is a class with no constructor written ([dcl.init.aggr]; `cpp_aggregate_class`); a memberwise marker
  and the implicit constructor made for a constructing member do not count. A constructor template, a virtual function
  or a virtual base excludes it. (0.84, 0.100)
- A local of an aggregate class that needs an implicit constructor is built from its braced list member by member
  (`cpp_decl_pieces`, `cpp_aggregate_inits/5`), then the destructor's defer: `Person p = {"ann", 30}`. A class with a
  written constructor takes `{12}` as its constructor's arguments, never as items: `std::atomic<int> a{12}`.
  (0.41, 0.100)
- A designated list is made positional over the class's data members ([dcl.init.aggr]/3.1; `cpp_agg_values/3`): `.f =
  v` at f's place, an item without a designator at the next, a skipped member the hole `'$no_item'` (taken as a member
  with no item). Every aggregate door asks it: a local, a member's braced list, a global. Why: the values were taken in
  order with their designators dropped, so `F l{.b_ = true}` set the first member. `aggconst.cpp`. (0.112)
- A designator may name a member of an ANONYMOUS UNION ([class.union.anon]/1): its slot is the union's own `$anonK`,
  its item `'$anon_item'(F, V)` (`cpp_agg_slots`, `cpp_anon_field/3`), stored through the union by `cpp_agg_inits`.
  `desiganon.cpp`. Why: libc++'s `__parsed_specifications{.__std_ = __std{...}, ...}` stored the whole `__std` into
  the union's bytes, a conversion LLVM refused. (0.112)
- A designated temporary of an aggregate class, `T{.a = 1}`, is built member by member over its zero bytes
  (`cpp_agg_temp/5` from `cpp_expr` on a designated `compound_lit`), destroyed with the statement or elided; a plain
  struct's stays the compound literal the lowering takes. `return {.a = 1}` designates the result the same way.
  `desiganon.cpp`. (0.112)
- A global of an aggregate class takes the aggregate road, not the constructor's (`cpp_fold_ctor_init` through
  `cpp_agg_constant/3`): its braced list is completed member by member -- the item written, else the default member
  initializer desugared in the class, else `init([])` -- and a member of an aggregate class is completed the same way.
  A header's inline variable is completed so too (`cpp_lazy_inline_var`). Only scalars, arrays of scalars and such
  aggregates take this road. Why: libc++ 18's `inline constexpr __fields __fields_integral{.__sign_ = true, ...}`, and
  the program's own refused `dynamic_initialization_of_global`. `aggconst.cpp`. (0.112)
- A scalar member from a braced list is its one item, or its zero from `{}` (`cpp_member_from`). (0.112)
- A member with no item takes its own default member initializer ([dcl.init.aggr]/5.1; `cpp_agg_inits/6` over the
  class's defaults from `cpp_agg_defaults`), else it is value-initialized ([dcl.init.aggr]/5.2; `cpp_value_init`):
  through the default constructor, zero-filled where none is user-provided, an array of objects element by element, a
  scalar zero: `Grid2 g2{}`. Why: libc++ 18's `struct __code_point<char> { char __data[4] = {' '}; }` is the fill of
  every format spec. `aggdefaults.cpp`. (0.84, 0.112)
- `cpp_member_from` builds one member from its item: an array from a nested braced list element by element (the rest
  zero) or from an array value as bytes; a nested aggregate from its own list; a class through its constructors, the
  `initializer_list` one first; a reference member bound; a scalar assigned. (0.84)
- Brace elision ([dcl.init.aggr]/15, C too): an array member given a non-braced item takes as many following items as
  it has elements, where more items than members remain (`cpp_aggregate_inits`, `cpp_elide_take`; the lowering's
  `ir_init_items`, `ir_elide_take`, a global's `ir_gelide`). Else one item for one array member is an array value.
  Every `std::array` initializer needs it. `stdarray.cpp`. (0.91, 0.110)
- `return { a, b }` builds the RESULT type's object: through its constructor, else member by member where a member
  constructs, else the compound literal (`cpp_stmt_` on `return(L, init(Items))`); it is elided. A designated list
  takes the designated road above. (0.72, 0.83, 0.112)
- A braced argument to a class parameter list-initializes a temporary ([over.ics.list]; `cpp_copies_`,
  `cpp_param_takes_class`), to `initializer_list<T>` the compiler's list. The fit (`cpp_arg_fit_` on `init(Items)`)
  takes a class the list constructs or an `initializer_list<T>` whose items fit, nothing else: `m.insert({4, 40})`.
  (0.79, 0.80)
- The compiler builds an `initializer_list` ([dcl.init.list]/6; `cpp_init_list`): a backing array `$il`, then libc++'s
  private `initializer_list(const _Ep *, size_t)` over it. A class with an `initializer_list` constructor takes a
  braced initializer through it first ([over.match.list]; `cpp_il_ctor`, `cpp_ctor_args`). An item of another type
  converts through the element's converting constructor, a braced item through its constructors (`cpp_il_item`). The
  items are collected once; a second answer registers a second temporary. (0.80, 0.83)
- A BRACED TEMPORARY `T{a, b}` (the reader's `braced_temp/1`) of a class WITH an `initializer_list` constructor takes
  the list through it FIRST ([over.match.list]/1): `std::vector<int>{5}` is one element, `std::vector<std::string>{"a",
  "b"}` two strings, never the (count, value) or (first, last) constructors the items would fit as arguments. `cpp_expr`
  asks `cpp_braced_class/3` (the type hook; never a name over an unbound template parameter) and `cpp_il_braced/3`: a
  non-empty list that is not one item of the class itself or a derived class ([dcl.init.list]/3.2: `std::vector<int>{v}`
  copies), whose items a class element type takes (`cpp_il_class_items_fit/2`: the inference's types only). Then
  `cpp_init_list/4` (it takes the CALLER'S context, so a method's `std::vector<int>{n_, m_}` names its members) and the
  list constructor. Any other form is the call it was. The same rule serves `return {"a", "b"}`, a braced argument to a
  class parameter (`f({"a", "b"})`) and a nested braced item (`std::vector<std::vector<int>> v = {{1, 2}, {3}}`). Not
  covered: `new T{a, b}` and a bound type parameter called with braces (`_Tp{x}`), which keep the parenthesized meaning.
  `tempinitlist.cpp`. Why: `total(std::vector<std::string>{"a", "b"})` took the iterator-range constructor, and
  `std::vector<int>{5}` had five elements. (0.117)
- A braced scalar is its one item, an empty list the type's zero, only for a scalar type (`cpp_plain_init`,
  `cpp_braced_scalar_type`, the resolver's first answer): `S s = {7}` is the aggregate; `int a[9] = {}`, `int k[3]{}`
  and `S s{}` value-initialize. A type without constructors direct-initialized (`_Tp __t(std::move(__x))`, `int n{}`)
  takes the value or the type's zero. `plaininit.cpp`, `emptybrace.cpp`. (0.45, 0.99)
- `Gen{h}` inside the class template `Gen`, read as a functional cast, list-initializes the aggregate from another
  class's value, also while the instance is being registered (`'$cpp_iname'`): a coroutine's `return Gen{handle}`.
  (0.108)

- The `initializer_list` constructor of an ARITHMETIC element type takes a braced list only where every item fits it
  ([over.match.list]/1.1; `cpp_il_ctor_for/3`), else the constructors are tried over the items: `std::string
  tag{"t"}` had taken `basic_string(initializer_list<char>)` for a `const char *`. A class element type converts its
  items (`Names{"x", "yy"}` over `initializer_list<std::string>`, `stdaggregate.cpp`), and an untyped or braced item is
  let through. `classforms.cpp`. (0.112)
- AN AGGREGATE MAY HAVE PUBLIC BASES (C++17, [dcl.init.aggr]/4.2; 0.121): each base is initialized from the next item
  of the list, in order, before the members. A base with no sub-object (`cpp_empty_class`: a closure that captures
  nothing) keeps no value, so its item is dropped (`cpp_agg_skip_bases/3` and `cpp_direct_bases/2`, in
  `cpp_aggregate_inits`, `cpp_plain_init` and the compound literal of `cpp_temporary`); a base with storage is the
  member `$base` / `$base$K`, which the member road takes in place. `cpp_class_takes/2` counts the empty bases among the
  items an aggregate takes. `overloaded o{ [](int) {...}, [](double) {...} }` through a deduction guide is the idiom of
  `std::visit`. `overloaded.cpp`. The class record's data are its OWN members, so the base sub-objects are put in front
  as the layout has them (`cpp_agg_with_bases/3` over `cpp_base_layout_`; 0.127): `D d{}` of `struct D : Q { int b; }`
  never ran Q's constructor, and `D d2{{}, 4}` gave b the base's `{}`. `aggbase.cpp`. (0.121, 0.127)
- A PRVALUE OF THE MEMBER'S OWN CLASS IS CONSTRUCTED IN THE MEMBER ([dcl.init.aggr]/4.2, [class.copy.elision]/1; 0.121):
  `Wrap<S>{S(9)}` constructs the S once, in the member, and no copy or move constructor runs (`cpp_member_from`'s first
  class clause, over `cpp_prvalue_in_place/3`: the statement expression that built the temporary is handed on with its
  `$tmp` declaration taken out and its name bound to the member's address, `cpp_without_decl/3`, `cpp_mentions/2`). An
  earlier form of this rule (a bitwise copy of the temporary into the member) was wrong for a class that holds its own
  address: `Wrap<std::list<int>>{std::list<int>{7, 8}}` and a `std::function` member left a sentinel pointing into the
  dead temporary, a crash at the first use (`free(): invalid pointer`). The lowering side is in the Lowering topic
  (`ir_prvalue_block`). `fwdmember.cpp`, `prvalueinplace.cpp`. (0.121)
### Conversions through constructors and conversion operators

- A converting constructor serves a call's argument (`cpp_copies_` -> `cpp_converting_ctor/2` -> a temporary) only
  where the argument's type is known and not already the class, for a parameter taking the class by value or binding a
  temporary, `const T &` or `T &&` (`cpp_param_takes_class/2`): `__rep(__long)`, `v.push_back("alpha")`.
  `callable.cpp`. (0.66, 0.70)
- `cpp_converting_ctor` never takes an `explicit` constructor ([class.conv.ctor]) or the copy or move one
  (`cpp_own_class_param`). It checks the fit in the class's words; a refusal there is no conversion. A constructor
  template converts by the fit, or by the template road where its parameter names its own template parameters
  (`cpp_member_template_ctor`): `pair(const pair<_U1, _U2> &)`. (0.70, 0.79, 0.80)
- A value of another type converts through the target class's converting constructor where it is returned
  (`cpp_stmt_(return)`), cast ([expr.static.cast]/4; `cpp_cast_to`) or an initializer list's item (`cpp_il_item`),
  as an argument does: `map::find` returns a `__tree_iterator`; optional's `value_or` casts a `const char *`.
  (0.79, 0.80, 0.82)
- A return of a conditional over class arms returns each arm on its own ([class.copy.elision]; `cpp_stmt_(return)`).
  Why: `value_or` copied the lvalue arm bitwise. (0.82)
- A class value converts through its conversion operator where a scalar or another class is wanted (`cpp_conv_to`):
  a declaration, an argument (`cpp_ref_args_`), a return ([class.conv.fct]), an assignment to a scalar (0.112), a
  temporary of another class ([over.match.copy]; `cpp_temporary`'s first clause, `__self_view(__str)`). An explicit
  operator applies only in a cast (`cpp_cast_to`). fpos's `operator streamoff()`. (0.78, 0.108, 0.112)
- A conversion operator fits where its result does (`cpp_conv_fits`): arithmetic for arithmetic, a pointer for a
  pointer, a function pointer only of an agreeing type (0.112), the same class for a class; it is found in the bases
  too (`cpp_conv_member`). A reference target is looked through with its top-level qualifiers (`cpp_conv_target`):
  the reference binds the operator's prvalue ([over.ics.user], [dcl.init.ref]/5). `convref.cpp`, `std::string_view
  v = s;`. (0.79, 0.90, 0.112)
- A conversion function that yields a REFERENCE is a candidate for the referent's type ([over.match.ref]/1.1;
  `cpp_conv_result_type/2` in `cpp_conv_member_/6`): libc++'s `reference_wrapper<T>::operator T &()` where a `T &`, a
  `T` or a base of T is wanted. The result's reference was kept, and neither `cpp_bare_type/2` nor `cpp_conv_fits/2`
  looks through one, so `bump(std::ref(c), 3)` over `void bump(Counter &, int)` passed the WRAPPER's address as the
  Counter. `fnptrargs.cpp`. (0.117)
- A class value where `bool` is wanted converts through its `operator bool`, explicit included (`cpp_to_bool`): `if`,
  `while`, `do`, `for`, `!`, `&&`, `||` and a cast to `bool`, as a stream's sentry is tested. (0.72, 0.78)
- A conversion function whose result IS the target comes first (`cpp_conv_member_/6` in the mode `exact`, then `fits`;
  [over.match.conv], [over.ics.rank]/3.3): `operator int()` beside `operator long()` (or `operator T()` of `S<long>`)
  converts to a `long` through the second, where the first declared served every arithmetic target. Its NAME holds its
  type, substituted with the class's arguments (`cpp_subst_mname/3`), so `operator T()` of `S<long>` is `op.conv_long`;
  a definition out of the class is found by its kind and compared once substituted (`cpp_mdef_lookup/6`). `convin.cpp`,
  `convout.cpp`. (0.117)
- A class value RETURNED where a scalar result is wanted converts through its conversion function (`cpp_stmt_(return)`,
  [stmt.return]/2; `cpp_conv_to` implicit, so an `explicit operator bool` is no candidate): libc++'s `bitset::test` is
  `bool test(size_t) const { return (*this)[__pos]; }`, a proxy converting to bool, and was compared with zero as a
  struct. `returnconv.cpp`. (0.117)
- A converting constructor's temporary handed to a BY-VALUE parameter is the parameter ([class.copy.elision]/1;
  `cpp_copies_` through `cpp_temp_elide`): the callee destroys it, and the statement does not. Why: `g(9)` over `g(T
  t)` destroyed the temporary twice. `convbyval.cpp`. (0.112)

### Static members

- A static data member is the global `C.N` (`cpp_static_name`), declared with the class (`cpp_static_decls/4`); its
  type is resolved in its class (`cpp_in_class`, `cpp_resolved_type/2`): `static constexpr const type __max`.
  (0.33, 0.58)
- `cpp_static_decls/4` emits a constant initializer as a folded `linkonce` definition, an aggregate one as its own
  `linkonce` definition (`cpp_static_aggregate`: libc++'s `__matches`), and a class-typed one constructed at compile
  time (`cpp_static_constructed` over `cpp_fold_ctor_init`). An empty class initialized in its class is its zero bytes,
  `linkonce`. Any other static is an `extern` declaration, which the link names when nothing defines it.
  (0.45, 0.90, 0.101, 0.109)
- A braced initializer of a class WITH constructors is the constructor's, never the aggregate road
  (`cpp_ctor_class_type/1` guards `cpp_static_aggregate`). Why: libc++'s `__bool_strings<char>::__true{"true"}`, a
  `basic_string_view`, took the literal as its pointer and 0 as its size, and `std::format("{}", true)` printed
  nothing. `constsv.cpp`. (0.112)
- A LAZY class's static data member is defined where the program names it, as its member functions are
  ([temp.inst]/3: a static's initialization occurs only where the member is used; `cpp_static_use/3`,
  `cpp_use_static/2`, `static(C, N)` in `'$cpp_inst'`); its declaration in the table is the registration's
  (`cpp_declare_statics`), and a folded constant needs no definition. Why: checking `std::format`'s second candidate
  instantiates `basic_format_string<wchar_t, int, int>`, and its statics' initializers (`__types_`, `__handles_`)
  pulled the whole `wchar_t` format road and `numpunct<wchar_t>` into a `char` program. (0.112)
- The word `static` sits in the innermost base's qualifiers, so a static pointer or array member is a static
  (`cpp_static_type`); else a class of statics was no empty base. `staticbase.cpp`. (0.72)
- `cpp_register_class_extras` records the static initializers in `'$cpp_sinit'`, also one defined out of the
  class in its header (`inline constexpr strong_ordering strong_ordering::less(...)`). Such a class-typed static is the
  class's own `linkonce` definition, never an Itanium symbol that nothing ships. (0.101)
- A library class's static that the header declares and does not define is named by its Itanium symbol
  (`cpp_static_name`); one with its initializer in the class is defined here as `C.N` (`cpp_static_here`). (0.73, 0.90)
- Out of the class, `int Counter::made = 0` is the global `Counter.made` (`cpp_item`). Several declarators, `int
  Tag::made = 0, Tag::gone = 0;`, become one item each; else `member_of_class` reached the lowering. (0.33, 0.101)
- A folded static const KEEPS THE MEMBER'S TYPE where it stands in an expression (`cpp_static_value/3`,
  `cpp_typed_const/4`): an arithmetic type other than `int` makes it `cast(T, int(K))`, an enumeration excepted. Else
  `static const long long v = -3;` named `A::v` was the INT literal -3 passed to a variadic call as an int
  (`printf("%lld", A::v)` printed 4294967293: libc++'s `ratio<-1, 2>::num`), and `static const unsigned n = 4; n - 5`
  was an int. `staticconsttype.cpp`. (0.117)
- A static const named bare in its class folds to its value (`cpp_expr(id)` via `cpp_static_const/3`,
  `cpp_fold_static`), as `C::value` does. The fold looks through the bases, and a nested class sees its holder's
  statics (`'$cpp_encl'`): `__long` divides by `__endian_factor`. (0.60, 0.63)
- A class-scope enumerator is a constant of the class (`cpp_class_enums/2`), kept raw in `'$cpp_sinit'` and
  folded in the class's words: `__min_cap` in members and array bounds. An enum that types a data member declares its
  enumerators so too (`cpp_member_enum/2`): libc++ 18's `__consume_result` writes `enum : char32_t { __ok, __error }
  __status : 1 {__ok};`. `memberenum.cpp`. (0.63, 0.112)
- A static named through an object, `__ct.space`, is the static: its constant, else its global
  (`cpp_static_through_object`, in `cpp_expr`'s member and arrow clauses). (0.75)
- An `auto` static takes its initializer's type, desugared in its class (`cpp_static_auto` in `cpp_declare_statics`),
  as a namespace-scope `auto` object does (`cpp_vars`). (0.109)
- A static data member of the PROGRAM's class is declared under its type resolved through the template road in its
  class (`cpp_declare_statics` over `cpp_type`), so `Words::yes.size()` over a `static constexpr std::string_view` is
  the member call. Why: resolved by the table alone, it named the instance's struct with no class registered. A
  library class keeps the table's type: resolving every library static at registration took std::format past 3.5 GB.
  `staticsv.cpp`, `widesv.cpp`. (0.115)
- A header's inline global of an empty class is its zero bytes, no constructor run (`cpp_lazy_inline_var`): `nullopt`,
  `in_place`, `piecewise_construct`. (0.82)

### Defaulted and deleted members

- `cpp_norm_members_` drops a member `= delete`, a deleted member template included (`cpp_member_body` through
  `template/3`): kept, unique_ptr's deleted constructor won and had no body. It drops `= default` as the implicit
  member, except that a copy or move constructor becomes memberwise, `==` and `<=>` are synthesized, and `C() = default`
  is recorded. It marks a pure method `pure`. (0.44, 0.92)
- A defaulted `==` or `<=>` ([class.compare.default]) is synthesized at `cpp_norm_members_` (`cpp_defaulted_cmp`): the
  first base sub-object with storage, then each data member, an array element by element (`cpp_cmp_pieces`,
  `'$cpp_norm_bases'`). `cxx20cmp.cpp`, `defaultcmp2.cpp`. (0.93, 0.99)
- A defaulted `<=>` answers the first non-zero `>` minus `<`, typed as the written class, else the members' common
  category where `<compare>` is included, else `int` (`cpp_defaulted_ordering`). Under `partial_ordering` a floating
  piece is -127 (unordered) where a side is a NaN (`cpp_cmp_sign`). A defaulted `<=>` adds a defaulted `==` only where
  none is declared. `stdcompare.cpp`. (0.101, 0.103)
- `a <=> b` on a class calls its `operator<=>`, else refuses `three_way_comparison_of_a_class(C)`. (0.42)

### Unions

- A union that declares a constructor or a method is a CLASS whose members share storage (`'$cpp_union'(C)`): a
  class's whole road, a union's layout. Its tag starts with `union_tag` (`ccl_is_union_tag/1`, the one test); it is
  emitted as `union(C, [union_tag|Data])` and answered by `ccl_tag_type/4` and `cpp_class_of_type_`.
  `basic_string::__rep`. (0.63)
- A union class's constructor initializes only the members an initializer or a default member initializer names
  (`cpp_union_inits/4`); the others share the bytes. (0.63)
- A nested union is a nested type (`cpp_nested_name`, `cpp_nested_spec`): with a constructor or method a union class
  (`cpp_nested_union_class`), else a plain union emitted once at file scope as `Holder.Name`. (0.63)
- A union at NAMESPACE SCOPE with a constructor, a destructor or a method is a union class too (0.121):
  `cpp_register_`'s clause over `cpp_union_class_members/1` -- the one test, which `cpp_nested_union_class` asks as
  well, with a destructor among the members now -- registers it with `'$cpp_union'` and `cpp_item`'s clause emits
  `class(union, N, [], Ms)`. The reader keeps it `union(N, Ms)`, which the lowering took for a plain union and refused
  at its first use, `class('U')`; a union of data members alone stays C's. `ccl_data_members/2` leaves the tag's
  `union_tag` out of the member list, so `U u = {5}` names the FIRST MEMBER. `unionclass.cpp`, `uniondtor.cpp`.
  (0.121)
- A UNION'S DESTRUCTOR DESTROYS NO MEMBER ([class.dtor]/16; `cpp_dtor_body`): the members share their storage, and
  which one is alive is the program's to say. libc++ 18's `__union` writes `~__union() {}` and `std::variant`'s own
  destructor destroys the active alternative; every member destroyed by the union freed a string twice.
  `uniondtor.cpp`. (0.121)
- A union TEMPLATE and its specializations are class templates (`cpp_template_defined`, `cpp_template_class_def`,
  `cpp_instance_class`, `cpp_spec_name`): the instance is a union class (`'$cpp_union'`, asserted in
  `cpp_instance_body_`). `std::variant` keeps its alternatives in `union __union<_Trait::_TriviallyAvailable, _Index,
  _Tp, _Types...>`. `varvisit.cpp`, `uniondtor.cpp`. (0.121)
- A union class's memberwise copy or move is its bytes, `memcpy` from the source's address (`cpp_ctor_body`'s
  `memberwise` clause). Why: as an assignment the two sides were typed by two roads and LLVM refused the load. (0.84)
- An anonymous union member is initialized by name through the member it became (`cpp_union_member_init`): a class
  constructs, a scalar is assigned, `m()` zeroes. Its memberwise copy is its bytes (`memcpy` in `cpp_member_inits`).
  Why: optional's storage, `: __val_(...)`, never engaged. (0.82, 0.83)
- An anonymous struct inside an anonymous union is ONE member of the union, its fields in sequence
  (`cpp_norm_union_members/3`), and a data member is found through every hidden member on the way (`cpp_anon_path/3`
  in `cpp_data_member`). `anonstructunion.cpp`. Why: flattened into the union, libc++ 18's `basic_format_args` laid
  `__types_` over `__values_`, and `std::format`'s `get(i)` crashed. (0.112)

### Nested classes

- A nested class is a type of its holder and a class of its own, `Enclosing.Nested`. `cpp_nested_names/3` notes its
  name first (`'$cpp_ctype'`, `'$cpp_nested'/5`), so a member of that type resolves before the class exists. It
  registers after its holder (`cpp_nested_classes/3`), or on the first ask through `cpp_class/2`
  (`cpp_nested_ready/1`). It is `Plain::Nested` outside, bare inside, and a temporary by either name
  (`Plain::Nested(7)`, `__destroy_vector(*this)`). `nested.cpp`. (0.48, 0.58)
- `cpp_nested_ready/1` marks the class in progress in `'$cpp_nesting'` while it registers, and clears the mark on
  success, failure and throw; a mark left behind fails every later ask. The holder's own registration can ask for it:
  vector's members name `_ConstructTransaction`. (0.58, 0.72)
- A nested class sees its holder's types, inherited ones included, and its statics: `cpp_encloses` records
  `'$cpp_encl'`, which `cpp_class_typedef/4` and `cpp_static_const/3` fall back to. (0.52, 0.63)
- A non-const static of the holder is found by name too, in the nested class's methods and in a lambda made there
  (`cpp_static_member/3` and `cpp_static_owner/3` walk `'$cpp_encl'`; [class.nest]/4). Why: only a static const
  was looked up there, so `scale` in `Outer::Inner`'s lambda was undeclared and the lambda's result could not be
  deduced, `lambda_result_type`. `nestedlambda.cpp`. (0.112)
- A nested class calls a STATIC member FUNCTION of its holder by its bare name ([class.nest]/1; `cpp_call`'s clause over
  `cpp_encl_chain/2` and `cpp_static_bare/2`): `compute()` in `A::N::get` is `A::compute()` with no object. A non-static
  one needs an object of the holder, which a nested class has none of. The data statics were found so since 0.112. The
  access check is the nested class's own (a member of the holder). `accessctl2.cpp`. (0.117)
- A nested type named as a type registers on the first ask, whatever its kind (`cpp_type`'s nested-tag clause): a lazy
  library instance never runs its holder's nested registrations (`basic_string::__rep`, `__short`, `__long`). (0.63)
- Inside a nested class's body its own short name takes the nested type with no guard, and the class is made ready
  afterwards: the nested-tag clause runs before the guarded one (`cpp_ctd_key`). Why: `coroutine_handle<promise_type>`
  keyed its instance by the free name. (0.108)
- A nested class declared in its holder and defined out of it (`class locale::facet : public __shared_count`) is
  `Holder.Nested` (`cpp_class_item_name`) in the index, the registrations and the emission. `class facet;` inside the
  holder names the type and registers no class (`cpp_nested_name`'s `class(N, none)` clause); the holder's types are in
  scope inside (`cpp_encloses`). `facet.cpp`. (0.71)
- A nested class known by name alone (`class locale::id;`) loads when its name resolves as a type
  (`cpp_touch_nested`), so its struct exists for the lowering. A nested class of a lazy class is lazy
  (`cpp_lazy_instance`): its members come as they are used. (0.72, 0.73)
- A nested class defined out of its class template is kept by the enclosing class's name (`cpp_mdef_item`'s class
  clause, key `nested(N)` in `cpp_member_shape`) and merged into the instance's forward declaration. Its out-of-class
  members are `in_nested(N, M)`, keyed `nested_member(N, K)`, merged once it is whole (`cpp_nested_defs`,
  `cpp_member_def_key`): basic_ostream's `sentry`. (0.72, 0.73)
- A nested enum is a type of its holder (`cpp_nested_enum`): one tag `Enclosing.Name`, emitted once at file scope, its
  enumerators global names. A scope path ends at a type of the class that is no class (`cpp_scope_walk`), so
  `B::strong::two` is the enumerator, never a static `B.two`. `nestedenum.cpp`. (0.71)

### Friends

- A hidden friend, a friend defined in the class body, is split out of the members at registration
  (`cpp_split_friends`) and registered as the free function it is (`cpp_register_friends`); a friend template is a
  template. A friend only declared names a function defined elsewhere and makes nothing. `<iomanip>`'s inserters and a
  program's `operator<<` are written so. (0.78)
- A plain hidden friend of the program's class is declared at file scope and emitted with the class
  (`'$cpp_friends'`, `cpp_item`). One of a library class is a lazy header function emitted where it is called, its
  types resolved and its body walked in the class (`'$cpp_friend_in'`, 0.112). Why: filter_view's iterator
  `operator==` read `__iterator` in the caller's words. (0.78, 0.112)
- A library class's hidden friend sees the class's statics (0.117; [class.friend]/7): its body is walked with no `this`
  and no `Ctx`, so a bare static const resolves through the class context set around it (`cpp_expr(id)`: `Ctx == none,
  cpp_class_ctx(Cx)`): libc++'s `__bit_iterator::__bits_per_word` in the friend `operator-`. A declaration-specifier may
  stand BEFORE `friend` (reader 113, `constexpr friend difference_type operator-(...)` at C++20; `friendprefix.cpp`):
  the word was no first word of anything and the operator was never registered (`no_operator(-)` for
  `std::bitset::count`). (0.117)
- The program's hidden friend has its result and parameters resolved in its class (`cpp_friends_resolved`). A friend
  TEMPLATE, of the program or of a library class, is in its class's words (`cpp_friend_tmpl_words`: a member class
  template's short name, the class's typedefs, the class's own short name), and its body is walked in the class
  (`'$in_class'(C, Body)`, read by `cpp_stmt_`). Why: the friend `operator==` of a member class template named `It` and
  `__iterator` unresolved, and took a sentinel by arity. `friendclash.cpp`, `friendtmpl.cpp`, `viewkeys.cpp`. (0.115)
- A free operator is an overload set like a function's (`cpp_free_operator`): noted by word and arity, `op.eq.2`,
  always named by its parameters (`cpp_fn_overloaded`), chosen through the free-function road. Why: two classes'
  friend inserters took each other's arguments. (0.78, 0.79)
- A defaulted friend `operator==` compares the data members in order, statics excluded (`cpp_friend_item` over
  `cpp_cmp_pieces`); it is never emitted as the word `default`. (0.101)

### Access control

- `public`, `private` and `protected` are checked for the PROGRAM's own classes (0.117; read and ignored since 0.34). A
  library class's discipline is the library's, as its functions are not checked: nothing is asked where `'$cpp_in_lib'`
  is `yes`. `cpp_register_class/5` notes at registration (`cpp_note_access/3`) the access each member NAME was declared
  under, `'$cpp_acc'(Class, Name, Access)`: a `class` starts private, a `struct` and a `union` public, `public:` and kin
  move it on, a `using Base::m;` puts `m` under the access it stands at, an anonymous aggregate's members are the
  holder's, `'$ctor'` and `'$dtor'` stand for the special members, and an overload set is as open as its most open
  member (`cpp_acc_put/3`: a name is refused only where every overload is). `'$cpp_afriend'(Class, class(F) | fn(F) |
  any)` holds the friends: `friend class F;` (`friend_class(Q)`, a template-id by its template's name; the name of a MEMBER class
  template's friend is its short name, and every instance of that template is the friend, `cpp_friend_is/2`: `friend class
  S<!C>;` inside `V<T>::S`, 0.118), a friend function by its name -- a friend function TEMPLATE's instance is the friend, named `F.<keys>` (`cpp_fn_is/2`) -- and
  `any` for a friend class template or anything the note cannot name, which opens the class to everyone. (0.117)
- `cpp_check_access(Ctx, C, N)` asks it where the walk of the program NAMES a member: `x.m`, `p->m`, a bare `m` in a
  member function or a derived class's, `C::f()`, a method call, the constructor chosen for a local and for a `new`. It
  refuses by name, `access(Kind, Owner, Member)`, with the statement's line (`'$cpp_line'`, set in `cpp_stmt/3`). The
  owner is the class on the way down through the bases that declares the name (`cpp_acc_owner/4`). The code may name a
  member when its scopes (`cpp_access_scopes/2`: the class it is a member of, the classes that class is nested in
  through `'$cpp_encl'`, a lambda's through the class it was made in) include the owner, or -- for a protected
  member -- derive from it, or a friend matches (`cpp_friend_match/2`: a class by name or instance, a function by
  `'$cpp_cur_fn'`, which `cpp_with_fn/2` sets around a function's body). A static member's initializer defined out of
  its class is in the class's scope (`cpp_with_access_scope/2`). Refusals: `test/cpp/access_data.cpp`,
  `access_method.cpp`, `access_protected.cpp`, `access_ctor.cpp`, `access_base.cpp`; allowed forms: `accessctl.cpp`,
  `accessctl2.cpp` (a private nested type, a private virtual function called through the public one, a protected
  constructor, `using` to open a base's member, friends of every kind, lambdas in a member function). `test/cpp.pl`'s
  `c38` checks the reader's forms. (0.117)
- The forms 0.117 left unasked are asked since 0.127:
  - AN INHERITANCE'S ACCESS ([class.access.base]/1): `class D : private B` (a class's unwritten one private, a struct's
    public) makes B's public and protected members D's private ones, `protected B` D's protected ones. The base's access
    is noted as written (`cpp_note_base_access/3`, `'$cpp_bacc'(Class, Base, Access)`) and matched to the resolved base
    where it is asked (`cpp_base_access/3`); `cpp_acc_base/5` narrows the member's access on the way down, a library
    base's member counting public. A constructor and a destructor are the class's own, never looked up in a base.
    `access_inherit.cpp`.
  - [class.protected]: a protected NON-STATIC member named through an object (`cpp_check_access_obj/3` at `x.m`, `p->m` and
    a method call), from a class S derived from its owner, only on an object of S or of a class derived from S
    (`cpp_may_access/5`, `cpp_protected_object/4`). `access_protobj.cpp`.
  - A POINTER TO MEMBER: `&C::m` names m (`cpp_expr` on `addr(scoped(...))`). `access_memptr.cpp`.
  - The NAME OF A NESTED TYPE: a nested class, struct, union or enum and a class-scope typedef are noted with their
    access (`cpp_access_decl` through `cpp_nested_type_name/2`), and `Outer::Secret` asks it where `cpp_type` resolves a
    scoped name. `access_nested.cpp`.
  - A DESTRUCTOR: a local's defer and a `delete` ask `'$dtor'`. `access_dtor.cpp`.
  - AN OPERATOR USED AS ONE: a member operator chosen by `cpp_operator/5` is a member named, asked from the body being
    walked (`'$cpp_body_ctx'`, set and restored by `cpp_method_body_`; `cpp_body_ctx/1`); a member operator is noted by
    its `operator(Op)` name, a conversion function aside. `access_operator.cpp`.

  Allowed forms of all six: `accessctl3.cpp`. (0.127)

### new, delete and placement new

- `new C(As)` constructs into `new(T, [])`'s block through the chosen constructor (`cpp_new`); `new T` of a type
  without constructors is malloc's block (`new(T, As)`). (0.33)
- `delete p` of a class with a destructor is `comma(dtor(p), delete(p))` (`cpp_delete`); a pointer that is no name
  goes through a temporary, else the check sees a borrow freed. A virtual destructor runs through its slot
  (`cpp_destroy`). (0.33, 0.34)
- Placement new constructs where it is told and allocates nothing (`cpp_new_at/4`): `::new ((void *) __p) _Up(args)`
  is `std::__construct_at`. A class with constructors is built over the address, the copy pass on the call. A value of
  the class itself is its bytes where the class writes no copy or move constructor, has no destructor and needs no
  implicit constructor (`cpp_trivial_copy_init`). One value, or a non-class scalar's zero, is stored through the
  address. Else it refuses `placement_new(T, NP, NA)`. (0.61, 0.79)
- `new (p) T[n]`, `T[n](...)` and `T[n]{...}` construct n elements over p with no allocation and no array cookie
  (`cpp_new_at_array/6`, [expr.new]/17): the written items construct the first elements (`cpp_new_items/5`), a loop of
  placement news default-constructs the rest, and a scalar or trivial element type is zeroed with the items stored over
  it; the result is a borrow of the placement address (the `$at` prefix). Refused as `placement_new_array` until 0.117.
  `placearray.cpp`. (0.117)
- Where no constructor runs, placement new stores what [expr.new]/24 says (`cpp_placed_value`): no argument
  value-initializes, a scalar's zero or a struct's or a union's every byte zero; one value of the type itself, or a
  scalar's one value, is copied; anything else is a struct's items, braced or (C++20) in parentheses. Why: a plain
  struct took the scalar zero of `cpp_zero_of/2`, an `int' stored into a struct. `placeplain.cpp`. (0.112)
- The result of a placement new borrows the address it was given (`ck_borrows_from` on the desugaring's `$at`):
  `int *p = new (buf) int(7)' over a local buffer was a loose pointer, `plain pointer not consumed'. (0.112)

### Range-for and structured bindings

- A range-for over an object with `begin()` and `end()` is C++'s ([stmt.ranged]; `cpp_stmt_(for_each)`): `$it` and
  `$end`, the iterator's own `!=`, `++` and `*`; a prvalue range binds to `auto &&` (`$range`); a structured binding
  as the declaration becomes `bindings/4`. It comes before the `size()` and `operator[]` rewrite, which needs an lvalue
  range (`range_for_over_a_value(C)`). Why: indexed by position, a map inserted the keys 0, 1, 2. (0.41, 0.79)
- A PRVALUE range of a class with a destructor is taken out of the loop statement's register of temporaries before the
  `auto &&` declaration is made (`cpp_temp_elide` in `cpp_stmt_(for_each)`): the declaration is a statement of its own,
  whose elision looks in its own register, so `for (auto x : std::vector<int>(3, 7))` destroyed the vector twice, the
  loop's statement and the `$ext` defer, a double free since 0.41. A call returning the class by value was never
  registered. `tempinitlist.cpp`. (0.117)
- A `for`'s init declaration is in the for's own scope ([stmt.for]/1), `{ decl; for (; c; s) b }`, so `auto` deduces
  and a class local constructs there. (0.79)
- A deferred structured binding (`cpp_stmt_(bindings)`) types its initializer (`cpp_arg_type`, else
  `bindings_untyped`) and holds it in a temporary `$bind`, a reference for `auto &` over an lvalue. Where
  `std::tuple_size<E>::value` folds, each binding is a reference to `get<i>(e)` (`cpp_tuple_size`,
  [dcl.struct.bind]/4); else the data members bind by position, `$base` and `$vptr` skipped, a count mismatch refusing
  `bindings_count`. A binding to a reference member is a reference (`cpp_binding_vt`): copied, the tree stored its new
  node into nothing. (0.79, 0.90)

## Templates

### Instantiation on use and the registries

- A template instantiates where it is used. Every type the walk meets goes through `cpp_type/2`, which turns a
  template-id into its instance's name. The table built before the walk holds template-ids raw; `cpp_class_of_type_/2`
  instantiates one on sight, and a rewritten typedef is noted at once (`ccl_note_typedefs`). (0.35)
- The registries are facts, one row per name: `'$cpp_tmpl'(N, TPs, Item)`, `'$cpp_spec'(N, TPs, Pattern, Item)`,
  `'$cpp_mt'(C, Key, TPs, M)`, `'$cpp_mdef'(C, Key, TPs, Pattern, M)`, `'$cpp_inst'(Name, What)`, `'$cpp_out'(Item)`
  (`cpp_reset/1`; written by `cpp_template_put/3`, `cpp_spec_put/4`, `cpp_mt_put/4`). A template item emits nothing.
  Why: a global list is copied at every lookup. (0.35, 0.44)
- `cpp_instantiate_class/3`: an instance asked again answers its name (`'$cpp_iname'(N, Args, Name)`, arguments
  compared with `==`). Else `cpp_class_template/3` gives the primary, a definition first, defaults merged from the
  other declarations (`cpp_merge_defaults`), or refuses `template_without_body(N)`. `cpp_bind_targs/3` binds,
  `cpp_constraints_hold/3` checks the head and `cpp_instance_name/4` names. Inside `\+ \+`, `'$cpp_inst'(Name,
  inst(N, FullArgs))` is recorded, the injected class name binds to the instance, and the body takes its out-of-class
  members (`cpp_member_defs/5`), registers (`cpp_register_class`) and is desugared under `cpp_isolated/1`. (0.35, 0.68)
- `cpp_isolated/1` sets the caller's open scopes aside, so an instance sees no caller local and declares at file
  scope. It restores them on success, failure and throw, as `cpp_in_class/2` and `cpp_as_lib/2` do: SFINAE throws by
  design (`__to_address`). (0.47)
- It sets the CALLER aside too (`'$cpp_caller'`, which `cpp_arg_type` reads an argument's words from): an instance
  made while a call's arguments are typed is no part of that call. Why: `std::vector<std::vector<int>>`'s copy read
  the inner vector's arguments in the outer call's class. `stdvectorvector.cpp`. (0.112)
- It sets the CALLER'S OBJECT aside too: the constness and the value category of the object a member call is chosen on
  (`'$cpp_obj_const'`, `'$cpp_obj_cat'`) are `none` in an isolated walk. Why: an emission made while a const object's
  call was chosen walked its body under `const`, and in `__copy_loop::operator() const` the non-const
  `back_insert_iterator::operator=` was no candidate (0.113's rule): `*__result = *__first` stored a `char` into the
  iterator. `isolatedobj.cpp`. (0.115)
- `cpp_flush_instances/2` appends `'$cpp_out'` to the unit's items, and repeats while new items make more. (0.35)
- An emission is IN PROGRESS while it runs (`'$cpp_making'`, `cpp_making/1`) and NOTED in `'$cpp_inst'` only when
  done; a throw clears the mark. This covers member, constructor and function template instances
  (`cpp_make_member/9`, `cpp_try_ctor`, `cpp_instantiate_function_`), lazy members (`cpp_make_lazy/5`) and library
  free-function overloads (`cpp_use_fn`). Failure refuses `member_instance_not_emitted`, `member_not_emitted` or
  `function_not_emitted` (a class: `instance_not_emitted`). Why: a SFINAE catch abandoned an emission noted too early
  (`allocator<string>::construct`). (0.69, 0.73)
- A class template declared and never defined is an incomplete type that a template argument may name
  (`cpp_incomplete_instance/2`, trace `incomplete(Name)`): a name and arguments that patterns match
  (`__single_iterator<_It>`). A registered body not taken refuses `template_without_body(N)`. (0.58)
- A library template's instance is lazy: members are made where used (`cpp_lazy_instance/2`). So is an instance over a
  class still being registered ([temp.inst]/4; `cpp_incomplete_arg`), and `__is_class` of that class is true
  (`cpp_trait_of`). Fixture: `crtpconcept.cpp` (`ref_view<R> : view_interface<ref_view<R>>`). So is a PLAIN class of a
  header that is being loaded (`cpp_class_in_progress/1`: marked `'$cpp_lib'`, its record not made yet, its definition
  in the index): its bases are instantiated before its record exists, and libc++ 21's `struct __fn :
  __range_adaptor_closure<__fn>` asks `requires is_class_v<_Tp> && same_as<_Tp, remove_cv_t<_Tp>>` of its CRTP base while
  `__fn` is registering -- the constraint failed and every `v | views::drop(5)` was `no_operator(|)`. The views
  fixtures at libc++ 21 (`viewdrop.cpp`, `viewtake.cpp` ...) are its gate. (0.52, 0.110, 0.126)
- The PROGRAM's own class template instances are lazy too ([temp.inst]/3; 0.127): `cpp_lazy_instance(prog, Name)` marks
  one `'$cpp_lazy_p'` (`cpp_is_lazy/1` answers either mark), a member is made where it is used, and what such a member's
  walk emits is the program's, checked by the safe part (`cpp_lazy_lib/2` keeps it out of `'$cpp_libfn'`; a library
  class tests `'$cpp_lazy_c'` alone). A nested class takes its holder's kind of mark. Fixture: `lazymember.cpp`. Why: every
  member was instantiated, and `D<Q>::sum()` naming `this->x` over a `Q` without `x` was refused though nothing called
  it.
- An instance whose BASE is still being registered WAITS for it (`cpp_instance_body/4`, `cpp_base_in_progress/1`):
  naming `__list_node<int, void *>` as the pointee of a typedef instantiates it, and its base `__list_node_base<int,
  void *>` is the class whose registration asked for that typedef; C++ asks no definition of a pointee, and the instance
  refused `base_not_registered`. The registration is recorded (`'$cpp_deferred'(Name, N, Args, Item)`, trace
  `deferred(Name)`) and runs when the class is first looked up (`cpp_class/2` through `cpp_run_deferred/1`, trace
  `deferred_run`), by which time the base is a class; the base in progress is an atom with `'$cpp_inst'` and no
  `'$cpp_cls'`, or a template-id whose instance is such. `std::list` (`__list_imp`, `__list_node_base`). `stdlist.cpp`.
  (0.117)
- Where one flattened name has CLASS TEMPLATES OF DIFFERENT PARAMETER KINDS, the first whose parameters take the
  arguments is the one (`cpp_class_template/4`, `cpp_tparam_kinds/2`, `cpp_kinds_fit/2`: a type parameter takes a type,
  a value parameter a non-type, a template parameter anything, a pack the rest, a default the missing ones; the
  arguments must also bind). The namespaces told them apart in C++ and the flattening lost them: `<variant>` defines
  `template <class _Tp, size_t _Idx> struct __overload` in `std::__variant_detail`, `<__algorithm/copy_move_common.h>`
  `template <class _F1, class _F2> struct __overload : _F1, _F2` in `std`, and `<iterator>` pulls `<variant>` in, so
  `std::copy` of trivially copyable ints, reached from `std::vector<int> v = {1, 2, 3}`, met the wrong one
  (`arity_mismatch`). A name with one kind is untouched. (0.117)
- THE BUDGET: `cpp_spend/1` counts instances and header loads, and refuses `instantiation_budget(K, What)` past 3000;
  `cpp_deeper/1` counts nested class instantiations, and refuses `instantiation_depth(D, What)` past 120. Why: an
  unbounded `std::vector<int>` took the machine's memory. (0.44)

- An `inline` function template's instance is `linkonce` like a plain one (`cpp_linkonce/2` takes the storage `none`
  or `inline`; 0.121): libc++'s `__invoke` instances were plain definitions, never dropped, and the one over
  `std::variant`'s overload set called a function that is only declared, a link error.

### Instance names and type keys

- `cpp_instance_name/4` joins the template's name and a key per named parameter with `.` (`Buf.int.4`). An operator
  member template is `op.<word>` (`cpp_instance_base/2`: `op.call`). A function template name with several candidates
  gives `F.c<K>.<keys>`, K the candidate's position. A library function template's instance with no body anywhere
  takes the shipped Itanium symbol (`cpp_ita_fn_instance`). (0.35, 0.48)
- `cpp_type_key/2`: specifiers joined by `_`, `const` and `volatile` first (`cpp_cv_key`: `const_int`); a pointer `_p`
  with its own `c` or `v` (`int_pc` is `int *const`), a reference `_r`, an rvalue reference `_rr`, an array `_a`, a
  member pointer `C_mp_<T>`; a function type `fn_<R>_<Ps>`, `_z` if variadic, by types and never parameter names; a
  pack its keys joined by `_` (`e` if empty); a template template argument its name, a member alias template `C.N`; a
  literal its value and suffix (`4`, `4u`, `4l`, `4ul`, `4wb`), `m4` if negative, `c<code>` for a char, `1` or `0` for
  a bool, so `true` and `1` name one instance. (0.42, 0.74)
- A key carries `const` and `volatile` and no other qualifier (no `own`, `tie`, `fresh`, marker). Why:
  `is_const<const int>` was `is_const<int>`, and `__tuple_like_ext<const T>` derived from itself. (0.95)
- An integer type has ONE spelling, the shortest, in keys and comparisons ([basic.fundamental]/2; `cpp_int_spelling/2`
  in `cpp_type_key` and `cpp_canon_specs`): `signed int` and `signed` are `int`, `long int` is `long`, `unsigned int`
  is `unsigned`; `signed char` stays apart from `char`. Fixture: `intspell.cpp`. Why: `__libcpp_is_signed_integer
  <signed int>` never matched `int`, and `std::format` took an int for a `__handle`. (0.112)
- A scoped template-id keys by name and argument keys (`cpp_spec_key`: `initializer_list.string`); a namespace path
  keys nothing. (0.84)
- A function's parameter key drops each by-value parameter's top-level cv ([dcl.fct]/5; `cpp_param_fn_type`,
  `cpp_no_cv` in `cpp_params_key`, `cpp_params_keys_seq`): `f(int)` and `f(const int x)` are one. (0.95)
- An unnamed template parameter is named by position, `$anon1` ... (`cpp_name_anon/2` at the three doors), so it binds
  and keys alike where emitted and where called (`tuple_element<size_t, class>`). (0.79)
- Two types are the same when they name one class with the same qualifiers, are equal, or key alike
  (`cpp_same_type`); two references, pointers or arrays of one shape are the same when what they refer to is the same
  (`cpp_same_compound`), since the resolution does not reach under a reference. Fixture: `arrayref.cpp` (`const
  uint32_t &` and `const unsigned &`). (0.79, 0.109, 0.112)

### Template arguments

- `cpp_bind_targs/3` binds in order: a pack takes the rest (`P-pack(Rest)`), a template template parameter a
  template's name (`cpp_tname_arg/3`), a missing argument its default under the earlier bindings, else
  `template_argument_missing(P)`. (0.35, 0.44)
- An argument is EVALUATED where it binds, on every road (`cpp_bind_targs_/4`, `cpp_bind_explicit/3`, via
  `cpp_targ_value`). One that does not evaluate binds raw and traces `targ_raw(P, A)` (`__align_it<__boundary>(n)`).
  (0.63, 0.100)
- A value argument naming a plain local refuses `template_argument_not_constant(P, A)`. An unfolded call or class
  static stays keyed as written: libc++ folds `__find_exactly_one_t<...>::value` inside the instance. Fixture:
  `targkeys.cpp`. (0.98)
- An explicit argument's KIND is checked ([temp.arg]; `kind_mismatch(P)` in `cpp_bind_explicit`): `get<0>` is no
  candidate of the by-type `get`. (0.79)
- A call's explicit template arguments go through `cpp_call_targs`: a variable template id or a concept-id to
  `cpp_targ_value`, the rest to `cpp_type` (`__introsort<..., __use_branchless_sort<...>>`). (0.92)
- `cpp_targ_value` evaluates one argument:
  - `X<T>::N` is a value where X's class has no type N, a type where it has one; with neither a type nor a member N it
    refuses `no_member_type(C, N)`, the SFINAE rejecting `typename _Up::category` (`detect2.cpp`) (0.47).
  - A scoped name that is a type of its class is a type, also in an expression (`scopedtarg.cpp`) (0.100).
  - A scoped enumerator is its value (`cpp_enum_scope`; `ttleak.cpp`) (0.93).
  - A concept-id is its truth, a variable template id its value (`cpp_variable_template/1`) (0.48, 0.84).
  - `X::template f<U>()`, read as a function type, is the CALL where X's class has that member template (pair's
    `__is_pair_constructible`) (0.72).
  - A static const named bare folds (`__str_find<..., npos>`) (0.84).
  - A member alias template's name is `tname(mt(C, N))`; `C::template ap<T>` is a type (0.93, 0.109).
  - Anything else is desugared in its class (`cpp_class_ctx`) and folded (`aligned_storage<sizeof(__buf_)>`) (0.88).

### Substitution

- `cpp_subst/3` substitutes the bindings once per instance. A type parameter becomes the argument with the written
  qualifiers merged (`cpp_merge_quals`): `const T` with T a pointer is a const pointer, with T an array has const
  elements ([dcl.type.cv]). A value parameter becomes its value. (0.35, 0.93)
- A path substitutes too (`cpp_subst_path`). A segment bound to a scalar, pointer, reference or function carries the
  type (`nonclass(A)`), and a name through it refuses `no_member_type(A, N)` (`cpp_type`) or `no_member(A, N)`
  (`cpp_expr`): SFINAE (unique_ptr's function-pointer deleter). (0.72)
- A CALLED bound type parameter has its arguments substituted first (`cpp_type_called/3`): one argument is a
  functional cast, none on a builtin or pointer the zero, and a class makes its temporary. A pack expansion is one
  element until it expands. Fixture: `packcall.cpp`. (0.90)
- A class bound as its TAG, a plain struct's form, names its class in a path too (`cpp_subst_path` over
  `cpp_tag_name/2`; 0.121): `using alt_type = remove_cvref_t<decltype(__alt)>; ... typename alt_type::__value_type` in
  the lambda of libc++ 18's `hash<variant>`. `stdvariant2.cpp`.
- A base clause or constructor initializer naming a bound type parameter takes the bound class (`cpp_subst` on
  `base(Access, Name)`, `virtual(P)`; `cpp_bound_base`). Fixture: `tpbase.cpp` (`__compressed_pair_elem`). (0.93,
  0.100)
- A method's and a constructor's qualifiers take the bindings (`cpp_subst_quals`): trailing return type, `noexcept`
  operand, trailing `requires`. Fixture: `stdbindfront.cpp`. Why: filter_view's constrained default constructor was
  checked over the free `_View`. (0.100, 0.112)
- `cpp_type` collapses references: `T & &&` is `T &` (`cpp_collapse_ref`). (0.78)
- A block typedef is substituted into the statements after it (`cpp_block_typedefs/2`): the typedef table is one per
  unit, and six libc++ functions declare their own `_ValueType`. (0.60)
- An initializer is walked once and handed on as `'$cpp_walked'(I)` (`cpp_decl_pieces`); walked twice, it declared a
  temporary twice and made two closures. (0.60)

### Packs and folds

- A pack binding holds a list (`cpp_pack_list`). `cpp_subst_elems` expands `pack(X)` in call and template arguments,
  `base(A, pack(Q))`, `item(D, pack(V))`, a builtin trait's `type(pack(T))` and `param(pack(T), N)`; a parameter pack
  becomes `N$1` .. `N$k`, bound as a `vpack` for the body (`cpp_param_packs`). An expansion handed through an alias's
  pack, `pack(id(_I1))`, is one element (`cpp_alias_binds`). Fixture: `generic.cpp`. (0.44, 0.79)
- Only BOUND packs expand (`cpp_pack_names`). An expansion zips the packs it names OUTSIDE its nested expansions and
  `sizeof...` ([temp.variadic]/5; `cpp_names_outside`), path segments (`cpp_names_in`:
  `__enable_if_t<_Pred::value>...`) and last-segment arguments (`std::get<_Idx>(__bound_args_)...`) included.
  Fixture: `packzip.cpp`. (0.93, 0.99)
- Packs of different lengths refuse `pack_lengths_differ(Ns)`, an expansion with no bound pack
  `pack_expansion_without_pack`, and a pack named outside an expansion `pack_unexpanded(P)`. (0.79)
- An expansion naming a class pack AND a member template's own waits for the member's instantiation
  ([temp.variadic]): `cpp_shadow` marks the member's pack `'$later'`, and the pattern travels as `pack_zip(Bound, X)`
  (`cpp_later_names`): `__tuple_impl`'s `__tuple_leaf<_Indx, _Tp>(std::forward<_Args>(__args))...`. (0.79)
- `cpp_fold_left/3` and `cpp_fold_right/3` fold an expanded pack. An empty fold of `&&` is `true`, of `||` `false`, of
  `,` `0`, any other refuses `empty_fold(Op)`. `sizeof...(P)` is `int(N)` once bound. (0.44)
- C++26 pack indexing (`Ts...[I]`, `args...[I]`) substitutes once the pack is bound (`cpp_pack_at`), else refuses
  `pack_index_not_constant(P)` or `pack_index_out_of_range(P, K)`. (0.93)
- An array initialized with a pack expansion is sized after the expansion (`cpp_size_by_init` in `cpp_decl_pieces`):
  `common_comparison_category`'s `__type_kinds[]`. (0.104)
- A BASE CLAUSE THAT IS A BARE PACK, `template <class... Ts> struct overloaded : Ts... { using Ts::operator()...; };`
  (0.121): the reader gives the pack's name as an atom, `base(Access, pack(Ts))`, and the expansion looked for a path
  or a template-id there. `cpp_subst_elems` takes the atom (`cpp_pack_list`, `cpp_bound_base`: one base per element,
  as a single parameter's base is) and expands `using(L, pack(Q))` into one `using(L, name(Q1))` per element. A
  closure that captures nothing is an empty base. `overloaded.cpp`. (0.121)

### Dependent names and scopes

- A class's typedefs are `'$cpp_ctype'`; `cpp_scope_class/2` answers `C::N` from them, skipping namespace
  prefixes, and refuses `no_member_type(C, N)` where the class has no such type. (0.44)
- A path of two or more segments is WALKED first, each segment named inside the one before (`cpp_scope_walk/3`); one
  segment goes to `cpp_path_class`. Fixture: `scopewalk.cpp`. Why: in a class with its own `type`, `_ITER_CONCEPT`'s
  `__iter_concept_cache<_Iter>::type::template _Apply<_Iter>` took that `type`. (0.47, 0.112)
- `cpp_path_class` tries, in order ([basic.lookup.unqual]): a typedef the current class sees, resolved where defined;
  a registered class; an instance still being registered (`'$cpp_inst'`, `'$cpp_iname'`); a plain struct, never an
  enum (`NoPtr::pointer` refuses, `Color::Green` is the enumerator); `decltype(e)`, the expression's class; a
  template-id, its instance; a file-scope alias, the class it names (`std::string::npos`). (0.46, 0.93, 0.112)
- An instance still being registered is a scope ([class.mem]): its typedefs are noted before its members are
  resolved (`cpp_register_class_extras` first in `cpp_register_class__`), so a member's class template may read one.
  Fixture: `inprogscope.cpp`. Why: `basic_format_context` holds `basic_format_args<basic_format_context>`, whose
  `__basic_format_arg_value` reads `typename _Context::char_type`; flattened, it was the bare `char_type`. (0.112)
- A scope that is not found flattens as a namespace and traces `flatten(Path, N, in(W))`. (0.46)
- A typedef resolves in the class that DEFINES it (`cpp_class_typedef/4` looks in the class, its bases, its enclosing
  class; then `cpp_in_class/2`, context `'$cpp_class_ctx'`) and beats a namespace typedef of the same name. Fixture:
  `padding.cpp` (`allocator_traits`' `typename __base::pointer`). (0.46)
- A typedef that is its own definition (`typedef value_type value_type`) is left alone (`cpp_self_typedef/2`), and a
  class typedef that asks for itself while resolving stays as written (guard `'$cpp_ctd:C.N'`, `cpp_ctd_key`). Why:
  `initializer_list<_Ep>` with `_Ep := value_type` looped. (0.64, 0.86)
- `X::f(args)` on a class with no such member or type refuses `no_member(C, M, K)`: the detection of
  `pointer_traits<P>::to_address`. (0.72)
- A decltype's expression and a template argument are walked in the class that writes them (`cpp_class_ctx`):
  `decltype(__find_base(...))`, `aligned_storage<sizeof(__buf_)>`. (0.88)
- A COLLIDED CLASS NAMED THROUGH ITS NAMESPACES is its key (`cpp_path_keys/2` in `cpp_scope_class_`; 0.121):
  `ns::visitation::base::make_dispatch<F>(...)`, with `base` declared by three namespaces, was walked bare and met the
  first class of that name, which has no such member. A class segment that follows namespace segments is replaced by
  the key `cpp_ns_key` finds, as a type name's is in `cpp_type`; a class's own member segments are not looked at.
  `varvisit.cpp`.
- THE FIRST SEGMENT OF A QUALIFIED NAME is looked up in the item's own scope ([basic.lookup.qual]/1;
  `cpp_rename_names`'s `scoped` clause over `cpp_rename_qualifier/3`): `__base::__visit_alt(...)` inside `namespace
  visitation` is `visitation`'s class. The rest of the path is resolved where it is read (`cpp_ns_key`). (0.121)
- A USING-DECLARATION IN A BLOCK that names a class of a namespace whose items were indexed apart (`cpp_ns_key`) is
  that class under its short name for the statements that follow (`cpp_stmts`; `cpp_body_typedefs_` for a deduced
  result), as a block typedef is: libc++ 18's `std::visit` opens with `using
  __variant_detail::__visitation::__variant;` and calls `__variant::__visit_value(...)`, where the bare name is
  `__access::__variant`, another class. (0.121)

### Partial specializations

- A pattern shorter than the argument list is filled from the primary's defaults ([temp.spec.partial];
  `cpp_spec_pattern`: `__is_trivially_equality_comparable_impl<_Tp, _Tp>`). (0.92)
- A template-id INSIDE a pattern names its template with the defaults ([temp.arg]/2; `cpp_fill_pattern`). Fixture:
  `tmpldefaults.cpp`. Why: `__enable_insertable<basic_string<_CharT>>` matched no string, and `std::format` wrote into
  a `__writer_container<void>`. (0.112)
- `cpp_match_pattern` has TWO passes: `cpp_match_deducible` binds, then `cpp_match_later` substitutes, resolves and
  compares each non-deduced element (`cpp_non_deduced/2`): an alias template-id; a name whose qualifier names a
  parameter anywhere, template-id segments included (`cpp_path_dependent`); a `decltype`; a value naming a parameter
  ([temp.deduct.type]/5). A refusal or a free parameter is no match. Fixtures: `detect.cpp`, `ndpath.cpp`. (0.46,
  0.112)
- A pattern element binds as follows:
  - A type parameter binds the argument AS IT IS ([temp.deduct.type]/1; `cpp_match_targs`); the pattern's qualifiers
    must be on the argument and are stripped (`cpp_pattern_quals/3`). Why: `numeric_limits<const _Tp>` matched
    everything; `pair<_T1, _T2> &` bound `_T1 = string` for `pair<const string, int>` (0.48, 0.95).
  - A value compares by its constant (`cpp_same_value`): the one evaluator's, else the template argument's own road
    (`cpp_value_of/2` -> `cpp_targ_value`, so a NAME such as `dynamic_extent` is its folded value), and a value past
    2^60 is `big(Atom)`, no number to `=:=` -- compared by `ccl_w_cmp/3`, a decimal atom against a hex one alike. Else
    `span<_Tp, dynamic_extent>` matched nothing, the primary was instantiated with that extent and its members' `_Extent
    * sizeof(element_type)` ran past memory (0.44, 0.117).
  - A template-id matches an instance by its recorded arguments (`cpp_instance_of`, also via its struct spec) and
    deduces a template template parameter (`cpp_match_tmpl`) (0.46, 0.93).
  - A trailing pack takes the rest (`cpp_match_targs`) (0.79).
  - A function type matches result and parameters, a trailing pack the rest, never decayed ([temp.deduct.type]/8;
    `cpp_match_fparams`): `function<_Rp(_ArgTypes...)>` (0.88).
  - An alias of a class template-id deduces through itself (`cpp_alias_through`); an alias of an alias stays
    non-deduced (0.79).
- `cpp_pick_spec/4` keeps the matches whose constraints hold, the more constrained first (`cpp_by_constraints`),
  prefers a definition to a forward declaration of one specialization (`cpp_template_class_def/1`:
  `struct char_traits<char>;`), then takes the most specialized (`cpp_most_special`, `cpp_more_special` asked `once`:
  X's pattern as arguments matches Y's). (0.63, 0.109)
- The picked specialization is used only where it has a body (`cpp_template_defined`), else the primary's body, else
  the instance is incomplete. (0.46, 0.58)

### Function templates: candidates and choice

- `f<A>(x)` and `f(x)` of a function template go to `cpp_instantiate_function/4`. The candidates are the name's items
  in declaration order (`cpp_fn_candidates`): definitions and bodyless declarations (`cpp_fn_item/2`). (0.45)
- A redeclaration (same parameter key, template parameters alike by kind and name) takes the defaults another
  declaration gives (`cpp_fn_merge_defaults`, `cpp_fn_lend_defaults`, `cpp_same_tparams`): `__to_chars_integral`'s
  definition lacks its prototype's `= 0`. A free OPERATOR template's declaration is registered and indexed as its
  definition is (`cpp_template_name`, `cpp_fn_item`: the name is `operator(Op)`, no atom), and lends its defaults the
  same way: libc++ 21 declares `template <class _Tp, __enable_if_t<is_floating_point<_Tp>::value, int> = 0>
  complex<_Tp> operator*(const complex<_Tp> &, const complex<_Tp> &);` and defines it later without the `= 0`, which
  only the declaration gives; unregistered, the definition's `$anon2` had none, `cannot_deduce($anon2)` dropped it and
  `a * b` of two `complex<double>` had no operator. Reader 119 (the AST beside `<complex>`'s summary holds the
  declaration). `enabledecl.cpp`, `stdcomplex.cpp`. (0.73, 0.126)
- `cpp_signature_holds/7` holds when, in order: the arity fits with defaults, packs and an ellipsis
  (`cpp_arity_holds/3`, else `arity_mismatch`); explicit arguments bind (`cpp_bind_explicit`); arguments deduce
  (`cpp_deduce_args`); defaults fill (`cpp_bind_defaults`, else `cannot_deduce(P)`); no parameter type names a
  template parameter (`cpp_all_bound`); constraints hold (`cpp_constraints_hold`); each parameter accepts its argument
  (`cpp_params_accept`). A failed step traces `sig_failed(F, Step)`; the result type comes next (`cpp_result_holds`).
  (0.45, 0.84)
- A refusing candidate drops (trace `candidate(F, K, holds(Cost) | refused(W))`). With none left, the call refuses
  with the first reason (`'$cpp_first_refusal'`), else `no_matching_template(F)`. The global is the CALL's: a
  candidate check makes calls of its own, so each call keeps the enclosing call's value and restores it
  (`cpp_instantiate_function__`). Else `std::invoke`'s refusal named a nested `__sfinae_test_impl`'s reason. (0.44,
  0.112)
- The winner has the lowest `Conversions-Demerits` (`cpp_fewest_conversions`, `cpp_min_of`; demerits rank equal
  conversions only); then a definition beats a declaration (`cpp_defined_first/2`, else `std::swap`'s declaration
  won); then the most specialized (`cpp_most_special_fn`); then the first declared. Fixture: `overloads.cpp`. (0.51,
  0.94)
- A function template declared and never defined still instantiates, as a declaration: a decltype wants only its type
  (`declval`). (0.51)
- AN EXPLICIT SPECIALIZATION OF A FUNCTION TEMPLATE IS NO CANDIDATE ([temp.expl.spec], [over.match.funcs]/7; 0.129):
  overload resolution chooses among the templates, and the chosen one's instance for those arguments IS the
  specialization. `cpp_register_` keeps a `template(L, [], Function)` apart, `'$cpp_fspec'(Template, Args | none, Item)`
  (`cpp_fspec_item/3`: a function or a declaration, named by an atom, by `tmpl(N, Args)` or as a free operator), and
  `cpp_instantiate_function_emit` takes the body of the DEFINED specialization whose parameter types are the instance's
  (resolved, by-value top-level cv dropped), whose explicit arguments are the instance's bindings and whose result is
  the instance's unless either is deduced (`cpp_fspec_for/6`; [temp.deduct.decl]: a specialization deduces its arguments
  from its function type, the result included); trace `explicit_specialization(F, Name)`. Before 0.129 `template <> int
  f(unsigned long, int)` was one more template with no parameter, tied with the primary and lost to it, the first
  declared, and `template <> int f<char>(char, int)` went to the class specializations, which nothing reads for a
  function: every one was silently ignored -- libc++'s `__to_chars_itoa(char *, char *, __uint128_t, false_type)`
  printed `42` as twenty digits, and `<locale>`'s `__do_strtod<double>` is one too. A specialization declared and not
  defined here leaves the primary's body. `fnspec.cpp` (two templates of one name, a result-only parameter, a
  specialization defined after its use, a namespace). (0.129)
- A refusal in a HELD candidate's body is the call's, `instance_refused(Name, W)` (`cpp_instantiate_function__`); the
  template roads of `cpp_call` and `cpp_free_operator_call` never fall to plain overloads on it (else C's `getline`
  won by arity). (0.76)
- An instance fills its default arguments at the call (`cpp_fill_defaults` at both template call sites). (0.93)
- An abbreviated function template's `auto` parameters, through pointers and references, become invented parameters
  `$A1`, `$A2` ... (`cpp_auto_params/4`); its item emits nothing. (0.42)
- An `auto` parameter beside a WRITTEN template head invents its parameter AFTER the written ones ([dcl.fct]/22;
  `cpp_register_`'s `template(_, _, function(...))` clause appends them). Fixture: `autohead.cpp`. Why: libc++ 18's
  `__parse_arg_id(_Iterator, _Iterator, auto &)`, which `std::format` calls. (0.112)
- A member function with an `auto` parameter is a member template, alone or beside a written head
  (`cpp_auto_members/2` in `cpp_norm_members`; a closure's `operator()` is left to the lambda's own road). Fixture:
  `automember.cpp`. Why: libc++ 18's format-spec parser, `__get_width(auto &__ctx) const`. (0.112)
- A function with an `auto` result is declared under the deduced type once walked (`cpp_item(function)`); else
  `auto f = make(3)` looped. (0.100)

### Deduction

- Deduction takes the explicit arguments, then the call's (`cpp_deduce_args`, `cpp_deduce_one`, `cpp_match/5`), then
  the defaults; an unbound parameter refuses `cannot_deduce(P)`. An argument's type is the inference's, else the
  DESUGARED form's (`cpp_deduce_type` over `cpp_arg_type`: `__index_sequence_for<_Args1...>()`). (0.35, 0.79)
- A parameter whose template parameters are ALL given explicitly takes no part in the deduction (`cpp_explicit_skip`);
  it is checked once bound. Why: `deduction_failed(basic_format_args)`. `explicitarg.cpp`. (0.115)
- A type parameter takes the argument DECAYED only as a by-value parameter (`cpp_decayed`: arrays and functions to
  pointers, top-level cv dropped). A pointee keeps its qualifiers ([temp.deduct.call]/4; `cpp_match_pointee`: `T *`
  against `const int *` is `T = const int`), and so does an array's element (`_Tp (&)[_Np]` against `const
  uint32_t[5]` is `_Tp = const uint32_t`). `T &` given a const lvalue keeps the const, and an array stays an array
  ([temp.deduct.call]/2: no array-to-pointer conversion for a reference): `addressof<const int>`, and ranges::begin's
  `is_array_v<_Tp>`. Fixtures: `arrayref.cpp`, `rangesarray.cpp`. (0.99, 0.108, 0.112)
- The decay of a by-value parameter drops a POINTER's own top-level `const` too (`cpp_decayed(ptr(_, E), ptr([], E))`;
  [temp.deduct.call]/2): `T` deduced from `const char *const` is `const char *`. Else a member of a const object, which
  is const since 0.121, handed `const char *const` to `std::format`'s `__format_arg_store` deduced a const pointer type
  that no `__determine_arg_t` specialization matched, five `std::format` fixtures went RED in the first 0.121 chain.
  `stdformat.cpp`. (0.121)
- `T &` and `const T &` given a FUNCTION deduce the function type ([temp.deduct.call]/2: a reference parameter has no
  function-to-pointer conversion; a by-value parameter has it, `cpp_decayed`): `std::addressof(f)` is a pointer to the
  function (`cpp_deduce_one`'s clause before the const lvalue's). Else `_Tp` was a pointer and `T &` a reference to a
  pointer, the call stayed raw and its definition was never emitted: libc++ 21's `std::thread` hands
  `std::addressof(__thread_proxy<_Gp>)` to `__libcpp_thread_create`, and every thread program failed at the link.
  `addressfn.cpp`. (0.126)
- A TEMPLATE PARAMETER DEDUCED FROM TWO PARAMETERS DEDUCES ONE TYPE ([temp.deduct.type]; `cpp_deduce_args_checked`,
  `cpp_deduced_agree/4`, `cpp_deduced_differ/2`): the first binding stood for the second silently, and the later
  acceptance step let a converting constructor rescue the wrong deduction -- `operator*(const _Tp &, const complex<_Tp>
  &)` over two `complex<double>` was a candidate with `_Tp = complex<double>`, the constructor of
  `complex<complex<double>>` taking the second argument. A name that this call's deduction bound (the explicit ones
  are marked `'$explicit'` for the call and exempt) and that a second parameter deduces as another type fails the
  candidate, in `cpp_match`'s type parameter, a pointee (`cpp_match_pointee`) and a template argument (`cpp_match_targs`);
  only where a CLASS stands on either side and `cpp_same_type` says they differ, after the references and the
  top-level qualifiers are dropped (scalars convert, and a type the inference could not settle agrees). Every road asks
  it: free, member and constructor templates, the deduction guides. `deduceagree.cpp`. (0.126)
- A FORWARDING REFERENCE `T &&` given an lvalue deduces T as a reference ([temp.deduct.call]/3; `cpp_deduce_one`, packs
  alike), the lvalue judged on the desugared argument too (`cpp_lvalue_deep`). Why: the rvalue-stream inserter
  recursed; an optional's copy moved its string out. (0.78, 0.82)
- A trailing function parameter pack deduces element by element (`cpp_deduce_pack`). (0.44)
- A template-id parameter takes an instance of the template, or a class derived from one at the cost of a conversion
  (`cpp_instance_or_base`, through the first bases and, since 0.117, any later base with storage:
  `cpp_class_base_instance/4` over `'$cpp_base_slot'`, so `operator<<(basic_ostream<_CharT, _Traits> &, ...)` deduces
  from a stringstream, whose basic_ostream is the SECOND base of basic_iostream), and a later EMPTY base too
  (`'$cpp_extra'(C, Bs)`: no sub-object, no slot, the object's own address is its address -- [temp.deduct.call]/4.3, and
  `cpp_class_fits/2` agrees, so the conversion is a derived-to-base one): libc++ 21 asks
  `ranges::__derived_from_range_adaptor_closure((_Tp *) nullptr)` of `__pipeable<_Fn> : _Fn,
  __range_adaptor_closure<__pipeable<_Fn>>`, and `v | views::transform(f) | views::take(3)` found no closure.
  `crtpclass.cpp` (C++20). Else it refuses `deduction_failed(N)` (`swap(tuple<_Tp...> &, ...)` for pointers).
  (0.45, 0.117, 0.126)
- NON-DEDUCED contexts bind nothing and are checked once the rest is bound: a name qualified by a template parameter
  (`cpp_path_dependent`, 0.73); a member alias template's template-id (`cpp_nested_alias`: unique_ptr's
  `_LValRefType<_Dummy>`, 0.93); an alias whose definition is no template-id (`__type_identity_t<_Tp>`, 0.45); a
  function template's name as an argument ([temp.deduct.call]/6, 0.74). A parameter whose template parameters are all
  non-deduced takes no part ([temp.deduct.call]/1): `format(format_string<_Args...>, _Args &&...)`. (0.108)
- Deduction goes THROUGH an alias template whose definition is a template-id or a bare parameter
  (`cpp_alias_pattern`, `cpp_alias_binds`, `cpp_transparent_alias`): `__index_sequence<_I1...>` is
  `__integer_sequence<size_t, _I1...>`; `hash<__enable_hash_helper<optional<_Tp>, ...>>` is `hash<optional<_Tp>>`.
  Fixture: `stdhashopt.cpp`. (0.79, 0.99)
- An array bound deduces from `T (&a)[N]` ([temp.deduct.type]/9; `cpp_match_bound`). Fixture: `arraybound.cpp`
  (`get<T>`'s `__find_idx`). (0.90)
- A function type parameter or argument matches exactly; in the convertibility test a function decays to a pointer
  ([conv.func]; `cpp_decayed`: `is_constructible<_Fd, _Gp>`). (0.88)
- A FUNCTION TEMPLATE'S NAME as an argument has no type: it is `tmplfn(F)` (`cpp_fn_template_ref`, `cpp_arg_type`). A
  function-pointer, -reference or function-type parameter DEDUCES it from the target ([temp.deduct.funcaddr];
  `cpp_fn_target`, `cpp_target_deduces`, `cpp_target_bindings`, `cpp_match_target`: reference for reference, then the
  result, defaults, constraints) and scores it exact (`cpp_arg_fit_`, `cpp_arg_exact`, `cpp_param_accepts`); no other
  parameter takes it. Chosen, it becomes the instance's name (`cpp_ref_args_`, `cpp_deduce_target`):
  `cout << std::endl`. (0.74)
- A parameter's type may name an earlier parameter ([dcl.fct]/9): parameters are declared in order as they are
  resolved and keyed (`cpp_plain_params_seq`, `cpp_params_keys_seq`). (0.109)

### SFINAE

- A refusal is a thrown `not_lowered` term; the candidate check catches it and drops the candidate
  (`cpp_holding_candidates`, `cpp_candidate_check`). `cpp_bind_defaults` RESOLVES each default and each value
  parameter's type: the SFINAE of `enable_if<c, int>::type = 0`. (0.44)
- The RESULT TYPE is part of the signature ([temp.deduct]/8; `cpp_result_holds/4`) on the free and the member roads.
  A failable shape (`cpp_sfinae_result/1`: a dependent qualified name, a template-id, a `decltype`, through `*`, `&`,
  `&&`) resolves once all its names are bound ([temp.deduct]/2; `cpp_all_bound`), parameters and `this` declared
  (`cpp_with_params`); an `auto` result waits for the body. Why: `__convert_to_integral(_Tp)` holds only for an enum;
  unresolved, every `_And` held. The result is substituted under the PACKS' bindings too (`cpp_param_packs/3`; 0.127: a
  fold over a pack in a trailing `decltype` was `decltype_unknown`). (0.55, 0.100, 0.127)
- A member named through a SCALAR is no member ([expr.ref]): `x.f()`, `x.m` and `p->f()` of an arithmetic or pointer
  value refuse `no_member(M, T)` (`cpp_scalar_object/1`, `cpp_scalar_arrow/2`, in the member-call fallbacks and the data
  member's clause), which the comma detection `decltype(t.foo(), void())` asks of an `int`. `trailret.cpp`. (0.127)
- An expression's class never comes from a RAW type (`cpp_class_of_type_of` with `\+ cpp_raw_type(T)`, as in
  `cpp_arg_type`): a free name, a template-id over one (`cpp_free_arg`, through pointers, references, pack
  expansions), or one in a scoped path (`invoke_result_t<...>`). `cpp_init_arg_class` then desugars the call and reads
  the instance's result; an instance asked on a free name traces `free_name_instance(N, A, ...)`. Why: a
  `void_t<decltype(...)>` specialization cannot match a free name. (0.87, 0.93)
- `sizeof` of an incomplete type refuses `incomplete_type(C)` ([expr.sizeof]/1; `cpp_incomplete_class`): the detection
  of `__has_default_three_way_comparator`. (0.79)
- A TYPEDEF THAT NAMES A SCALAR has no member types, as the scalar has none (`cpp_subst_path/3` through
  `cpp_typedef_scalar/1`: the argument `size_t` bound to `_Up` makes the path segment `nonclass(size_t)`, and naming a
  member of it refuses `no_member_type`). The segment kept its NAME before, which flattened as a namespace and found
  some other class's `iterator_category`, so libc++'s `__has_iterator_typedefs<size_t>` held. `sfinaetypedef.cpp`.
  (0.117)
- The TYPES of the parameters a call leaves out are substituted and resolved with the rest (`cpp_params_resolve/2`, the
  end of `cpp_params_accept/3`; [temp.deduct]/7: the type of every function parameter, supplied or defaulted, is in the
  immediate context). libc++ 18 writes the SFINAE of `list::insert` and `list::assign` as a trailing parameter,
  `__enable_if_t<__has_input_iterator_category<_InpIter>::value> * = 0`, which no call supplies, so a template with
  `_InpIter = size_t` held whatever the trait said and was dropped only by the ranking -- behind a walk of 400,000
  flattened names: `list<int>::assign(3, 4)` ran past 28 minutes and 2.6 GB (the trace is the flood of `flatten(...,
  in(sig(__test)))` and `free_name_instance(iterator_traits, _InputIterator, ...)`). `sfinaetypedef.cpp`, `stdlist.cpp`.
  (0.117)

### Partial ordering of function templates

- `cpp_fn_more_special(X, Y)` holds when Y's parameter types deduce from X's, X's parameters opaque (`$opaque.P`,
  `cpp_opaque_bindings`). A template-id over opaque names is an incomplete instance, never instantiated
  (`cpp_opaque_types`: `__pad_and_output`'s ostreambuf overload). (0.45, 0.72)
- A parameter that STANDS TWICE deduces ONE type in the comparison ([temp.deduct.partial]/10; `cpp_params_consistent/3`, `cpp_bare_param/5`): `f(I1, I1, I2, I2)` is more specialized than `f(I1, I1, I2, P)`. `cpp_match` takes the second occurrence unseen, so both directions deduced and the first declared won; libc++ 21's `__lexicographical_compare` calls `std::mismatch(a, a + n, b, b + n)` of four pointers, which took the predicate overload (also at libc++ 18 under C++20). `partialorder2.cpp`, `mismatch4.cpp`. (0.125)
- A function parameter pack is less specialized ([temp.deduct.partial]/8; `cpp_has_pack_param`). Fixtures:
  `packorder.cpp`, `stdinvoke.cpp` (libc++'s `__invoke` for a data-member pointer). (0.99)
- Of `T &` and `const T &` deducing each other, the less cv-qualified loses ([temp.deduct.partial]/9;
  `cpp_partial_cv_ok`), only where X's referent is a bare type parameter; elsewhere /7 strips the top-level cv.
  Fixtures: `constref.cpp`, `overloads.cpp`. (0.99)
- Each comparison is a TEST asked `once`: `cpp_most_special_fn` asks `once(cpp_fn_more_special(Y, H))` and
  `\+ cpp_fn_more_special(H, Y)`; inside, the opaque bindings, the substitution and the parameter types are `once` and
  the deduction `once(catch(...))`; `cpp_most_special` does the same for classes. Why: under `\+` each failure retried
  every alternative deduction, exponential in the parameters (the two-range `<algorithm>` family). (0.95, 0.99)

### `decltype` and deduced (`auto`) results

- `decltype(e)` types the desugared expression (`cpp_decltype_of`): a call keeps its declared reference; `*p` and `a[i]`
  are `T &` ([dcl.type.decltype]); a conditional over two glvalues of one type -- spelled alike or not, each qualifier
  once -- is a reference with both arms' cv (`cpp_cond_glvalue`, `cpp_cv_union`; `arrayref.cpp`: libc++'s
  `common_reference` of `const unsigned &` and `uint32_t &`, 0.112); a call through a function reference, pointer or
  member-function pointer is the declared result (`cpp_fn_result`). Fixture: `concepttraits.cpp` (`common_reference`).
  (0.79, 0.109)
- `decltype(std::move(x))` is `T &&` ([dcl.type.decltype]; `cpp_decltype_of(move(X))`, the call recognized before it
  is desugared, `cpp_std_move_call/2`), where the desugaring makes the move of a scalar the value itself; a call through
  a member-function pointer is the member's declared result (`cpp_called_fn/3`). `decltypemove.cpp`, `memptrdecl.cpp`.
  (0.112)
- `decltype(x)` of an UNPARENTHESIZED NAME is its DECLARED type, the reference kept ([dcl.type.decltype]/1.3;
  `cpp_decltype_of(id(N), T)`; 0.121): `std::forward<decltype(__rhs_alt)>(__rhs_alt)` in libc++ 18's variant copy took
  the alternative by value, forwarded it as an rvalue and moved the source's string out. `fwdmember.cpp`.
- An `auto` result comes from the first return that ONE walk finds (`cpp_first_return_in`), for methods
  (`cpp_method_ret`) and for free functions, instances and lambdas (`cpp_lambda_ret`). The locals before it are in
  scope (`cpp_declare_only`); an `if constexpr` that folds is entered only on its KEPT branch ([stmt.if]/2); nested
  lambdas' and local classes' returns do not count; earlier block typedefs are substituted (`cpp_body_typedefs`); no
  return gives `void`. Why: `__get_comp_type` returns `void()` first, in a discarded branch. (0.81, 0.104)
- The PARAMETERS ARE DECLARED BEFORE THE BLOCK TYPEDEFS ARE RESOLVED (`cpp_method_ret`, `cpp_lambda_ret_mode`; 0.121):
  `using alt_type = remove_cvref_t<decltype(__alt)>;` names a parameter, and resolved outside its scope it was
  untyped. A refusal of a block typedef, or of a declaration on the way to the first return, is traced
  (`body_typedef_refused`, `declare_only_refused`). `stdvariant2.cpp`.
- A plain function's `auto &` and `const auto &` result is the first return's type UNDECAYED under the reference
  (`cpp_auto_result/1`, `cpp_fn_auto_ret/4` over `cpp_lambda_ret_mode/5` in the mode `keep`; the qualifiers of the
  `auto` merged): `auto &gr() { return g; }` is `int &`. It had been left as written, and the first call was `not
  lowered yet: auto`. `auto &&` (a forwarding reference) is `T &` for an lvalue return and `T &&` for any other
  (`cpp_ref_auto_result/5`, 0.121), for a free function and for a member (`cpp_method_ret`). `autoref.cpp`. (0.117, 0.121)
- The result is that return desugared, typed and DECAYED ([dcl.spec.auto]; `cpp_decayed`:
  `return partial_ordering::equivalent` is a `partial_ordering`); a conditional gives the arm the other converts to
  ([expr.cond]/4; `cpp_deduced_ret`). Untyped, it refuses `lambda_result_type` or `auto_result(C)` and traces
  `lambda_ret_refused(W)`. (0.84, 0.104)
- A member's trailing return type is its result ([dcl.fct]/2; `cpp_trailing_rets`), resolved with the parameters and
  `this` declared (`cpp_with_params`) in the candidate check and at emission (`cpp_method_ret`). (0.93, 0.100)
- `auto` under a reference or pointer deduces from the initializer (`cpp_auto_deduce`, `cpp_has_auto`):
  `auto &b = *is.rdbuf()` takes the referent undecayed, `const auto *f = b.gptr()` the pointee with its cv. (0.76)

### Alias and variable templates

- An alias template instantiates as its type (`cpp_instantiate_type`); a class wins a name it shares with an alias
  (`cpp_alias_template`: `std::pmr::vector`); alias and variable templates stay out of the C typedef table
  (`ccl_collect_item`). (0.44)
- An alias whose WHOLE definition is a template-id resolves to the INSTANCE (`cpp_type` on `ccl_typedef_of`:
  `false_type`), a refusal traced `alias_refused(N, W)`; a bare name such as `type` never resolves through the global
  table. Fixture: `aliastype.cpp`. Why: a summary keeps a header's aliases raw. So does an alias whose definition is a
  MEMBER type of an instance, `typedef underlying_type<E>::type __memory_order_underlying_t` (0.117). Never a definition
  that names a template parameter (`cpp_raw_type`, 0.118): the table holds the block-local and class-scope typedefs of the
  headers too, and `typedef typename iterator_traits<_ForwardIterator>::value_type value_type` followed with its free
  name instantiated `iterator_traits` on it for ever (`rangesarray.cpp`: 12 s at 0.116, 8.7 GB and no end at 0.117; the
  trace read `alias_followed`, 48,279 times in 25 s). (0.58, 0.63, 0.117, 0.118)
- Clang's builtin templates resolve in `cpp_instantiate_type`: `__make_integer_seq<S, T, N>` is `S<T, 0, ..., N-1>`,
  `__type_pack_element<I, Ts...>` the I-th of `Ts`. (0.79)
- A variable template's instance is its VALUE: the initializer, or the picked specialization's (`cpp_pick_spec`),
  substituted, desugared and folded (`cpp_instantiate_variable`, trace `vartmpl(N, Args, V)`), else
  `variable_template_not_constant(N)`. The value is remembered per ground argument list (`'$cpp_vtm'(N, Args, E)`,
  compared with `==`), since libc++'s ranges evaluate one `is_convertible_v` hundreds of times. (0.48, 0.112)
- A variable template whose value is an OBJECT of class type answers that value, a compound literal of the class
  (`cpp_object_value/1` in `cpp_instantiate_variable_`), and its instance called is the object's `operator()` (the
  `cpp_call` clause on `tmpl(N, As)`, never for a function template's prototype, which is a declaration item too).
  Why: libc++ 18 writes `template <size_t _Np> inline constexpr auto elements = __elements::__fn<_Np>{};` and
  `keys = elements<0>`, and an object that is no constant was refused. The value is a copy, the same object wherever
  its address is not asked for. `vtobject.cpp`. (0.113)
- A variable template is evaluated wherever a value stands (`cpp_expr`): read as a type
  (`!__has_max_size_v<const _Ap>`), as a bare id, or namespace-qualified (`std::is_same_v<A, B>`) where the path names
  no class. (0.50, 0.104)
- A variable template whose value is a BRACED OBJECT OF THE DECLARED CLASS TYPE -- libc++ 18's `template <size_t _Idx>
  inline constexpr in_place_index_t<_Idx> in_place_index{};` -- is that class's object, a compound literal of the
  declared type (`cpp_braced_object/4` in `cpp_instantiate_variable_`; an empty or trivially constructible class, any
  other being run-time). The declaration's type is substituted with the picked specialization's bindings.
  `stdvariant2.cpp`. (0.121)
- A variable template's specialization named with its namespace registers like any other (`cpp_spec_name`:
  `__format::__enable_insertable<basic_string<_CharT>>`). (0.112)

### Member templates and members defined out of class

- A member template is `'$cpp_mt'(C, Key, TPs, M)` (`cpp_register_class_extras`; `cpp_member_key` gives the method
  name, `ctor`, or a member alias's name). `cpp_method` falls back to `cpp_member_template_call`, and `cpp_ctor` to
  `cpp_member_template_ctor`, never for the class's own value. Fixture: `detect3.cpp`. (0.44, 0.47)
- A member or constructor template's signature, result type included, is checked IN ITS CLASS (`cpp_try_member`,
  `cpp_member_holding`, `cpp_try_ctor`, `cpp_ctor_holding`, under `cpp_as_callee` and `cpp_with_req_ctx`): its
  parameters are in the class's words (`const allocator_type &`). The fewest conversions win, the first in the list
  among equals (pair's `pair(const _T1 &, const _T2 &)` before `pair(_U1 &&, _U2 &&)`); the object's constness orders
  the list (`cpp_prefer_const`), and ellipsis candidates go last (`cpp_variadic_member/1`; `detect2.cpp`). Traces:
  `ctor_candidate`; failures `ctor_no`, `member_refused`, `member_error`; the choice `ctor_holds`, `member_holds`.
  (0.51, 0.84, 0.93)
- A member template's requires-clause among its qualifiers is part of the candidate: checked under the deduced
  bindings (`cpp_member_tmpl_req`), and the instance is made with its qualifiers substituted (`cpp_try_member`).
  Fixture: `rangesarray.cpp`. Why: checked with `_Tp` free, ranges::begin's `requires(sizeof(_Tp) >= 0)` skipped the
  member at its emission, its name was noted made and the call named nothing. (0.112)
- A member template called BARE with explicit arguments is found in the class, then in each base
  ([class.member.lookup]; `cpp_member_template_of`), and checked in its declaring class; `this` goes through the base
  hops, null for a static. Fixture: `basetmpl.cpp`. (0.79, 0.93)
- `X::f<U>(args)` goes to `cpp_member_template_call` (`cpp_call`'s `scoped(Path, tmpl(M, TArgs))` clause), with a null
  `this` for a static. (0.72)
- A member ALIAS template: `C::template _Select<A, B>` resolves through `cpp_member_alias_of`, a clause before
  `cpp_type`'s template-id clause, which strips scopes (0.47). Named bare in its class or a nested or derived class, it
  resolves at the instantiation door (`cpp_nested_alias`: optional's `__enable_implicit<_Up>()`, 0.82). As a template
  template argument (`_Tester::template _Apply`) it stays `tname(mt(C, N))`, keyed `C.N`, substitutes as a scoped
  template-id and is found through the bases (`memberaliasttp.cpp`: `_ITER_CONCEPT`). (0.109)
- A member CLASS template and its partial specializations are a template `C.N` (`cpp_nested_template_put`,
  `'$cpp_nested_tmpl'`), registered at its declaration even when defined later. It resolves bare in its class, the
  nested classes and the bases at the instantiation door (`cpp_nested_template`), and the class encloses its instance
  (unique_ptr's `_CheckArrayPointerConversion`). (0.81, 0.93)
- Inside a member class template's instance its SHORT name is the instance too, as the template's registered name is
  (`cpp_instantiate_class_`, from `'$cpp_nested_tmpl'(Enclosing, Short, Name)`). Why: the hidden friend
  `operator==(const iterator_t<_Base> &, const __sentinel &)` of take_while_view's `__sentinel<_Const>` reached the
  lowering as `typedef('__sentinel')`. `sentinelpair.cpp`. (0.112)
- An out-of-class CONSTRUCTOR or DESTRUCTOR carries its class's template-id as the qualifier `pattern(Args)` (the
  reader, `ccl_def_pattern/5`; `cpp_take_pattern/3` takes it off), so `__bitset<1, _Size>::__bitset()` is the one-word
  specialization's and `__bitset<_N_words, _Size>::__bitset()` the primary's, as a method's pattern always was. A
  SPECIALIZATION'S definitions are tried before the primary's (`cpp_mdef_lookup/6`, `cpp_special_pattern/1`: a pattern
  with anything but distinct parameters in it). Else every definition applied to every instance, the first registered
  won, and `std::bitset<16>` ran the constructor of `__bitset<0, 0>` (an empty body) and the primary's array members
  over its one word: a silent wrong answer, `count()` 8 for an empty set. `stdbitset.cpp`, `specmember.cpp`. (0.117)
- A class template's member DEFINED OUT OF CLASS is kept by its class, `'$cpp_mdef'(Class, Key, TPs, Pattern, Member)`
  (`cpp_mdef_item/4`: method, member template, constructor, destructor, nested class or its member). An instance takes
  the definition whose pattern matches (`cpp_mdef_bind`, `cpp_match_pattern`), whose parameters key alike and whose
  constness agrees (`cpp_member_defs/5`, before it registers); else the member stays an undefined declaration
  (`__vector_layout::__set_bound_using_pointer`). Fixture: `outofclass.cpp`. (0.55, 0.79)
- A MEMBER TEMPLATE of a PLAIN class defined out of it (`template <class F> T::T(F f, int x) : v(f(x)) {}`, 0.117) is
  kept as a member template of the class (`cpp_register_` on a `template` item whose member `cpp_mdef_item/4` names with
  no pattern: `cpp_mdef_put/4`, then `cpp_refresh_mts/1`): the declaration, registered with the class and bodyless
  (`'$cpp_mt'`), takes the body through the merge an instance of a class template makes (`cpp_member_def/5`), its
  default arguments and template-parameter defaults kept. The row's key is `ctor` where the member's shape key is
  `$ctor` (`cpp_member_shape(M, _, _, none)` finds the bodyless ones). Else the call named a symbol nothing defined
  (`std::mutex` and `std::thread`, whose constructors are such). `membertmpl.cpp`. (0.117)
- A STATIC DATA MEMBER of a class TEMPLATE DEFINED OUT OF ITS CLASS (`template <class _V, ..., _D _BlockSize> const _D
  __deque_iterator<_V, ..., _BlockSize>::__block_size = _BlockSize;`) is kept by the class, `static_def(N, Init)`
  (`cpp_mdef_item/4`, the pattern required), and the instance takes the initializer as the member's own default
  (`cpp_static_defs/5`, `cpp_static_def_init/3`: substituted with the instance's arguments, `default_init(SN, Init)`
  unless the class wrote one), so it folds as one written in the class does. The header's index keys it under the class
  (reader 114). Unmerged, `deque<int>::begin()` read an undefined symbol. `tmplstatic.cpp`, `stddeque.cpp`. (0.117)
- A definition whose template parameters AGREE with the declaration's, in the class's words, comes first
  (`cpp_mdef_match` agree then any; `cpp_tparams_alike`, `cpp_mdef_types`). Differently named parameters are renamed to
  the declaration's ([temp.mem]; `cpp_align_tparams`). The declaration lends its template-parameter defaults where the
  lists are alike or of one shape ([temp.param]/12; `cpp_keep_tdefaults`, `cpp_tparams_shape`). Fixtures:
  `sfinaedefs.cpp`, `stdvectorinsert.cpp` (libc++ 18's twin `__construct_at_end`). (0.99, 0.100)
- An UNNAMED parameter of the declaration takes the definition's name, never the reverse (`cpp_tparam_renames`,
  `cpp_rename_tparams`). Why: libc++ declares `template <bool> class __iterator;` in transform_view and defines it
  `template <bool _Const> class transform_view<...>::__iterator`, and `__iterator<!_Const>` was renamed to nobody's
  `anon` -- `constraint_unknown(id(anon))`, no converting constructor. `viewiter.cpp`. (0.113)

- A MEMBER TEMPLATE CALLED WITH ITS ARGUMENTS GIVEN, through an object or a pointer (`o.f<T>(args)`, `p->f<T>(args)`;
  0.121), is found in the class and in each base, `this` moved through the base sub-objects, null where the template
  is static, the defaults filled (`cpp_member_tmpl_via/7`). `p->f<T>()` had no clause: the arrow's general road took
  the template-id for a method name and left a raw call, refused `no_member` at the lowering. libc++ 18's
  `__assignment::__assign_alt` calls `__this->__emplace<_Ip>(...)`, and `variant::emplace` calls
  `__impl_.__emplace<_Ip>(...)` of a base of `__impl`. `memtmplid.cpp`. (0.121)
- A STATIC MEMBER TEMPLATE-ID NAMED AS A VALUE -- `dispatcher<Is...>::template dispatch<F, Vs...>`, the function
  pointers libc++ 18's `std::visit` stores in an array -- is the function of the instance its explicit arguments name
  (`cpp_member_explicit_instance/4`, `cpp_member_explicit_candidate/7`: the first candidate whose explicit arguments
  bind, whose defaults fill the rest, whose parameters are all bound and whose constraints hold), as a thunk over the
  instance's own parameters with the null `this` dropped (`cpp_instance_thunk/3`, `<Name>.fn`, declared at file
  scope). The address under `&` alike. `varvisit.cpp`. (0.121)
- A NESTED CLASS CALLS A STATIC MEMBER TEMPLATE OF ITS HOLDER BARE, its arguments given ([class.nest]/1, as a static
  member function's call is, 0.117; `cpp_call`'s clause over `cpp_encl_chain/2` and `cpp_static_member_template/2`):
  `__std_visit_exhaustive_visitor_check<_Visitor, ...>();` in libc++ 18's `__value_visitor`, read as a class
  template-id, refused `template_without_body`. The access check is the nested class's own. `varvisit.cpp`. (0.121)

### Class template argument deduction

- A class template named without arguments deduces them ([over.match.class.deduct], [dcl.type.class.deduct];
  `cpp_ctad_args`): the copy deduction candidate first, then the written guides (`$guide.<N>`), then each constructor
  as a guide, then an aggregate's members in order. It serves a call (`pair{a, b}`), a qualified call (`std::pair{a,
  b}`) and a declaration (`std::pair p(a, b)`, `cpp_decl_pieces`), whose name may be namespace-qualified
  (`cpp_ctad_name/2`). Fixtures: `stdctad.cpp`, `deduceguide.cpp` (libc++'s pair has template constructors only).
  (0.84, 0.108, 0.112)
- The copy deduction candidate ([over.match.class.deduct]/1.3): ONE initializer whose class is an instance of the
  template gives that instance's arguments (`cpp_init_arg_class`, `'$cpp_inst'`). Why: libc++ 18 writes
  `__format::__parse_number_result __r = __format::__parse_arg_id(...)`, and the bare template reached the lowering.
  `ctadcopy.cpp`. (0.112)
- In a constructor taken as a guide, the injected class name is the class over its own parameters ([temp.local]/1;
  `cpp_ctad_self/4`). Why: libc++ 18's `basic_format_context(_OutIt, basic_format_args<basic_format_context>, ...)`
  deduces `_CharT` only so. `ctadself.cpp`. (0.112)

### Template template parameters

- A template template parameter binds a template's NAME, `tname(X)` (`cpp_tname_arg/3`): an atom, a flattened
  namespace, or another such binding passed on. `cpp_subst` replaces `typedef(P)` and `tmpl(P, Args)` with it, paths
  included; the key is the name; `cpp_match` and `cpp_match_one` deduce H from `f(H<T>)`. A member alias template is
  one too (`tname(mt(C, N))`). Fixture: `ttp.cpp` (`__split_buffer`'s `_Layout`). (0.45, 0.109)

## Concepts and constraints

### Concepts: registration and satisfaction

- A concept is the fact `'$cpp_concept'(N, concept(TPs, E))` (`cpp_register_`); its item emits nothing. A header's
  concept is indexed by name and registered on the first ask (`cpp_template_name(concept(...))`, `cpp_concept_known`,
  `cpp_hdr_join_concept`); an unknown concept refuses `concept_without_body(C)`. (0.84, 0.112)
- `cpp_concept_holds(C, Args)` resolves the arguments (`cpp_types`), binds the parameters and asks `cpp_satisfied/1`
  of the body, at namespace scope, never in the asking class (`cpp_with_req_ctx(none, ...)`). A failure traces
  `concept_unsatisfied(C, Args)`. (0.42, 0.109)
- Satisfaction is REMEMBERED per ground argument list, as C++ caches it ([temp.constr.atomic]):
  `'$cpp_ccm'(C, Args, yes | no)`, compared with `==`. Why: libc++'s ranges ask `same_as<I &, I &>` hundreds of times
  in one build. (0.112)
- `cpp_satisfied/1` decides a constraint: `&&`, `||` and `!` combine; `true` holds, `false` does not; a variable
  template is its folded value (`cpp_instantiate_variable`); a concept-id asks `cpp_concept_holds/2`; a
  requires-expression holds when each requirement holds; anything else is a constant, folded through the desugaring in
  the requirement's context where needed (`requires _IsSame<...>::value;`). What does not fold refuses
  `constraint_unknown(E)`. (0.42, 0.84)
- A concept-id is a `bool` prvalue in an expression ([temp.names]/8; `cpp_expr`: `(int) std::same_as<A, B>`), a
  refusal inside giving `false`. As a template argument it is its truth (`cpp_targ_value`: C++20 `iterator_traits`'
  `conditional_t<__primary_template<...>, ...>`). (0.84, 0.109)

### Where constraints are checked

- `cpp_constraints_hold/3` checks EVERY `requires` entry of a head under the bindings, written or made for constrained
  parameters; an unmet entry refuses `constraint_not_satisfied(N)`. Fixture: `test/cpp/concept_fail.cpp`, refused by
  name. (0.42, 0.93)
- The checked heads: a class template at instantiation (`cpp_instantiate_class_`), each function template candidate
  (`cpp_signature_holds/7`), member and constructor template candidates, CTAD guides, a function template deduced from
  a target (`cpp_target_bindings`). On a candidate road a refusal drops the candidate. (0.42, 0.74)
- A partial specialization is a candidate only where its constraints hold ([temp.spec.partial.match];
  `cpp_pick_spec`); the more constrained comes first, counted by `&&` conjuncts, equals in declaration order
  (`cpp_by_constraints`, `cpp_constraint_count`). Fixture: `concepttraits.cpp`. Why:
  `indirectly_readable_traits<_Ip> requires is_array_v<_Ip>` took every iterator. (0.109)

### Requires-expressions and requirements

- A type requirement keeps its `typename` (`requires { typename T::key_type; }`; `ccl_requirement` peeks the word). Why:
  the rule ate the word, and the read of `<print>` stopped at `format_kind`. `typereq.cpp`. (0.115)
- A requires-expression declares its parameters in its own scope, and each requirement must hold
  (`cpp_requirements_hold`, `cpp_requirement_holds`). A refusal inside a requirement makes it unmet (SFINAE), never a
  program error; unmet traces `requirement_unmet(R)`. Its parameter PACK is expanded like a function's
  (`cpp_subst` on `requires_expr(Ps, Rs)` through `cpp_param_packs/3`): the parameters of `requires(_Fn &&__fn, _Args
  &&...__args) { std::invoke(std::forward<_Fn>(__fn), std::forward<_Args>(__args)...); }` -- the concept `invocable` of
  libc++ 21 -- became `__args$1` and `__args$2` while its requirement kept the name `__args`, found nowhere, so a variable of
  the function being walked under that name was found: `__try_constant_folding(..., basic_format_args __args)` asks
  `std::ranges::find_first_of(__fmt, array{'{', '}'})`, `indirectly_comparable` asks `invocable<equal_to &, char &, char &>`,
  and the requirement called `std::invoke` with two `basic_format_args` -- unmet, in every `std::format` and `std::print`.
  `reqpack.cpp` (`-std=c++20`). (0.42, 0.109, 0.126)
- A simple requirement `e;` holds when e, desugared in the requirement's context, has a type; a type requirement when
  the type resolves past a bare name; a nested `requires E;` when E is satisfied; a compound `{ e } -> C<...>` when e
  has a type and `decltype((e))` satisfies C ([expr.prim.req.compound]; `cpp_decltype_paren`: an lvalue is `T &`, a
  call its declared reference; `assignable_from`'s `-> same_as<_Lhs>`). (0.42, 0.109)
- A prvalue of non-class type has no top-level cv-qualifier ([expr.type]/2): `decltype((e))` of such a prvalue drops
  it (`cpp_decltype_paren`'s third clause, `cpp_prvalue_type/2`). Fixture: `prvaluecv.cpp`. Why: `__j + __n` over
  `const T *const __j` asked for `const T *const`, and a pointer was no `random_access_iterator`. (0.112)
- A type-constraint may be qualified, `std::same_as<I>` or `template <std::integral T>`: its concept is the last
  segment's (`cpp_concept_of(scoped(_, X), T)`). Fixture: `prvaluecv.cpp`. (0.112)
- A requires-expression is a `bool` prvalue in an expression ([expr.prim.req]/1; `cpp_expr`):
  `enable_view = derived_from<...> || requires { ... }`. Fixture: `reqvalue.cpp`. (0.110)

### Constrained parameters and constrained `auto`

- The reader turns `template <Concept T>` into a `requires` entry and joins a head's entries into ONE, last
  (`ccl_tparam_c`, `ccl_gather_requires`). (0.84)
- An abbreviated template's constraints (`Number auto x`) become ONE `requires` entry, last and conjoined
  (`cpp_auto_params`, `cpp_conj_reqs`), each `tmpl(C, [base([], [typedef('$Ak')])|As])`, but only for a concept
  registered then, the program's own (`'$cpp_concept'`); a library concept's `auto` parameter compiles unchecked.
  (0.93)
- A constrained `auto` variable is checked where its type is deduced (`cpp_constrained_ok` in `cpp_auto_deduce`,
  `cpp_auto_bind`): `Number auto x = e`, `const Number auto &r = x`. Unmet, it refuses `constraint_not_satisfied(C)`.
  Fixture: `test/cpp/constrained_fail.cpp`, refused by name. (0.93)
- A lambda's `requires`-clause, after its template parameters or its declarator, is read and dropped, never checked.
  (0.84)

### Constrained members and constructors

- A member function with an unmet trailing `requires`-clause is no candidate and is not instantiated ([temp.inst]/11;
  `cpp_method_viable`, `cpp_member_req_holds`; `cpp_member_fns` skips it). The clause is walked in its class with `this`
  and the parameters declared (`'$cpp_req_ctx'`), substituted with the class's arguments (`cpp_subst_quals`). An error
  inside is unmet (traces `member_req_error`, `member_req_unmet`). Fixtures: `memberreq.cpp`, `refview.cpp` (ref_view's
  `empty()` names a data member). (0.110)
- A CONSTRUCTOR with an unmet trailing `requires`-clause is no candidate on any `cpp_ctor` road (copy and move, the
  fitting set, the arity-only resort) and is not instantiated (`cpp_member_fns`). (0.112)
- A defaulted default constructor with a `requires`-clause (`H() requires default_initializable<V> = default`) is a
  default constructor only where the clause holds, decided once the class is registered (`cpp_register_class__`,
  `'$cpp_default_ctor'`; trace `default_ctor_unmet(C)`). Fixture: `defaultreq.cpp`. Why: filter_view
  default-constructed its ref_view member, which has no default constructor. (0.112)
- Member and constructor templates' own constraints are walked in their class (`cpp_with_req_ctx(C, ...)`), and a
  concept's body never is. Fixture: `ctorreq.cpp` (ref_view's constructor names its static `__fun`). (0.110)
- A member whose clause is unmet is not DECLARED where its declaration cannot be made: an `auto` result that does not
  deduce, or a constrained constructor whose parameter types do not resolve (`cpp_unmet_member/4` in
  `cpp_declare_members`, asked only after the failure, trace `member_unmet_undeclared`; the scope that the failed
  deduction left open is restored). Why: ref_view<map>'s `data() const requires contiguous_range<_Range>` refused
  `views::keys`, and transform_view's iterator `__iterator(__iterator<!_Const>) requires _Const` instantiated an
  `__iterator<true>` over a const filter_view, which has no iterator type. `memberunmet.cpp`. (0.113)
- A HIDDEN FRIEND with an unmet requires-clause is not registered ([temp.inst]/11): the split keeps the clause,
  `req(R, F)` (`cpp_friend_req/3`), and `cpp_friends_viable/3` asks it in the class once the class is registered,
  trace `friend_req_unmet`. Why: transform_view's iterator `friend auto operator<=>(...) requires random_access_range<
  _Base> && three_way_comparable<iterator_t<_Base>>` deduced its `auto` over a `__wrap_iter`, which has no `<=>`.
  `friendreq.cpp`. (0.113)

## Overload resolution

The desugaring (`library/ccl_cpp.pl`) chooses every C++ overload. A fixture named alone is in `test/cpp/run/`.

### The roads and their order

- The member road, `cpp_method/5`, tries in this order: the plain overloads that fit (`cpp_args_fit/2`, `cpp_pick_q/3`),
  the member templates (`cpp_member_template_call`), the arity alone (`cpp_args_no_clash/2`), a variadic member, the
  first base, a later base (`cpp_extra_method/5`). An ellipsis is the worst match ([over.ics.ellipsis]).
  `detectbase.cpp`. Why: with the arity before the templates, `basic_string::compare` called itself. (0.79, 0.88)
- The constructor road, `cpp_ctor/3`: the class's own value takes its copy or move constructor, written or implicit,
  and no other ([over.best.ics]). Else: the constructors that fit (`cpp_pick/3`), the constructor templates (never for
  the own value), the implicit copy or move, the arity alone, the implicit default constructor. Why:
  `explicit basic_string(const allocator_type &)` took `std::string s = "abc"`. (0.63, 0.83)
- A member or a constructor whose trailing requires-clause is unmet is no candidate ([temp.inst]/11;
  `cpp_method_viable/3`). `memberreq.cpp`, `defaultreq.cpp`. (0.110, 0.112)
- Of two members that tie, the one whose requires-clause holds wins, counted by conjuncts ([over.match.best]/2.6;
  `cpp_best_q` over `cpp_constraint_count`, the last key of the score); such a member is another function and carries
  `.rq<fold of the clause>` in its name (`cpp_mangle_q`, `cpp_req_key/2`). Why: libc++'s iota_view has `end() const`
  beside `end() const requires same_as<_Start, _BoundSentinel>`; the first declared answered a sentinel, and the
  program's own class template emitted both under one name. `moreconstrained.cpp`. A member TEMPLATE's instance is
  named from its SUBSTITUTED qualifiers, as it is declared (`cpp_try_member`); named from the raw clause, the call named
  nothing (`rangesarray.cpp`, 0.114). (0.112, 0.114)
- A derived object fits a base's reference or value parameter, a Conversion (2, `cpp_arg_fit_` through
  `cpp_derives/2`), and is no clash in the arity-only road ([over.ics.ref]/1). Why: libc++'s `__save_flags<_CharT,
  _Traits> __sf(__is)` over an istream took the private copy constructor, declared and never defined, where
  `explicit __save_flags(basic_ios &)` is meant. `explicitvbase.cpp`. (0.112)
- The free road, `cpp_call/4` on a non-local `id(F)`: an overload that takes the arguments EXACTLY beats every template
  (`cpp_fn_exact/4`); else the function templates (`cpp_instantiate_function`); else the plain overloads as one set
  (`cpp_fn_best/4`); else the first refusal, or `no_matching_template(F)`. A name the tables do not know stays a call.
  (0.56)
- A template that holds and whose body refuses makes the call refuse, `instance_refused(Name, W)`; no plain overload
  stands in. Why: C's `getline(char **, size_t *, FILE *)` took a stream by arity. (0.76)
- Among the function templates that hold: the fewest conversions (below), then a definition before a declaration
  (`cpp_defined_first/2`), then the most specialized (`cpp_most_special_fn/3`), then the first declared. The member and
  constructor template roads take the fewest conversions, then the first declared. (0.45, 0.84)
- A static method named bare in its class takes a null `this` (`cpp_object_arg(Name, nullptr, Obj)`). (0.88)

### Where the parameters and the arguments are read

- The plain candidates are scored and picked in the callee's class (`cpp_as_callee/2`), where a parameter type is
  written. An argument that only the desugaring can type is read in the caller's words (`cpp_caller_ctx/2`).
  `classwords.cpp`. Why: `operator+=(initializer_list<value_type>)` scored in `main` used the free name. (0.65, 0.81)
- A parameter is resolved in its class and read through an alias for its reference before it is judged
  (`cpp_param_ref/2`, at the head of `cpp_arg_fit/3` and in `cpp_params_accept/3`). `refparam.cpp`. Why:
  `push_back(const_reference)` beside `push_back(value_type &&)`; `unique_ptr`'s `const deleter_type &`. (0.66, 0.92)

### The type and the value category of an argument

- `cpp_arg_type/2` is the one door: it looks through `move(X)` and `std::move(X)` first, answers `tmplfn(F)` for a
  function template's name, takes the inference's type unless it is RAW, else types the desugared form in the
  caller's words. Why: `std::move`'s raw result won, and raw, `__rep_(std::move(...))` took `__rep(__short)`.
  (0.68, 0.69)
- A RAW type names a template's own parameter: a free name, or a template-id or scoped path over one, through
  pointers, references and packs (`cpp_raw_type/1`, `cpp_free_arg/1`). It counts as no type, so the desugaring types the
  call. Why: `std::exchange(...)` read `_T1`. (0.83, 0.87)
- THE TYPE OF A CALL OF A FUNCTION TEMPLATE THAT NAMES THE TEMPLATE'S OWN PARAMETER IS RAW whatever the tables know of
  the name (`cpp_callee_param_type/2`, asked by `cpp_arg_type/2` after `cpp_raw_type/1`, for a callee in
  `ccl_fn_template/1` whose `tparam(_, P, _)` the type mentions as `typedef(P)`): `cpp_raw_type` calls a name raw when no
  table holds it, and the tables hold `_Tp` -- libc++'s `__format_char` opens with `using _Tp = decltype(__value);`, a
  typedef in a block joins the unit's one table, and every instance the walk meets adds its own. So the raw argument
  `std::addressof(__max_output_size_)` of a BASE's initializer, typed by the summary's `_Tp *`, became an `int *`, fitted
  no `__max_output_size *` parameter, and libc++ 21's `__formatted_size_buffer` was refused `base_constructor(
  __output_buffer.char)` -- only when `formatted_size` had walked a `_Tp` before. Inside the callee's own signature the
  name is its parameter ([temp.local]). The block typedef itself still joins the table (a reduction of the leak is in
  Not done). `rawparam.cpp`, `stdvformat.cpp` (libc++ 21). (0.126)
- `cpp_init_arg_class/2` gives an argument's class, through the desugared form where a known type names no class.
  `cpp_class_of_type_of/2` looks through `move` and a reference, and never takes a raw type. (0.69, 0.87)
- `std::move(x)` keeps its `move` where `x` is a class or holds owners ([expr.xvalue]; `cpp_expr(move(X))`, the door of
  both spellings); else it is the value. `stdnodehandle.cpp`. Why: `t.insert(std::move(nh))` found no
  `insert(node_type &&)`. (0.83)
- An lvalue is an `id`, `member`, `arrow`, `deref`, `index`, a call declared to return `T &`, or a cast to `T &`
  (`cpp_lvalue/1`). A cast to a reference is typed as its object (`ccl_type_of(ccast)`). (0.79)
- AN ARGUMENT IS AN LVALUE ([basic.lval]) judged on its DESUGARED form where the raw one cannot tell, and an xvalue
  never (`cpp_arg_lvalue/1` over `cpp_deep_form/2` and `cpp_lvalue_deep`; 0.121): a member initializer's
  `std::forward<_Args>(__args)` is raw when the constructor is chosen, and read as no lvalue it took the MOVE
  constructor for every argument -- libc++ 18's `__alt(in_place_t, _Args &&... __args) :
  __value(std::forward<_Args>(__args)...)` moved the string out of a variant that was being COPIED. `cpp_own_value`,
  `cpp_category_mismatch` and the score of an rvalue for `C &&` (4) ask it. `fwdmember.cpp`.
- A MEMBER OF AN XVALUE IS AN XVALUE ([expr.ref]/6; 0.121): `std::move(x).m` is `std::move(x.m)`
  (`cpp_xvalue_member/2` in `cpp_expr`'s member clauses -- on the object it is a move of a class that holds no owner,
  which the safe part refuses), and `std::forward<D>(x).m` of an rvalue is one too (`cpp_xvalue_object/1` knows
  `move`, a cast to an rvalue reference, a call declared to return `T &&` and a member of such). `auto &&` deduces `T
  &` or `T &&` from it. `fwdmember.cpp`.
- A MEMBER OF A CONST OBJECT IS CONST ([expr.ref]/6, [dcl.type.cv]; 0.121) to an argument's type and to a deduced
  result (`cpp_arg_type/2` and `cpp_deduced_ret/2`, over `cpp_obj_const/2`): the type of `std::forward<const V
  &>(v).__head` under `auto &&` is `const T &`. libc++ 18's variant reaches a const alternative through a non-const
  union; the inference's type lost the const, `_Vp` deduced non-const, and the copy constructor moved the source's
  string out. `stdvariant.cpp`.
- A comparison, `!`, `&&` and `||` are `bool` in C++ and `int` in C ([expr.rel]/1, [expr.eq]/1, [expr.log.and]/1,
  [expr.unary.op]/9; `ccl_type_of` through `ccl_truth_type/1`); with a class operand the operator the desugaring chooses
  types it (`ccl_class_operand/1`). Fixture: `boolresult.cpp`. Why: `decltype(x < y)` was `int`, `auto b = x < y` four bytes,
  `std::boolalpha` printed `1`, and `f(x < y)` took `f(int)` over `f(bool)`; libc++ 21's `__synth_three_way` asks
  `decltype(a < b)`. (0.127)
- A conditional over two arms of ONE arithmetic type has that type in C++ ([expr.cond]/7.1: the usual arithmetic
  conversions bring two DIFFERENT types to one; `ccl_cond_arith/3`), where C converts them always (6.5.15/5). Why:
  `std::cout << (c ? 'Y' : 'N')` printed 89, and `c ? Red : Green` was no `Color`. `boolresult.cpp`. (0.127)
- A conditional with a `nullptr` arm has the other arm's type, unknown included ([expr.cond]; `ccl_type_of(cond)`). Why:
  `__nbc > 0 ? allocate(...) : nullptr` chose `reset(nullptr_t)`. (0.81) So has one with the literal ZERO against a
  pointer, in both orders ([expr.cond]/7: the null pointer constant converts to the pointer's type;
  `ccl_null_constant/1` over `int(0)` ... `ulong(0)`, asked where the other arm is a pointer): `c ? 0 : p` was an `int`,
  the overload taking the pointer lost to the one taking a `long`, and libc++'s `deque::begin()` passed `__map_.empty()
  ? 0 : *__mp + ...` to an iterator constructor. `condzero.cpp`, `test/c/run/condnull.c`. (0.81, 0.117)
- A character literal is a `char` in C++ and an `int` in C (`ccl_type_of(chr(_))`, `ir_expr(chr(C))`). Why:
  `cout << ' '` printed 32. (0.78)

### Scoring a plain candidate

- `cpp_arg_fit/3` scores one argument, `cpp_score/3` adds them (0.41, 0.44, 0.78, 0.79):
  - 4: an rvalue of the class for `C &&`.
  - 3: the same class, or the same bare type; a null pointer constant for `nullptr_t`; a function template's name
    whose target deduces it.
  - 2.75: an enum with a FIXED underlying type for exactly that type ([over.ics.rank]/4.2; `cpp_promotes_to_underlying/2`,
    0.127): `std::cout << e` of an `enum : unsigned char` is the `unsigned char` inserter.
  - 2.5: a PROMOTION ([conv.prom], [conv.fpprom]; `cpp_arith_fit/3` over `cpp_promotes_to/2`, 0.127): an integral
    promotion, `float` to `double`, an enum to its underlying type or that promoted. `p(short)` beside `p(long)` and
    `p(int)` calls `p(int)`; both were 2, and the first declared won.
  - 2: two other arithmetic types (a SCOPED enum takes none: 0); a null pointer constant for a pointer; two pointers
    that fit; a class whose conversion operator gives the parameter's class or exactly its scalar type; a braced list
    the class constructs, or whose items all fit an `initializer_list<T>`.
  - 1: a class whose conversion operator gives only the parameter's kind; an argument with no type; a pointer to a
    class for a `void *` parameter (`cpp_void_for_class/2`, [over.ics.rank]/4.2: B * to A * is the better conversion,
    0.117).
  - 0: anything else, and a category the parameter cannot bind (`cpp_category_mismatch/2`: `T &&` takes no lvalue, a
    non-const `T &` no rvalue but `move(x)`).
- `cpp_pick_q/3` ranks a method by twice its score, plus 1 where its constness matches the object's
  (`cpp_const_bonus/2`), plus 1 for a matching ref-qualifier or -100 for a mismatched one (`cpp_ref_bonus/2`). A tie
  keeps the first declared, as `cpp_pick/3` does. (0.79, 0.82)
- A pointer fits by its pointee (`cpp_pointer_fit/2`, `cpp_pointee_fit/2`): `void *` takes any object pointer; a
  function pointer only a function of its type, names dropped (`cpp_fn_types_agree/2`); a class pointer the same class
  or one derived through its first base or any later base with storage (`cpp_pointees_agree/2`, `cpp_class_fits/2`,
  `'$cpp_base_slot'` since 0.117); an arithmetic pointee an arithmetic one. `ptrfit.cpp`. Why: `cout << "hello"` called
  the literal through the manipulator inserter, and `cout << is.rdbuf()` -- a `basic_stringbuf *`, scored 2 as the
  `const void *` was, which is declared first -- printed the address (0.117, `stdstringstream.cpp`). (0.72, 0.74, 0.94,
  0.117)
- A function decays to a pointer to itself, and a pointer to member takes a null pointer constant ([conv.mem]/1;
  `cpp_pointerish/1`). Why: `0` fits `_CmpUnspecifiedParam(int _CmpUnspecifiedParam::*)`, so `o < 0` works. (0.74,
  0.101)
- `nullptr_t` takes a null pointer constant and nothing else ([conv.ptr]; `cpp_nullptr_param/1` at the fit, the
  arity-only resort and the template road). Why: as `void *`, `unique_ptr::reset(nullptr_t)` took every pointer.
  (0.81, 0.86)
- An integer type has one spelling, the shortest, wherever sameness is judged ([basic.fundamental]/2;
  `cpp_canon_specs/2` via `cpp_int_spelling/2`, also in `cpp_type_key/2`). `signed char` stays its own type.
  `intspell.cpp`. Why: libc++ specializes `__libcpp_is_signed_integer` over `signed int`. (0.78, 0.112)

- A braced list fits an `initializer_list<T>` parameter whose every item fits T with 3, a class it constructs with
  2 ([over.ics.rank]/3.1: the list conversion is the better one): `vector(initializer_list<int>)` over `vector(const
  vector &)` for `{1, 2, 3}`, which had tied and gone to the first declared. `globalinit.cpp`. (0.112)
- An item fits an `initializer_list<T>` element when it fits T OR T is a class whose converting constructor takes it
  (`cpp_il_elem_fits/2`): `std::vector<std::string>({"x", "y", "zz"})` has the list conversion though each literal
  becomes a string. Scored 0 for that, the list constructor was no candidate and the arity alone chose `explicit
  vector(const allocator_type &)`, handing the allocator three strings. `tempinitlist.cpp`. (0.117)
### The arity-only last resort

- `cpp_args_no_clash/2` admits a candidate by arity alone, after every fit and template. It refuses an argument where:
  a `nullptr_t` parameter gets no null pointer constant; a class parameter gets another known class, unbridged by a
  converting constructor or a conversion operator; a scalar parameter gets a class with no conversion operator; a
  pointer meets an arithmetic type or a disagreeing pointer, a null pointer constant aside (`cpp_scalar_mismatch/2`); a
  class-taking parameter gets a scalar and no converting constructor; a scalar parameter gets a PLAIN struct or union,
  which converts to nothing (`cpp_scalar_param_plain_arg/2`, 0.127). `stdvectorstring.cpp`, `plainclash.cpp`. Why:
  `__rep_(__str.__rep_)` stored a union into a byte; `callable<Eq &, P &, char &>` held where `Eq::operator()` takes two
  chars and P is a struct (0.127). (0.68, 0.78, 0.81, 0.127)
- A call through a pointer or reference to function whose parameter is a scalar and whose argument a plain struct or
  union is refused `argument_mismatch` (`cpp_callee_mismatch/2` in `cpp_call/4`'s last clause), so a detection over a
  function type is false as clang++ has it. `plainclash.cpp`. (0.127)
- A class-reference parameter clashes with another known class in the arity-only resort too (`cpp_args_no_clash` looks
  through the reference). Why: `iota`'s friend `operator-` took a `filter_view` iterator, and `filter_view` became a
  sized range. `friendclash.cpp`. (0.115)
- The free road's resort is the same test (`cpp_fn_best/4`); an ellipsis takes any number past the named parameters
  (`cpp_fn_arity_fits/3`, `cpp_fn_variadic/1`). (0.56, 0.61, 0.100)

### Constness, value category and reference binding

- A const method is another function ([over.match.funcs]): its name takes `.c`, then `.r` or `.rr` for a ref-qualifier
  (`cpp_mangle_q/5`). A shipped member keeps its Itanium symbol (`cpp_shipped_member_q/4`). The out-of-class merge
  matches constness (`cpp_member_const/2`). Why: libc++'s two `find`s shared one name. (0.79, 0.82)
- A member call carries the object's constness (`cpp_obj_const/2`, `'$cpp_obj_const'`) and value category
  (`cpp_obj_cat/2`, `'$cpp_obj_cat'`; `cpp_method_on/6`, `cpp_method_on_ptr/6`): an lvalue takes `&`, an rvalue `&&`
  ([over.match.funcs]/5). Both order the member templates too (`cpp_prefer_const/2`, `cpp_cand_const/2`). Why:
  optional's four `__get()`. (0.79, 0.81, 0.82)
- A member of a const object is const ([dcl.type.cv]; `cpp_obj_const/2`); a reference member keeps its referent's own
  constness (`cpp_member_own_const/3`). Why: `unordered_map::begin() const` took the non-const `begin`. (0.81)
- A non-const member is no candidate on a const object ([over.match.funcs]/5; `cpp_const_viable/1` in `cpp_method`): a
  static member, one with an explicit object parameter and a closure's `operator()` (const unless `mutable`, which
  is not marked) excepted. Why: it was only scored lower, so `range<const transform_view<filter_view<...>>>` held
  through the non-const `begin()`. `constmember.cpp`. (0.113)
- In a template candidate's check, how a reference binds decides whether it binds ([over.ics.ref];
  `cpp_param_accepts/2`) (0.91, 0.93, 0.99):
  - An rvalue never binds a non-const `T &`. An rvalue is a call declared to return `T &&` (`cpp_xvalue_call/1`) or a
    class by value, also ending a temporary (`cpp_prvalue_call/1`). The test is this whitelist, never `\+ cpp_lvalue`.
  - A const lvalue never binds a non-const `T &` ([dcl.init.ref]/5; `cpp_ref_lvalue_only/1`); a const pointer referent
    is const (`cpp_top_const/1`: `int (*const &)(int)`). `constref.cpp`.
  - An lvalue never binds a true `T &&` after substitution ([dcl.init.ref]/5).
  - An lvalue of one ARITHMETIC type never binds a non-const `T &` of another ([dcl.init.ref]/5.1: reference-related
    types only; `cpp_param_accepts/2`, the types compared by `cpp_type_key` without their qualifiers). Else libc++ 18's
    `__mul_overflowed(unsigned char, _Tp, unsigned char &)` held for a `uint32_t` lvalue and its store wrote ONE BYTE of
    the caller's variable: `std::from_chars("12345", ...)` stored 0 (0.117). `stdcharconv.cpp`.
- A binding that holds can cost one DEMERIT ([over.ics.rank]/3.2.3, /3.2.6; `cpp_ref_rank/2` -> `cpp_ref_demerit/0`):
  an rvalue, or a non-const lvalue, bound to `const T &`. The `const` is the reference's or its referent's.
  `refrank.cpp` (both declaration orders), `commafold.cpp`. (0.91, 0.93, 0.94)

### Ranking the template candidates: Conversions-Demerits

- A holding template candidate costs `Conversions-Demerits` (`cpp_conversions/1` over `'$cpp_conversions'` and
  `'$cpp_refbind'`). The lowest wins in standard order (`cpp_fewest_conversions/2`, `cpp_min_of/3`), so a demerit only
  breaks a tie. Trace: `holds(1-0)`. Why: as a conversion, `const string &` tied with a user-defined one. (0.94)
- A conversion is counted (`cpp_converted/0`) for a derived class taken as its base, a class through a conversion
  operator or the parameter class's constructor, and a non-class value through a converting constructor
  ([over.match.best]). The free, member (`cpp_member_holding/5`) and constructor (`cpp_ctor_holding/4`) template roads
  all rank so. Why: pair's `pair(_U1 &&, _U2 &&)` beats `pair(const _T1 &, const _T2 &)`. (0.45, 0.84)
- THE COUNTS OF A CHECK UNDER WAY SURVIVE THE CHECKS IT MAKES (0.117): each candidate starts its counts at 0
  (`cpp_conv_enter/1`) and puts the enclosing ones back when it ends (`cpp_conv_leave/1`), on the free, member and
  constructor roads. A candidate whose signature makes a call of its own -- an `enable_if` that asks a trait, a
  constraint -- ran that call's candidates in the middle of its count, each resetting it, and came out with what the
  LAST nested one counted. Why: `<fstream>` brings the filesystem path's friend inserter, whose signature asks a trait;
  `out << "x"` on an ofstream held it at ONE conversion and the `const char *` inserters at three (a derived-to-base
  counted in the deduction and in the acceptance), and the path inserter won. `stdfstream.cpp`.
- A class argument whose conversion operator gives EXACTLY the parameter's type is as good as an exact match for the
  member-against-free test (`cpp_arg_conv_exact/2` in `cpp_args_exact`; [over.ics.rank]/3.3: two user-defined
  conversions through the same function are ranked by the second standard conversion, and the identity wins). Why: `cout
  << os.tellp()` is the member `operator<<(long long)` over an fpos's `operator streamoff()`; the free `char` inserter
  took it and printed the byte 6. `stdstringstream.cpp`. (0.117)
- AN ARITHMETIC ARGUMENT OF ANOTHER ARITHMETIC TYPE IS A CONVERSION, an exact match is not ([over.ics.rank]/3;
  `cpp_scalar_rank/2`, asked by the main clause of `cpp_param_accepts/2`; 0.121): it costs one demerit, the
  reference-binding kind, so that of two templates that tie on the class conversions the one that takes the arguments
  as they are wins. libc++'s `std::variant` picks its alternative so (`__overload<int, 0>` and `__overload<double, 1>`
  called with an int); the program's `template <class T> int f(T x, int y)` against `template <class T, class U> int
  f(T &&, U &&)` for `(2.5, 3.5)` is the second. `stdvariant2.cpp`, `overloaded.cpp`. A PROMOTION costs one demerit and
  any other conversion two (0.127, [over.ics.rank]/4.2; `cpp_promotes_to/2`): `std::cout << e` of an `enum : unsigned
  char` is the free `unsigned char` inserter, which beats the member `operator<<(int)`, never the `char` one. `enumtype.cpp`.

### The template acceptance

- `cpp_params_accept/3` checks each parameter, substituted and resolved in its class, with `cpp_param_accepts/2`,
  through every reference layer (`cpp_unref_all/2`), the argument typed as deduction types it (`cpp_deduce_type/2`).
  An argument with no type passes. A mismatch refuses `argument_mismatch`: no candidate. Two class types are the same
  by class and qualifiers (`cpp_same_type/2`). (0.45, 0.79, 0.92)
- A class parameter accepts its class, a class derived through first bases (`cpp_class_fits/2`), a class with a
  conversion operator to it (`cpp_conv_result/3`), or a class its constructor takes ([over.ics.user];
  `cpp_class_converts/2`, in `cpp_type_accepts/2`). A non-explicit constructor TEMPLATE over a template-id that the
  argument's class instantiates converts too. `ctortconv.cpp`. Why: libc++'s `basic_format_args`. (0.80, 0.112)
- A non-class argument converts to a class only through a non-explicit constructor whose parameter takes its kind, or a
  constructor template (`cpp_converting/2`). `cpp_converting/1` serves `is_convertible` only, and also takes no
  `explicit` constructor ([meta.rel]: an implicit conversion; it counted them until 0.112, `is_convertible<int, E>`
  true for `explicit E(int)`, `explicitconv.cpp`). Why: `const pair *` passed for a map's `const_iterator`. (0.83)
- A constructor TEMPLATE converts an argument only where its one parameter deduces from the argument's type, the
  defaults bind and the head's and trailing requires-clauses hold (`cpp_ctor_tmpl_takes`; a parameter pack keeps the
  old answer). A constructor over a template-id converts an instance only where the substituted parameter IS the
  argument's class (`cpp_class_converts`). A pointer to one arithmetic type takes no pointer to another
  (`cpp_arith_pointee_differs`). Why: `std::format(L"...")` held the narrow overload through
  `basic_format_string<char, ...>`, and `std::vformat` the wide one through `basic_format_args<wformat_context>`.
  `wideformat.cpp`, `ctorctx.cpp`. (0.115)
- A class argument converts to a non-class parameter only through a conversion operator whose result fits it
  ([over.ics.user]; `cpp_conv_result/3`; any one, `cpp_has_conversion/1`, only where the parameter does not resolve).
  Why: `operator basic_string_view()` let libc++ 18's char inserter take a string. (0.94)
- No standard conversion joins a pointer and an arithmetic type (only `bool` takes a pointer), a function and an
  object pointer, or two pointers whose pointees disagree (`cpp_scalar_mismatch/2`). Why: the char inserter took the
  literal's address as a byte. (0.73, 0.78, 0.94)
- A null pointer constant converts to any pointer or pointer to member ([conv.ptr]/1; `cpp_null_to_pointer/2`); the
  template road accepts it only where the pointee resolves ([temp.deduct]/8; `cpp_pointee_settles/1`). `nullconst.cpp`,
  `detect2.cpp`. Why: `pair<value_type *, ptrdiff_t> __p(0, 0)`. (0.92, 0.93, 0.101)
- The traits' convertibility takes a derived pointer for a pointer to ANY base, the pointee losing no qualifier
  ([conv.ptr]/3; `cpp_pointer_to_base/2` via `cpp_derives/2`). The call roads keep the first-base walk, whose hops
  they emit. `stdsharedfromthis.cpp`. Why: `__enable_weak_this`; `__range_adaptor_closure_t`'s CRTP base. (0.100, 0.112)
  `cpp_derives/2` is ONE predicate since 0.112: dynamic_cast's first-base walk (0.108) had a definition of the same
  name and arity elsewhere in the file, which cocolog joined into one.

- A BRACED LIST FOR AN ARRAY PARAMETER holds only without NARROWING ([over.ics.list]/6, [dcl.init.list]/7; 0.121):
  `_Dest (&&)[1]` given `{declval<_Source>()}` is a substitution failure when the conversion narrows -- floating to
  integer, integer to floating or to a type that holds not all its values, floating to a narrower floating type, a
  pointer to bool -- unless the item is a constant that fits (`cpp_param_accepts(PT, init(Items))`, `cpp_narrows/2`,
  `cpp_narrow_conv/2`, `cpp_int_subset/2`, `cpp_constant_fits/3`); any other parameter takes a braced list as before.
  That is how libc++ 18's `__check_for_narrowing` keeps an alternative out of `std::variant`'s converting constructor:
  `std::variant<std::string, bool> v = "text";` holds the string. `narrowing.cpp`, `stdvariantsel.cpp` (C++20).
  (0.121)

### Free functions and free operators as overload sets

- A pre-pass notes every free function before anything registers, `'$cpp_fn'(Name, Key, Params, Defined, Origin)`
  (`cpp_note_fns/1`; a header's through `cpp_note_hdr_fns/1`). The origin is `decl(Ret, V)`, `own(V)` or `lazy(Item)`;
  `own(V)` keeps the program's ellipsis, so a call falls to `f(...)` (`cpp_fn_origin/4`). (0.56, 0.58, 0.100)
- `cpp_fn_name/4` names a free function in the table, the emission and the call (`cpp_free_call/5`): an `extern "C"`
  name keeps it (`'$cpp_cname'`); a library declaration with a namespace path takes its Itanium symbol; a definition
  of an overloaded name is `F.<keys>` (`cpp_fn_overloaded/1`); else the plain name. `freeoverloads.cpp`. (0.56, 0.61)
- An EXACT overload has as many parameters as arguments, each one, resolved (`cpp_type_or_self/2`), unreffed and bare,
  equal to its argument's type (`cpp_arg_exact/2`); a function is exact for a function pointer of its type. (0.56, 0.78)
- A header's templates and functions of a name join the program's on the first ask (`cpp_hdr_join/1` in
  `cpp_template/3`, `cpp_fn_ready/1`). Why: a friend `op.shl.2` hid libc++'s inserters. (0.78)
- A USER-DEFINED LITERAL is the call of a free operator, `op.literal_<suffix>.<arity>` (`cpp_expr(udl(Sfx, Lit))`,
  `cpp_free_operator(literal(Sfx), Qs, Name)`), over the arguments the standard hands the literal operator
  ([over.literal]): an integer literal as an `unsigned long long`, a floating one as a `long double`, a string as its
  pointer and its length (a `size_t`; the wide kinds count code points, `u"..."` units), a character as it is. The
  overloads (`operator""_m(long double)` beside `operator""_m(unsigned long long)`) are chosen by those types, in a
  namespace the program opened or a header's inline one. A raw literal operator (`const char *` alone) and the template
  form are not asked. `userliteral.cpp`, `stdliterals.cpp`. (0.117)
- A free operator is `op.<word>.<arity>` (`cpp_free_operator/3`), the program's and a header's template alike
  (`cpp_template_name/2`). That name is always an overload set, keyed by its parameters (`cpp_fn_overloaded/1`); an
  instance is one function under its own name. (0.67, 0.78, 0.79)
- A free operator FUNCTION that a header DEFINES -- no template, a class's `operator==`: `inline bool
  operator==(__thread_id __x, __thread_id __y)` of `<thread>`, `<system_error>`'s -- is indexed, noted and registered
  lazily under its free operator name (`cpp_index_name/2`, `cpp_note_hdr_fns/1`, `cpp_register_lazy/1`: the three
  clauses that had named a literal operator alone), then emitted where a call chooses it. A conversion function is a
  member, never one of these; a declaration alone is not indexed. Else `none == std::thread::id()` refused
  `no_operator(==)`: the name was keyed by an atom only. Reader 114. `stdthread.cpp`. (0.117)
- A KEYED qualified call tries the outer namespace's overloads when the key's own refuse (0.117; `cpp_call` on
  `scoped(Path, F)`, `cpp_bare_fn/1`): with `<complex>` included `std::abs` is the key `std.abs`, complex's template,
  and `using ::abs` brings the plain overloads into std -- `std::abs(x)` of a double and `std::norm(z)` (whose body
  calls it) were `deduction_failed(complex)`. A refusal of a body that held (`instance_refused`) is the call's.
  `stdcomplex.cpp`.
- A namespace-qualified call resolves as the bare name, never as a member (`std::swap(a, b)`); a deeper namespace's
  name takes its key (`cpp_ns_key/3`). A namespace's key beats a class of that name unless the class has the member.
  Why: libc++'s namespace `ranges::views::__all` and class template `__all`. (0.45, 0.100, 0.109)

### Operators and comparisons

- `cpp_operator/5` tries: the left class's member operator; a free operator (`cpp_free_operator_call/4`); a free
  operator over an enumeration operand (`cpp_enum_operator_call/4`); a rewritten candidate (`cpp_rewritten_cmp/4`);
  the refusal `no_operator(Op)`; else the plain form. (0.67, 0.94, 0.112)
- A member operator that is not exact for the arguments (`cpp_member_exact/2`) yields to a free operator that answers
  where the free one's parameters score at least the member's (`cpp_prefer_free/3`, 0.127; [over.match.best]: the members
  and the free functions are one set). Why: `cout << "hello"` is the free `const _CharT *` template, not the member over
  `const void *` (0.72); `cout << c` of an enum is the member `operator<<(int)`, a promotion, not the free `char` template,
  a conversion, which printed the byte (0.127). (0.72, 0.127)
- A free operator serves a class, plain struct or union on either side (`cpp_op_operand/1`) through the free road, and
  counts only where its callee comes back DECLARED; a held template's body refusal propagates. Why: `s == "abc"`,
  `"amy" < s`, a program's `operator<(const S &, const S &)`. (0.67, 0.80, 0.92)
- An enumeration operand takes a free operator whose parameter takes that enum ([over.match.oper]/1;
  `cpp_enum_operator_call/4`), else the built-in stays. The program's operators are registered before anything is
  walked; a header's are loaded by the operator's name, templates among them, but for a comparison, which every enum has
  built in and whose overload set is the library's biggest (0.127). A template is asked only where a parameter names
  a type by its bare name (`cpp_enum_op_param/2`): resolving `const duration<_Rep1, _Period1> &` instantiated the class
  over its free names, and `<ratio>`'s `__static_gcd<_Yp, _Xp % _Yp>` recursed on spellings that never fold.
  `enumeq.cpp`, `byteops.cpp`. Why: `std::find` over an enum compared with the built-in `==` (0.112); a SCOPED enum has
  no built-in arithmetic, and `~b` of a `std::byte`, promoted to `int`, gave -16 where libc++'s `operator~(byte)` gives
  the byte 0xF0 (0.127). (0.112, 0.127)
- An operator over a class operand that no road answers refuses `no_operator(Op)`, never for `!`, `&&`, `||` (their
  operand converts through `operator bool` afterwards) nor under `Plain = none` (the rewritten `!=`'s ask).
  `stdoptional2.cpp`. Why: raw, `int == nullopt_t` typed `int` in a constraint's `decltype`. (0.94)
- A built-in operator over a class with a conversion function to an arithmetic type is the operator on what the function
  gives ([over.match.oper]/3.3, [over.built]; `cpp_builtin_via_conv/4`, `cpp_scalar_conv/2`): `count += v[i]` over a
  `vector<bool>`'s `__bit_reference` (its `operator bool`), `m * 2` over a class with `operator double`. It comes after
  the class's own operators, the free ones, the enumeration ones and the rewritten comparisons have answered nothing,
  and before the refusal `no_operator`; only a non-`explicit` function (`cpp_arith_conv_result/2`, bases included); a
  compound assignment keeps its left side. Unary `-` and `~` alike. `convarith.cpp`. (0.117)
- Rewritten candidates ([over.match.oper]/3.4; `cpp_rewritten_cmp/4`): with `<=>` and no `<`, `a < b` (`>`, `<=`, `>=`)
  is `(a <=> b) < 0`, the `< 0` taken by the class `<=>` answers; `a != b` is `!(a == b)`. (0.93, 0.101)
- The rewritten candidates also take a FREE `operator<=>` (`cpp_free_operator_call` on `<=>`; the result goes through
  `cpp_copies` and its comparison with 0 through `cpp_operator`, else the plain `bin`) and its REVERSE (`b <=> a` with
  the comparison mirrored, `cpp_cmp_mirror/2`: `<` with `>`, `<=` with `>=`; [over.match.oper]/3.4.3), a class on either
  side. Why: libc++ 18's `operator<=>(const basic_string &, const _CharT *)` is the only comparison C++20 `"a" < s`
  has, and `std::map<std::string, int>` at C++20 compared its keys through it; `variant <=> variant` asks
  `three_way_comparable<std::string>`. `stringcmp20.cpp`, `stdvariantcmp.cpp` (both `-std=c++20`). (0.121)
- The REVERSED `==` (C++20, [over.match.oper]/3.4.4; `cpp_rewritten_cmp/4`): where no candidate takes `x == y` in
  order, `operator==(y, x)` is tried, once per pair (`'$cpp_reversing'`); `x != y` is then `!(y == x)`, a class on
  either side. Why: libc++ 18 writes `operator==(const _CharT *, __nul_terminator)` alone, and `sentinel_for` asks
  `__nul_terminator == p`. `reversedeq.cpp`. (0.115)
- `a <=> b` of a class calls its `operator<=>`, member or free (a hidden friend among them, 0.113), else refuses
  `three_way_comparison_of_a_class(C)`; a plain struct with none refuses too, never the scalar rule. An `auto` operator
  deduces its result as a plain function does (`cpp_item`). `friendreq.cpp`. Of scalars it is
  `<compare>`'s `strong_ordering`, or `partial_ordering` (-127 unordered) for a floating operand ([expr.spaceship];
  `cpp_scalar_ordering/3`); without `<compare>`, the int `(A > B) - (A < B)`. `stdcompare.cpp`. (0.42, 0.101)

### Overload sets and function templates named as values

- An overload set named as a value is chosen by its target's parameter keys ([over.over]; `cpp_conv_to/4` on `id(F)`,
  `cpp_fn_target/2`) and emitted by `cpp_use_fn`: `int (*pi)(int) = twice`. `overloadset.cpp`. (0.99)
- A function template's name is `tmplfn(F)` (`cpp_fn_template_ref/2`). A function-pointer, -reference or -type parameter
  deduces it from its target ([temp.deduct.funcaddr]; `cpp_target_deduces/2`) and scores it exact; no other parameter
  takes it. The argument pass makes it the instance (`cpp_deduce_target/3`). Why: `cout << std::endl`. (0.74)
- A function template-id with EXPLICIT arguments, `f<int>` or `&f<int>`, needs no target: the instance is the first
  candidate of the name whose explicit arguments bind, whose defaults fill the rest, whose parameters are ALL bound and
  whose constraints hold (`cpp_explicit_instance/3`, `cpp_explicit_candidate/7`, after `cpp_call_targs/2`), and the
  value is its name, the address under `&` (`cpp_expr` on `addr(X)` and on the bare id, `cpp_fn_template_id/3`, also
  namespace qualified). No candidate refuses `no_matching_template(F)`. Why: libc++ 18's `std::thread` hands
  `&__thread_proxy<_Gp>` to `pthread_create`, and the address reached the lowering as `lvalue(tmpl(...))`.
  `stdthread.cpp`. (0.117)

- An overloaded member's address, `&C::add`, is `'$memaddr'(C, N)` until a target chooses ([over.over];
  `cpp_conv_to`'s clause: the overload whose parameters key as the pointer to member's, `cpp_method_address/4`); one
  no target chose is refused at the lowering, `overloaded_member_address(C, N)`. `classforms.cpp`. (0.88, 0.112)
### The argument pass at a call (the copy pass)

- After the choice: the defaults fill (`cpp_fill_defaults/3`); the reference parameters take their objects
  (`cpp_ref_args/3`, `cpp_ref_args_of/3`); the other parameters take their copies and conversions (`cpp_copies/2`).
  (0.44, 0.63)
- `cpp_ref_args_/3` makes a function template's name its instance, casts a null pointer constant (accepting is not
  converting), converts a class through its conversion operator (`cpp_conv_to/3`), and passes `x` for `move(x)` to a
  reference (the move is the callee's). A temporary of a class built from another class's value takes that value's
  conversion operator where no converting constructor takes it ([over.match.copy]; `cpp_temporary`). (0.74, 0.79, 0.92)
- `cpp_copies_/3`: a braced scalar is its one item or its zero (`cpp_scalar_braced/3`; more refuse
  `braced_scalar_argument`); a braced class a temporary or the compiler's `initializer_list`; another type a temporary
  through the converting constructor; a class with a destructor its move constructor for `std::move(x)`, its copy
  constructor for an lvalue; a derived object for a base is sliced; a prvalue is elided ([class.copy.elision]).
  (0.66, 0.83, 0.86, 0.93)
- The pass runs on every call the desugaring walks (`cpp_expr(call)`), an operator's call, a temporary's constructor
  call (`cpp_temporary`), placement new (`cpp_new_at`), a template instance's call, a local's constructor call
  (`cpp_decl_pieces`, `localconv.cpp`), and a braced default (`cpp_braced_defaults/4`). Why: `w["apple"]` handed a
  `const char *` to `operator[](const key_type &)`. (0.79, 0.84, 0.112)
- A call through a cast to a reference calls the operand ([expr.static.cast]; the `ccast` clause of `cpp_call/4`); a
  cast to a base's reference calls the base's `operator()` on the sub-object (`cpp_base_operator_call`).
  `basecastcall.cpp`. Why: libc++ 18's `__invoke`, `__map_value_compare`. (0.93, 0.94)
- A call whose callee is no function NAME but an expression of function type -- a pointer or a reference to function
  held by a local, a parameter, a member or an element -- takes the passes a call by name gives, read off the FUNCTION
  TYPE's parameters (`cpp_callee_params/2`): the reference parameters their objects and the conversion operators
  (`cpp_ref_args/3` on a name, `cpp_ref_args_/3` on the generic callee of `cpp_call/4`'s last clause), the copies of a
  class taken by value and the converting constructors (`cpp_copies/2`). They took none: libc++'s `__invoke` writes
  `static_cast<_Fp &&>(__f)(static_cast<_Args &&>(__args)...)` with `_Fp` a function reference, so `std::invoke(bump,
  std::ref(c), 5)` and every `std::thread t(bump, std::ref(c), 500)` ran the callee on the wrapper's address (four
  threads waited on four mutexes of their own), and a Tag handed by value to `void (*)(Tag)` was the caller's own
  object, destroyed twice. `fnptrargs.cpp`, `stdthread.cpp`. (0.117)

## Lambdas

A lambda is a class of its captures (`library/ccl_cpp.pl`). A fixture named alone is in `test/cpp/run/`.

### The closure class

- A lambda becomes the class `lambda.K` (`cpp_lambda/6` -> `cpp_lambda_/6`; `'$cpp_lambdas'` counts K): a data member
  per capture, and `operator()` over the parameters and body, marked `closure`. It is registered and emitted under
  `cpp_isolated/1`, so a local that is not captured is undeclared in the body. `lambdas.cpp`. (0.36)
- A lambda is desugared ONCE, memoized by its text, context and captured types (`'$cpp_lambda_memo'`,
  `cpp_lambda_key/6`). `lambdas2.cpp`. Why: an `auto` method's result made a second closure class. (0.99)
- A closure is enclosed by the class it is made in (`cpp_lambda_scope/2` -> `'$cpp_encl'`): that class's types,
  statics and enumerators are in scope, `this` captured or not. Why: a string lambda's `__rep __new_rep = __short()`.
  (0.76)
- A closure has no implicit constructor (`cpp_closure_class/1` in `cpp_implicit_ctor_needed/1`). Why: `[this, __p]`
  captures an iterator, and that constructor was walked under the enclosing `this`. (0.80)
- A closure's `operator()` is CONST unless the lambda is `mutable` or has an explicit object parameter
  ([expr.prim.lambda.closure]/5; `[const, closure]` among its qualifiers, 0.127): a by-value capture is a member of a const
  object, so a call of its NON-const member function is refused `non_const_member_on_const(M, C)` (the member-call
  fallback), and binding it to a non-const lvalue reference `binds_const(N)` (`cpp_binds_const_lvalue/2`, the rule for any
  const lvalue, [dcl.init.ref]/5). The 0.117 pre-check of a write, `assign_to_capture(N)`, stays. Fixtures:
  `lambdaconst.cpp`; refusals `test/cpp/lambda_method.cpp`, `bind_const.cpp`. Why: `[c] { c.bump(); }` compiled and
  changed the copy, where clang++ refuses it.
- A lambda's own parameter pack expands with the enclosing bindings (`cpp_subst/3` on `lambda(...)`,
  `cpp_param_packs`). Why: `__tree::__emplace_unique`'s `[this](_Args &&... __args2)`. (0.79)
- A generic lambda's `operator()` is a member template ([expr.prim.lambda.closure]/3): its own `tparams(Ps)`, then one
  invented per `auto` (`cpp_auto_params/4`); its `auto` result is deduced at the call (`cpp_member_template_call`, the
  instance `op.call`). Why: libc++'s `__find_generic`. (0.92)
- A GENERIC LAMBDA'S PARAMETERS THAT NAME ITS OWN TEMPLATE PARAMETERS STAY AS WRITTEN WHERE THE TABLES KNOW THE NAME
  (`cpp_lambda_params/3`, `cpp_params_hiding/3`, `cpp_known_type_name/1`): the template parameter hides every outer name
  ([temp.local]) and `cpp_type` resolves through the tables. A typedef in a block joins the unit's one table, and libc++
  writes `using _Up = __libcpp_remove_reference_t<_Tp>;` inside a function: the second parameter of `[]<class _Tp, class
  _Up>(const _Tp &__t, const _Up &__u)` -- libc++ 21's `__synth_three_way`, the comparison a vector's `<=>` is built on --
  became `const _Tp &`, `_Up` could not be deduced (`cannot_deduce(_Up)`), the operator's result type refused, and
  `std::three_way_comparable<std::vector<int>>` was false. Only a parameter whose type names such a template parameter
  is kept raw; the rest resolve as before, and a lambda whose names no table knows takes the old road whole.
  `lambdatparam.cpp` (C++20), `stringcmp20.cpp` (libc++ 21). (0.126)
- A lambda's requires-clauses -- after its template parameters and trailing -- are kept by the reader as `lreq(R)`
  among its captures (reader version 105), and for the PROGRAM's generic lambda conjoined into the operator template's
  one requires entry (`cpp_lambda_constraint/4`), a parameter named in a `decltype` replaced by its declared type
  (`cpp_lreq_subst/3`: the invented `$A1` for an `auto`), so a call or a detection checks it. A library lambda's is
  kept and not checked (`'$cpp_in_lib'`: libc++'s `__synth_three_way`). `lambdareq.cpp`. (0.84, 0.112)

### Captures

- `cpp_captures/5` gives each capture `Name-val(T)` (the local's type decayed) or `Name-ref(T)` (a `ref([], T)` member;
  `cpp_cap_member_type/2`). (0.36)
- A default capture takes each enclosing local the body names, less its parameters and own declarations, kept where
  `cpp_local/1` (`cpp_lambda_free/3`): by value for `[=]`, by reference for `[&]`. (0.36)
- An init-capture is a member named by the capture ([expr.prim.lambda.capture]/6; `cpp_init_capture/4`): `[n = e]`
  (`cap(init, N, E)`) of `e`'s type decayed, `[&r = e]` (`cap(init_ref, N, E)`) a reference bound to `e`. `e` is walked
  once in the enclosing scope (`'$cpp_walked'`, `cpp_cap_init/3`); the name is in scope for the result.
  `initcapture.cpp`. Why: libc++'s radix sort's `[__map = std::move(__map)]`. (0.112)
- `[xs...]` over a bound pack is one by-value capture per element (`cap(pack, N)`, `cpp_subst_caps/3`). (0.99)
- `this` is captured for `[this]`, and under a default capture where the body names `this` or an enclosing data member,
  static, method or member template, bases included (`cpp_captures_this/4`, `cpp_has_member/2`). The closure holds the
  object in the reference member `'$this'`; `'$cpp_closure_this'` pairs closure and class. `capturethis.cpp`. Why:
  `vector::emplace_back`'s lambda names `__emplace_back_assume_capacity`. (0.59)
- Through `'$this'`: a bare data member is `this->$this.m` (`cpp_closure_member/3`); a bare method takes `&this->$this`
  with the hops (`cpp_closure_object/2`), a virtual one by its slot; a static is its global; `this` is `&this->$this`.
  In a GENERATED body (the closure's destructor or copy), `this->$this` is the closure's own member. (0.59, 0.101)
- `[*this]` captures the object by value ([expr.prim.lambda.capture]/10): `'$this'` is of the class itself,
  copy-constructed from `*this`, reached as `[this]`'s (`cap(star_this)`). (0.99, 0.101)
- `this auto self` (C++23) is the closure by value, or by reference for `&` and `&&` (`cpp_self_type/3`); the body runs
  under `Ctx = self(C, SN)`, a bare capture `member(id(self), N)`. A recursive lambda through `self` deduces its result
  from a first return that does not recurse, as C++ requires ([dcl.spec.auto]/11; `recself.cpp`, 0.112). (0.43, 0.112)
- A LAMBDA INSIDE A LAMBDA captures what the outer closure holds ([expr.prim.lambda.capture]/9; 0.117): a name is
  capturable when it is a local or, inside a closure's `operator()`, a capture of that closure
  (`cpp_capturable/3`, read as the body reads it, `this->a`, its type unreferenced), so `[a] { return [a] { return a +
  1; }(); }` and the default captures of `[=] { return [=] { return a * b; }(); }` capture the outer's members; they
  named no local and the inner body met `undeclared(a)`.
- `[this]` inside a lambda that captured `this` captures THE OBJECT (`cpp_captures_this/4` answers the object's class,
  `cpp_this_item/3` its address `&this->$this` in the outer body), never the outer closure; a default capture whose body
  names a member of that class does the same, and one that names only the outer's captures keeps the old road (the
  outer closure itself). `lambdanest.cpp`. (0.117)
- A NON-MUTABLE LAMBDA's by-value captures are const (0.117; [expr.prim.lambda.capture]/11): the closure's `operator()`
  here is never const, so the rule is applied to the lambda's text (`cpp_lambda_const_check/3`): an assignment, an
  increment or a decrement whose left side is a by-value capture, or a member of one, is refused `assign_to_capture(N)`
  unless the lambda is `mutable` (kept by the reader). A name the body declares itself, a nested lambda's parameter
  among them, is not the capture (`cpp_declared_names/2`); a write THROUGH a copied pointer is the pointee's.
  `lambdamutable.cpp`; `test/cpp/lambda_const.cpp` is refused.

### The closure object and its calls

- The closure is a compound literal of the captures' values, `&t` by reference (`cpp_closure_value/5`; trace
  `closure_bitwise`). (0.36)
- A by-value capture whose class has constructors (a `std::string`, a class with a destructor, `[*this]`'s object) is
  COPY-CONSTRUCTED ([expr.prim.lambda.capture]/10): the closure is built member by member (`cpp_aggregate_inits`), a
  reference capture BOUND (`cpp_closure_bind_value/2`). The temporary joins `'$cpp_temps'` with the closure's
  destructor, or is elided into its local (`cpp_temp_elide/2`). `closurecopy.cpp`. Why: one copy too many was destroyed.
  (0.101)
- `auto f = <lambda>`, as any unsettled `auto`, takes its initializer's type in `cpp_decl_pieces`, the initializer
  walked once (`'$cpp_walked'`). Why: a second walk made a second closure. (0.36, 0.60)
- `f(a)` on a local with `operator()` is `lambda.K.op.call.<keys>(&f, a)` (`cpp_call/4`, `cpp_method_on/6`). A
  template's by-value parameter of closure type copies the closure. (0.36)
- The lowering reads a reference member through (`ir_ref_member/4`); the check's `ccl_type_of` unrefs a member's type.
  (0.36)

### The result type

- A written result type is resolved under the parameters and the init-captures (`cpp_lambda_written_ret/3`;
  [expr.prim.lambda]). Why: libc++ 18's `[](basic_string &__s) -> decltype(__s.__r_) && {...}`. (0.93, 0.112)
- Else it is the first return, desugared in the ENCLOSING context with its locals and `this` (`cpp_lambda_ret/4`), then
  typed and decayed: the declarations before it in scope, a discarded `if constexpr` branch skipped
  (`cpp_first_return_in/3`), the block typedefs before it substituted (`cpp_body_typedefs/2`), a conditional over
  class arms the arm the other converts to (`cpp_deduced_ret/2`). (0.59, 0.84, 0.104)
- No return gives `void`; an untypable first return refuses `lambda_result_type` (trace `lambda_ret_refused`). (0.59)
- The first-return walk never enters a lambda or a local class (`cpp_first_return/2`). `closurescope.cpp`. (0.100)

### The conversion to a pointer to function

- A captureless lambda converts to a pointer to function ([expr.prim.lambda.closure]/8): a const conversion operator to
  `R (*)(Ps)` answers `&lambda.K.fn`, the static invoker (`cpp_closure_invoker/5`) that calls `operator()` over a null
  `this`. An invoker with no `operator()` to call refuses `closure_invoker(Name)`. (0.112)
- It exists only with no capture (`this` included), no template parameter, no explicit object parameter and a result
  other than `auto`. (0.112)
- A captureless GENERIC lambda converts too ([expr.prim.lambda.closure]/9: a conversion function template whose
  arguments the target deduces): at a conversion to a function pointer, `cpp_conv_to` makes an invoker per closure
  and target, `lambda.K.fn.<keys>`, whose body calls a temporary closure's `operator()` over the target's parameters,
  so the member template is instantiated by that call; the invoker's address is the value (`cpp_generic_closure/1`,
  `cpp_generic_invoker/5`, `'$cpp_gen_invs'`). Why: the closure's struct was handed on as the pointer, an `inttoptr`
  LLVM refused. `genericfp.cpp`. (0.112)
- It serves a declaration, an argument, an assignment and a member initializer; a function-pointer conversion fits
  only an agreeing function type (`cpp_conv_fits/2`, `cpp_fn_types_agree/2`). `lambdafp.cpp`. Why: `<format>` stores
  `__flush_([](_CharT *, size_t, void *) {...})`. (0.112)

### Closures and the safe part

- A closure borrows what its captures borrow (`ck_borrows_from/3` on `compound_lit`): an initializer and a return ask
  `ck_borrowing_type/1` (`ck_closure_type/1`). A closure holding `&x` of a local that leaves the function is
  `borrow_escapes` (`test/cpp/escape.cpp`, refused); `[this]` may leave; a plain by-value capture borrows nothing.
  `closurescope.cpp`. (0.100)
- A `'$this'` slot's item is walked, never refused as an unfollowable borrow (`ck_init_slots_/6`): a closure is
  scope-bound here. (0.59)

## Constant evaluation

`ccl_const_eval/2` (`library/ccl_infer.pl`) folds in C and C++; in C++ the desugaring adds a constexpr evaluator
(`library/ccl_cpp.pl`). A fixture named alone is in `test/cpp/run/`.

### The doors

- In C++ the door is `cpp_const_value/2`: `ccl_const_eval/2`, then `cpp_const_fold/2`, then `cpp_const_reduce/2`, which
  folds each call, index and member subterm where it sits and asks again. The arithmetic stays `ccl_const_eval`'s
  (owner's rule: a table is written once). Why: libc++'s `__find_idx` recurses inside a conditional. (0.72, 0.90)
- The door serves template arguments (`cpp_targ_value/2`), statics, array bounds, const locals and file-scope
  constants; a `consteval` call asks `cpp_const_fold/2` itself. What does not fold stays as it was: a call stays a call.
  (0.72, 0.99)

### `ccl_const_eval`: literals, names and operators

- A literal folds to its value (`int`, `uint`, `long`, `ulong`, the character kinds, `wb`/`uwb`, `bool`); past 2^60 it
  is `big(Atom)`, its own value, but a `_BitInt` literal past 2^60 folds nowhere. (0.94)
- A name folds to its entry in `'$ccl_enums'` unless a NON-CONST local shadows it (`ccl_shadowed_constant/1`); a const
  local with a constant initializer is the constant. `enumshadow.cpp`, `test/c/run/enumshadow.c`. Why: `<format>`'s
  enumerator `__ptr` replaced `__tree`'s parameter; `__mu`'s `const size_t __indx` must fold. (0.94)
- At `-std=c23` a `const` or `constexpr` object with a constant initializer joins `'$ccl_enums'`
  (`ccl_note_constants/2`), folding in a bound, a static assertion, a case label. `test/c/run/c23.c`. (0.57)
- The operators fold (`ccl_const_op/4`), and so do `?:`, a C or C++ cast (`ccl_w_cast/3`: `type(~0)`), `sizeof` (a
  string literal's array bytes, `ccl_literal_bytes/2`), `sizeof_type`, `alignof_type` ([expr.alignof]; its type resolved
  by the desugaring's hook first), `offsetof` (`ccl_offsetof/3`) and `noexcept_expr` (1). Division by zero and a bad
  shift count do not fold. (0.60, 0.88, 0.103)
- The comma folds to B's value where A is a constant or a `(void)` cast ([expr.const]). `commafold.cpp`. Why: libc++'s
  `__all<((void)_Preds, true)...>`. (0.93)

### 64-bit arithmetic

- The arithmetic is a 64-bit machine's though cocolog's integers are 61-bit: a value is an integer below 2^60 in
  magnitude, else `big(Atom)` of decimal digits (`ccl_narrow/2`); a hex, octal or binary literal `big('0x...')` is read
  as hex (`ccl_wide/2`, `ccl_limbs_of_hex/3`). `test/c/run/bighex.c`. (0.94, 0.112)
- A wide result runs on base-2^30 limbs (`ccl_w_*` over `ccl_mag_*`; `ccl_w_fits/1` the fast path). `/` and `%` truncate
  toward zero, `>>` of a negative is arithmetic, bitwise operators are two's complement (`~0` is -1). (0.94)
- A FLOATING CONSTANT THAT IS THE OPERAND OF A CAST TO AN INTEGER TYPE folds (C 6.6/6, [expr.const]; 0.129):
  `(int) 2.5`, `(__int128) 1e30` and `(long) -3.75` (`ccl_float_operand/2`, the two cast clauses of `ccl_const_eval/2`
  before the general ones). A floating literal alone still folds nowhere, since a folded floating static would become an
  integer. A double past 2^59 converts to an integer exactly: it is m * 2^e with m below 2^53, halving it is exact, and
  the wide value is m shifted (`ccl_float_int/2`; `truncate/1` has the engine's 61 bits); an integer past 2^60 converts
  to a double rounded to nearest, ties to even, from its top 53 bits, the next one and the sticky rest (`ccl_w_float/2`;
  it had stayed an integer for a double). An infinity or a NaN converts to no integer. `test/c/run/floatglobal.c`.
  (0.129)
- A cast to an integer type WRAPS to its width and signedness ([conv.integral]; `ccl_w_cast/3`, `ccl_w_wrap/4`):
  `(long long) (1ULL << 63)` is -2^63; a floating value truncates, then wraps. `test/c/run/bigint.c`. Why: libc++'s
  `numeric_limits<T>::max()` folded to -1 and the string extractor never looped. (0.94, 0.108)
- AN UNSIGNED OPERATION IS DONE IN ITS TYPE (C 6.3.1.8, 6.2.5/9; [expr.arith.conv]; 0.128): the values stay untyped
  mathematical integers, so `~0u` was -1, `~0u / 3` folded to 0 (it is 0x55555555), `0u - 1` was -1 and `-1 < 0u` held.
  `ccl_cv_binary/7` (after `ccl_const_op/4` in `ccl_const_eval/2`'s `bin` clause) answers at once where both operands
  and the result are small and not negative (`ccl_cv_small/1`: the same in every type); else it asks the operands'
  types, and where their usual arithmetic conversion is an unsigned type (`ccl_cv_unsigned/1`: an integer type of
  unsigned rank, `bool` excepted) both operands are converted to it, the operation is done again, and the result
  wraps to it (a comparison answers its 0 or 1; `ccl_cv_typed_op/2` names the operators). A `>>` of an unsigned left
  operand shifts its converted value. `ccl_cv_unary/3` wraps `-x` and `~x` of an unsigned promoted type
  (`-1u == 4294967295u`). An operand that the inference cannot type keeps the mathematical answer. In `#if` the type is
  `uintmax_t` (the Preprocessor topic). `test/c/run/unsignedconst.c`, which prints clang's values for globals, enum
  values, array bounds and `_Static_assert`s. (0.128)
- ONE EVALUATOR FOR AN ENUMERATOR'S VALUE (0.128): the bulk noter's `ccl_const_eval_in/3` had an arithmetic of its own
  (it read `(unsigned char) 300` as 300 and `-1 < 0u` as 1, where the parser's read gave 44 and 0); it now puts the
  enumerators before as their values (`ccl_enum_ids_in/3`: `int(V)`, `long(V)` past 2^31) and asks
  `ccl_const_eval/2`. Reader 123, since a summary's `enum/2` values come from it. (0.128)
- A LEFT SHIFT WRAPS in the promoted type of its left operand (`ccl_shl_wrap/3`; [expr.shift]/1): `intmax_t(1) << 63` is
  -2^63, as clang folds it, and libc++'s `-((intmax_t(1) << (sizeof(intmax_t) * CHAR_BIT - 1)) + 1)` is `INTMAX_MAX`. It
  was +2^63 and its negation -2^63 - 1, every `duration::__no_overflow<...>::value` false, and no `<chrono>` duration
  converted to another (`seconds` to `milliseconds`). An operand with no type keeps the mathematical shift.
  `shiftwrap.cpp`. (0.117)
- `__builtin_popcount` and its `l`, `ll` and `g` forms fold over the value wrapped unsigned to its type's width, 64
  where the type is unknown, limb by limb (`cpp_popcount/2`): libc++'s `digits`. (0.60, 0.94)

### Constants of the desugaring

- `if constexpr` keeps one branch where `cpp_const_bool/2` decides (a constant, a `bool`, a concept-id, a constexpr call
  through the evaluator); else it is a plain `if`. Why: libc++ 18's `if constexpr
  (__format::__use_packed_format_arg_store(sizeof...(_Args)))` kept both branches, and the other named a member the
  store does not have. `ifconstexprcall.cpp`. (0.42, 0.112)
- A static const folds from `'$cpp_sinit'`, also through the bases and the enclosing class
  (`cpp_static_const/3`), raw or else desugared in its class under `'$cpp_folding:C.N'` (`cpp_fold_static/4`). Named
  bare in its class it folds in an expression and as a template argument. Why: libc++'s `__str_find<..., npos>`. (0.47,
  0.60, 0.84)
- A class's own static shadows a global enumerator in a static's initializer ([basic.lookup.unqual];
  `cpp_shadowing_static/2`): no raw fold. `stdmanip.cpp`. Why: `ios_base::floatfield` read `chars_format`'s values.
  (0.94)
- A qualified enumerator is its value whatever a local is named (`cpp_expr` on `scoped(...)`, `cpp_targ_value/2`,
  through `cpp_enumerator/4`). (0.93, 0.94)
- A QUALIFIED ENUMERATOR IS THE VALUE ITS OWN ENUM GIVES IT (`cpp_enumerator/4`, `cpp_enum_path_tag/3`, `cpp_enum_value/3`;
  0.126). The enumerators' table (`'$ccl_enums'`, `ccl_enum_value/2`) is keyed by the BARE name, so `B::X` beside `A::X` -- two
  enum classes, enums nested in two classes, a namespace's -- took the value of whichever the table answered first, a SILENT
  wrong answer (`(int) B::X` printed A::X's value; `T::D::W` the one of `S::D::W`), and a `case state::Consonant:` naming an enum
  nested in the class being walked reached the lowering raw (`case(scoped([state], ...))`: only a file-scope enum's name was
  asked, a nested one is the tag `Enclosing.Name`). The path names the enum -- the class-nested one by the class being walked
  (its bases and enclosing classes included) or by the class the path names, the file-scope one by its name -- and the value
  is taken from THAT enum's own list, each initializer folded (`ccl_const_eval/2`) with the enumerators before it substituted,
  as the reader gives them (`ccl_declare_enumerators`); the whole list is walked once and remembered
  (`'$cpp_enumv'(Tag, Name, Value)`). An initializer that does not fold ends the walk (the enumerators before it stand), and
  a name it did not reach is the table's answer, as before. The nested enums' short names are `'$cpp_nenum'` facts
  (`cpp_note_nested_enum/1`, written where `cpp_nested_names/3` notes the tag), so that a qualified name which is no enum's
  costs one failed lookup. An UNQUALIFIED enumerator is still the table's. libc++ 21's grapheme-cluster rules switch over
  `__GB9c_indic_conjunct_break_state`, nested in a class and declared after the member that switches, whose `__Consonant`
  is also `__inCB_property::__Consonant` (`std::print`, `std::format` of a string). `enumscope.cpp`. (0.126)
- A `const` non-floating local whose desugared initializer folds, a constexpr call through the evaluator included, is a
  constant (`cpp_note_const/3` into `'$ccl_enums'`; trace `const_not_folded`). Why: `__align_it<__boundary>`.
  (0.63, 0.104)
- A file-scope `const` initialized by a CALL is folded TWICE at its declaration (`cpp_fold_const_inits_`): the first
  attempt EMITS the library instances the call runs through (`numeric_limits<size_t>::max()`), and only the second sees
  them. A value past 2^60 is the initializer `int(big(A))`. Else `inline constexpr size_t dynamic_extent` stayed a call
  and became a run-time initialization (0.117).
- A `const` local aggregate with a constant initializer is an evaluator value, `'$cpp_gagg:N'` = `agg(T, Init, local)`,
  read by `cpp_global_agg/2` only while the name is a local. Traces: `const_agg_not_folded`, `agg_item`. (0.104)
- A file-scope `const` integral object with a constant initializer is a constant ([expr.const]): `cpp_global_const/2` ->
  `cpp_fold_global/2` under `'$cpp_gfolding:N'`, keeping only a SUCCESS (`'$cpp_gconst:N'`). Why: a failure in an
  abandoned candidate would stand for ever; `__aligned_storage_max_align`. (0.88)
- A file-scope `const` object initialized by a constexpr call takes its value (`cpp_fold_const_inits/3`): a scalar, a
  `bool`, or an aggregate spelled as braced items (`cpp_eval_init_term/2`). A file-scope `const` aggregate is a value,
  `agg(T, Init, global)` in `'$cpp_gagg:N'`, so `table[2]`, `origin.x` fold anywhere. Why: `constexpr int N =
  twice(21);` reached the lowering as a call. (0.95, 0.97, 0.98)
- `cpp_const_fold/2` also folds an index into a static member array with an in-class initializer (`get<T>`'s
  `__find_idx`), and a member or index of a call's aggregate answer (`make(5).y`). (0.90, 0.98)
- A static member's braced initializer is walked ONCE per item (`cpp_init_expr`, `once/1` in its `findall`: a
  template-id's call has two answers) and each item is folded, a constexpr call through the evaluator
  (`cpp_static_aggregate`, `cpp_fold_items/2`). Why: libc++ 18's `basic_format_string` holds `static constexpr
  array<__arg_t, sizeof...(_Args)> __types_{__determine_arg_t<_Context, ...>()...}`, which came out doubled and
  unfolded. A static whose items do not all fold (an immediately invoked lambda) is no constant: it is declared and
  not defined (`cpp_has_call/1`), which costs nothing where it is unused -- libc++ 18's `__handles_`, for the consteval
  check this compiler drops. `staticpack.cpp`, `staticunused.cpp`. (0.90, 0.112)
- A `case` label is a constant expression ([stmt.switch]/2): desugared, then folded through the evaluator where it is a
  call (`cpp_stmt_` on `case/3`). Why: libc++ 18's `case __format_spec::__type::__default:` reached the lowering raw.
  `caselabel.cpp`. (0.112)
- A reduction that changed nothing is no value (`cpp_const_fold`'s member and index clauses; 0.121): the evaluator
  leaves an expression it cannot take as it was, `cpp_eval_value` handed that back to `cpp_const_value`, and it came
  here again with the same term -- no depth limit covers a member. `const bool v = as(b).vl();` over a derived class's
  object and a template that returns its argument's reference compiled for 20 minutes (the prologue of `std::visit`).
  `varvisit.cpp`.
- An array bound is desugared in its class and folded, the evaluator included (`cpp_array_bound/2`); else it is a VLA.
  `padding.cpp`. Why: `char __padding_[sizeof(_ToPad) - __datasizeof_v<_ToPad>]` was empty. (0.45, 0.99)
- `__builtin_offsetof` folds from the layout (`cpp_offsetof/4`): libc++'s data size. `offsetof.cpp`. In C++,
  `decltype(sizeof ...)` is `unsigned long`, any other `decltype` its expression's type (`ccl_resolve_base`,
  `ccl_sizeof_expr/1`). Why: through `ccl_type_of`, libc++'s `size_t` went round in a circle. (0.45)

### The constexpr function evaluator

- A call folds through the evaluator first ([dcl.constexpr]; `cpp_eval_fn/3`, `cpp_eval_args/4`, `cpp_eval_call/5`),
  over an emitted instance (`'$cpp_out'`) or the program's own desugared function or method (`'$cpp_ownfn'`); the door
  wants a scalar (`cpp_eval_scalar/1`). `constexprfn3.cpp`. (0.96, 0.98)
- Else 0.72's road folds a one-`return` body, the parameters bound as written (`cpp_param_binds/3`, `cpp_replace_ids/3`;
  `this` null). `cpp_targ_value/2` turns `X::template f<U>()` into that call. `constexprfn.cpp`, `stdtraits.cpp`. Why:
  pair's `__is_pair_constructible<_U1, _U2>()`. (0.72, 0.95)
- Both roads stay under depth 32 (`'$cpp_fold_depth'`): a constexpr function may call itself. (0.72, 0.96)
- The evaluator runs statements (`cpp_eval_stmts/4`): declarations, a block's own dropped at its end; effects, also
  inside operands (`cpp_eval_effect/4`); `if`, `if constexpr`, `while`, `do`, `for`, `switch`, a range-for over an
  array, `break`, `continue`, several `return`s. A void function falling off its end answers 0. (0.96, 0.97)
- ONE step budget per fold: `cpp_eval_step/0` counts `'$cpp_eval_steps'` to 200000, so an endless loop fails and never
  hangs; only depth 0 resets it, nested calls share it, and an unset count reads 0. (0.96, 0.98)
- Each local and parameter is a CELL, the global `'$cpp_ec:K'` (`cpp_ec_new/2`; `'$cpp_ec_n'` never restarts). The
  environment holds `N-'$cell'(K)`, `'$t'(N)-T`, and a reference as `N-'$alias'(Ptr)`. (0.99)
- A value is an integer, `big(A)`, `arr(Elems)`, `obj([Name-Value ...])` or `ptr(cell(K), Path)`; the path is `[]` the
  whole, `[2]` an element, `[x]` a member, `[1, y]` nested. (0.97, 0.99)
- An expression is REDUCED bottom up (`cpp_eval_reduce/3`): names to values, arrays to pointers to their first element
  (`cpp_eval_decay/3`), places to contents, a string literal (or the address of a value that is no place) to a pointer
  into a new cell, a constexpr call to its answer (an aggregate as `'$val'(Agg)`), pointer arithmetic, a statement
  expression to its last value, a compound literal. The scalar rest is `ccl_const_eval`'s (`cpp_eval_value/2`).
  (0.98, 0.99)
- A store through a pointer writes the named cell in any function (`cpp_eval_addr/3`, `cpp_eval_load/2`,
  `cpp_eval_store_ptr/2`, `cpp_eval_padd/3`): `*p`, `p[i]`, `q->x`, a callee's `a[i]`, `this->x` in a non-const member,
  `&x` of a scalar, a reference. `constexprfn6.cpp`. (0.99)
- Pointers into one array compare and subtract by their last path step; a pointer compared with null is not null. A
  method on an object is a call over `&q` (`corner.scaled(3)`). `constexprfn5.cpp`. (0.98)
- An aggregate is built from its braced initializer (`cpp_eval_agg_kind/2`, `cpp_eval_agg_init/5`): by position, by
  `.f = e`, nested braces, the rest zero ([dcl.init.aggr]); an unbounded array takes its items' count.
  `constexprfn4.cpp`. (0.97)
- `switch` runs from the matching label or `default` through to a `break` (`cpp_eval_switch_flat/2`,
  `cpp_eval_switch_run/4`); a range-for over an array binds each element (`cpp_eval_foreach/6`). (0.97)
- `sizeof` over a local comes from its declared type, an unbounded array's from its value (`cpp_eval_sizeof/3`). (0.99)
- The C library's `strlen` over a string the evaluator holds counts its codes (`cpp_eval_strlen/3`), and `nullptr` is
  0 (`cpp_eval_value/2`), the null `this` of a static member function. Why: `basic_string_view(const char *)` counts
  its literal through `__builtin_strlen`, and `n(len(s))` in a constexpr constructor called a static `len`.
  `constsv.cpp`. (0.112)
- THE BIT COUNTS FOLD IN THE EVALUATOR (`cpp_bitcount/3`, `cpp_eval_bitcount/6`): `__builtin_clz`, `ctz`, `popcount` and their
  `l`, `ll` and `g` forms over the argument reduced to a value and WRAPPED TO ITS WIDTH, unsigned (the builtin's own: 32 bits, `l`
  and `ll` 64; for a `g` form the argument's type, read from the callee's declared parameter or a cast, `cpp_eval_width/3`), counted
  on the base-2^30 limbs. Zero has no leading or trailing bit: a `g` form answers its second argument, the others are undefined
  and do not fold. The desugaring folded a count of a CONSTANT argument alone (`cpp_builtin_call`), and the argument of
  libc++ 21's `__countl_zero` -> `__builtin_clzg(__t, numeric_limits<_Tp>::digits)` is the callee's parameter: its radix sort's
  `static constexpr auto __radix_size = std::__bit_log2<uint64_t>(...)` stayed an unfolded static, an undefined symbol at the
  link (`stable_sort` of ints). `bitcount.cpp`, `stdalgorithm6.cpp`. (0.126)
- A CAST TO A POINTER TYPE keeps the pointer the evaluator holds (`cpp_eval_ptr_cast/4`), `cast(T, E)` and the C++ named
  forms the desugaring keeps, `ccast(reinterpret, T, E)`: libc++ 21's `__constexpr_strlen` counts through
  `__builtin_strlen(reinterpret_cast<const char *>(__str))` (the evaluator's `__libcpp_is_constant_evaluated()` is false, so
  the loop above it is not taken), and a pointer wrapped in a cast was none to `strlen`: `std::string_view s{"true"}` of a
  constant did not fold, and the static member stayed an undefined symbol (`constsv.cpp`, `staticsv.cpp`, `strlencast.cpp`).
  (0.126)
- A wide literal (`L"..."`, `u"..."`, `U"..."`) is its code units to the evaluator (`ir_utf8_decode`,
  `ir_wide_units`), `wcslen` counts them, and a pointer into such a cell spells back as the literal (`cpp_ec_lit`). Why:
  `__bool_strings<wchar_t>::__true{L"true"}` did not fold and was an undefined symbol. `widesv.cpp`. (0.115)
- `if consteval` keeps both branches, `ifce(L, CT, RT)`: the evaluator takes CT (`cpp_eval_stmt(ifce)`), the check and
  the lowering RT (`ck_stmt(ifce)`, `ir_stmt(ifce)`). `ifconsteval.cpp`. (0.108)

### Constexpr constructors, globals and consteval

- A global of a class with constructors -- any initializer, or none where its default construction is no trivial one
  (`cpp_global_object/5`) -- is constructed at compile time over a cell of the class's zero where the evaluator can
  ([basic.start.static]; `cpp_fold_ctor_value/4`, `cpp_eval_construct/4`). `constexprfn6.cpp`. (0.99, 0.112)
- Else it is INITIALIZED DYNAMICALLY ([basic.start.dynamic]; `cpp_global_ctor_init/7`, `cpp_dynamic_init/4`): the
  global stays zero bytes, and the unit's one function `$cpp_ginit` -- run before main through `@llvm.global_ctors`,
  which the lowering spells where it lowers that function -- constructs it where it stands, a placement new over its
  address from the RAW initializer (a prvalue `Tag(3)` its own arguments, `cpp_dyn_init_args/3`; a braced list for an
  `initializer_list` constructor one argument), and registers its destructor with `atexit` through a wrapper
  `$cpp_gdtor.N`, in declaration order, so the globals die in the reverse order ([basic.start.term]). `extern` stays a
  declaration; `dynamic_initialization_of_global(N, C)` remains for a static member the evaluator cannot build.
  `globalinit.cpp`. (0.112)
- A file-scope SCALAR whose initializer needs the run time is initialized dynamically too (C++ only, 0.117): `int g =
  f() * 2;`, `static int h = g + 4;`, `const int k = f();`, `double d = f() / 2.0;`, `Color c = pick();`, `int
  br{f(3)};`, `int *p = &arr[2];`, `int A::v = A::compute() * 2;` were refused by the lowering as `global_init(...)`,
  for the constant initialization of a global is all it spells. `cpp_dynamic_scalars/7` (after `cpp_fold_const_inits` in
  `cpp_item(declaration)`, and in the scoped-static clause) leaves the declaration's initializer `none` -- the global is
  its zero -- and appends `expr(L, assign('=', id(N), Raw))` to `'$cpp_ginit'`, the RAW initializer, walked as any
  statement of the function is (temporaries, copies), in declaration order beside the class-typed globals; a static
  member defined out of its class is assigned inside `'$in_class'(C, ...)`, in the class's words and access. The test
  (`cpp_runtime_init/1`) is on the desugared initializer: a call that did not fold, a read of a variable (a name that is
  no function, no enumerator and does not fold), a dereference, a member, an index, an assignment, an increment, a `new`
  or the address of anything but a name. Everything else stays what it was, a constant the lowering spells or refuses.
  Never for a `thread_local`, an `extern` declaration, a class, an array or a reference. A global `int *p = new int(7);`
  is still `untied` (the safe part's rule: a global slot with no owner behind). `globalscalar.cpp`. (0.117)
- The constructed value becomes the initializer whole or not at all (`cpp_eval_init_term/2`, `cpp_eval_init_items/2`):
  a pointer into a string literal's cell (marked `'$cpp_ecs:K'` where the literal is reduced) is the literal at its
  offset, `str(Cs)` or `bin('+', str(Cs), int(K))` (`ir_gconst` spells a `getelementptr` into it); a value it cannot
  spell fails the conversion. Why: a member it could not spell was DROPPED and the items after it moved up, `{ ptr 4,
  i64 0 }` for a `string_view` of size 4. `constsv.cpp`. (0.112)
- A file-scope object is declared again under its RESOLVED type (`cpp_redeclare_globals/2`): the table held the
  reader's `std::string_view`, a scoped name the inference cannot resolve, and `g.size()` stayed a raw member call.
  (0.112)
- A static data member of class type initialized in its class is built so and emitted `linkonce`
  (`cpp_static_constructed/4`): `strong_ordering::less`. (0.101)
- In a body, a class local and a temporary use cells too: the declaration, then the constructor over its address. (0.99)
- A call of the program's `consteval` free function folds to a scalar or refuses `consteval_call_not_constant(F)`
  ([dcl.constexpr]/13; `'$cpp_consteval'`, `cpp_free_call/5`). `consteval.cpp`. (0.99)
- So does the program's consteval member function, static or not (`cpp_note_consteval/3` where the method is emitted,
  `cpp_consteval_fold/2` after every call), and its consteval constructor builds a local at compile time
  (`cpp_eval_construct` in `cpp_decl_pieces`: the object's value is the local's initializer). `constevalm.cpp`. (0.112)

## Object layout and the ABI

### Structs, unions and bitfields

- A struct has its C layout with SysV packing (`ccl_members_layout/4`, cached in `'$ccl_laycache'`). Each member is
  `lay(Name, T, ByteOff, none | bits(BitOff, Width, UnitBytes) | empty)`. A bitfield that would cross an alignment
  boundary of its type starts at the boundary; a zero width closes the unit. (M2b)
- The LLVM shape follows the layout (`ir_struct_shape/3`): one element per plain member, one `[K x i8]` per bitfield
  run (split where no byte is shared), and padding where C's offset passes LLVM's and up to `ccl_tag_size`. The map
  `m(Name, Index, T, none | bf(RunLL, BitOff, Width, Signed))` goes to `'$ir_maps'`. A struct is named once
  (`%struct.Tag`, `'$ir_structs'`); an anonymous one is keyed by its members (`'$ir_anons'`). (M2b, 0.89)
- A member is a slot (`ir_member_slot/5`): an address, `bf(Addr, RunLL, Off, W, Signed)` or `empty(P)`. All lvalue
  loads and stores go through `ir_load_slot` and `ir_store_slot`; a bitfield run loads `align 1`, shifted and masked.
  `&` of a bitfield refuses `address_of_bitfield`. `ir_ref_of` takes a slot's address only through `ir_slot_addr`.
  (M2b, 0.89)
- A union is `{ iA, [N-A x i8] }` for its alignment A, `[N x i8]` when A is 1 (`ir_union_type`). A union with
  constructors keeps a union's layout; its tag starts with `union_tag` (`ccl_is_union_tag/1`). Every member lies at the
  union's address. A member of an anonymous struct or union is reached through the hidden member (`ccl_anon_route`).
  Struct and union allocas and globals carry `align`. (M2b, 0.63, 0.108)
- A bitfield in a union is the low bits of the union's first bytes (SysV, little-endian): its slot is
  `bf(Base, RunLL, 0, W, Signed)` over the bytes its bits span (`ir_union_slot/4`), so a read masks and a write keeps
  the other bits. `test/c/run/unionbits.c`. Why: every union member was read at the union's address whole, so a 3-bit
  `al` read the byte a struct member had written; libc++'s `__parsed_specifications` reads `__alignment_` so.
  (0.112)
- A layout uses the data members only: `ccl_members_layout_` and `ccl_union_layout` skip each term that is not
  `member/3` (a C++ tag also holds methods, as libc++'s `union __rep` does). (0.63)
- Layout markers (`align_as(E)`, `virtual_base`, `virtual_base_of(T)`) leave the member list at one door,
  `ccl_members_of` (`ccl_data_members`, `ccl_layout_marker`). A tag with markers is still a plain struct
  (`ccl_class_shape`). Else a marker failed a field walk with no message (`phase(check)`). (0.89, 0.110)
- An enum with an underlying type has that type's size and LLVM type (`ccl_size_align`, `ir_base` on `enum_base(T)`);
  an underlying type named by a typedef is resolved first: `enum class __alignment : uint8_t`. Other enums are 4 bytes.
  An enum with no enumerators is no empty struct (`ccl_is_enum_tag/1` in `ccl_tag_type/4`), so `__element_count(n)` is
  a cast. An enum is no scope (`cpp_path_class`): `Color::Green` is its enumerator. `enumbits.cpp`. (0.55, 0.112)
- An underlying type named through a typedef of a DEPENDENT name is SETTLED where the enum is first named (0.117;
  `cpp_type` on the enum's name through `cpp_enum_unsettled/4`): libc++ 18's `enum class memory_order :
  __memory_order_underlying_t` over `typedef underlying_type<__legacy_memory_order>::type __memory_order_underlying_t`
  keeps a template-id in the tag, and the lowering cannot instantiate a class. The base is resolved by `cpp_type`, the
  tag noted again and the typedef OUTPUT as an item (`cpp_settle_typedef/2`): the passes build the symbol table again
  from the output's items, and a note made during the desugaring is gone by then. The clause asks `ccl_tag/2` with its
  members unbound and a refusal while resolving leaves the tag as it was. Every `-std=c++20` program that stored into a
  `std::atomic` met `typedef(scoped([tmpl(underlying_type, ...)], type))` in `main`. The typedef may be a TEMPLATE-ID of an
  alias template too (`cpp_dependent_typedef/1`): libc++ 21 writes `using __memory_order_underlying_t =
  __underlying_type_t<__legacy_memory_order>;` over `template <class _Tp> using __underlying_type_t =
  __underlying_type(_Tp);`, and the base stayed `typedef(tmpl('__underlying_type_t', ...))` for the lowering (a typedef of the
  program's own is walked as an item and needs none of this: only a LIBRARY header's alias reaches the lowering raw, so
  `stdatomic20.cpp` at libc++ 21 is the measure). `enumsettle.cpp`, `stdatomic20.cpp`. (0.117, 0.126)
- A bitfield is read with its type's sign (`ir_signed/1`, written once in `ir_signed_/1`): `bool`, `_Bool`, `char8_t`,
  `char16_t` and `char32_t` are unsigned ([basic.fundamental]), an enum with an underlying type takes that type's sign
  ([dcl.enum]/5). The same test decides every extension, comparison and division. Why: a `bool f : 1` holding true read
  as -1, and a `char16_t` past 0x7FFF was sign-extended. `enumbits.cpp`. (0.112)

### How values and classes cross a call

- A struct by value crosses a call as the platform ABI says (`ir_abi/2`, cached in `'$ir_abicache'`): `scalar`,
  `direct([piece(LL, Off)...])`, `memory(LL, Align)` (SysV byval and sret) or `indirect(LL, Align)` (AAPCS64's copy).
  SysV: over 16 bytes in memory, else each eightbyte `iN` when an integer or pointer lies in it, else `double`, `float`
  or `<2 x float>`. AAPCS64: over 16 bytes indirect, else an HFA `[k x float|double]` (k up to 4), else `i64` or
  `[2 x i64]`. (M3)
- `ir_leaves/3` gives the leaves from the same layout. A pointer to member function is two INTEGER eightbytes, and a
  complex its two components. On SysV an aggregate with a long double (`x87`) leaf goes in memory; a result of one long
  double or one complex long double comes back on the x87 stack, `%st0` or `%st0` and `%st1` (`ir_ret_abi/2`,
  `ir_x87_ret/2`). (0.100, 0.108)
- A class that is not trivially copyable or destructible crosses a call by invisible reference and returns through a
  hidden pointer, whatever its size (the Itanium C++ ABI). `cpp_note_nontrivial` marks it in `'$cpp_nontrivial'`: a
  destructor, a written copy or move constructor, a virtual function, or such a base or member. `ir_nontrivial_class`
  makes it `indirect` (`ir_abi_`), the program's classes too. Else `ios_base::getloc()`'s `locale` came back in a
  register. (0.73)
- `ir_leaves` resolves an array member's ELEMENT type first (`once(ccl_resolve_type(E0, E))`): `unsigned long
  __first_[2]` of a bitset's base held `typedef(size_t)`, which has no size, so the ABI of `bitset<70>` failed -- and a
  failure in the lowering backtracks into the resolver and every statement before it, which are emitted AGAIN (nothing
  undoes an emitted line): the body of `main` came out twice, a duplicate alloca LLVM refused. (0.117)
- An empty class crosses a call as one byte, one `i8` piece on SysV. A zero-size aggregate takes `ir_abi_`'s size-0
  clause, also `i8` (`ir_pieces_type([], i8)`). (0.54, 0.89)
- `ir_fn_sig/6` spells a define, a call and a declare alike. A define stores the pieces in an alloca aligned 16 and uses
  byval and indirect parameters in place (`ir_params/4`). A call goes through a temporary, sret first, and reloads a
  direct return (`ir_call_/6`, `ir_arg_parts/5`). Variadic arguments take the default promotions
  (`ir_promote_arg/4`). `ir_arch_init` sets `'$ir_arch'`: `aapcs` on arm64 (`ccl_host_arch/1`), else `sysv`; the arm64
  side is written and not proven. `test/driver.sh` checks both directions against clang (`test/c/link/abi_main.c`,
  `abi_helper.c`), and `test/c/run/abi_libc.c` goes through `div` and `ldiv`. (M3)
- A reference handed to a by-value aggregate parameter is read through before the argument is split into its parts
  (`ir_args_`, `ir_ref_value_type/2`): the value of a cast to a reference and of a forwarding reference is the
  referent's address. `test/cpp/run/refbyvalue.cpp`. Else `std::invoke` of a generic lambda `[](auto a)` stored
  the address as the struct, and LLVM refused it (`std::format`'s visit over `monostate`). (0.112)
- THE SysV REGISTER BUDGET (psABI 3.2.3, 0.117): six INTEGER and eight SSE registers serve a call, and an argument whose
  eightbytes do not ALL fit the free ones goes wholly on the stack. `ir_regs_start/2` opens the budget (a result in
  memory takes one INTEGER register for its sret pointer), `ir_regs_take/5` charges each parameter: a scalar one
  register of its class, an `__int128` two INTEGER, a `direct` struct one register per eightbyte by that eightbyte's
  class, and the struct that does not fit becomes `memory` (byval) -- a long-lived defect: after five `long`, a 16-byte
  struct of two `long` went to the sixth register and the stack, where clang passes it on the stack whole. The budget is
  threaded through the declare (`ir_params_lls`), the define (`ir_params`) and the call (`ir_args_`, the variadic tail
  included). Checked both ways against clang in `test/c/link/abi_main.c` (`budget_*` built by clang, `bud_*` by
  cicilang) and `test/driver.sh`; the 0.116 library fails the new lines. AAPCS64 has no such rule here. (0.117)
- `__int128` and `unsigned __int128` are `i128`: two INTEGER eightbytes, aligned 16, in two registers or none (the
  budget above), 16 bytes in a struct at a 16-byte boundary, `big(A)` constants spelled whole (`ir_gconst`,
  `ir_big_text`). `test/c/run/int128.c`, `test/cpp/run/int128.cpp`. (0.117)

### The empty class and the empty base

- A C++ class with no data members has size 1 ([class]/4; `ccl_class_size`, C++ only); a C empty struct stays 0 bytes.
  The test is the member list, written once (`ccl_no_data_members`, for `ccl_class_size` and `ccl_empty_layout`), never
  "lays out to zero": `ccl_members_layout_` skips a member that it cannot size yet. `char p[0]` alone stays 0 bytes.
  `emptyclass.cpp`. Else basic_string's `__rep_` became a member of no bytes. (0.89)
- An empty base (`cpp_empty_class`: no data, no slots) has no sub-object, as the first base (`cpp_base_layout_`) or a
  later one (`cpp_extra_bases_`). Its address is the object's (`cpp_base_place`, `cpp_base_src`, `cpp_base_hop`); a
  memberwise copy names it by a reference cast. It keeps its alignment as `align_as(int(A))` (`cpp_empty_base_align`):
  libc++'s `__max_align_impl` derives from six empty `alignas` bases. (0.71, 0.89)
- A base's names are found through `cpp_base_scope/2`, the first base, then each later one (`'$cpp_extra'`): typedefs,
  static constants, statics, `cpp_has_member` and methods. `cpp_extra_method` takes the object's address for an empty
  base, `'$cpp_base_slot'` for one with storage. `ctype<char> : locale::facet, ctype_base`. (0.71, 0.88)
- An empty class value moves no bytes. A store to an `empty(_)` slot or of an empty class value writes nothing, and a
  load gives zero (`ir_store_slot`, `ir_load_slot`, `ir_empty_class`). `emptyassign.cpp`. Else libc++ 18's compressed
  pair wrote over a pointer's low byte when it swapped its empty deleter. (0.89, 0.94)

### `alignas` and `[[no_unique_address]]`

- `alignas` on a class, struct or union stays in the tag as `align_as(E)` after the members, folded in the class's
  words (`cpp_align_tag` via `cpp_array_bound`). The layout reads it (`ccl_tag_size` -> `ccl_align_as`): never below
  the natural alignment, the size rounded up ([dcl.align]). `alignas.cpp`. (0.89)
- `_Alignas(E)` or `alignas(E)` among an object's or a member's specifiers is the qualifier `aligned(E)`, which
  `ccl_size_align`, the alloca and the global read (`ir_aligned_q`, `ir_galign`). It raises the alignment and leaves
  the size alone (0.112). As an attribute elsewhere, `ccl_gnu_attr` drops it. (0.99)
- `[[no_unique_address]]` is the one attribute the reader keeps, in the member's bit-width slot (`ccl_take_nua`,
  `ccl_plain_width`). A marked member whose type has bytes lies where an unmarked one lies; the ABI agrees.
  `nounique.cpp`. (0.89, 0.96)
- An empty marked member lies where Itanium 2.4 II.3 puts it (`ccl_empty_offset`, `ccl_empty_step`): at 0, unless an
  empty subobject of its type is there; then at the data size rounded to its alignment, stepping by it. It takes no data
  bytes and keeps its alignment. The size is the larger of the data and the end of the empty subobjects
  (`acc(Seen, EmptyEnd)`). A plain member of an empty class counts as one in the way. `nounique2.cpp` (C++20). (0.96)
- An empty marked member has no LLVM element. Its map entry is `m(N, empty(Off), T, empty)`, and `ir_member_slot`
  addresses it by byte offset (`getelementptr inbounds i8`). (0.96)

### Base sub-objects

- A first base that is neither virtual nor empty is the `$base` member at offset 0; `this` is never adjusted for it.
  (0.34)
- A later base with storage is its own sub-object, `$base$2`, `$base$3` ... (`cpp_extra_bases_`, `'$cpp_base_slot'`),
  after the first base and before the own members ([class.derived]). It is built and destroyed with the first base
  (`cpp_extra_inits`, `cpp_dtor_body`) and found by `cpp_base_scope` and `ir_base_route`. `std::tuple` and `std::bind`
  are built so. `multibase.cpp`. (0.88)
- A virtual base must be the first base: a later one refuses `multiple_inheritance`. (0.88)
- The PRIMARY base is laid out first (the Itanium ABI): where the first base written has no table and a later
  non-virtual one has, the first such is moved to the front at registration (`cpp_primary_first/3`), the bases
  written before it follow it, and the class's table pointer is in it. The bases are still constructed in the order
  written and destroyed in the reverse (`'$cpp_primary_moved'(C, K)`, `cpp_bases_in_order/4` over one group of
  calls per later base, a base with nothing to call giving an empty group). Why: refused by name since 0.108,
  `polymorphic_base_after_a_plain_one`. `primarybase.cpp`, `primarybase2.cpp`. (0.112)
- A pointer to a derived class converts to its base by the base's offset (`ir_convert`; `ir_base_path`,
  `ir_base_route`, `ir_base_hops`), and a null pointer stays null ([conv.ptr]/3; `nullbase.cpp`). A reference binds the
  same way at a local, a parameter and a cast (`ir_ref_to`, `ir_ref_hops`). (0.72, 0.99)
- A cast to a reference is a conversion of its own ([expr.static.cast]): `ir_ref_to` makes the operand-to-target
  conversion (`ir_ref_cast`), then the binding's (`ir_ref_hops`). `basecast.cpp`. Else tuple's
  `L1::sw(static_cast<L1 &>(o))` swapped the wrong leaf. (0.90)

### Virtual functions and vtables

- A class's slots (`cpp_slots/4`, in `cls/6`) are the base's, then each own virtual method by name and arity. A method
  that overrides a base slot, or a later base's virtual (`cpp_overrides_extra`), is virtual without the word. A slot is
  named `M.K` or `op.<word>.K` (`cpp_slot_name`): `__base::__clone()` and `__clone(__base *)` are two slots. Its result
  type is resolved in its class (`cpp_slot_ret`). (0.72, 0.88, 0.110)
- A virtual destructor, by `virtual` or `override`, takes two slots, `'$dtor'` and `'$dtor_del'` (`cpp_own_slots`):
  Itanium's complete and deleting destructors, both the one destructor here. A virtual call into an object that the
  shipped library made indexes that object's own table. (0.72)
- The class that introduces the slots has a `'$vptr'` to `struct C.vt` (`cpp_vt_struct`): a function pointer per slot
  over the owner's `this` (`cpp_vt_owner/2`), a `dying` `this` for the destructor slots. The vptr follows the base
  sub-objects, and comes first in a class with a virtual base. (0.34, 0.72)
- The table `C.vtable` has the Itanium shape `{ [$vbo,] $off, $ti, $vt }` (`cpp_vtable`): the virtual base offset where
  needed (`vptr[-3]`), the offset to top (`vptr[-2]`), the type_info (`vptr[-1]`), and the slots, where the vptr points.
  Each slot holds the most derived implementation (`cpp_primary_entry`, `cpp_slot_def`, `cpp_slot_impl/4`,
  `cpp_dtor/2`); a pure slot that nothing overrides holds null. (0.34, 0.108, 0.110)
- Every constructor, the implicit one too, stores the primary vptr after the base's constructor, then each secondary
  one (`cpp_vptr_store/3`). A destructor stores the same tables FIRST ([class.cdtor]/4) and ends with the bases'
  destructors (`cpp_dtor_body`). Why: without the store a virtual call in a base's destructor reached the derived
  class's override, whose members were already destroyed (`~A() { f(); }` under a T called T::f). A diamond path's
  base variant (`.nv`) stores nothing either way. `dtorvt.cpp`. (0.112) `ir_gconst` takes a
  function's or a global's address for a table, and the check counts `&global` static (`ck_static_value`). (0.34, 0.108)
- `p->m(a)` of a slot dispatches through the vptr, cast to the object's own `struct C.vt` (`cpp_dispatch/5`); the tables
  are laid out base first. `o.m(a)` dispatches only for a reference or `*p` (`cpp_static_object/1`). A bare `m(a)` and a
  virtual `operator()` dispatch too. A virtual of a base that the class does not name uses that base's table
  (`cpp_hops_class`). `delete` goes through a virtual destructor's slot (`cpp_destroy`). (0.34, 0.72, 0.88, 0.110)
- `cpp_abstract_class/1` is the one test for an abstract class: a slot with no implementation or a pure one
  (`cpp_slot_pure`). A complete object of it refuses `pure_virtual` (`cpp_not_abstract`; `test/cpp/abstract.cpp`); a
  base sub-object is still built ([class.abstract]/6; `'$cpp_base_ctor'`), as libc++'s `__shared_weak_count` needs.
  `__is_abstract` asks the same test (`abstracttrait.cpp`). (0.99, 0.112)

### Multiple polymorphic bases and thunks

- A later polymorphic base keeps its own vptr in its sub-object (`'$cpp_poly_extra'`), to a secondary table
  `C.vtable<S>` (`cpp_secondary_table`). Its prefix holds minus the sub-object's offset and the class's type_info. Its
  slots are the base's implementations or thunks `C.thunk<S>.<slot>` that move `this` back and call the override
  (`cpp_thunk_entry`, `cpp_mk_thunk`). A thunk is `'$cpp_libfn'`; the check walks the override. `multibase2.cpp`,
  `multibase3.cpp`. (0.108)
- A class derived from such a class makes its own secondary tables for those sub-objects, one `$base` hop further in
  (`cpp_inherit_poly_extras`, `'$cpp_poly_path'`). `thunkdeep.cpp`. (0.110)
- `delete` through a later polymorphic base frees the complete object, found by the offset to top before the destructor
  runs (`cpp_delete`, `delete_poly`). (0.108)

### Virtual bases and the diamond

- A class with a virtual first base (`'$cpp_vbase'`) is laid out as a complete object: its own vptr, its own members,
  the shared `$base` last (`cpp_base_layout`). The base's virtual destructor puts two destructor slots first in the
  class's own table (`cpp_vbase_dtor_slots`); with none written the class gets the implicit one
  (`cpp_implicit_dtor_needed`). `basic_ostream : virtual basic_ios`; `virtualbase.cpp`. (0.72)
- With a table of its own (`cpp_vbase_dynamic`), it reaches the base through the table. Its struct carries
  `virtual_base`, or `virtual_base_of(T)` in its `.nv` form (`ccl_vbase_kind/2`); `ir_member_slot` adds the offset at
  `vptr[-3]` (-24), and `cpp_vbase_offset` writes it into every table. The complete object builds and destroys the base
  at its own place (`$base!`, `cpp_class_base_place`). A polymorphic virtual base holds this class's secondary table.
  libc++'s streams are read through the shipped tables the same way. `vbasertti.cpp`. (0.110)
- A diamond ([class.mi]/6) has clang's record layout (`cpp_diamond_paths`). Each path is its `B.nv` form, the class
  without the shared base at its data size, so a later member can use its tail padding (`ccl_size_align`'s
  `virtual_base_of` clause). The complete object holds the shared base once, at its end (`$vb`, `'$cpp_vb_holder'`,
  `'$cpp_nv_base'`), built first and destroyed last. It stores its own tables before the paths' base-variant
  constructors and destructors run, `C.C.k.nv` and `C.dtor.0.nv` (`cpp_nv_twin`, the ABI's C2 and D2; the program's
  classes since 0.110 and, since 0.117, a LIBRARY class's constructors written in its class: libc++'s basic_iostream is
  a diamond over basic_ios, and `std::stringstream` is built with the `.nv` constructors of basic_istream and
  basic_ostream compiled here). (0.110, 0.117)
- A path base's SHIPPED destructor with an EMPTY definition in the header is left out of a diamond's destruction
  (`cpp_nv_dtor/4`, `cpp_empty_header_dtor/1`; 0.117): the library ships `~basic_ostream<wchar_t>()` as the complete
  destructor only and has no base-variant form to call, `'$no_dtor'` stands for the call, and what the destructor would
  do is the virtual base's destruction, which the holder performs. `std::wstringstream`, a diamond libc++ does not ship
  for wchar_t, is destroyed so. Any other shipped path destructor keeps the `.nv` name and fails at the link.
  `stdstringstream.cpp`. (0.117)
- A class laid out otherwise than the ABI lays it is never CALLED by the shipped library's members (0.117). The ABI puts
  a class's own members before the virtual base at the end of the complete object, and this compiler embeds a base that
  has a virtual base WHOLE (the base at the end of it) before the derived members, so `basic_ofstream<char>`'s `__sb_`
  lies at offset 160 here and 8 for clang. The members that libc++ exports for such an instance (`basic_ofstream<char>::
  open`, `basic_ifstream<char>::open`, the two overloads each) read it at the ABI's offset: they are compiled from their
  definition in the header instead (`cpp_nonabi_bases/1`, `'$cpp_nonabi'` around `cpp_member_defs` in
  `cpp_instance_body`, read by `cpp_extern_shipped`). The members of the class that HOLDS the virtual base
  (`basic_ostream`) and of a diamond's holder (`basic_iostream`) are shipped as before: their layout is the ABI's.
  `stdfstream.cpp`. (0.117)
- A diamond's method takes its final overrider from the path that overrides it (`cpp_final_impl`, a
  `cpp_primary_entry` thunk). A path that holds the base further in stays whole, and the later paths are `.nv`. A
  diamond over a virtual base with no table refuses `virtual_base_by_two_paths` (`test/cpp/diamond.cpp`), and so does a
  program class over two library classes sharing a virtual base (`cpp_direct_nv`). `diamond.cpp`, `diamond2.cpp`.
  (0.110)

### Pointers to members

- A pointer to member keeps the type `memptr(C, Q, T)` through the passes (`cpp_is_type`), so deduction and
  `__weak_result_type`'s specializations match it (`cpp_match_one`). (0.88)
- A pointer to a data member is its byte offset, an `i64` (`cpp_member_address` over `cpp_offsetof`); `x.*pm` and
  `p->*pm` read `*(T *) ((char *) &x + pm)` (`cpp_memptr_read`). A member function pointer read as a value refuses
  `pointer_to_member_function_read`. A PLAIN struct's data member has one too (`cpp_member_address`'s clause over
  `ccl_tag/2`): a struct of data members alone stays C's and is no registered class, so `&Pt::x` met `no_member(Pt, x)` unless
  the program also derived from `Pt` -- while `std::invoke(&Pt::x, p)`, `std::mem_fn(&Pt::x)` and a ranges projection are written
  over exactly such aggregates; `cpp_memptr_object` takes a pointer to one as an object's pointer. `memptrdata.cpp`,
  `invokedata.cpp`. (0.99, 0.126)
- The member of a CONST object is const, and the member of an RVALUE is an xvalue ([expr.mptr.oper]/6, [expr.ref]/6;
  `cpp_memptr_qualify/4`, the one rule `__builtin_invoke` has in `cpp_invoke_result/4`): `x.*pm` carries the object's
  `const` (`const int &`) and, for an object that is no lvalue, is `T &&`; `p->*pm` carries the pointee's `const`. libc++
  18's `__invoke` reads `decltype(std::declval<_A0>().*std::declval<_Fp>())`, and `invoke_result_t<int Pt::*, const Pt &>`
  was `int &`, `<int Pt::*, Pt &&>` `int &`. A type the inference cannot settle leaves the plain read. `memptrqual.cpp`,
  `invokedata.cpp`. (0.126)
- A pointer to member function is `{ ptr, adj }`, 16 bytes aligned 8 (`ccl_size_align`, `ir_type_`), with the fields
  `ptr` and `adj` (`ccl_members_of_`, `ir_member_slot`), built by a cast (`ir_expr(cast)`, `ir_gconst`). `ptr` is the
  address, or `1 + slot offset` for a virtual member (`cpp_slot_offset`, 8 bytes a slot). An overloaded member's
  address refuses `overloaded_member_address`. `memfnptr.cpp`. (0.100)
- A call through it (`cpp_memptr_call`) moves `this` by `adj`; an odd `ptr` indexes the object's own table, read as the
  member's class, an even one is the function. `(obj.*pm)(args)`, `(p->*pm)(args)` and `__builtin_invoke(pm, obj, ...)`
  take this road. A base's member pointer converted to a derived class's adds the base's offset to `adj` ([conv.mem];
  `ir_convert`). `memfnadj.cpp`. (0.100, 0.108)

### The array cookie

- `new T[n]` of a class that constructs or destroys (`\+ cpp_trivial_class`) uses the Itanium array cookie
  (`cpp_new_objects`). Only a class with a destructor gets one: the count, in max(8, alignof(T)) bytes before the first
  element. The elements are made in place, by the default constructor or from braced items, the rest value-initialized.
  (0.108)
- `delete[]` reads the count, destroys in reverse and frees from the cookie (`cpp_delete_array`, `delete_cookie`).
  `new T[n]()` and `new T[n]{}` of a trivial type are `calloc`; `new int[n]{a, b}` stores the items over the zeroes
  (`cpp_new_scalars`). `arraycookie.cpp`. (0.86, 0.108)

### The Itanium mangler

- The compiler's own definitions keep its own names (`C.m.k`, `F.<keys>`, `C.dtor.0`). A name that the shipped library
  defines takes its Itanium symbol from `cpp_ita_*` (the libc++ section says which). A name the mangler cannot spell
  keeps the compiler's name, so the link names it. (0.61, 0.73)
- A function is `_ZN <namespace path> <len>name E <parameters>` (`cpp_ita_function/7`), `v` for no parameter and `z`
  for an ellipsis. `St` is std and no substitution candidate; `St3__1` is one. A function directly in std is
  `_ZSt<len>name<parameters>`. (0.61, 0.73)
- The substitution table is threaded through (`cpp_ita_sub`, `cpp_ita_note`): each prefix level, nested name and
  non-builtin type is a candidate in the order met, and its second occurrence is `S_`, `S0_` ... in base 36. A builtin
  is none; each layer (`P`, `R`, `O`, `K`) is one of its own, inner first. (0.73)
- A class type is `N <prefix> <chain> E` (`cpp_ita_class` over `cpp_class_scope`), or `St<len>name` directly in std. Its
  key is the chain's own, so the type and the same prefix level are one entity (`RS3_`). An instance is
  `<len>name I <args> E`, its template-name prefix and its template-id each a candidate. (0.73, 0.75)
- A member is `_ZN [K] <class chain> <member> E <parameters>`, `K` for a const method; a constructor is `C1`, a
  destructor `D1` (`cpp_ita_member_name`). An operator has the ABI's code (`cpp_ita_op`: `rs`, `ls`, `pL` ...), the
  unary one with no parameter (`cpp_ita_unary`). (0.73, 0.75)
- A function template's instance (`cpp_ita_fn_instance`) has the template-id in its nested name (its prefix a
  candidate, its own arguments never), the return type first, and a template parameter as `T_`, `T0_` ... (decimal),
  each a candidate: `_ZNSt3__16__sortIRNS_6__lessIiiEEPiEEvT0_S5_T_`. (0.92)
- A nested enum is a nested name of its holder (`cpp_ita_type_`; `cpp_class_scope_` finds the holder in
  `'$cpp_ctype'`): `..7seekoffExNS_8ios_base7seekdirEj`; else the stream fixtures failed to link. A program's
  global enum is a global name, `1K` (`cpp_ita_global`); else it resolved to itself without end. `enumarray.cpp`.
  (0.94, 0.110)
- The holder's type must carry the enum's OWN last name (`cpp_class_scope_`, `cpp_last_segment`): an ALIAS of the enum
  in some class (`typedef _Tp value_type` of `__split_buffer<std::byte, ...>`) is no holder. Else `std::byte` was a
  member of that buffer, the chain of names named itself, and `std::vector<std::byte>` took 4 GB in ten seconds (a
  defect since 0.94, met once a library function template had a `byte` among its arguments). `stdbyte.cpp`. (0.117)
- `volatile` is spelled (`cpp_ita_cv/2`, 0.117): `V` before `K`, the group one substitution candidate with its type
  (`void const volatile *` is `PVKv`), and a by-value parameter loses both ([dcl.fct]/5). Dropped, libc++ 18's
  `__cxx_atomic_notify_one(void const volatile *)` was called by `..EPKv`, a symbol no library exports (every
  `-std=c++20` `notify_one`, `notify_all` and `wait` of a `std::atomic` failed at the link). `stdatomic20.cpp`.
- A C struct has its linkage name ([basic.link]): an unnamed one the first typedef that names it, asked before the type
  is resolved (`cpp_ita_c_struct`: glibc's `mbstate_t` is `__mbstate_t`), a named one its tag (`2tm`). (0.94)
- A tag is a C struct to the mangler where no class of that name is registered, or where the one registered stands in
  an `extern "C"` scope, `c` in the header index (`cpp_ita_c_tag`). Why: glibc's `_IO_FILE`, registered by a header
  load, left `__is_posix_terminal(FILE *)` with its plain name, an undefined symbol at the link of `std::print`. (0.115)
- The mangler works without the desugaring's registries (`cpp_class_known`): `test/cpp.pl`'s `c34` spells nine symbols
  as clang++ and the shipped library do. (0.73, 0.94)
- A FUNCTION TYPE, an ARRAY and a POINTER TO MEMBER are parameter types now (`cpp_ita_type_`; 0.117): a function type is
  `F <result> <parameters> E` (`z` for an ellipsis), so a pointer to it is `PF...E`; an array is `A <n> _ <element>`; a
  pointer to member `M <class> <type>`. A parameter of array or function type is the pointer it decays to and loses its
  top-level `const` ([dcl.fct]/5; `cpp_ita_fparams/6`), and the whole parameter type is one substitution candidate
  (`cpp_ita_whole/5`): `void (*)(int, ...)` is `PFvizE`, `int (&)[4]` is `RA4_i`, two `void (*)()` are `PFvvE` and
  `S1_` -- the symbols `std::set_terminate(void (*)())` is shipped under. `__int128` is `n` and `unsigned __int128` `o`.
  `test/cpp.pl`'s `c37`. Such a symbol kept this compiler's own name until 0.117, and the link named it. (0.73, 0.117)

## Exceptions, RTTI, coroutines, modules and contracts

### Exceptions

- libc++ runs its no-exceptions configuration (`__cpp_exceptions`, `__EXCEPTIONS` not predefined): a library throw
  aborts with its message, so no program catches `bad_optional_access`. (0.50)
- The program's own `throw`, `try` and `catch` run over libc++abi (linked through `-lc++`, `ccl_link_libs` on Linux).
  `throw e` is `__cxa_allocate_exception`, the object built in place (`cpp_new_at`), then `__cxa_throw` with the
  type_info and the destructor; `throw E(args)` builds E in the exception's memory. `throw;` is `__cxa_rethrow`. An
  untyped throw refuses `throw_of_untyped`. `exceptions.cpp`, `exceptions2.cpp`. (0.108, 0.110)
- Where the program throws or catches (`'$cpp_eh_used'`, `'$ir_eh'`), a call under a `try` or a scope with defers is an
  `invoke` (`ir_invoke_needed`). Its landing pad (`ir_landing_pad`, personality `__gxx_personality_v0`) lists the
  handlers' type_infos and `cleanup`, runs the defers of the scopes it leaves (`ir_unwind_to`), tests the selector with
  `llvm.eh.typeid.for`, and else resumes. Code run while unwinding makes plain calls. (0.108)
- A handler binds its parameter to `__cxa_begin_catch`'s object, with `__cxa_end_catch` as its scope's defer
  (`ir_handler`); `catch (...)` takes all. A class caught by value is a copy ([except.handle]/15; `cpp_catches`),
  destroyed at the handler's end. `catchvalue.cpp`. (0.108, 0.110)
- The reader keeps `noexcept` (`'$ccl_nx'`): a free function's name joins `'$ccl_nothrow'` (`ccl_note_nx`), a method
  keeps it among its qualifiers. `noexcept(false)` and `throw(X)` are not noexcept; `throw()` is. (0.110)
- noexcept is enforced where the program throws (`'$cpp_throws'`; [except.spec]/5): a noexcept function that makes a
  call has its body in a `try` with a `terminate` handler (`cpp_nx_wrap`). It calls `std::terminate` and runs no
  destructor on the way (`ir_unwind_to`), as clang's pad does. `noexcept.cpp`. (0.110)
- `noexcept(e)` is false when e holds a `throw` or calls a program function that is not noexcept (`cpp_nx_throws`): a
  free function not in `'$ccl_nothrow'`, or a method with no noexcept overload of its name. A library function and a
  destructor count as noexcept. (0.110)

### RTTI

- libc++ runs without RTTI (`__cpp_rtti`, `__GXX_RTTI` not predefined); the program's own `typeid` and `dynamic_cast`
  work over libc++abi. `rtti.cpp`. (0.86, 0.108)
- `typeid` of a type is its type_info (`cpp_rtti_of_type`); of a polymorphic object it reads `vptr[-1]` (`rtti_dyn`);
  anything else refuses `typeid_of`. (0.108)
- A class's type_info is `_ZTI<name>` with the string `_ZTS<name>`, both `linkonce_odr` (`cpp_rtti_chain`,
  `ir_rtti_emit`): `__class_type_info` for a root, `__si_class_type_info` for one base, `__vmi_class_type_info` for
  several bases or a virtual base. A vmi entry is the base's offset x 256 + 2; a table-reached virtual base is flagged
  virtual at -24, and a diamond sets `__diamond_shaped_mask`. (0.108, 0.110)
- A program class at file scope is named `<len><name>` (`cpp_rtti_name`). A library class's type_info is the shipped
  symbol (`_ZTISt13runtime_error`), a builtin's libc++abi's (`_ZTIi`, `_ZTIPKi`); a plain struct is a root. (0.108)
- `dynamic_cast` to a base is a plain conversion. A downcast or a cross-cast calls
  `__dynamic_cast(sub, &src, &dst, -1)`, and null gives null without the call; a failed reference cast calls `abort()`.
  Another target refuses `dynamic_cast_to(T)`. `multibase3.cpp`, `vbasertti.cpp`. (0.108)
- `dynamic_cast<void *>` of a pointer to a polymorphic class is the complete object ([expr.dynamic.cast]/7): the node
  `dyncast(X, void, void, T)`, which the check and the inference read as the other casts, lowered as the address plus
  the offset-to-top at `vptr[-2]`, null kept null. A pointer to a class without a table refuses
  `dynamic_cast_to_void`. `dynvoid.cpp`. (0.112)

### Coroutines

- A body with `co_await`, `co_yield` or `co_return` (outside a lambda) takes LLVM's switch-resumed lowering. The
  desugaring makes it a skeleton (`cpp_coro_skeleton`), in order:
  1. the promise `$promise` declared;
  2. `coro_begin`: `llvm.coro.id`, the frame from operator new, `llvm.coro.begin`;
  3. `coro_ret`: `get_return_object()`, converted as a return is;
  4. the initial suspend's await;
  5. `coro_body`, with a fall-off `return_void()` where the promise has one;
  6. the final suspend's await;
  7. `coro_done`: the defers, `llvm.coro.free`, `llvm.coro.end`. (0.108)
- `co_await e` is a statement expression over the awaiter, through `await_transform` where the promise has one:
  `await_ready()`; else `coro_suspend` (`llvm.coro.save`, `await_suspend(coroutine_handle<P>::from_address(frame))`
  whose void, bool or handle result decides, `llvm.coro.suspend`, a switch whose destroy edge runs each defer); then
  `await_resume()`. `co_yield e` awaits `yield_value(e)`. `co_return` calls `return_value` or `return_void`, runs its
  scopes' defers and goes to the final await. (0.108)
- The awaiter is the awaitable's `operator co_await`, member or free (`cpp_coro_awaiter`; `coawaitop.cpp`). The promise
  type is `std::coroutine_traits<R, Ps...>::promise_type` where the program specializes the traits, a method's object
  first (`cpp_promise_type`), else `R::promise_type`. The promise is built from the parameters where it has such a
  constructor (`cpp_promise_init`). Where the program throws, the body runs under
  `catch (...) { promise.unhandled_exception(); }` (`cpp_coro_guard`). `cotraits.cpp`. (0.110)
- libc++'s `coroutine_handle` builtins (`__builtin_coro_resume`, `destroy`, `done`, `promise`, `noop`,
  `__builtin_coro_frame`) are LLVM's intrinsics (`ir_coro_builtin`). The embedded LLVM runs `default<O0>` at `-O0` too,
  for its CoroSplit (`module/ccl_llvm.cicili`). (0.108)
- A promise with no `get_return_object` is refused (`test/cpp/coro.cpp`); a result with no promise type refuses
  `coroutine_result(R)`. `cogenerator.cpp`, `cotask.cpp`, `coeager.cpp`, `coawait.cpp`, `cotemplate.cpp` (C++20).
  (0.108)

### Modules

- `export module M;` names the unit's module (`ccl_note_module`); `module;` and `module :private;` are nothing; `export`
  before an item or a braced group gives the items; `import <h>;` and `import "h";` are includes. (0.108)
- `import M;` reads M's interface (`ccl_module_path`): one met earlier in the run, else `M.cppm`, `.ccm`, `.cxxm`,
  `.ixx` or `.mpp` beside the importer, then on the path; `import :P` reads `M-P.cppm`. Its functions and initialized
  globals are spliced in `linkonce` (`ccl_module_split`); its classes and templates are read as the program's header.
  `import std;` and `import std.compat;` are a fixed header list (`ccl_std_module_headers`). `modules.cpp` (over
  `mathm.cppm` and `basem.cppm`). (0.108)
- A name the module does not export is not the importer's ([module.interface]/7): `ccl_module_hide` emits it as
  `N$Module` and rewrites the module's own uses (`ccl_note_export`, `'$ccl_exports'`, `ccl_exported`), so the importer
  sees it undeclared (`test/cpp/modhidden.cpp`). (0.110)
- A header unit's macros reach the importer ([module.import]/5; `pp_import_line`; `headerunit.cpp`). An inline function
  that the program's own `"..."` header defines is emitted once, `linkonce`, included or imported (`cpp_header_fns`;
  `hdrinline.cpp`). (0.110)

### Contracts

- C++26 contracts are enforced at run time: `pre(e)` and `post(r: e)` on a function or a method (`ccl_method_quals`,
  `ccl_contracts_apart`), and `contract_assert(e);`. `ccl_contract_body` checks the preconditions first, and the
  postconditions at each return (the result bound for `r`) and at a void function's end. A violation writes
  `contract violation: precondition|postcondition|assertion of F (line L)` to fd 2 and calls `abort()`
  (`contract_violation`). `contracts.cpp` (C++26) exits 134. (0.108)

## libc++: how the library is compiled

### The owner's rule and the configuration

- (owner's rule) Nothing of the standard library is the compiler's own; the C side's freestanding headers
  (`library/include`) are the one exception. C++ compiles against libc++ as it is: C++17 first, then C++20, 23, 26.
  (0.41)
- (owner's rule) A library module is taken whole, its whole surface in fixtures, never function by function. (0.78)
- libc++ runs configurations that it ships, chosen by the predefined macros: no exceptions (0.50), no RTTI (0.86),
  scalar algorithms through `__OPTIMIZE_SIZE__` (0.92), `<atomic>` over `_Atomic` through `__has_extension(c_atomic)`
  (0.100). The preprocessor section has the details.
- `std::move(x)` is the language's own `move(x)`, with no header (`cpp_call` on `scoped([std], move)`). It stays a move
  on a class value or a value holding owners (`cpp_holds_owners/1`), else it is the value. (0.40, 0.83)

### Headers: the index and the load

- A flattened header's items become `'$cpp_hdr'(Key, Item)` facts (`cpp_index_header` over `ccl_flat_items/3`,
  `cpp_index_flat`), their namespace paths `'$cpp_hdr_ns'` facts. `cpp_index_name/2` keys a class by its definition
  (never a forward declaration), a function by its name, a member or static defined out of its class by the class, an
  extern global, an inline variable, an extern template by the template, a concept, and a guide as `$guide.<class>`. A
  summary-served header gives the same items from the AST file (`'$cpp_hdr_ast'`, `cpp_load_ast`); `cpp_hdr_item/2`
  reads either. (0.44, 0.45, 0.61, 0.75, 0.108)
- A header's LITERAL OPERATOR is indexed by its free operator name (`cpp_index_name`: `op.literal_s.2`), noted as a lazy
  inline function (`cpp_note_hdr_fns`, `cpp_register_lazy`: the item renamed to that name, the atom clause then declares
  it with its types resolved) and emitted `linkonce` where a literal calls it: `<string>`'s `operator""s`,
  `<string_view>`'s `operator""sv`. The four `operator""s` overloads (`char`, `wchar_t`, `char16_t`, `char32_t`) are one
  overload set, so a call resolves all four signatures (each `basic_string` instance is registered). (0.117)
- `cpp_hdr_load/1` loads a name's items once (`'$cpp_hdr_loaded'`): on the first miss of `cpp_class` or
  `cpp_class_template`, and on the first ask of `cpp_template` or the overload road (`cpp_hdr_join`, `cpp_fn_ready`), so
  a header's templates and functions join the program's. A load spends the instantiation budget (`cpp_spend/1`, 3000)
  and records `'$cpp_lib'(N)`. (0.44, 0.78)
- A load notes the out-of-class definitions first (`cpp_note_hdr_mdefs`), and runs inside `\+ \+`, at file scope
  (`cpp_isolated` around `cpp_register_lazy`), under `cpp_as_lib(yes, ...)`. A load that refuses throws through, since
  the name is marked loaded first. Else a load met in a function body declared the header's functions in its frame.
  (0.73, 0.80)

### Lazy classes, instances and functions

- A header's class is lazy (`'$cpp_lazy_c'`, `cpp_lazy_class`): registered, its struct emitted, and a member emitted when
  `cpp_method`, `cpp_ctor` or `cpp_own_dtor` first names it (`cpp_use_member/2`, `cpp_make_lazy/5`, trace
  `make_lazy(Name)`). The member is in progress while it emits (`'$cpp_making'`) and noted after; a failure refuses
  `member_not_emitted`. A class with no body (`class bad_alloc;`) registers nothing. (0.44, 0.69)
- A lazy polymorphic class emits only what its table names (`cpp_slot_fns`, in progress while walked); its other
  members come as named. (0.72)
- A library template's instance is lazy too (`cpp_lazy_instance/2`); else `push_back` compiled all of vector and stopped
  at `__swap_allocator`. The program's own instances stay eager, so the safe part sees them. (0.52)
- A member class template of a library class is the library's (`cpp_lib_origin/2` over `'$cpp_nested_tmpl'`): its
  instance is lazy and unchecked. Why: transform_view's `__iterator<_Const>` was checked as the program's, and its
  `__parent_(std::addressof(__parent))` was refused `untied`. (0.113)
- A header's free function is declared at the load with resolved types (`cpp_register_lazy`, `cpp_resolved_params`)
  and emitted `linkonce` where called (`cpp_use_fn/3`, origin `lazy(Item)`), once per overload, in progress while it
  emits and noted after; a failure refuses `function_not_emitted(Name)`. So the `__convert_to_integral` overloads over
  `__int128_t` are never emitted. (0.58, 0.73, 0.78)
- A library class's hidden friend is registered as a free function, its types resolved in its class
  (`cpp_register_lazy_friends`), and its body is walked in that class when emitted (`'$cpp_friend_in'`). Else
  filter_view's iterator `operator==`, which names its nested class bare, matched nothing. `stdviews.cpp`. (0.78, 0.112)
- The unit's own items come first in the bulk noter (`ccl_own_first` in `ccl_items_note`), so an emitted definition
  shadows a summary's raw declaration. (0.78)
- A header's function named as a value (`std::hex`) is emitted as a call would emit it (`cpp_lazy_fn_value`, one
  definition); an overload set goes by its target (`cpp_conv_to`). (0.78, 0.99)
- A header's C++17 inline variable, which no library exports (`__digits_base_10`), is a `linkonce` global of the
  program that names it (`cpp_lazy_inline_var`), its initializer desugared; an `auto` one takes the initializer's type
  (`ranges::iter_move`). A global of an empty class is its zero bytes, with no constructor run (`nullopt`,
  `piecewise_construct`); with no initializer it is value-initialized ([dcl.init]/8): `std::ignore`. (0.73, 0.82, 0.90,
  0.109)
- A nested class of a library class is the library's (`cpp_lib_class` via `'$cpp_encl'`). A library class's
  `consteval` constructor keeps its member initializers and drops its body, a compile-time check that nothing here
  evaluates (`cpp_member_fns`, trace `consteval_ctor_unchecked`): `basic_format_string`'s format parse. (0.84, 0.110)

### Library functions are not checked

- A function from a library header is `'$cpp_libfn'(Name)`: an inline one, a lazy member, an instance of a header's
  template, or what such a walk emits (`cpp_as_lib/2`; a template's origin `'$cpp_lib'(N)`). The check skips it
  (`cpp_library_function/1` in `ck_items`); the lowering lowers it. libc++ keeps raw pointers by its own discipline,
  which the safe part refuses. The program's functions and its own templates' instances are checked. (0.45)
- A library class's value is opaque to the check (`ck_carries_`, `ck_library_class`) and can be moved
  (`ck_moves_library`). A plain pointer that its member returns borrows the object (`ck_borrows_from`), and such a
  borrow can be consumed (`ck_library_root`). (0.79, 0.86, 0.91, 0.94)

### Namespaces: flattening and collisions

- Namespaces flatten to bare names. A qualified type that is no deeper namespace's key and no class goes through the
  type hook again as its bare name (`cpp_type`, trace `flatten(Path, N, in(W))`), so `std::string` reaches the lowering
  as the instance. A file-scope alias in a path is the class it names (`cpp_path_class`: `std::string::npos`). (0.32,
  0.63, 0.84)
- When two namespaces declare one flattened name, the outermost keeps the bare name and a deeper one's item is keyed
  by the shortest unique suffix of its namespace path (`cpp_ns_quals`, `cpp_ns_unique_suffix`, `cpp_index_key`,
  `cpp_qualify_item`; 0.112, where it was the innermost namespace alone). A qualified use resolves to the key
  (`cpp_ns_key` in `cpp_type`, `cpp_call`, `cpp_expr`), a qualified template-id called too (`__elements::__fn<0>{}`,
  views::keys). Else `function<int(int)>` took the wrong `__maybe_derive_from_unary_function`. (0.88, 0.112)
- An ENUM's tag and an unscoped enum's enumerators collide as names do (0.127; `cpp_ns_enum_name/2` in
  `cpp_ns_resolve`, `cpp_qualify_enum/4`): keyed and renamed in the deeper namespace, a qualified enumerator `n2::x`
  taken by its key (`cpp_expr`'s clause before the enumerator road), `n2::Mode::Fast` through the tag's key
  (`cpp_enum_path_tag/3`, `cpp_enum_key_name/3`). Fixture: `nsenum.cpp`. Why: `n2::x` and the bare `x` inside n2 read
  n1's 7, and two enums `Mode` were one tag.
- A bare use in the deeper namespace is rewritten to the key (`cpp_qualify_body`, `cpp_rename_names`; a header's in
  `cpp_index_flat`), base clauses included (`base(Access, N)`, `base(Access, virtual(N))`), unless the item declares the
  name (`cpp_declared_names`: vector's own `begin()`). `nscollide2.cpp`. (0.100, 0.101)
- The program's own collisions follow the same rule before registration (`cpp_ns_resolve`, `'$cpp_ns_own'`): the units
  are rewritten and the table built again; a declared-only function keeps its shipped name. `nscollide.cpp`. (0.100)
- An inline namespace is in the mangler's path (`cpp_hdr_ns`, `cpp_ns_plain`: `St3__1`) and out of the keys:
  two paths are one namespace by their named segments (`cpp_ns_named_path`). (0.100, 0.112)
- An item declared by a namespace-qualified name stands in that namespace ([namespace.memdef]/2; `ccl_flat_quals`,
  `ccl_item_ns_path`) when each segment is a namespace of the same items (`ios_base::flags` stays). This holds in a
  header's index and in the program's units (`cpp_ns_resolve`, `'$cpp_ns_names'`); a variable template's
  specialization is named with its namespace (`cpp_spec_name`). Else libc++'s
  `__format::__enable_insertable<basic_string<_CharT>>` belonged to nothing, and std::format took no string.
  `qualspec.cpp`. (0.112)
- `std::rel_ops` is not indexed (`ccl_flat_items_`): only a using-directive finds its names ([namespace.udir]), which
  is not modelled, and flattened its `operator!=` took every class. `stdviews.cpp`. (0.112)
- A namespace-scope object that is called goes to its class's `operator()` (`cpp_callable_global`, `cpp_object_call`):
  libc++'s customization points, `ranges::iter_move`. `stderaseifuset.cpp`. (0.100)
- A class typedef that asks for itself while it is resolved stays as written, with a guard per class and name
  (`'$cpp_ctd:C.N'`, `cpp_ctd_key`): `typedef __impl __impl` after flattening. No test by shape is made, since
  allocator_traits' `typedef typename __base::pointer pointer` resolves. (0.86)

### Shipped symbols by their Itanium names

- A function that a library header declares and never defines, not `extern "C"`, with a known namespace path, is called
  by its Itanium symbol (`cpp_mangled_name/3`, parameters resolved first). Its prototype is emitted once with the
  ellipsis, resolved types and defaults (`cpp_use_mangled/3`, `cpp_fn_variadic/1`, `cpp_fn_arity_fits/3`):
  `_ZNSt3__122__libcpp_verbose_abortEPKcz`, `std::stoi`. The prototype is DECLARED AT FILE SCOPE (`ccl_gdeclare/1`;
  0.117), not in the innermost frame: an instance's body walk is one, the name was noted done, and the second function
  that called `__thread_local_data()` met a call of no type (`unknown`), so `.set_pointer(...)` on its result refused
  `no_member`: a program with two kinds of `std::thread`. `stdthread.cpp`. (0.61, 0.108, 0.117)
- A member that a header declares and the shipped library defines takes its symbol where declared, called and slotted
  (`cpp_mangle/4`). `cpp_shipped_member` says which: no body in the class, not pure, not defined out of the class
  (`cpp_defined_out_of_class`), operators included. Its parameters are resolved in the class first
  (`ctype<char>::do_narrow`). A const one keeps its symbol, which spells `K`, where the compiler's own name ends `.c`
  (`cpp_shipped_member_q`). (0.73, 0.79)
- A shipped static data member takes its symbol (`cpp_static_name`: `_ZNSt3__15ctypeIcE2idE`); one that folds or that
  its class defines (`cpp_static_here`) is the compiler's own. A library class's destructor declared with no body is
  called by its symbol (`cpp_dtor_name`: `_ZNSt3__18ios_baseD1Ev`), any other is `C.dtor.0`; a constructor with no body
  is a declaration under its symbol (`bad_alloc()`). (0.46, 0.72, 0.73, 0.90)
- A static member FUNCTION that the shipped library defines is declared and called by its ABI's signature, with no
  `this` (`cpp_note_static_abi/2`, `'$cpp_static_abi'`; 0.127). The desugaring keeps its own null first argument, which
  every pass reads as the object's place, and the lowering drops it at the call and in the declaration (`ir_call/4`'s
  first clause; an object with side effects is still evaluated). Fixture: `shipstatic.cpp`. Why:
  `ios_base::sync_with_stdio(true)` handed the library a null where its bool goes, and `locale::global(loc)` a null for its
  locale.
- `extern ostream cout;` is registered on the first ask (`cpp_lazy_var`) under its exported symbol (`cpp_mangled_var`
  over `'$cpp_hdr_ns'`), `_ZNSt3__14coutE`; `cpp_global_var/2` gives it to `std::cout` and a bare `cout`. (0.71)
- A header's enum keeps its namespace path without being an item to load (`cpp_enum_ns_name/2` in `cpp_index_flat`,
  and in the AST beside the summary, `'$cpp_hdr_ast_ns'`), so in a shipped function's symbol it is a nested name:
  `to_chars(char *, char *, double, chars_format)` is `_ZNSt3__18to_charsEPcS0_dNS_12chars_formatE`. A program's own
  enum stays a global name. `tocharsfmt.cpp`. Why: spelled `12chars_format`, the link named six `to_chars` for
  `std::format`. (0.112)
- A function template's instance with no body anywhere is the shipped library's, called by its symbol at the call and
  target roads (`cpp_ita_fn_instance`): `extern template __sort<__less<int>&, int*>`. (0.92)
- `extern template class X<Args>;` is noted at the load (`cpp_note_extern` -> `'$cpp_extern'(N, Args, all)`), and
  `extern template R X<Args>::m(Ps);` notes one member (`member(M, K)`). An instance whose first arguments match
  (`cpp_extern_args`) keeps those out-of-class definitions declared (`cpp_member_def_key`, `cpp_extern_shipped`) and
  calls them by their symbols: `cin >> n` calls `_ZNSt3__113basic_istreamIcNS_11char_traitsIcEEErsERi`. An `inline`
  definition stays compiled (`cpp_mdef_inline`; libc++ 21 writes each `_LIBCPP_HIDE_FROM_ABI` member `inline`), as do a
  nested class's definition, a member template (`cpp_mdef_function`) and in-class bodies. (0.75)
- A definition marked hidden stays compiled too (`cpp_mdef_inline` on the qualifier `hidden`, the reader's mark of
  `__visibility__("hidden")`): libc++ 18 writes `_LIBCPP_HIDE_FROM_ABI void basic_stringbuf<...>::__init_buf_ptrs()`
  without `inline`, and the link named the symbol (`std::quoted` over an `istringstream`). (0.112) A mark on an
  attribute that BEGINS an item, after a template head, is kept too (0.113). `stdquoted.cpp`. A constructor or
  destructor defined out of its class keeps `inline` and the mark in its qualifiers (reader 112), so libc++ 18's
  `inline basic_ofstream<...>::basic_ofstream(const char *, ios_base::openmode)` is compiled and the program's
  `std::ofstream out(path)` links (`cpp_mdef_inline` reads the `ctor` and `dtor` shapes). (0.117)
- A NAME THE C LIBRARY DECLARES is never mangled, whatever other namespaces list it (`cpp_header_c_name/1`, the index's
  path `c`; 0.117). The index lists a name's paths in the order the headers were read, and `remove` came as
  `[std, __1]` -- the algorithm's template -- before `c` -- stdio's -- when `<fstream>` precedes `<cstdio>`; the plain
  declaration was called as `std::remove(const char *)`, a symbol no library has. Such a C function is declared again
  as an item when the table holds another overload under its name (`cpp_c_decl_current/2` in `cpp_use_fn`; the table
  keeps ONE type per name, here the template's raw signature, and the passes rebuild it from the items): without it the
  lowering met `_ForwardIterator` in the call. `stdfstream.cpp`.

### Builtins answered

- `cpp_builtin_call/3` answers libc++'s builtins as this compiler can:
  - `__builtin_is_constant_evaluated` is false, and `__builtin_constant_p` is 0;
  - `__builtin_operator_new` and `__builtin_operator_delete` are `malloc` and `free` at any arity, as written-out
    `::operator new` and `::operator delete` are (`cpp_operator_new/3`);
  - `__builtin_launder`, `__builtin_assume_aligned` and `__builtin_expect` give their operand, and
    `__builtin_addressof(X)` is `addr(X)`;
  - `__builtin_assume`, `__builtin_assume_dereferenceable`, `__builtin_unreachable` and `__builtin_prefetch` are
    nothing;
  - `__builtin_invoke(f, args...)` is the call, through `cpp_memptr_call` for a member pointer (`stdinvoke.cpp`); a pointer to
    a DATA member applied to an object is `o.*pm`, to a pointer to one `p->*pm` ([func.require]/1.4, 1.5;
    `cpp_invoke_object/4`): the object must be of the member's class or a class derived from it, else the call is refused
    (`invoke_object(C)`, what `is_invocable_v<int Pt::*, int>` reads); the result carries the object's `const` and, for an
    rvalue object, is an xvalue (`int &&`; `cpp_invoke_result/4`). libc++ 21 writes `std::invoke` and `__invoke_result` on
    it, where libc++ 18 had overloads of `__invoke` that read `std::forward<_A0>(__a0).*__f`. `invokedata.cpp`.
    (0.50, 0.60, 0.80, 0.92, 0.100, 0.126)
- `__builtin_bit_cast(T, e)` ([bit.cast]; `cpp_trait/3`, 0.117) is a statement expression: a local of T, a local copy of
  e (its type unref'd and unqualified), a `memcpy` of `sizeof(T)` bytes between them, the local of T last. <bit>'s
  `std::bit_cast` is `return __builtin_bit_cast(_ToType, __from);`; the builtin was `trait_unknown`. `stdbitcast.cpp`.
- The memory builtins are libc's: `memcpy`, `memmove`, `memset`, `memcmp`, `memchr`, `strlen`, and
  `__builtin_char_memchr` as `memchr`. `ir_cpp_prelude` declares `malloc`, `free`, `calloc`, `memcpy`, `memmove` and
  `memset` where the file did not. `__builtin_wmemchr`, `wmemcmp` and `wcslen` are libc's, declared where no header did
  (`cpp_wide_fn`): `std::find` of an int goes that road. (0.60, 0.76, 0.92)
- The math builtins are libm's (`cpp_math_fn`, `cpp_math_stem`, `cpp_math_shape`): `f` float, `l` libm's own long double
  function, each declared once where no header did (`cpp_math_declared`): the rehash's `__builtin_ceilf`. `scalbn` and
  `ldexp` take (T, int), `frexp` (T, int *), `modf` (T, T *), and `ilogb` answers an int (`cpp_math_odd/4`):
  `<complex>`'s division calls `std::scalbn` and `std::logb`. `__builtin_abs`, `labs` and `llabs` are the C library's
  too (libc++'s `<stdlib.h>` writes `abs(long)` through `__builtin_labs`). (0.81, 0.108, 0.117)
- `__builtin_popcount` and its forms fold where their argument folds, over the type's width (`cpp_popcount`): libc++'s
  `digits`. `__builtin_offsetof` comes from the layout (`cpp_trait`, `cpp_offsetof`). (0.45, 0.60, 0.94)

### Traits answered

- The traits are decided in the desugaring: `cpp_trait` (`__is_same`, `__builtin_offsetof`), `cpp_trait_of` (the
  one-type tests), `cpp_trait_n` (constructible, assignable, convertible, base_of) and `cpp_builtin_type` (the type
  traits). An unknown one refuses `trait_unknown(N)`; a nothrow one is the plain one. A `type(T)` argument is a type
  (`cpp_expr(_, type(T0), type(T))`): libc++ 18's `is_copy_constructible`. (0.44, 0.93)
- A PLAIN STRUCT IS ITS OWN BASE (`__is_base_of`, `cpp_base_of/2`; [meta.rel]: `is_base_of<T, T>` holds for a class that is
  no union; 0.126): a struct of data members alone is no registered class and has no base, so only itself, and a pointer to
  it is none. It was false, and libc++ 18's `__enable_if_bullet4` of `__invoke` (`is_same<_ClassT, _DecayA0>::value ||
  is_base_of<_ClassT, _DecayA0>::value`) read it. `memptrqual.cpp`. (0.112, 0.126)
- `*e` OF AN ARITHMETIC VALUE IS REFUSED (`cpp_deref_operand/1`, `deref_of_arithmetic(T)`; 0.126), as an operator on a class
  that has none is: an operand whose type is KNOWN and arithmetic (an enumeration included). A detection reads it --
  libc++ 18's `decltype((*std::declval<_A0>()).*std::declval<_Fp>())` with `_A0` `int` is a substitution failure, and the
  dereference had stayed in the tree, the candidate held and its body failed in the lowering (`is_invocable<int Pt::*,
  int>`). A type the inference could not settle is let through. `memptrqual.cpp`. (0.126)
- `__datasizeof(T)`, clang's builtin, is the Itanium dsize (`cpp_trait`): a POD's whole size (no base, no table,
  trivial; `cpp_pod_layout`), else the byte where its last data member ends (`cpp_lays_end`). The preprocessor answers
  `__has_extension(datasizeof)` with 1, as clang does, so libc++ 18's `__libcpp_datasizeof<T>::value` is that builtin.
  `datasizeof.cpp`. Why: the fallback libc++ writes for other compilers, a member template's explicit specialization,
  did not fold, and the static was an undefined symbol wherever `__constexpr_memmove` copied a range. (0.112)
- Constructible and assignable unref the argument and count constructor templates, defaulted constructors, a made
  implicit default constructor (`cpp_constructible`, `cpp_ctor_arity_fits`) and an assignment template
  (`cpp_assign_member` over `'$cpp_mt'`). Else `std::tie(a, std::ignore) = f()` read an int as an address. (0.46, 0.90,
  0.93)
- `cpp_convertible` passes top-level qualifiers (`cpp_same_unqualified`) and the qualification conversion ([conv.qual];
  `cpp_quals_added`; `qualconv.cpp`), through an array too (an array's element carries the array's qualifiers
  [basic.type.qualifier]/3: `int (*)[]` converts to `const int (*)[]`, which libc++ 18's `__span_array_convertible` asks
  of `span<const int>(span<int>)`; 0.117, `stdspan.cpp`); a pointer to a derived class converts to its base
  ([conv.ptr]/3; `cpp_pointer_to_base`), and a function to a pointer to it ([conv.func]). A class converts to another
  class when it is derived from it (`cpp_class_fits`), when the target's converting constructor takes it
  (`cpp_converting`) or when its conversion function gives the target (`cpp_conv_result`): the class-to-class case of
  `is_convertible`, which `three_way_comparable_with` and `std::variant`'s selection ask. (0.88, 0.93, 0.100, 0.117,
  0.121)
- A conversion to a class asks the source's type (`cpp_converting/2`): a constructor whose parameter takes its kind.
  Why: any one-argument constructor counted, and `is_convertible<const wchar_t *, string_view>` was true. (0.115)
- `__is_trivially_equality_comparable` (`cpp_trait_of`) is true for the integral types and pointers. It is false for a
  floating type (0.0 == -0.0 with other bits), a class, and an enum (`cpp_enum_type/1`), since a program may write its
  own `==` for an enum (`enumeq.cpp`). False for an int, `std::find` recursed; true for an enum, `std::find` used
  `memcmp` past the program's `operator==`. (0.92, 0.112)
- An enumeration is no arithmetic type ([basic.fundamental]): `__is_integral`, `__is_arithmetic`, `__is_signed` and
  `__is_fundamental` ask `cpp_arith/1`, which is `ccl_is_arith` without an enum (`cpp_enum_type/1`; the inference's
  `ccl_is_arith` still counts an enum, for C's usual conversions). Else libc++ took an enum for an integer. (0.112)
- `__is_volatile` reads the top-level qualifiers, a pointer's included; `__is_abstract` asks `cpp_abstract_class/1`.
  The member-pointer traits answer on `memptr(...)`; libc++ 18 picks its `__invoke` overloads by them
  (`memptrtraits.cpp`, `stdbind.cpp`). `decltype` of a call through a member function pointer is the member's result,
  its reference kept: `cpp_decltype_of` reads the statement expression `cpp_memptr_call` makes (`cpp_called_fn/3`: the
  last call through a cast to the function type or through a local of it), and the lowering binds a reference result
  through such a statement expression (`ir_ref_result/2` in `ir_ref_of`). Why: the clause on the bare call matched
  nothing since 0.100, so `std::invoke(pm, s) += 2` over `int &(S::*)()` wrote into a dead copy. `memptrdecl.cpp`.
  (0.93, 0.100, 0.112)
- The reference-temporary traits (`__reference_constructs_from_temporary`, `__reference_converts_from_temporary`,
  `__reference_binds_to_temporary`) and `__builtin_{lt,le,gt,ge}_synthesizes_from_spaceship` are false (`cpp_trait`).
  (0.84)
- `cpp_builtin_type`: `__remove_cv`, `__remove_const` and `__remove_cvref` strip a pointer's own qualifiers too
  (`cpp_strip_quals`) and keep a named type; `__remove_extent`, `__remove_all_extents`, `__add_pointer`,
  `__remove_pointer`, `__decay`, `__add_lvalue_reference` and `__add_rvalue_reference` (collapsing), `__make_unsigned`
  and `__make_signed` (`cpp_signedness/3`) answer. `__underlying_type(E)` is the enum's written base ([dcl.enum]), else
  `int` when an enumerator is negative and `unsigned` otherwise (`cpp_underlying_of/2`; the lowering's size for an
  unfixed enum is 4 bytes). `underlyingtype.cpp`. (0.60, 0.72, 0.79, 0.86, 0.117)

### The ordering classes of `<compare>`

- `<compare>`'s ordering classes are libc++'s own, loaded on demand (`cpp_ordering_class`). A scalar `<=>` is
  `strong_ordering` for integers and pointers, `partial_ordering` for floating operands (`cpp_scalar_ordering`), valued
  as the private constructor builds it (`cpp_ordering_value`: one `signed char`, -1, 0, 1, or -127 unordered). `o < 0`
  and `std::is_lt(o)` reach the hidden friends. Without `<compare>`, a scalar `<=>` is an int. `stdcompare.cpp`. (0.101)
- A defaulted `<=>` answers the class written, else the common category of its pieces, else an int
  (`cpp_defaulted_ordering`). The pieces are `pc(A, B, T)` (`cpp_cmp_pieces`), the base first, an array element by
  element; a floating piece makes it partial and compares unordered on NaN ([class.spaceship]/2; `cpp_cmp_sign`).
  `std::compare_three_way` and `common_comparison_category_t` follow (`stdcompare2.cpp`). (0.101, 0.103, 0.104)

## The safe part

### The check in the build

- `library/ccl_check.pl` checks ownership before anything is lowered. `ccl_ir_units/2` runs `ccl_check_noted/1` over
  the table it built, after the C++ desugaring. `ccl_check_units/1` builds a table of its own. A violation is a
  compile error. Each function is walked inside `\+ \+` (`ck_items/1`). A walk that merely fails says
  `check_failed(Name)` under the C++ trace. (M3, 0.80, 0.108)
- Every local joins the symbol table (`ccl_declare/2`, a scope per block). So `ccl_type_of/2` types every slot, and
  `ck_is_local/1` tells a local from a global or a static. Every statement carries its line first; `ccl_add_lines/3`
  gives a macro's short forms the call's line. `ck_line/1` keeps the line. `ck_short/2` names a form without its line,
  and `ck_squash/2` without a macro's expansion. (M3)

### Owners and moves

- An owner is a pointer qualified `own`. C's grammar puts the qualifier on the pointee (`own char *p` is `ptr([],
  base([own], [char]))`), so `ck_own_type/1` looks in both places. `move(E)` is a node. (M3)
- An owner is linear: every path consumes it exactly once. `free`, `fclose` and `realloc` consume their first argument
  (`ck_consumes/2`). So does a callee whose i-th parameter is `own`, named or read off a function pointer's type as
  `params(Ps)` (`ck_fn_params/2`). `move(p)`, `return p` and a `defer` that frees `p` consume it too. A consumed owner
  may own again by assignment. `test/c/run/owners.c`, `own_struct.c`. (M3)
- The state is `st(Frames)`, innermost first, and a frame is `fr([Key-State ...], Defers)`. `ck_stmt/3` threads it;
  `dead` marks a path that ended. An owner is `live`, `null` (free, move and overwrite are fine), `unset` (no value
  yet, or a field of a struct from malloc), `moved` or `partial`. Other keys hold `borrow(P)`, `dangling(P)`,
  `anchor`, `loose`, `array` or `none`. (M3)
- A join (`ck_merge/3`) keeps equal states. `null` beside `live` is `live`. `null` or `unset` beside `moved` is
  `moved`. `unset` beside `null` is `unset`. `dangling` wins, `borrow` beats `loose`, two borrows keep the first, and
  `none` gives the other side. Any other pair is `partial`, which is refused on use and counts as a leak. (M3)
- A scope's end runs its defers last first (`ck_run_defers/3`). Then `ck_leaks/2` demands each owner consumed
  (`owner_leaked`; a loose pointer is `unconsumed`). Then every borrow of the closing frame's keys dangles
  (`ck_scope_end/2`). A `return` does the same for every frame. (M3)
- A loop may not consume an owner from outside it, unless the iteration owns it again by its end
  (`ck_no_moves_across/3`, `move_in_loop`). `break` and `continue` close the frames inside the loop and join its exits
  (`'$ck_loops'`). A `switch` merges its entry state at each case label. (M3)
- `ck_consume/6` consumes by its `How`. `free` needs the own fields consumed first (`owner_leaked` names the field).
  `move` needs them live or null (`owner_unset`, `use_after_move`) and moves them along. Then the owner's borrows
  dangle (`ck_dangle/3`). (M3)
- A null test refines an owner and its own fields (`ck_refine/4`, `ck_set_null/3`). `!p` and `p == NULL` make them
  null on the then path; `p` and `p != NULL` do so on the else path. (M3)
- A statement expression's last value is consumed when it is an owner. That is how `clone`'s copy leaves its block.
  (M3)

### Owners inside structs

- An owner is a KEY: a name or a path atom (`'p->name'`, `'c.inner.name'`; `ck_path/2`). `ck_var_fields/3` declares a
  variable's own fields with it: `->` under an own pointer, `.` in a struct by value, recursing into members held by
  value. The base comes first, so a leak names the base. An own pointer member is one key; what it points to is not
  opened. (M3)
- A struct's birth sets its own fields (`ck_alloc_mode/2`, `ck_set_fields/5`). malloc and realloc give `unset`, calloc
  gives `null`, and any other call or a move gives `live`. (M3)
- `ck_into_own/6` assigns an own slot. It takes an owner moved in with its fields (`ck_transfer/5`), a null or a fresh
  value. A borrow is `borrow_stored`, unless it borrows a loose pointer: the slot then takes that memory over
  (`ck_retarget/4`). A live owner assigned is `owner_overwritten`. An owner from an own FIELD has complete fields
  (`ck_complete_rest/4`). Fields move or fill only for a struct held BY VALUE (`ck_by_value/1`). (M3)
- `ck_into_plain/5` assigns a plain slot. An owner is `owner_stored`. A borrow is `borrow_stored`, unless it borrows an
  anchor or static storage. A fresh non-static value or a loose pointer is `untied`. (M3)
- `ck_fill/6` gives a struct by value a whole value. The fields move over from a struct, come item by item from a list
  (`ck_init_slots/5`), or are all live from a call. (M3)
- A struct with owners handed BY VALUE hands them to the callee's copy, as a copy does. They move at the call
  (`ck_args_/5`, `ck_param_by_value/2`). The by-value parameter owns them and must consume them (`ck_param_owners/2`).
  `move(E)` of such a struct moves its fields (`ck_expr(move)`, `ck_kind(move(E))`). `test/c/safe/by_value_move.c`,
  `test/c/run/own_fields.c`. (0.40)

### Borrows and parameters

- A BORROW is a value whose type carries a pointer (`ck_carries_type/1`), taken from what `ck_borrows_from/3` traces to
  an owner: a name, `+` or `-`, a cast, `&p[i]`, `&p->x`, a path through `->` `.` `[]` `*`, or another borrow. It is
  `N-borrow(P)`. Once P is consumed it is `dangling(P)`, and a use is `borrow_after_move`. An assignment from anything
  else unbinds it. `test/c/run/borrows.c`. (M3)
- A plain pointer or array PARAMETER is a borrow of the caller's, tagged with its own name: `N-borrow(N)`
  (`'$ck_params'`). The callee reads it, passes it on and returns it; it never stores, frees or moves it. A borrow
  handed where the callee consumes is `borrow_consumed` (`ck_args_/5`). A parameter assigned anew is a plain local
  from there. `test/c/run/params.c`, `test/c/safe/param_*.c`. (M3)
- The own fields of the struct that a plain pointer parameter points to stay the struct's (`'$ck_borrowed'`). The
  callee may free and replace them, and they are exempt from leaks. They must be live or null at every return
  (`ck_complete_owners/2`, `borrow_incomplete`). (M3)
- Such a field returned as a plain pointer, from a function whose result is not `own`, is a borrow out and stays the
  caller's (`ck_consume_or_use/3`, first clause), as `c_str` is. (0.41)
- A return (`ck_no_escape/2`) checks a value whose type carries a pointer, or a closure. A loose pointer and static
  storage may leave. With a result tie, only what lies within it leaves (`tie_mismatch`); without one, a borrow of a
  parameter or a global. Any other borrow is `borrow_escapes`. A conditional returns either arm, a comma its right
  side. (M3, 0.44)
- A copy of a null pointer, or of a local with no ownership state, is `null` (`ck_plain_copy/2` in `ck_kind/3`). In a
  declaration this holds only for a pointer-typed local, so `int x = n` makes no owner. `test/c/run/nullcopy.c`.
  (0.99, 0.100)
- A value that lives as long as the program is never fresh (`ck_static_value/1`): a narrow or wide string literal,
  `&global`, a global array or function, arithmetic on one, a conditional of two. So a vtable store is no fresh value.
  (0.34, 0.93)
- A function pointer and a pointer to member are code, which the check never follows (`ck_is_pointer_type/1`,
  `ck_carries_/1`). Else `int (*f)(int) = c ? a : b` was a loose pointer. (0.100)

### Ties

- `x tie y` says that x lives within y. The reader puts `tie(y)` in x's outermost qualifiers (`ccl_add_tie/3`,
  `ccl_tie_of/2`). `'$ck_ties'` holds Key-Root for each tie: a local's, a parameter's, or a field's per instance
  (`ck_note_tie/2`; dropped when the key is declared again). A tie to nothing declared before, or to itself, is
  `tie_unknown`. (M3; the word `tie` since 0.109)
- A tied plain value is `borrow(Root)` whatever its type (`ck_var_tie/4`). The root is what y borrows when y is itself
  a borrow. Field ties go in member order (`ck_field_ties/5`), so a tie to a later member is `tie_unknown`. Parameter
  ties come after the owners and name earlier parameters only (`ck_param_ties/4`). (M3)
- A tied OWNER keeps its state. Consuming its root while it lives is `tie_outlived` (`ck_tied_consumed/3`). It moves
  only into a slot within its tie (`ck_tie_kept/4`, `tie_escapes`), in `ck_into_own`, `ck_args_` and `ck_no_escape`.
  (M3)
- A slot under a tied base is tied to the base's root (`ck_tied_to/2`, `ck_base_path/2`). `ck_into_tied/6` gives it a
  borrow within the root, a null or a fresh value; anything else is `tie_mismatch` (`ck_within/3`). A member tied to
  an earlier member is the one place a borrow may be stored. (M3)
- Direction: a slot tied to y takes a value whose root outlives y. An owner tied to y moves only into a slot within y.
  A value rooted at a field counts as rooted at its holder. Nothing ends loose memory or static storage. (M3)
- A result tie (`'$ck_ret_tie'`) binds both sides. The callee's returns must lie within it, and the caller's variable
  borrows the argument (`ck_call_tie/3`). A parameter tie is checked at every call (`ck_arg_ties/3`). (M3)
- A result tie may name a static local of the function (`ck_body_static/2`) or a global. The root is then
  `static(Name)`: nothing ends it, and freeing it is `borrow_consumed`. `test/c/run/statics.c`. (M3)
- A tie to a plain local, `&x` of one, or a local array used as a pointer ANCHORS the local (`ck_anchor/3`;
  `ck_anchor_addrs/3` runs before an expression statement, an initializer and a return). The anchor is `Y-anchor` in
  the state frame of Y's symbol frame (`ck_declare_at/4`). Nothing consumes it, it ends with its scope, and its
  borrows may sit in plain slots, as C has them. A static local is never anchored (`'$ck_statics'`). An array member of
  a local struct anchors the struct. `test/c/run/tie.c`, `clone.c`, the eight `test/c/safe/tie_*.c`. (M3, 0.108)

### Loose pointers: every pointer has an ownership path

- Owner's rule: every pointer has an ownership path, or the program is refused. There is no warning channel: `untied`
  and `unconsumed` are errors (owner's decision). (M3, 0.14)
- A plain pointer local given a fresh value is `N-loose`, a root for borrows (`ck_borrow_source/3`). A value is fresh
  when it is not none, an initializer list, null, static, rooted under an unfollowed reference, or a `ck_va_value/1`
  form (`ck_fresh_value/1`). (M3)
- `free`, `fclose`, `realloc` and an own parameter consume a loose pointer (`ck_consume_loose/3`), and its borrows
  dangle. A `return` takes it (`ck_loose_taken/3`), and an own slot takes it over (`ck_retarget/4`). Left at a scope's
  end or a return, or overwritten, it is `unconsumed`. A rebind lands in the variable's own frame (`ck_declare_at/4`).
  `test/c/safe/unconsumed.c`. (M3)
- `untied` ("no owner behind") is a slot the check cannot follow, given a fresh value or a loose pointer: a struct by
  value (`ck_no_owner_behind/4`), or a field, an element, `*p`, a global or an initializer item (`ck_into_plain/5`,
  named by `ck_slot_label/4`). `test/c/safe/untied.c`. (M3)
- `ck_va_value/1` lists what is never fresh: a value read by `va_arg` (the caller's), a C99 compound literal (the
  block's object), a `dynamic_cast`'s result, an exception's storage, a coroutine's frame, promise or noop handle.
  (0.108)

### Own arrays and their drains

- Own arrays (owner's rule: a constant bound, or nothing). `own node *C[4]` is ONE key in state `array`
  (`'$ck_arrays'`, `ck_note_array/1`, `ck_own_elem/2`). It is readable, a root for borrows, exempt from leaks, and
  never consumed by the check: the lowering drains it. (M3)
- An element is an own slot with no key (`ck_into_own(none, ...)`). It takes an owner, a null or a fresh value, never
  a borrow. `move(C[i])` is `fresh`. Moving, freeing or overwriting an element dangles the array's borrows. (M3)
- An own array is zeroed at birth: by calloc, an initializer or a call. One from malloc or realloc is `array_unset`,
  and a local own array needs an initializer. (M3)
- `ck_type_rules/3` checks each local and parameter. `ck_bounds_ok/3` refuses `own_unbounded`: an own pointer behind a
  plain pointer, or an own array with no constant bound. An own-array parameter is `own_unbounded` too
  (`ck_param_ties/4`). `ck_array_struct_ok/3` refuses `own_array_untagged`, since the drain is named by the tag.
  `own_array_by_value` refuses such a struct declared, copied (`ck_no_array_copy/3`), passed or returned by value: a
  copy would own the elements twice. (M3)
- The one other bound is a struct's LAST member `own T *a[n]`, with `n` an earlier integer member (`ck_members_ok/3`).
  It is a flexible member of no bytes, `[0 x T]`. The developer allocates `sizeof(s) + k * sizeof(T *)` and sets `n`.
  A bound is any constant expression (`ccl_const_eval/2`), alike in the layout, the LLVM type and the check. (M3)
- The drains keep every element null or owned. `ir_drain_functions/1` makes `function(0, static, void,
  ccl_drain_<tag>, [x], ...)` for each tagged struct in `'$ccl_tags'` with an own array (`ck_has_own_array/1`; in the
  buckets' order, `ccl_tab_list/2`, so a program with two such structs has the two functions in that order). Its
  body is a `for` per array path (`ir_drain_loop/4`: `if (a[i]) { ccl_drain_T(a[i]); drain_free(a[i]); }`), recursive
  through the element's struct. The drains are noted (`ccl_items_note/1`) and lowered after the units. A flexible
  member's drain loops to `arrow(x, n)` (`ir_array_bound/4`). (M3)
- `free(E)` of such a struct is `({ drain(E); drain_free(E); })` (`ir_drain_free/2`). `a[i] = R` frees the old element
  first (`ir_elem_assign/3`). `move(a[i])` nulls the slot. An element handed to a consumer is `move`d
  (`ir_moved_args/3`). A local own array's drain is a defer of its scope (`ir_array_defers/2`). (M3)
- `test/c/run/btree.c` (`own node *C[4]`) and `btree_del.c` (`own node *C[nc]`, with deletion) are the ownership test
  case, and `leaks` finds nothing in them. `slots.c` gates a local own array, `flex.c` a flexible member. The `own_*`,
  `flex_unbounded` and `array_unset` programs in `test/c/safe/` are refused. (M3)

### What the C++ forms mean to the check

- The check sees the desugared C. `scoped(_, N)` is `id(N)`, a C++ cast is its operand, and a range-for over an array
  is its `for` (`ccl_for_each_as_for/2`). (0.32)
- A reference is the pointer it is (`ck_ref_params/2`, `ck_ref_decl/5`). A reference parameter is a borrow. A local
  bound to an lvalue borrows `addr(Init)`; one bound to a call has no state. (0.32)
- `'$ck_refs'` names the function's references, and a use of one is a use of its referent: `x = v` is `*x = v`, and
  `&x` is the pointer held. `r.f` is keyed `r->f` (`ck_path/2`). A reference result is a borrow out (`'$ck_ret'`,
  `ck_no_escape/2`); a reference to a non-parameter local is `borrow_escapes`. (0.32, 0.44)
- Every `delete` consumes as `free`: plain, `[]`, polymorphic, and past an array cookie. `new` is fresh. `new T` of a
  struct without a constructor is malloc's bytes (`ck_alloc_mode/2` on `new(_, [])`, `new_array`, through a cast);
  `new C(args)` is complete. `ir_cpp_prelude/0` declares `malloc`, `free`, `calloc`, `memcpy`, `memmove` and `memset`
  before the check when the file did not. (0.32, 0.37, 0.108)
- The desugaring marks a constructor's `this` `[fresh]` and a destructor's `[dying]` (`cpp_this_type/4`), and
  `ck_this_marker/2` reads the marks. Under `fresh` the own fields start `unset` (`ck_param_owners/2`) and must be live
  or null at each return (`ck_complete_owners/2`). Under `dying` they are exempt (`'$ck_dying_fields'`).
  `test/cpp/run/btree.cpp`. (0.37)
- The caller of a destructor takes the object's own fields as moved; the caller of a constructor takes them as live
  (`ck_args_/5`: `ck_dying_param/2`, `ck_fresh_param/2`, `ck_own_under/3`). `ck_arg_base/2` takes any path, and
  `ck_pointee_fields/3` recurses into members held by value, so a member's constructor and destructor update its
  fields. (0.37, 0.41)
- The library's functions are not checked (0.45's decision, open to the owner to confirm or reverse): libc++ keeps raw
  pointers by its own discipline. `cpp_as_lib/2` marks each function a library walk emits `'$cpp_libfn'(Name)`; a
  library template's origin is `'$cpp_lib'(N)`. `ck_items/1` skips them (`cpp_library_function/1`), and compiler-made
  thunks too. The program's own functions and its templates' instances are checked. (0.45, 0.108)
- A library class's VALUE is opaque (`ck_carries_/1` via `ck_library_class/1` -> `cpp_lib_class/1`). A nested class of
  a library class is the library's. So a map iterator's node pointer is not followed. Such a value may be moved
  (`ck_moves_library/1`): `auto r = std::move(q)` over a `unique_ptr`. (0.79, 0.84, 0.86)
- A class's TABLE POINTER, `$vptr`, is static storage, never memory the check follows (`ck_carries_/1`; 0.127). Why: `V v
  = V();` of a polymorphic class was refused `untied`, a struct by value carrying a pointer given a fresh value.
- A plain pointer that a library function returns over an object's address (`call(id(F), [addr(E)|_])`) is a borrow of
  the object's root (`ck_borrows_from/3` -> `ck_borrow_of/3`), never loose: `std::array`'s iterators. A borrow of a
  library-class local may be consumed (`ck_library_root/1` in `ck_args_/5`): `delete u.release()`.
  `test/cpp/run/stduniqueptr.cpp`. (0.91, 0.94)
- A library STATIC function's pointer result is a borrow of the object it takes by reference (`ck_borrows_from` on
  `call(id(F), [nullptr|As])`, the leading null being the static's `this`; `ck_ref_object/3`): `allocator_traits<A>::
  allocate(a, n)` borrows `a`. A library function's pointer result borrows what its pointer arguments borrow
  (`call(id(F), Args)`): `std::construct_at(p + 2, 42)` returns `p + 2`. `stdallocator.cpp`, `stduninit.cpp`
  (`-std=c++20`: `construct_at`, `destroy`, `destroy_n`, `destroy_at`, `uninitialized_copy`, `_fill`, `_fill_n`,
  `_move`, `_default_construct`, `_value_construct_n`). A direct `allocate` was refused as a loose pointer until 0.117.
  (0.117)
- An address under a reference that the check does not follow is no fresh value (`ck_ref_rooted/1`):
  `const auto &[k, v] = *it` binds a plain value. (0.79)
- A closure is a compound literal of its captures, and it borrows what they borrow (`ck_borrows_from/3` on
  `compound_lit`; `ck_borrowing_type/1` at an initializer and a return). Returning one that holds `&x` of a local is
  `borrow_escapes`; a `[this]` closure may leave. `test/cpp/run/closurescope.cpp`; `test/cpp/escape.cpp` is refused.
  (0.100)
- A closure's `'$this'` slot is walked (`ck_init_slots_/6`), and a bound reference member is a plain walk
  (`ck_stmt(expr(_, bind_ref(_, E)))`): the check follows neither object. It follows a closure only where it is made;
  a closure in a `std::function` is the library's discipline. (0.59, 0.61)
- A `try` checks its body, then each handler from the `try`'s entry state, and merges them (`ck_catches/4`).
  `if consteval` checks the run-time branch (`ck_stmt(ifce)`). `co_return` exits as a return does. A `dynamic_cast`
  borrows what its operand borrows. `[[assume(e)]]` only reads `e`. (0.93, 0.108)

### What is refused, by name

- A refusal is `error(ownership(Kind, Name, Form), where(Function, line(L)))`. `dr_diag/3` and `dr_kind/2` word it:
  `unconsumed` reads "plain pointer not consumed", `untied` "no owner behind". The kinds: `use_after_move`,
  `owner_unset`, `borrow_after_move`, `borrow_escapes`, `borrow_stored`, `borrow_consumed`, `borrow_incomplete`,
  `owner_stored`, `owner_leaked`, `owner_overwritten`, `move_in_loop`, `move_of_non_owner`, `goto_with_owners`,
  `tie_unknown`, `tie_outlived`, `tie_escapes`, `tie_mismatch`, `own_unbounded`, `own_array_by_value`,
  `own_array_untagged`, `array_unset`, `unconsumed`, `untied`, `not_checked`. (M3)
- The kinds not met above: `use_after_move` is a consumed owner used, freed or passed again, the double free.
  `owner_unset` is an owner used before it got a value. `move_of_non_owner` is `move` of no owner and no library value.
  `goto_with_owners` is a `goto` in a function with owners, which the check does not follow. `not_checked` is a form
  the walk cannot follow: a range-for over a non-array, a `continue` in a switch with no loop. (M3)
- A statement form the check does not know throws `not_lowered(F)` from the last `ck_stmt` clause. Every
  `test/c/safe/NAME.c` is refused with the error its `.expect` names (`test/compile.pl`). (M3, 0.32)

## The lowering

### The pipeline

- `ccl_ir_units/2` builds the symbol table from the units (`ccl_items_note/1`). In C++ it desugars them
  (`ccl_cpp_units/2`), builds the table again, and runs `ir_cpp_prelude/0`. Then come the check
  (`ccl_check_noted/1`), the drains, every item, and the text (`ir_assemble/1`). A phase that merely fails names
  itself: `ir_fail(phase(desugaring | check | lowering))`. (M2, 0.53)
- Each item is lowered inside `\+ \+` (`ir_items/1`). A function's text goes to a global of its own (`'$ir_fdef:K'`,
  `ir_add_fdef/1`). An item that merely fails is `ir_fail(item(W))` (`ir_item_name/2`). An error inside an item carries
  the item (`ir_item_error/2`: `item(W, raised(E))`); a `not_lowered` passes as it is, and the C++ trace prints it
  with the whole item (`item_failed(X, I)`). (0.54, 0.80)
- `ir_fail(What)` throws `error(not_lowered(What), Where)`. A C++ form that the desugaring removes is refused by name
  if one arrives: in `ir_item` (`operator`, `member_of_class`, `class`, `constructor`, `destructor`, `method`,
  `template`), `ir_expr` (`lambda`, `throw`) and `ir_base` (`class`, `auto`). Namespace and `extern_c` items lower
  their items; `using` lowers nothing. (0.32)
- The module text is the struct types, the strings, the globals and the functions, then a `declare` line for each
  external used (an intrinsic's line raw). (M2)
- The lowering reads four qualifiers only: `own` (moves, drains), `thread_local` (`ir_tls/1`), `aligned(E)`
  (`ir_aligned_q/2`) and `'_Atomic'` (`ir_atomic_q/1`). `const` and `volatile` change nothing. Nothing reads `tie(Y)`,
  so a tie costs the lowering and the layout nothing. (M3, 0.99)
- `ccl_lowering_version/1` (`ccl_ir.pl`) is part of every stored IR's signature (`dr_ir/3`) and of `KB.version`
  (`Reader.Lowering`). Bump it for EVERY change to what the check or the lowering emits, however small. Else the store
  serves the old IR. (M4, 0.103)

### Per-function state and values

- Globals hold a function's state, and `ir_function/7` resets them: `'$ir_body'` (the lines, reversed),
  `'$ir_allocas'` (the entry block's), `'$ir_env'` (frames of `Name-loc(Addr, Type)`), `'$ir_defers'`, `'$ir_loops'`
  (the break and continue targets, with the defer depth) and `'$ir_term'`. (M2)
- Locals are allocas in the entry block, which `mem2reg` lifts. A struct or union alloca is aligned as C aligns it,
  and `aligned(E)` raises the alignment (`ir_alloca_typed/2`). `ir_ins/1` opens a dead block after a terminator, so
  every block ends once. (M2, 0.99)
- A function that falls off its end returns its result's zero (`ir_zero/2`); `main` returns 0. A function item with no
  body is a prototype, and its `declare` comes from the externals a call names. (M2, 0.54)
- `ir_expr/4` gives a value, its resolved C type and its LLVM type (owner's request, 2026-09-06: the LLVM type travels
  with the value, and no consumer derives it again from the C type). A decayed array is `ptr` (`ir_value_ll/2`).
  `ir_lval/4` gives a slot with the same two types. `ir_load_slot/4`, `ir_store_slot/4`, `ir_convert/6`,
  `ir_binary/8` and `ir_arith_op/4` take the LLVM type; `ir_cond/2` makes an `i1`. The /3 forms and `ir_convert/4` are
  wrappers. (2026-09-06)
- `ir_type/2` is cached per type term (`'$ir_tcache'`). A pointer, a reference and a function are `ptr`; an array is
  `[N x T]`, or `[0 x T]` without a constant bound. (M2)
- Signed integer arithmetic is `nsw`, and every address is `getelementptr inbounds` (`ir_arith_op/4`, `ir_step/6`). C
  leaves signed overflow and addresses past the object undefined. So LLVM widens loop counters and drops the sign
  extensions before an index. (2026-09-05)
- `int(N)` is `i32`, or `long` past 32 bits; `uint`, `long` and `ulong` keep their suffix's type. A `big(Atom)` past
  2^60 is spelled as written (`ir_big_text/2`; `u0x...` for hex). A character literal is a `char` in C++ and an `int`
  in C. `__func__` and its kin are the function's name. (0.42, 0.78, 0.94, 0.108)
- A double prints as LLVM's hex (`ir_double/2`). A floating global is spelled for its own type (`ir_fp_const/3`): a
  float as the double hex of its value rounded to a float, `x86_fp80` in the `0xK` form, `_Float16` as `half`. (M2,
  0.108)
- A local shadows an enumerator: `ir_expr(id(N))` asks `ir_lookup/2` before `ccl_enum_value/2`. Else an enumerator of
  libc++'s `<format>`, `__ptr`, replaced a parameter. `test/c/run/enumshadow.c`, `test/cpp/run/enumshadow.cpp`. (0.94)
- `ir_convert/6` tries, in order: a reference read through, where a reference to a function is its address
  ([conv.func]); a class pointer to its base by the base's offset, null kept null by a `select` ([conv.ptr]/3;
  `nullbase.cpp`); a member-function pointer's `adj` grown by a base's offset; a complex value; the scalar rules.
  (0.61, 0.72, 0.84, 0.99, 0.108)
- The scalar rules first convert to `bool` or `_Bool` (`ir_to_bool/4`): `icmp ne`, `fcmp une`, or a member-function
  pointer's `ptr` against null, then `zext` to `i8`. `bool` and `char8_t` are `i8`. (0.32, 0.108)

### Control flow and defer

- `defer` is scope-bound and static, with no runtime (owner's rule). `ir_defer_push/1` registers a body in its scope's
  frame. `ir_run_defers/1` inlines the bodies last first: at a block's end, at `break` and `continue` (the frames inside
  the loop), and at `return` (every frame, after the value is computed). A statement expression runs its own block's
  defers. A `goto` runs none. (M2)
- A conditional is a `phi` of its arms in their usual type -- in C++ the arms' own type where both are of ONE arithmetic
  type (`ccl_cond_arith/3`, 0.127) -- and void arms have no phi ([expr.cond]/2; `ir_expr(cond)`'s first clause, which
  tests the first arm). Else LLVM refused `phi void` in libc++ 18's string algorithms. `test/cpp/run/voidcond.cpp`.
  (0.95, 0.127)
- A conditional of a pointer and the literal zero is the POINTER, in C and C++ (`ir_expr(cond)`: both arms arithmetic
  give the usual conversion, else the null constant's arm takes the other arm's pointer type). The phi was `i32` and the
  address went through it truncated: `deque::begin()` returned a pointer whose high half was gone.
  `test/c/run/condnull.c` (the safe part refuses a plain pointer stored in a struct, so the program keeps its pointers
  in locals). (0.117)
- A conditional over two lvalues is an lvalue whose address is the phi of the arms' addresses ([expr.cond]/4;
  `ir_lvalue_form/1`, `ir_lval(cond)`). Else `std::min(a, b).c_str()` read a dead temporary.
  `test/cpp/run/condlvalue.cpp`. (0.92)
- `&&` and `||` branch and join in a `phi i1`. A comparison, `!`, `&&` and `||` give C's `int` (`ir_bool/2`) and C++'s
  `bool`, an `i8` (`ir_truth/4`, the inference's `ccl_truth_type/1`; 0.127). (M2, 0.127)
- An ENUMERATOR is a prvalue (`ir_lvalue_form(id(N))` over `ir_enumerator/1`): bound to `const Color &` it takes the
  temporary C++ materializes. Why: `v.push_back(Green)` bound it through `ir_lval` and it was `undeclared`. (0.127)
- A `switch` converts its value to `int` and lists its cases as `i32` constants (`ir_case_lines/2` over
  `ccl_const_eval/2`). It finds its cases at the top level of its block (`ir_switch_cases/3`). (M2)
- A range-for over an array is `for (int i = 0; i < N; i++) { T x = xs[i]; S }` for both passes
  (`ccl_for_each_as_for/2`); `auto &` and `auto &&` bind a reference. Any other range-for that reaches the lowering is
  `range_for_over_non_array`. (0.32)

### References, temporaries, moves and new (C++)

- A reference is a pointer bound once. A local's slot holds the address (`ir_locals/2` through `ir_ref_to/3`), and a
  use loads it first (`ir_ref_slot/4`). A reference parameter takes the argument's address (`ir_args_/4`). A reference
  result returns the address (`ir_stmt(return)`, `ir_lval(call)`) and is read through for a value (`ir_expr(call)`).
  (0.32)
- `ir_ref_of/2` gives what a reference binds: an lvalue's address (through `ir_slot_addr/2`), the operand of `move(E)`
  or of a cast to a reference, or a call's reference result. A call's value or any other prvalue gets the temporary
  C++ materializes, as `v.push_back(1)` needs. (0.50, 0.58, 0.83)
- A cast to a reference is a bind, never a value conversion: its value is the address (`ir_expr(cast(T, E))` ->
  `ir_ref_to/3`). The cast's own base offset applies first (`ir_ref_cast/3`), then the binding's (`ir_ref_hops/4`).
  Else `static_cast<_Tp &&>(__t)`, `std::forward`'s body, made an `inttoptr`. `test/cpp/run/stdvector.cpp`,
  `basecast.cpp`. (0.61, 0.90)
- A function bound to a reference to a pointer converts first, and the reference binds the temporary pointer
  ([conv.func]; `ir_ref_to/3`). Else libc++'s `__tuple_leaf` loaded code bytes. `test/cpp/run/fnrefptr.cpp`. (0.100)
- A POINTER OPERAND THAT IS A REFERENCE TO A POINTER IS READ THROUGH (`ir_ptr_operand/3`, asked by the lvalue forms of `*e`,
  `e[i]` and `e->m`; 0.126): `*static_cast<A0 &&>(a0)` with `A0` `Pt *` -- the cast to a reference is a bind (the bullet
  above), so its value is the ADDRESS of the pointer and its type `Pt *&&`, and `ir_elem` found no pointer in it
  (`not_a_pointer(rref(...))`). A named reference or a call's reference result is read through where it is made, so only a
  cast met it. libc++ 18's `__invoke` for a data member pointer and an object given by pointer is written so,
  `(*static_cast<_A0 &&>(__a0)).*__f`. `memptrqual.cpp`. (0.126)
- A reference to an arithmetic type bound to an arithmetic expression of ANOTHER LLVM type -- or a `bool` to a
  non-`bool` -- binds a TEMPORARY of the referent's type, converted from the value ([dcl.init.ref]/5.4;
  `ir_ref_converts/3`, `ir_ref_convert/3`, tried first by `ir_ref_to/3`; a reference MEMBER bound in a constructor goes
  through the same door, `ir_bind_into/3`). Types of one LLVM type share the lvalue's address, as before. Why:
  `std::max<size_t>(2 * n, 1)` hands the int `1` to a `const size_t &`, and the temporary was as wide as the int, four
  bytes read as eight; `std::deque` asked for a map of 8589934593 pointers and crashed at its first growth. `const
  size_t &r = 3;` alike. `refwiden.cpp`, `stddeque.cpp`. (0.117)
- A call whose result is a reference to an ARRAY is the array's address, which decays (`ir_expr(call)`, 0.117): libc++'s
  `static auto &__pow() { return __table<>::__pow10_32; }` is added to (`__pow() + 1`), and the whole `[10 x i32]` had
  been loaded (`type(unknown)` at the lowering). `autoref.cpp`.
- A prvalue used as a place gets a temporary (`ir_lval(call(...))`): `end()[-1]`, `f().x`. A statement expression that
  ends with a place is a place (`ir_lvalue_form/1`). So a reference binds the temporary
  `({ C $tmp; ctor(&$tmp); $tmp; })` itself, not a copy. (0.60, 0.62)
- A reference member holds an address and is read through (`ir_ref_member/4`). Binding one stores the address into the
  slot (`ir_bind_ref/2`). (0.36, 0.61)
- `move(E)` is E, with two exceptions. An own array's element is loaded and its slot nulled. A struct lvalue with own
  fields has them nulled behind it, nested structs too (`ir_null_own_fields/2`, `ir_has_own_fields/1`), so its
  destructor frees nothing. (M3, 0.40)
- `new T` is `(T *) malloc(sizeof(T))`, `new T(v)` stores v, `new T[n]` mallocs `n * sizeof(T)`, and `delete` is
  `free` (`ir_new/3`). A `new` that still needs a constructor is `new_with_constructor(T)`. A polymorphic `delete`
  frees the complete object found through `vptr[-2]`; a `delete[]` past an array cookie frees from the cookie. (0.32,
  0.108)
- The drains are in the safe part above. Exceptions (`invoke`, landing pads), RTTI (libc++abi), coroutines
  (`llvm.coro.*`) and contracts lower as their own section says. (0.108)

- A REFERENCE MEMBER OF AN AGGREGATE BINDS ITS ITEM ([dcl.init.aggr]/4.2, [dcl.init.ref]; `ir_init_sub/4` over
  `ir_bind_into`; 0.121): the slot holds the item's address, as a constructor's member initializer stores it
  (`ir_bind_ref`); the item was loaded and converted to a pointer, an `inttoptr` of a struct. libc++ 18's
  `__value_visitor<_Visitor>{std::forward<_Visitor>(__visitor)}` of `std::visit` has `_Visitor &&` as its one member.
  The item a CLOSURE gives its reference member is the captured object's address already (`cpp_closure_value`, `[&x]`
  and `[this]`) and is stored as it is (`ir_address_item/2`, by type). `varvisit.cpp`. (0.121)

- A PRVALUE IS CONSTRUCTED IN THE OBJECT IT INITIALIZES (C++17, [class.copy.elision]/1; 0.121). The desugaring hands a
  fresh temporary on as the statement expression that built it, its declaration inside the block and its name last
  (`$tmp...`, and `$ret...` for a local moved into the result of a function); the lowering takes the declaration out and
  binds the name to the object's address (`ir_prvalue_block/4`, `ir_take_tmp_decl/4`, `ir_in_place/4`), for a local's
  initializer (`ir_init/3`), a `return` through the hidden result pointer (`ir_stmt(return)`, over `%agg.result`) and an
  aggregate member (`cpp_prvalue_in_place`). A CALL that returns the object's class through the hidden pointer gets the
  object's address as its result (`ir_sret_call/2`; the global `'$ir_sret_into'`, read and cleared by `ir_call_` and
  initialized in `ir_reset`, since `ccl_global/3` ignores a default): `std::map<int, int> m = build();` and `return
  build();`. Why: built in a slot of its own and copied bitwise, a class that holds its own address (a map's end node, a
  list's sentinel, a `std::function`'s small buffer) pointed into the dead slot -- three defects of 0.120 and before
  (`std::function<int(int)> f = std::function<int(int)>(g)` freed an invalid pointer, `return std::list<int>{1, 2, 3};`
  and a `std::map` returned by value corrupted their first growth, `std::map<int, int> m = build();` iterated for ever).
  `prvalueinplace.cpp`. (0.121)

### Statics, globals and initializers

- The layout of a struct, a union and a bitfield, a member's slot, an empty value and the call ABI are rules of the
  object layout (the section "Object layout and the ABI"); the rules below are the lowering's own.
- A static local is `@fn.name.K = internal global` (`ir_static_locals/1`), or `internal thread_local global`. A
  `thread_local` global is `thread_local global` (`ir_tls/1`). `linkonce` storage is `linkonce_odr global` for a
  global and `define linkonce_odr` for a function. (M2b, 0.35, 0.93)
- A global's constant (`ir_gconst/3`): a struct over its shape, with bitfield runs packed into `c"..."` bytes
  (`ir_gstruct/3`); a union in its given member's literal type, padded (`ir_gunion/4`); a designated list made
  positional (`ccl_init_norm`), a hole `init([])`. A bitfield's value is read by `ir_gbit_value/2`: a hole is 0 and a
  braced scalar its one item (`test/c/run/bitdesig.c`). An empty class's temporary is its constant, and a scalar `T{}`
  is its zero. A char array from a shorter literal is zero-filled to its bound (`ir_str_tail/3`;
  `test/cpp/run/staticbase.cpp`). (M2b, 0.72, 0.79, 0.108, 0.112)
- A wide literal, or a pointer into one, is a pointer's global constant (`ir_wide_lit`: `wstr` and `u32str` i32,
  `u16str` i16, through `ir_wstring`); an array of wide characters is not taken here. (0.115)
- A FLOATING global's fold (`ir_fp_value/2`) takes a cast to an integer type as the truncation and the wrap it is
  (`ir_fp_cast/3`: `(double) (int) 2.5` was 2.5, the cast passed over) and an integer past 2^60 as a double
  (`ccl_w_float/2`: `double d = (double) ((__int128) 1 << 100)` was refused); an INTEGER global from a floating initializer
  converts (C 6.3.1.4; `ir_int_of_float/3`): `int g = 2.5;` and `unsigned __int128 g = 3e38;` were spelled as a double's hex,
  which LLVM refuses for an integer, and `int g = -2.5;` was refused, `global_init`. `test/c/run/floatglobal.c`. (0.129)
- Brace elision ([dcl.init.aggr]/15, and C's own rule): an array member given a non-braced item takes as many of the
  following items as it has elements, while more items than members remain (`ir_init_items/4`, `ir_elide_take/4`; a
  global's through `ir_gelide/4`). Every `std::array` initializer needs it. (0.91, 0.110)
- A local aggregate initializer stores `zeroinitializer`, then its items (`ir_init/3`). A braced list on a scalar is
  its one value or the type's zero; more items are `initializer_of_a_scalar(T)`. The scalar test takes the resolver's
  first answer, else `int arr[9] = {}` became a `sext`. An item with no member names its type, `initializer(I, ST)`.
  An unsized array takes its size from its initializer (`ir_sized_type/4`). (0.54, 0.93, 0.99)
- A char array from a string is zero-filled past the literal (C11 6.7.9/21; `ir_init_zero/2`). A wide one stores its
  decoded code points (`ir_init_chars/4`). `test/c/run/wstr_alignas.c`. (0.99)

### Decimal floating types

- C23's `_Decimal32`, `_Decimal64` and `_Decimal128` run as gcc builds them (0.129; read and sized since 0.93, refused by
  name until 0.129). A value is its BID encoding (IEEE 754-2008's binary integer decimal) CARRIED in LLVM as a `float`, a
  `double` and an `fp128` (`ir_base` through `ir_dec_ll/2`) -- never computed on as one -- so the SysV ABI passes it
  where gcc does, in an SSE register, the `fp128` in one. Every operation is a call of libgcc's decimal runtime, which `cc`
  links (`ir_dec_call/5` declares each): `+ - * /` are `__bid_add<k>3` ... (k `sd`, `dd` or `td`; `ir_dec_arith/6`,
  another operator refused, `decimal_operator(Op)`); a comparison is `__bid_<eq|ne|lt|le|gt|ge><k>2`, whose long answer's
  sign tells (`ir_dec_cmp/6`); a truth test is the `ne` against the carrier's zero, whose all-zero bits are a decimal zero
  (`ir_dec_nonzero/4`, in `ir_cond/2` and `ir_to_bool/4`); `++` and `--` add the kind's one (`ir_step_`); a negation flips
  the sign bit, as gcc does (`ir_dec_negate/4`). (0.129)
- The conversions (`ir_dec_convert/6`, a clause of `ir_convert/6`): between decimal kinds `__bid_extend<f><t>2` and
  `__bid_trunc<f><t>2`; to and from an integer the width's routine, `si` for 32 bits and below (`__bid_floatsidd`,
  `__bid_fixunsddsi` ...) and `di` for 64, a 128-bit integer refused (`decimal_conversion(From, To)`); to and from a
  standard floating type `sf`, `df`, `xf` (a `_Float16` through a float), named `extend` or `trunc` by the formats' widths
  -- between formats of one width a decimal truncates to binary and a binary extends to decimal, as libgcc names them;
  to a bool the test. (0.129)
- A literal is encoded here, exactly (`ir_dec_literal/3`): its text's digits and exponent (`ir_dec_parse/3`), rounded half
  to even past the kind's precision (7, 16, 34 digits; `ir_dec_round_to/5`), an exponent past the greatest clamped by
  padding with zeros where the coefficient holds them, else an infinity, one past the least rounded away (`ir_dec_fit/3`),
  then the short form (the biased exponent above the coefficient) or the long one (`11`, the exponent, the coefficient's
  low bits under an implied `100`; `ir_dec_bits/3`), spelled `bitcast (i64 N to double)` with N the pattern read signed.
  A decimal GLOBAL's constant is a literal of any decimal kind re-encoded in its own, its negation or an integer constant
  (`ir_dec_fold/3`); anything else is refused by name, `decimal_constant(E)`. (0.129)
- The inference (`library/ccl_infer.pl`): `ccl_is_decimal/1`, `ccl_decimal_kind/2`; a decimal is arithmetic and no
  standard floating type (`ccl_is_float/1` stays false); the usual arithmetic conversions take the wider decimal type
  where either operand is decimal, an integer converted to it (C23 6.3.1.8; `ccl_decimal_usual/3`); a decimal is never
  promoted. A decimal member of an aggregate is an SSE leaf, a `_Decimal128` SSE and SSEUP, one `fp128` piece in one
  register (`ir_leaves/3`, `ir_eightbytes/4`, the register budget and `va_arg`'s register area): the driver gate passes
  values, structs and a variadic call both ways against gcc-built code. `test/c/run/decimal.c` (gcc's output; clang has no
  decimal types). (0.129)

### long double, _Complex, _BitInt and wide characters

- `long double` on x86-64 is `x86_fp80` (`ccl_long_double(x87)`), 16 bytes aligned 16, its constants in `0xK` hex.
  On arm64 it is a `double`. `test/c/run/ldouble.c`, `test/cpp/run/ldouble.cpp`. (0.108)
- `_Complex T` is `{ E, E }` over its real type (`ccl_complex_real/2`; a bare `_Complex` is a double), twice the real's
  size and aligned as one. `ir_complex_elem/2` covers `double`, `x86_fp80`, `float`, `i64`, `i32`, `i16` and `i8`. The
  usual arithmetic conversions give the complex of the common real type (`ccl_complex_usual/3`). (0.100, 0.103)
- A complex conversion is decided by the C types (`ccl_is_complex/1` in `ir_complex_convert/6`), never by the LLVM
  shape: an ABI piece `{ i64, i64 }` is no complex. A real becomes a complex with a zero imaginary part; a complex
  becomes a real by its real part. (0.100, 0.103)
- `+` and `-` work per component, `==` and `!=` compare both components, and negation negates both. A floating `*` or
  `/` calls the Annex G runtime, which recovers the infinities (`ir_complex_rt/8`). An integer one uses the textbook
  formulas and divides with `sdiv` or `udiv` (`ir_complex_op/9`), as clang does:

  | Type | Helpers | Value type |
  |---|---|---|
  | complex double | `__muldc3`, `__divdc3` | `{ double, double }` |
  | complex float | `__mulsc3`, `__divsc3` | `<2 x float>` |
  | complex long double | `__mulxc3`, `__divxc3` | `{ x86_fp80, x86_fp80 }` |

  (0.101, 0.103, 0.108)
- An imaginary literal (`imag`, `imagf`, `imagi(Specs, N)`) is the constant `{ 0, F }` of its type. A global's
  complex constant is spelled per component (`ir_complex_text/3`, `ir_imag_const/2`; a `big(A)` through
  `ir_big_text/2`). `__builtin_complex(x, y)`, C11's `CMPLX`, builds one. `test/c/run/complex.c`, `complex2.c`,
  `complex3.c`. (0.100, 0.101, 0.104)
- `__real__ z` and `__imag__ z` are values and places: a component's address inside the complex (`ir_complex_slot/5`).
  The imaginary part of a real as a place is `imaginary_part_of_a_real_as_a_place`, as clang refuses it (`expression is
  not assignable`). A complex crosses a call as its
  components (`ir_leaves/3`): SSE leaves for a floating one, INTEGER for an integer one, X87 and X87UP for a long
  double one. (0.100, 0.101, 0.108)
- `_BitInt(N)` is exactly `iN` (`ir_base`), sized by the psABI: the smallest of 1, 2, 4 or 8 bytes up to 64 bits, and
  whole eightbytes aligned 8 past that. (0.93)
- `wchar_t` is a signed `i32`, `char16_t` an unsigned `i16` and `char32_t` an unsigned `i32` (LP64). A wide string
  literal is a constant of its decoded code points (`ir_wstring/3`, `ir_utf8_decode/2`). `sizeof` of a string literal
  is its array's bytes, one element per code point for a wide one (`ccl_literal_bytes/2`). (0.92, 0.93, 0.103)

### Atomics

- The `__atomic_*` builtins are LLVM's own instructions, never calls (`ir_atomic_rmw/3`). `__atomic_<op>_fetch` is an
  `atomicrmw` followed by the op on the old value; `__atomic_fetch_<op>` answers the old value; `__atomic_exchange_n`
  is `xchg`. `__atomic_load_n` and `__atomic_store_n` carry the order and the type's alignment. The thread fence is a
  `fence`, the signal fence a `fence syncscope("singlethread")`. libc++'s `shared_ptr` counts its owners so. (0.86)
- The memory order is the constant the header spells, in clang's numbering (`ir_atomic_order/2`): 0 is `monotonic`, 1
  and 2 `acquire`, 3 `release`, 4 `acq_rel`, 5 `seq_cst`. An order that does not fold is `seq_cst`. (0.86)
- The `__c11_atomic_*` builtins are the same instructions (`ir_c11_rmw/2`; load, store and the fences as above; init a
  plain store). Compare-exchange, strong or weak, is a `cmpxchg` that stores the old value to `*expected`; its failure
  order is never a release (`ir_cmpxchg_fail/2`). `is_lock_free` answers 1 up to 8 bytes. The compiler's own
  `library/include/stdatomic.h` and libc++'s `<atomic>` are written on them. `test/c/run/atomic.c`. (0.99)
- An `_Atomic` object loads and stores `seq_cst` (`ir_load_slot/4`, `ir_store_slot/4` over `ir_atomic_q/1`). An
  integer `x++` or `--x` (`ir_step/6`) and `+=`, `-=`, `&=`, `|=`, `^=` are one `atomicrmw` each (C11 6.7.3, 7.17.7).
  (0.99)
- A compound assignment and an increment take their place ONCE ([expr.ass]/6, C 6.5.16.2/3): `ir_lval` first, the
  atomic test asked of the slot after (`ir_step_/6`). Why: the `_Atomic` road was a clause of its own that took the
  place to decide, a lowering emits as it goes and backtracking undoes no instruction, so `slot() += 5` called slot
  twice (since 0.99). `test/c/run/oncetarget.c`, `oncetarget.cpp`. (0.112)

### VLAs

- A VLA is allocated where it is declared: `alloca EL, i64 Total, align 16` in the body. Its bounds are evaluated once
  (C11 6.7.6.2/5) and kept in the local's type, `arr(vla(Reg), E)`. A VLA with `= {}` is zeroed (C23 6.7.10,
  `llvm.memset` over the kept bytes, `ir_locals`); any other initializer is `vla_initialized(N)`, as C23 6.7.10 has it and
  clang refuses it (`variable-sized object may not be initialized`). `test/c/run/vlaempty.c` (`-std=c23`). (0.93, 0.99,
  0.117)
- `sizeof` of a VLA local reads the kept bounds (`ir_vla_expr_type/2`, `ir_vla_bytes/2`). A VLA of a VLA is one
  allocation, and row `a[i]` lies at i times the row's bytes (`ir_lval(index)`). `test/c/run/vla_nested.c`. A VLA type
  that no local holds multiplies the bound read at the `sizeof`. (0.99)

### Builtins

- The bit builtins answer an `int` to the inference too (`ccl_bit_builtin/2`, the one table, which the lowering's
  `ir_bit_builtin/2` reads; 0.129): `c ? 64 + __builtin_clzll(x) : __builtin_clzll(y)` had no type, in C as in C++, and the
  lowering refused it, `type(unknown)` -- libc++'s `__libcpp_clz(__uint128_t)` is written so. `test/c/run/bitcond.c`.
- The bit builtins are LLVM's intrinsics at the argument's own width (`ir_bit_builtin/2`): `__builtin_clz*`, `ctz*`,
  `popcount*`, and the generic `g` forms with their value for zero. A zero argument is defined, and the result is an
  `int`. The intrinsic's `declare` is a raw line, since `i1` has no C spelling. Every integer width is one
  (`ir_bit_width/2`): an `unsigned __int128` is `i128` and an `unsigned _BitInt(N)` its own `iN` -- libc++ 21's
  `__countl_zero` calls `__builtin_clzg` on an `unsigned __int128` (libc++ 18 splits it into two 64-bit calls), and the
  gate over libc++ 21 found the widths 8 to 64 only, eight fixtures RED. `bitwide.c`, `bit128.cpp`. (0.73, 0.129)
- The overflow builtins (`__builtin_add_overflow` and kin, `ccl_overflow_builtin/2`) compute the exact result in
  `i128` over operands widened by their own signedness (`ir_widen128/4`). They store the truncated result and answer
  whether it lost anything. C23's `<stdckdint.h>` is written on them. (0.93)
- `__builtin_unreachable()` is `unreachable`, and `[[assume(e)]]` calls `llvm.assume`. (0.93)
- `va_start`, `va_end` and `va_copy` are the `llvm.va_*` intrinsics (`ir_va_intrinsic/3`); `va_arg` of a scalar is
  LLVM's own instruction. `va_arg` of a struct, a union, a complex or an `__int128` is expanded here on x86-64 (psABI
  3.5.7; `ir_va_arg_aggregate/4`, `ir_piece_classes/5`, `ir_va_fetch/7`, `ir_va_overflow/4`): every eightbyte of the
  type comes from the register save area by its class (`gp_offset` / `fp_offset`) when they all fit, else the whole
  value from `overflow_arg_area`, aligned to 8 or 16 and advanced; AAPCS64 refuses `va_arg_of_aggregate`.
  `__builtin_va_list` is the ABI's type (`ccl_va_list_type/2`): `unsigned long[3]` on x86-64, `[4]` on AAPCS64, `char *`
  on Apple's arm64. `test/c/run/varargs.c`, `vaaggregate.c`. (0.108, 0.117)
- `__builtin_inf`, `huge_val` and `nan`, in double, float and long double forms, are constants (`ir_float_builtin/4`),
  as glibc's `INFINITY`, `NAN` and `HUGE_VAL` need. `__builtin_isnan`, `isinf`, `isinf_sign`, `isfinite`, `isnormal`
  and `signbit` are `fcmp` or bit tests that answer an `int` (`ir_fp_class/1`). (0.101, 0.108)
- libc++'s memory builtins become the C library's `memcpy`, `memmove` and `memset` in the desugaring;
  `ir_cpp_prelude/0` declares them when the file did not. (0.60)

### Line tables (`-g`)

- Under the driver's `debug` option (`'$ccl_debug'` = `file(Path)`, the Driver topic) the lowering writes LINE TABLES,
  DWARF 5 (0.128). A function the program defines gets a `distinct !DISubprogram` with its name, its line and the one
  file (`ir_dbg_begin/3`, from `ir_function/7`; the line from the item, `'$ir_fn_line'`), and EVERY instruction of its
  body a `!DILocation` of the line of the statement being lowered (`'$ir_line'`; the function's own line before the
  first statement): `ir_ins/1`, `ir_end/1` and the fall-through branch of `ir_block/1` append `, !dbg !N`
  (`ir_dbg_parts/2`). LLVM's verifier asks a location of every call in a function that has a subprogram, and of an
  inlinable call in particular, so no instruction is left without one. A location is made once per line and function
  (`'$ir_dbg_locs'`). A declaration sets the line too (`ir_stmt(declaration(L, ...))`): its initializer's calls are its
  own. (0.128)
- A LIBRARY function (`cpp_library_function/1`) gets no subprogram: its lines are a header's, and the table names one
  file. A function without a subprogram has no location on any instruction. (0.128)
- `ir_assemble/1` appends the module's own metadata (`ir_dbg_module/1`): `!0` the `DICompileUnit` (language
  `DW_LANG_C11` or `DW_LANG_C_plus_plus_14`, producer `cicilang <version>`, `emissionKind: LineTablesOnly`), `!1` and
  `!2` the two module flags LLVM asks (`Dwarf Version` 5, `Debug Info Version` 3), `!3` the `DIFile` (the base name and
  the directory of the absolute path), `!4` the one `DISubroutineType` every subprogram shares, then the subprograms and
  the locations from `!5` on (`'$ir_dbg_md'`, `'$ir_dbg_n'`). A name or a path is escaped for a metadata string
  (`ir_dbg_escape/2`). No variable, type or lexical scope is described: `-g1` to `-g3` give what `-gline-tables-only`
  gives. A subprogram's name is the function's LLVM name, so a C++ function is known to a debugger by this compiler's
  own name (gdb: `break 'Counter.bump.int'`; a breakpoint by `file:line` works in both languages). (0.128)

### The embedded LLVM

- `module/ccl_llvm.cicili` is the whole back end, a cocolog module over llvm-c (owner's rule: no clang, no LLVM
  binary). Its surface: `ccl_llvm_version/1`, `ccl_llvm_triple/1`, `ccl_llvm_check/2` (parse and verify) and
  `ccl_llvm_compile/3`. `cicilang_compile/3` calls it through `ccl_compile/3` (`library/ccl_build.pl`); without the
  module it is `no_embedded_llvm`. (M2, M5)
- `ccl_llvm_compile/3` parses and verifies the IR in a fresh context. It sets the host's triple, CPU, features and data
  layout, runs the pass pipeline, and writes an object file, or assembly under `-S`. An LLVM error is
  `error(ccl_llvm(What), Detail)`, for example `no_target`, `passes_failed` or `emit_failed`. (M2)
- The pipeline is `default<On>` for the flag's level (`ccl_llvm_pipeline`). When the flags name no level the module
  takes `-O1`; the driver passes `-O0` unless an `-O` flag is given. (M2)
- At `-O0` the pipeline is `default<O0>,globaldce`. `default<O0>` holds CoroSplit, which every coroutine needs.
  `globaldce` drops the `linkonce_odr` instances that nothing calls, such as libc++'s `iter_move` over
  `__projected_impl`, whose operator the library never defines. (0.108, 0.109)
- `module/build-llvm.sh` builds `library/ccl_llvm.so` with an rpath to LLVM. It links `-lLLVM-C` when `libLLVM-C.*` is
  in `llvm-config --libdir` (Homebrew), else `-lLLVM` (Debian, Ubuntu). Rebuild it after a change to
  `module/ccl_llvm.cicili` and after a cocolog update. (0.87)

## Time and memory

### Memory: every unit of work inside `\+ \+`

- cocolog reclaimed the heap only on backtracking before 1.8.36, and its collector does not run inside a nested engine
  (findings below). So each unit of work runs inside `\+ \+` and passes
  its result out through a global or a fact: a preprocessed file (`pp_include_file`, its output under `'$pp_out:N'`,
  spliced by `pp_finish`), a parsed item (`ccl_externals_/5`: the item and the tokens left pass through `'$ccl_item'`,
  and `ccl_skip` restores the position), a gate check (`test/reader.pl`, `test/cpp.pl`). Why: a `std::vector<int>`
  build restarted the owner's machine. (0.46)
- Large text is built a hundred items at a time, each chunk inside `\+ \+` (`ccl_ast_chunks`, `ccl_sum_chunks`).
  (0.71)
- `ck_items` scopes each checked function and `ir_items` each lowered item. A function's text is a global of its own
  (`'$ir_fdef:K'`, `ir_add_fdef/1`), never a list copied at each addition. (0.80)
- Each emission road of the desugaring runs inside `\+ \+`: `cpp_instantiate_class_` (an instance's whole body),
  `cpp_make_lazy`, `cpp_use_fn`, `cpp_instantiate_function_`, `cpp_make_member`, `cpp_nested_class`, `cpp_hdr_load`,
  `cpp_implicit_copy_ctor`, `cpp_implicit_assign`. Their facts and globals survive. (0.68, 0.80)
- A candidate's check runs inside `\+ \+` where the arguments and the explicit template arguments are ground
  (`cpp_candidate_check/5`, on the free, member and constructor roads); only the bindings come out, through
  `'$cpp_cand_out'`. (0.109)
- A goal that writes a global runs under `once/1` where a search can ask it again: `nb_setval/2` survives
  backtracking, and a `findall` once registered one temporary twice. (0.80)
- `cpp_spend/1` refuses `instantiation_budget` past 3000 loads and instances; `cpp_deeper/1` refuses
  `instantiation_depth` past a nesting of 120. Why: a runaway instantiation took the machine's memory. (0.44)

### Tables: a global is copied, a fact is indexed

- `nb_getval/2` and `nb_setval/2` copy the whole term. So `ccl_items_note/1` sets each table once per unit tree
  (per-item writes were quadratic), and the file scope is its own table (`'$ccl_gscope'`, in buckets since 0.120, below):
  `'$ccl_scope'` holds only the open frames, and `ccl_declare/2` and `ccl_declared/2` never copy the headers' names.
- The globals are set once per process (`ccl_ensure_globals/0`) and read bare. `ccl_global/3` calls it first, so code
  that the initialization reaches reads with a bare `catch(nb_getval(K, V), _, fail)` (`ccl_set_new_bucket/2`); else
  the initialization re-enters itself. A `catch/3` stays only where a call can throw (`time_file/2`, `proc_run/4`, a
  macro call, a candidate check), never around a hot read. (0.46)
- A name set that the parser asks at every identifier is held in buckets, a global each (`ccl_set_has/2`,
  `ccl_set_add/2`, `ccl_set_new/3` over `'$ccl_envs'`, `'$ccl_tmpls'`, `'$ccl_ftmpls'`). Every writer keeps the
  buckets and the list (`ccl_env_put/1`, `ccl_add_env(s)/1`, `ccl_note_template(s)/1`, `ccl_tparams_leave/1`). A deep
  grammar rule passes `genv` for the global env (`ccl_env_member/2`). A C++ tag is noted without its bodies
  (`ccl_slim_members/2`, `ccl_sum_slim/2`). (0.46)
- THREE TABLES ARE BUCKETED (0.120): the file scope `'$ccl_gscope'`, the typedefs `'$ccl_typedefs'` and the tags
  `'$ccl_tags'` are 128 globals each, `P_0` to `P_127` (`ccl_tab_g/3`), and an entry lives in the bucket its key's
  characters hash to (`ccl_tab_bucket/2`; a key that is no atom, a method defined out of its class, is in bucket 0). A
  write or a lookup copies ONE bucket, 150 entries at 20,000 names: `ccl_tab_add/2` (one entry, or a bulk grouped by
  bucket), `ccl_tab_find/3` (by key), `ccl_tab_member/3`, `ccl_tab_list/2` (every entry, the buckets concatenated, for a
  reader that wants them all), `ccl_tab_reset/1`, and `ccl_tab_save/2` with `ccl_tab_restore/2` (a nested read's save and
  restore keep the buckets, `ccl_with_file/2`). Inside a bucket the order is the old list's, newest first, so the first
  entry that unifies is the one the single list gave; ACROSS buckets there is no order, and a caller with an UNBOUND key
  gets the first bucket's (every caller asks with the name). The drain functions follow `ccl_tab_list`, which is why the
  lowering version moved. `ck_declare_at/4` asks the open frames and the file scope apart for the same reason (the file
  scope is the LAST frame). Why: 800 file-scope declarations into 3,000 names and 6,000 lookups were 6 of the 15 CPU
  seconds of a `std::vector` build, and one write was 40 ms at 20,000 names. (0.120)
- SEVEN OF THE DESUGARING'S REGISTRIES, lists in a global until 0.119, are facts (0.120): the class typedefs
  `'$cpp_ctype'(Class, Name, Type)`, the enclosing classes `'$cpp_encl'(Nested, Enclosing)`, the static initializers
  `'$cpp_sinit'(Class, Name, Init)`, the lazy library classes `'$cpp_lazy_c'(Class)`, the destructors defined out of their
  class `'$cpp_dtor_def'(Class)`, the names that keep C linkage `'$cpp_cname'(Name)` and the functions' default arguments
  `'$cpp_dflt'(Name, Defaults)`. A fact is found by its first argument and copies only what it answers. They are written
  NEWEST FIRST (`asserta`) and a lookup takes the first match (the cut), as `memberchk/2` did on the lists. The class
  typedefs alone were copied 38,777 times in a `std::vector` build (1.5 of its 9.6 s), and the heap those copies leave is
  what a nested engine does not collect. `test/cpp.pl` sets `'$cpp_encl'` for its mangler check. (0.120)
- The C++ registries that hold bodies are facts, cleared in `cpp_register_units/1`: `'$cpp_cls'`, `'$cpp_clsl'`,
  `'$cpp_tmpl'`, `'$cpp_spec'`, `'$cpp_mt'`, `'$cpp_inst'`, `'$cpp_out'`, `'$cpp_hdr'`, and the concepts,
  `'$cpp_concept'(N, concept(TPs, E))`. C's tables stay globals (a clause is a store row under `--embed`); C++ runs
  `--local`. (0.44, 0.112, 0.120)
- THE LIGHT CLASS RECORD (0.120): a class's record `'$cpp_cls'(C, cls(Base, Data, Members, Statics, Defaults, Slots))` is
  97% its members (every method with its body), so a lookup that wanted only the base copied the whole class:
  `cpp_base_scope/2` alone asked 44,764 times in a `std::vector` build, 2.6 of its 9.6 s. `cpp_class_put/2` writes beside
  the record `'$cpp_clsl'(C, cls(Base, Data, Statics, Defaults, Slots))` (a hundredth of the size), `cpp_class_l/2` answers
  it (a class not registered yet is asked of `cpp_class/2`, which loads it), and every caller whose members field was `_`
  asks that one. A caller that wants the members still asks `cpp_class/2`.
- Per-process state is a global, never a dynamic clause (`'$ccl_reading'`, `'$ccl_macro_files'`, `'$ccl_unit_paths'`):
  a dynamic predicate persists under `--embed`.
- No header's macro table is parsed whole: a macro reaches a preprocessor run by name, on first use
  (`pp_outer_macro/3`, `pp_header_macro/3`). In C++ it is a fact, `'$ccl_hml'(Name, Path, raw(Line))`, parsed when
  asked (`pp_raw_macro/4`); in C it is the store's row under its name (`ccl_kb_macro/5`).

### Caches of the symbol table

- `ccl_cached(Cache, Key, Value, Goal)` keeps the Key-Value pairs found so far in one global, for a term key and a
  small value: layouts (`'$ccl_laycache'`), `ir_type/2` (`'$ir_tcache'`), `ir_abi/2` (`'$ir_abicache'`).
- `ccl_cached_named(Prefix, Name, Value, Goal)` keeps a global per name and an index of the names, for a large value:
  typedefs (`'$ccl_td:'`), tags (`'$ccl_tag:'`), struct forms (`'$ccl_ts:'`), resolutions (`'$ccl_r:'`), the file
  scope (`'$ccl_g:'`), `ck_has_own_array/1` (`'$ck_oa:'`), a summary's tables (`'$ccl_sumload:'`).
- `ccl_tables_changed/0` empties the small caches and the index of each `ccl_named_caches/1` prefix wherever a table
  is written (the noters, a summary's note, `ccl_scope_init/0`, `ccl_with_file/2`'s restore). `ccl_sum_forget/1`
  empties `'$ccl_sumload:'`.
- A miss is remembered as `'$ccl_miss'` for the `ccl_caches_misses/1` prefixes (`'$ccl_tag:'`, `'$ccl_td:'`,
  `'$ccl_ts:'`, `'$ccl_g:'`), only for an atom name asked with the value unbound. `ccl_gdeclare/1` marks each
  remembered name it declares `'$ccl_recheck'` (`ccl_gdeclare_recheck/1`), so the next ask looks again. Why:
  `cpp_path_class(std, _)` copied the whole tags table at every `std::` call. (0.112)
- A cached predicate is not re-entrant: both forms read the cache once before the goal and write it after, so a nested
  ask on the same cache is lost (a recomputation). An entry's computation never asks its own cache: it takes the
  `_nocache` form or asks nothing (`ccl_empty_layout/1` over `ccl_no_data_members/1`). (0.89)
- Ask a cached predicate with the output unbound, then compare: on a miss a bound output reaches the goal
  (`ir_type(T, x86_fp80)` met `ir_base`'s throwing last clause). Write `ir_type(T, LL), LL == x86_fp80`. (0.108)
- Answer by shape first: `ccl_resolve_type/2` takes a plain specifier list in one head and sends `base` to
  `ccl_resolve_base/3`; `ck_own_array_type/1` answers an array, a pointer or a plain type in one head each.
- A summary is parsed once per process (`ccl_sum_terms/2` into `'$ccl_sum:<File>'`, forgotten by `ccl_sum_write/4`),
  split once (`ccl_sum_load/7`), and its names added in ONE read and write (`ccl_add_envs/1`, `ccl_note_templates/1`).
- `time_file/2` is never memoized: a memo served a touched file stale inside one gate process.

### Memos of the C++ desugaring

- An instance asked for again answers its name only (`'$cpp_iname'(N, Args, Name)`, the arguments compared with `==`).
  Why: a clause retrieval copies what it answers, here a template's whole item. (0.64)
- A function template's candidate set is made once per name (`cpp_fn_candidates/2`, `cands(N, Cands)` in
  `'$cpp_fncands:F'`, each key computed once by `cpp_fn_merge_defaults/3`), and again only where the count N of its
  templates moves. Why: each call of `std::get` (96 definitions) rebuilt it. (0.97)
- ONE FUNCTION TEMPLATE DECLARED TWICE IS ONE CANDIDATE (`cpp_dedupe_candidates/2`, `cpp_same_candidate/2`, `cpp_unlined/2`; the
  set is made once per name, above): a header's items come from every summary that flattened it, and `<format>` and
  `<string>` each hold libc++ 21's `back_inserter`, so a program that read both had it TWICE under one name. Alike means
  the same template head, storage, result, name, parameters and variadic mark and the same body once the line of each
  statement is set aside (`cpp_line_functor/1` lists the forms that carry one; a form the list lacks compares unequal and
  keeps both copies, as before); a declaration is alike to a declaration only. Why: the second copy is tried after the
  first, and when the first candidate's check refuses and leaves its instance half made -- `back_insert_iterator<void>`,
  whose `operator=(const typename _Container::value_type &)` cannot be declared; a class's name is recorded before its body
  registers and a refusal leaves it, which later asks of the NAME rely on (the views at libc++ 21 need it) -- the second is
  answered the name, holds, and emits a constructor of a class that was never made: `not lowered yet:
  typedef(back_insert_iterator.void)`. Forgetting the half-made instance instead was tried (0.126) and broke `viewchain`
  and `viewsall`: a registration that refuses and is asked again refuses again, where the name had been answered. A
  reduction needs libc++ 21 (`formatton.cpp`: `format_to_n` with `<string>` read first). (0.97, 0.126)
- The holding set is remembered per call shape (`cpp_holding_set/6`, `cpp_call_shape/5`, `hs(Hs, FirstRefusal)` in
  `'$cpp_hs:<key>'`): the name, the explicit arguments' VALUES (`cpp_targ_value`), each argument and its type, the
  template count, `'$cpp_class_ctx'`. An untypable argument disables it. Why by value: `get<__indx>` in libc++'s
  `__mu` differs per instantiation (`stdbind`). (0.97)
- A concept's satisfaction (`'$cpp_ccm'(C, Args, yes | no)` in `cpp_concept_holds/2`, cached as C++ caches it,
  [temp.constr.atomic]) and a variable template's value (`'$cpp_vtm'(N, Args, E)` in `cpp_instantiate_variable/3`) are
  remembered per ground arguments. Why: libc++'s ranges ask the same ones thousands of times. (0.112)
- The partial ordering's comparisons are tests under `once/1` (`cpp_most_special_fn/3`, `cpp_most_special/3`), and
  `cpp_fn_more_special/2` runs its prefix under `once`. Why: a comparison failing under `\+` retried every alternative
  before it, 4^k + 1 comparisons for k parameters. (0.95, 0.99)
- A library template's instance and a lazy library class emit only the members the program names
  (`cpp_lazy_instance/2`, `cpp_use_member/2`); a lazy polymorphic class emits only its slot implementations
  (`cpp_slot_fns/6`). The program's own templates stay eager, for the safe part. (0.52, 0.72)
- Measured at noise and taken out: a memo of the choice among the holding set (0.97), a kind pre-filter (0.98).

### The reader, the lowering and the processes

- The lexer that runs is native (`ccl_lex_native/6`, chosen once by a probe into `'$ccl_lexer'`), about 600 times
  faster than the DCG, which stays the specification and the fallback.
- The grammar chooses a clause by one look at the next token (`ccl_peek//2`, `ccl_unary_//3`, `ccl_primary_//3`,
  `ccl_postfix_p//3`), and one precedence-climbing rule reads the binary levels (`ccl_binary//2` over `ccl_binop/2`;
  owner's rule: a pattern is written once). Why: trying every alternative cost 30 token matches a token, against 8.
- Text goes through builtins: `atomic_list_concat/3` splits a file, `atom_codes/2` and `memberchk/2` test a line, and
  only a line that needs it is walked code by code (`pp_clean/3`). On a hot path `sub_atom/5` has every position
  bound.
- A C++ library header is flattened and read once, never raw: raw, `<sstream>`'s headers each failed and were
  preprocessed in turn, for ten minutes.
- The lowering caches `ir_type/2` and `ir_abi/2` per type term; `ir_expr/4` carries the LLVM type beside the C type;
  `ir_join/3` is `atomic_list_concat/3`.
- The inference is at its floor. The check's cost is `ck_expr`'s walk, a `ck_in` lookup per node over the threaded
  `st(Frames)`; a further cut is a redesign (a state table per function, or the lookups in C).
- The host's arch and OS come from the module (`ccl_host_arch/1`, `ccl_host_os/1`), `uname` only without it. A build's
  only spawns are the link (`ccl_sh/3`) and, for a C++ summary, `mkdir -p` (`ccl_sum_dir_ready`).
- `bin/cicilang` forks about six times, where it forked twenty: every `$(...)` and every pipe is a fork.

### Finding a cost

- The memory trace is in the code: `cpp_mem/1` and `ir_mem/1` give `kb(Heap, Store)`
  (`statistics(globalused | store_used)`) on every `'$cpp_trace'` line (`cpp_trace_mem/1`, each spend), at each phase
  (`phase(check | lowering | assemble)`) and per lowered item (`lower(Item, Mem)`); `stmt_out(S)` shows the program's
  statements. Call cocolog directly: `bin/cicilang`'s filter drops the trace lines. (0.80)
- The breadcrumb is a stack of eight frames (`cpp_where/2`, `'$cpp_wstack'`), kept only under `'$cpp_trace'`, since it
  is entered at every statement: `class`, `fn`, `load`, `member`, `sig`, `subst`, `body`, `auto`, `call`, `args`,
  `stmt`, `scope`. `cpp_refuse/2` prints `refuse(What, in(Stack))`, and an instance keyed by a free name prints
  `free_name_instance(N, A, ctx(C), making(M), from(Stack))`: such an instance can run to the cap. (0.87, 0.93)
- Rank time by CPU per trace line: a scratch copy stamps `statistics(cputime, T)` on each line, and a script sums the
  gap after each line by its functor. A count of one event (per comparison, per deduction) then names an exponential
  that switching rules off one at a time could not. (0.95, 0.99)
- A FLAT PROFILE, made by a script (0.120; cocolog has no profiler, and the script is session scratch, not in the
  repository): a scratch copy of `ccl_cpp.pl` and `ccl_infer.pl` in which every rule and fact begins with a goal that stamps
  `statistics(cputime, T)` and adds the time since the last stamp to the clause entered BEFORE it, the stamp taken again as
  the goal ends so that the instrument's own cost is not charged, and a dump after a CPU limit. A clause is charged for what
  runs after it is entered and before the next one is -- its own goals, the builtins it calls, the callees that are not
  instrumented -- so a builtin's copying (`nb_getval/2`) is its CALLER's. The overhead is a factor of three; the ranking is
  the work's. On a `std::vector` build, `cpp_class/2` was 19% and `cpp_class_typedef/4` 12%, the rest flat. A smear names a
  region, not a line: timers in situ around the suspected reads (`statistics(cputime)` before and after, summed in a
  global) then measured the copies themselves -- the class record 68,075 times, 2.61 s; the class typedefs 38,777 times,
  1.23 s; the enclosing classes 29,700 times, 0.06 s -- and a count of one predicate per CALL SITE (`cpp_base_scope/2`
  alone, 44,764 times) named who asked. The dump comes at the CPU limit whatever the program is doing, so it serves a build
  that does not end as well as one that does.
- Rank memory by event: sum the heap stamps by the event before each growth. Trace at a LOW cap to see what is in
  flight when the memory goes; spends against distinct instances tell breadth from a loop. A loop grows to the cap and
  raises nothing, so each failing candidate step traces itself (`ctor_candidate`, `ctor_no`, `member_refused`,
  `sig_failed(F, Step)`). (0.64, 0.68, 0.109)
- Rank every predicate's calls before touching a pass: a scratch library first on `COCOLOG_LIBRARY`, every rule HEAD
  wrapped by a counter (heads only: renamed calls bypass the wrapper).
- Attribute time with stubs, ten runs deep: one clause stubbed in a scratch library
  (`ck_anchor_addrs(_, St, St) :- !.`), the pass run ten times in one process. A stub must be SEEN to succeed: one
  that failed fast read as the cost.
- Take the phases apart before guessing: the read alone (`cicilang++ -fsyntax-only`), then `ccl_cpp_units` alone. Why:
  the serial gates' seven hours were one cold read done twice, on one core of four. (0.64, 0.105)
- Measure against a baseline: probes that differ by one line, beside one that calls nothing; a fix that breaks it is a
  wrong edit. A bad thing in a trace is not THE cost until the CPU time says so. A dominant cost hides the rest, so
  measure again after each fix. A rise can be right, where work had been skipped. (0.65, 0.68, 0.92, 0.95)

## Findings about the neighbours and the instruments

### cocolog, Cicili, the installer and the host

- cocolog collects the heap since 1.8.36 (`coco_heap_gc`, a sliding mark-compact, the trail with it): between two
  steps of the outermost engine, when it is the only engine running on the machine and its host turned it on (the
  `query` host does), never inside a nested engine -- `findall/3`, `forall/2`, `aggregate_all/3`,
  `with_output_to/2`, a directive. It runs between steps only, so a module's C frame never holds a moved cell: the
  native lexer and the embedded LLVM are safe. Before it, the heap came back on backtracking only (on 1.2.12 thirty
  million-integer lists built deterministically took 521 MB, and 42 MB inside `\+ \+`): hence the `\+ \+` scoping
  above, which still serves the work inside a `findall/3`. Measured on the `std::format` build, warm: 1.8.1 peaked
  at 2882 MB, 1.8.38 at 591 MB. After a cocolog update the modules are rebuilt (`module/build.sh`,
  `module/build-llvm.sh`, and cocolog's `os` and `process` modules); 1.8.36 to 1.8.41 left the SDK's ABI unchanged.
  (0.46, 0.112, 0.114)
- cocolog is at 1.9.1 since 0.117 (it was 1.8.41; ZiguratIP is rebuilt first, then cocolog, then both modules here). The
  baseline of that step was 0.116 over 1.9.1, all seven gates GREEN, so the engine's compiled-control stages (1.8.55,
  1.8.57, 1.9.1: one dispatch per functor, an index on any argument) changed nothing cicilang relies on. cocolog's own
  reader refuses an integer literal past 61 bits since 1.8.50; cicilang writes none (`big(Atom)`). The collector still
  skips a nested engine (cocolog's own `CLAUDE.md` says so); the missing `oom` check is not re-measured at 1.9.1.
  (0.117)
- Since cocolog 1.8.39 a load directive that loads nothing says so, in SWI's two lines (`ERROR: ... source_sink
  `library(X)' does not exist`, then `Warning: ... Goal (directive) failed`), and the load goes on; it was silent
  before. cicilang's directives name only libraries that exist (`process`, `os`, its own), and every `ensure_loaded/1`
  of a cache file asks `exists_file/1` first, so no run prints them. A missing `os` or `process` module now prints them;
  `bin/cicilang`'s filter drops the lines. 1.8.40 and 1.8.41 add the translation library (`library/reasoning/`), which
  cicilang does not load. (0.114)
- The store compacts itself since cocolog 1.2.13: once 32 MB or more of cells are dead and outnumber the live ones, a
  safe point copies the reachable terms to a fresh array (sized at the live length since 1.2.14). `garbage_collect/0`
  forces it; `statistics(store_used, B)` reads it. It is the process's array, not the disk. Before it, `nb_setval`
  overwrites left most of a build's store dead. (0.79, 0.84)
- On disk a process that writes a predicate rewrites all of it, about 360 bytes per row it holds (500 measured here);
  a read-only process adds nothing. Dead rows stay until `cocolog vacuum` (since 0.128 every 64th run of
  `bin/cicilang` and each gate vacuum the store), and a write is quadratic past about 30,000 rows (undiagnosed). So
  the AST cache is one predicate per file (`'$ccl_items:<Path>'`), no C++ header enters the store (`cicilang++` runs
  `--no-kb`), and the store is stamped `Reader.Lowering` and started afresh when a version moves (`kb_prepare`,
  `ccl_kb_prepare`).
- A writer killed mid-write can damage the store (`hexmap ends inside the chunk`). It is a cache:
  `rm -rf ~/.cicilang/KB ~/.cicilang/KB.version` repairs it. (0.108)
- Integers are 61-bit and `is/2` wraps silently. So a literal past 2^60 is `big(Atom)` in both lexers, the constant
  evaluator computes 64 bits over base-2^30 limbs (`ccl_w_*`), and `dr_fold/4` keeps two folds under 2^31. (0.94)
- A refused allocation is a WRONG ANSWER (unchanged at 1.8.41). The `oom` flag is set at eleven growth sites and read
  only by the compaction, which declines and keeps the store; new terms then alias cell 0. The query answers `false.`,
  prints `ERROR: ?-: Unknown message: _G0` and exits 1. A gate dies so when the MACHINE runs out, and runs clean
  alone; `test/cpp.sh` then prints `RED: the gate did not finish (query exit N)` and the raw tail. Request: an `oom`
  check that answers `resource_error(memory)`. (0.84)
- Fixed in cocolog 1.1.0: a `catch/3` whose goal succeeded stayed live for a later `throw/1`; a throw in
  `findall/forall/aggregate_all` escaped its catch; `atomic_list_concat` segfaulted on an unbound element and failed
  past 8 KB. Kept as habit: every `catch/3` under `once/1` or as a condition, a raising loop written as recursion,
  `new/3` checking its initial values first.
- Fixed in cocolog 1.2.0: a clause over a store row (about 8 KB; no limit under `--local`) silently lost every clause
  of its predicate. It now raises `resource_error(clause_length)`, which the writers catch to leave the file uncached
  (`ccl_kb_store_items`, `dr_ir_store`). Nothing large goes in one clause: a row per item, IR chunks of 3500
  characters, a row per dependency under `'$dep'`.
- Fixed in cocolog 1.2.2 (7f6a1ac): a first call probed the store at a cost growing with it. The stamp and the
  one-process gates stay, for the dead rows.
- `term_to_atom/2` with T bound, even partly, WRITES T and compares the texts
  (`term_to_atom(mnames(Ns), 'mnames([a])')` fails): parse into a fresh variable. It reads at most 8191 characters
  (`char buf[8192]`, then `type_error(atom, A)`), so `ccl_sum_lines` silently drops a summary's `tag(...)` line for a
  big class (`pair`, `tuple`, `optional`, `variant`, `basic_string`, `vector` ...). A summary-served run's tag table
  lacks the class until the desugaring loads it from the `.ast.pl`. Named, not fixed.
- cocolog writes a float with `%.15g` (no exact round-trip) and an infinity as `inf.0`, which its reader refuses
  (`its clauses would not consult`, no line). `ccl_finite_float/2` clamps a literal past a double. (0.55)
- The reader refuses, naming no line, `is` as a plain atom argument, a quoted atom holding `"` and
  `append([declaration(...)] , Ifs, B0)`. Bisect by splitting the file into clauses, or by each hunk alone onto HEAD
  (a library file consulted alone fails for its own reasons). (0.93)
- `cocolog --embed run FILE goal` consults FILE into the store, and a module's clauses do not reach the knowledge base
  (1.2.18): a gate program is loaded by `ensure_loaded/1` from a `query` (`reader_main`, `compile_main`, `cpp_main`).
  Every dynamic predicate asserted at run time persists under `--embed`. A second `ensure_loaded/1` replaces a file's
  clauses, which stay in the process, unstored.
- Seventy goal-carrying facts consulted into a store segfaulted once, and cocolog cannot reproduce it: the gate checks
  are clauses (`k1 :- check(Name, Goal).`).
- Builtins at 1.8.1. `current_predicate/1` lists the program's predicates only, not a file's loaded by
  `ensure_loaded/1` (an alias of `use_module/1`): macro heads come from `ccl_pl_clauses/2`. Absent: `consult/1` as a
  goal, `load_files/2`, `open/3`, `predicate_property/2`, `flag/3`, `recorda/2`, `prolog_load_context/2`,
  `term_expansion`. Present: `abolish/1`, `clause/2`, `retract/1`, `nb_setval/2`, `b_getval/2`, `dynamic/1`,
  `read_file_to_codes/2`, `phrase/2,3`, `number_codes/2`, `statistics/2` (cputime, inferences, globalused, trailused,
  atoms, functors, store_used), `get_time/1` (microseconds). `time_file/2` answers whole seconds.
- An unset global throws an existence error: read it through `ccl_global/3`, or by a catch as a condition or under
  `once/1`.
- The query loop asks for a second answer, so an entry point is under `once/1` (`ccl_drive/2`). It reads standard
  input, so a background run gets `< /dev/null` and a pool job runs with `/dev/null` (`test/parlib.sh`): one job
  swallowed the queued job lines. (0.46, 0.106)
- Costs: `nb_getval/2` and `nb_setval/2` copy the whole term (0.63 ms for 5,000 pairs), and so does a clause
  retrieval; `memberchk/2` 0.15 µs a step; a fact among 5,000 found by its first argument 3 µs, asserted 2 µs (under
  `--embed` a store row, indexed by an ATOM first argument, not `dep(I)`), where a global per name costs 25 µs; a
  predicate call about 5 µs; `catch/3` grows with the terms bound in it (37 ms against 0.3 ms bare); a code walk about
  1 µs a code; `sub_atom/5` with a free position about 150 µs; a spawn 0.14 s and a shell fork 10 ms on macOS; the DCG
  lexer 0.15 ms a token whatever its clauses.
- The module SDK builds no compound: `coco_make/4` (lib/term.cicili, behind `coco_m_machine`) does. `coco_m_error/3`
  returns the predicate's ANSWER, not a status: a raising helper hands it back through an out parameter and returns 0,
  else its caller walks on into LLVM with a null module.
- The DCG translates `->` and `*->` in a body. `( A, ! ; B )` in a DCG body cuts the WHOLE clause, so it serves only a
  choice that decides the clause; an optional word is `( X ; [] )`. A misplaced cut once killed every inline function.
- A predicate whose name and arity are a nonterminal's plus two IS that nonterminal: `ccl_init_items/3` joined
  `ccl_init_items//1` and raised `Arguments are not sufficiently instantiated`, no line. Look a name up at its arity
  and at the DCG's. (0.93)
- `memberchk/2` on an open list binds its tail: never on an open accumulator. `atom_concat/3` on a compound throws: a
  name that may be compound is guarded with `atom(N)` (the noters, `ccl_resolve_base/3`, the mangler). (0.32)
- `::` is xfy: `a::b::c(X)` reads `a::(b::c(X))`; the objects layer has a `Recv::(Inner::Msg)` clause.
- The lexers write `"`, `'` and `\` as the codes 34, 39 and 92, since `0'"` and `0''` read badly in an older cocolog;
  the 1.8.1 reader takes any character after `0'`, not yet checked by a run.
- Cicili: a function is defined above every function that names it, else the transpiler says `unknown symbol: NAME`.
  (0.93)
- Cicili's module pattern: a C function outside Cicili's std is declared
  `(decl) (func Name ((Type arg) ...) (out Type))` with one-token types (`LLVMBool`, `char **`); `unsigned` needs an
  alias (`(@define (code "uint_t unsigned"))`). A header's enum constant or `static inline` goes behind a one-line raw
  C helper (`(code "static T ccl_ll_x(...) {...}")`, declared with `(decl)`). `(cof p)` is `*p`, `(? c a b)` the
  conditional, `(cond ...)` a chain; a `let` initializer that is no call is `(T x . nil)` then `(set x ...)`; no
  parameter is named `asm`.
- cocolog's installer took `ZIGURATIP_HOME=${ZIGURATIP_HOME:-$ZIGURATIP/home}`: an inherited value beat the caller's
  `ZIGURATIP`, nothing linked, and the completeness check audited the OTHER tree. Since cocolog 1.2.16 it refuses
  (`INSTALL RED: ZIGURATIP and ZIGURATIP_HOME name different trees`); `make EMBED=0` builds a store-less cocolog.
  (0.87)
- macOS's memory counters read LOW: a realloc moved by copy-on-write remap drops its pages from `/usr/bin/time -l` and
  ps's RSS until touched, so identical runs read 1.7 to 3.5 GB. The high reading is honest; Linux has neither effect.
  Ask `statistics/2` from inside (`cpp_mem/1`, `ir_mem/1`); a ps-RSS watchdog under-protects there. macOS does not
  enforce `ulimit -v`. (0.46, 0.79)
- On Linux a container's memory ceiling is set outside: `/sys/fs/cgroup/memory.max` reads `max` inside, and the OOM
  killer takes the biggest process. When a gate dies silent, run `dmesg | grep -i "killed process"` first. (0.87)
- dash, the Linux `/bin/sh`, has no `jobs -r`: the pool tracks its children by PID with `kill -0` (`test/parlib.sh`).
  (0.105)
- sh has no local variables: a helper's variable is its caller's, so each helper a pool job calls uses names no job
  uses (`_nd_cond`, `_nd_f`, `_nd_r` in `ccl_needs_met`). A MISSING verdict is the tell. (0.107)
- The Unicode name table comes from Perl's `Unicode::UCD` (`module/gen-uninames.pl`): python3's `unicodedata` is
  Unicode 14.0.0 and lists no alias, and the proxy refuses unicode.org. `charprop` is slow per Hangul syllable, so
  those names come from the Jamo tables. (0.104)

### Measurement and the instruments

- An instrument that answers without measuring the thing asked answers confidently and wrongly. The tell is an answer
  that came too cheaply, or at all when what makes it had just failed. Absence is evidence only on a channel known to
  carry a presence (macOS's counters, the installer's check, a sleeping clock, a stale binary, a filtered write, a
  missing runner's old log, a self-matching waiter). (0.88, 0.92)
- A wall clock counts a sleeping laptop. Compare timings only over windows known awake
  (`pmset -g log | awk '$4=="Sleep"||$4=="DarkWake"'`), and use CPU time where a number must mean something. A real
  slowdown is even; a sleep leaves the progress in bursts. (0.88)
- Change ONE variable and compare with the same fixture built on the COMMITTED library (a scratch copy of
  `git show HEAD:library/X.pl` first on `COCOLOG_LIBRARY`, its own HOME), alone and over the same cache. Measure
  BEFORE changing: a cap's bound is not a value. Name a cause only after measuring it; a number that looks right, or a
  probe of another road, measures nothing. (0.89, 0.92, 0.94)
- Run-to-run noise is up to a fifth on the owner's machine: only interleaved minimums of generated code mean anything,
  and a gate run again after an engine change claims nothing from its numbers. A gate's average moves with the box,
  the library version and the fixtures added: compare it on one box only. (0.90, 0.97)
- Every cocolog run has a memory cap and a time cap, a small fixture included (owner's rule), and a cap kills the
  whole tree: coreutils' `timeout -s KILL` signals the group it leads. A perl `alarm` kills only what it execs, so
  around `bin/cicilang++` (a shell) cocolog runs on. A watchdog put after a `#` on its line never runs. (0.46, 0.90,
  0.93)
- A memory watchdog sums every `cocolog ... query` on the box and kills them all past its cap (the session's
  `watch.sh`; `test/parlib.sh`'s pool past its hard cap). So: one guarded run at a time, or a cap of the sum. A probe
  beside a gate dies with it, and a "crash" may be that kill line above the verdict. A gate's watchdog follows the
  gate's process, never "any cocolog"; a probe watches its own process group. (0.93, 0.94)
- A waiter whose pattern matches its own shell waits for ever (`pgrep -f "cocolog ..."`): write `[c]ocolog`, or watch
  the RESULT file. (0.92)
- A KILLED GATE LEAVES ITS TEMPORARY DIRECTORY (`mktemp -d`: the `trap` does not run on SIGKILL), and a watcher that takes
  the last of `ls -d /tmp/cicilang-cpp-*/res` reads the dead run's verdicts as the live one's: it reported eight FAIL
  lines, all of the stopped first run of 0.118, while the live run had none. Take the newest (`ls -dt`), or remove the
  dead directory first; the gate's own log is the verdict. (0.119)
- After a reader-version bump every summary is cold: the next run flattens its headers in-process and peaks far above
  the steady state, and a run killed then writes no summary. A RED or a "regression" that comes with a bump is a cold
  cache until a warm run says otherwise; warm outside the gates (`test/libcxx.sh`). A mixed-age cache inflates a
  fixture, and a stale one reads as a fresh defect. (0.61, 0.89, 0.95, 0.105)
- A grammar or index edit WITHIN one reader version leaves the summaries of the older edit VALID (same key): a probe of
  the new edit runs over a HOME of its own, or the version is bumped. Over the old cache, `deque` missed its
  out-of-class statics (a link error, then a segmentation fault) and `<thread>` its operator, after both were fixed.
  (0.117)
- Remove what a run can be served: a probe's HOME first (a leftover summary is served and nothing reaches the index),
  the binary before the build (a failed build ran the last one under its heading), and bump the lowering version with
  every change to what is emitted (`dr_ir/3` serves the stored IR). (0.44, 0.89, 0.103)
- Filtered output reads as silence. `bin/cicilang`'s filter keeps diagnostics and the `cicilang: ` and `unit(` lines:
  a debug `write/1` in the library shows only with a `cicilang: ` prefix, or with cocolog called directly. The link
  diagnostic keeps ld's first line only: link by hand to see the symbol. (0.90, 0.93)
- A flag that skips the stage under test passes for unrelated reasons: `cicilang++ -fsyntax-only` skips the
  desugaring, the check and the lowering, so it passes where a build fails and a probe inside them prints nothing.
  Instrument under `-S -emit-llvm`. (0.87, 0.103)
- A partial read is silent: `ccl_read_unit` takes it, and the symptom shows far away (`undeclared(printf)`). Find the
  stop with the census: `cicilang++ -E f.cpp -o flat.cpp`, then `sh test/census.sh flat.cpp` (`CCL_CENSUS_STD=20` for
  a level) prints the stop line, the farthest line, their tokens and a functor histogram. Bisect by census cuts. If
  the declaration alone compiles, the reader stopped short. To compare two grammars, call cocolog directly, the other
  library under its own HOME (`test/census.sh` puts this tree's library first). (0.44, 0.87, 0.93, 0.109)
- A step that merely fails lies: make each failure a named refusal and trace it (a half-registered class made every
  later lookup wrong, 0.46). A write allowed to fail never fails silently (`ast_not_written`, 0.71). A recovery that
  traces an error and then succeeds makes it a success (a valid summary with no AST, 0.106). A `catch` that maps an
  `existence_error` to failure leaves no refusal in the trace; a tracing `catch` on a scratch copy names it (0.98).
- A refusal that should fire and does not says the work was SKIPPED (0.69). A swallowed refusal hides: trace it
  (`refuse(What, in(W))`, `alias_refused`). A removed predicate still called is an existence error that the driver
  reports as the compiled FILE's error (0.83).
- A breadcrumb is scoped and stacked: an unscoped one names the last thing entered, a one-frame one the ask itself
  (0.65, 0.87). A trace prints refusals, caught ones too, so a refusal in a log is no cause (0.91). It never prints a
  choice: for a wrong pick read the emitted IR per function (`-S -emit-llvm`). A missing definition is a name in the
  trace (`implicit_copy(...)`) with no `lower(function(...))` after it. A refusal's NAME is a symptom: grep the AST
  beside a summary (`<name>-<fold>.ast.pl`) for the shape. (0.93, 0.94)
- Cut each defect to a reproduction of ten to twenty lines that fails in a second (0.87, 0.94). Take the cheapest
  evidence first: write the deduced `auto` type out (0.91); print the constants or traits a road turns on beside
  clang++'s (0.94). A passing reduction can mean the probe is wrong (a file-scope typedef where libc++ has a
  class-scope one; 0.92, 0.104). Stacked defects hide each other until the front one moves; one defect seen twice is
  one (0.91).
- An expectation comes from an independent compiler: clang or clang++, or the C mirror for the B-tree
  (`bench/btree/btree_cicilang.c`, `-O1`, 20000 keys). A self-consistent error passes the program's own fixtures (a
  mangling that agrees with itself, `std::string` at 40 bytes against libc++'s 24), so measure against clang++'s
  symbols, the shipped library's export list (`nm`) and clang++'s sizes and offsets. `nm -u` names what the link will
  refuse. Measure an assumption before relying on it (a hidden stream member's `inline` mark). (0.37, 0.55, 0.75,
  0.86)
- The gates run no leak checker: a fixture over owners is checked by hand (`leaks` and MallocScribble on macOS,
  valgrind on Linux). (0.41)
- A gate finds what probes do not: run the gate the change touches. A change to one overload rule is worth only the
  gate it passes, since the rules interact ("not an lvalue" is not "an rvalue"). (0.68, 0.91, 0.94)
- A gate that ends early reads like one that passed the rest: a truncated FAIL list is no pass list. A restart under a
  gate leaves no verdict (the log is written at the end): run it again alone. A missing runner's old log read as
  GREEN: a loop over gates takes each runner's EXIT STATUS, never a log it did not see written. (0.90, 0.93, 0.101)
- Identical numbers where they must differ are a tell: equal item counts across levels meant one read was served (the
  unit cache is keyed by path and level since 0.99). An order-only failure can then fail alone, a bad read STORED as
  the AST: reproduce in the gate's order in one process and read the store's rows (0.99). Measure a tool's coverage
  before believing it; its log names the list it ran (0.96).
- Every gate check has its own name and number: two clauses of one name both run, by backtracking.
- A clause's head is part of its answer: a body that computes a new result must reach the head (`cpp_lambda_`).
  (0.101)
- Look a variable up before giving it: a `findall` reused the head's `PT`, and every defaulted `<=>` answered "equal".
  When a step adds an argument to a predicate, read the clauses of that predicate for its name first: `ir_args_/5` got a
  register state `R0`, and an older clause that used `R0` for a resolved reference type failed silently, for every
  reference handed to a by-value aggregate (`refbyvalue.cpp`). (0.103, 0.117)
- Carry a lesson to every predicate that asks the same question (`ccl_class_size` and `ccl_empty_layout`). A shape is
  no test: refusing `typedef X X` by its spelling broke `allocator_traits`, where a guard per (class, name) fixed
  both. (0.86, 0.89)
- The passes rebuild the symbol table from the top-level items (`ccl_items_note/1`): what the reader notes only inside
  a body is lost to them unless the bulk noter collects it. (0.43)
- An instrument can break what it measures: markers on `user_error`, which cocolog lacks, failed the write they
  watched. (0.106)
- A string in an `.ll` file carries its length in its type (`[19 x i8]` in `proof/forty2.ll`): edit both. (0.100)
- The session's tools are not in the repository: `probe.sh` (time and memory caps over its own process group),
  `trace.sh` (cocolog with `'$cpp_trace'` on), `fx.sh` (removes the binary, builds, compares as the gate does),
  `guard.sh` and `watch.sh` (a query or a gate under the summing watchdog). A new session writes them again. (0.93)

## What runs

### Hosts

- macOS on x86-64 (Apple's SDK, Homebrew's LLVM, libc++ 21) is the first host. The seven gates last ran there at
  0.90, all GREEN (cocolog 1.2.18). The fixtures added since 0.93 have run on Linux only.
- Ubuntu 24.04 on x86_64 (clang and LLVM 18, glibc, libc++ 18 and 21) is a host since 0.87. Every gate but the C++ one is
  GREEN there since 0.93, and all seven since 0.95. Every step from 0.93 on is gated there, but the save points 0.112,
  0.113, 0.117, 0.122 to 0.125 (gated by the steps after them); the last full run is 0.129's, over cocolog 1.9.1, on one
  tree: over libc++ 18 all seven GREEN (reader 5 s, compile 10 s, driver 7 s, objects 3 s, proof, the library read in 1327 s,
  the C++ gate in 1128 s with 442 of 443 fixtures ok, the skip is `stdoptionalref`, and the 21 refusals); over libc++ 21 the
  library read (1141 s) and the C++ gate (794 s, 442 of 443 ok, the same skip) GREEN -- the C gates do not read libc++. Two libc++ passes are one
  gate: `LLVM=/usr/lib/llvm-18` and `LLVM=/usr/lib/llvm-21` choose the tree the chain reads and links. libc++ 22 (the
  newest tree, which a run without `$LLVM` reads) is untried but for `stdoptionalref`, which passes there. The run before
  0.121's (0.118, 0.119) found, over 0.117, two defects and one stale check of `test/cpp.pl` (c20, above).
- The host sets the predefined macros (`ccl_host_os/1` and `ccl_host_arch/1` in the module), the inclusion path
  (Debian's `/usr/lib/llvm-NN`, the multiarch directory) and the link (`-lc++` and `-lm` on Linux) (0.87, 0.93, 0.100).
- A struct passed or returned by value crosses a call as clang's x86-64 code expects, in both directions, with the
  register budget of SysV 3.2.3 (`test/driver.sh` over `test/c/link/abi_main.c` and `abi_helper.c`) (M3, 0.117).
- `long double` is x87's 80-bit type on x86-64 and a double on arm64 (`ccl_long_double/1`; `test/c/run/ldouble.c`,
  `test/cpp/run/ldouble.cpp`) (0.108).

### C

- C17 is the default level, and `-std=c23` gives C23. C99 and C11 are accepted, and the ISO modes read trigraphs.
  C89 and C90 are refused (`bin/cicilang`, `cstd(N)`) (0.57, 0.108).
- C17 and C23 are whole (0.93). `test/c/run/*.c` gates them, at C17 unless a fixture's `NAME.std` names a level:
  `c17rest.c` and `cforms.c` at C17, `trigraphs.c` at `-std=c17`, `c23.c`, `c23b.c` and `c23pp.c` at C23.
- These forms have fixtures of their own: complex types and every imaginary literal (`complex.c`, `complex2.c`,
  `complex3.c`), `\N{NAME}` with its aliases (`uniname.c`), C11's atomics (`atomic.c`), literals past 2^60 and
  `LONG_MAX` (`bigint.c`, `bighex.c`, `longmax.c`), a VLA of a VLA (`vla_nested.c`), wide strings and `_Alignas`
  (`wstr_alignas.c`), x87 `long double` (`ldouble.c`), variadic definitions (`varargs.c`), hex floats (`hexfloat.c`),
  designated initializers (`designated.c`, over bitfields `bitdesig.c`), a bitfield in a union (`unionbits.c`), line
  splices (`splice.c`), the size of an aligned object (`alignsize.c`). Since 0.117: a VLA initialized by `= {}`
  (`vlaempty.c`, C23), `va_arg` of a struct, a union and a complex (`vaaggregate.c`), `__int128` (`int128.c`) and a
  `_Static_assert` over the `sizeof` of a struct (`sizeofassert.c`) and a conditional of a pointer and the literal zero
  (`condnull.c`).
- The C library is the host's. The compiler's own freestanding headers are in `library/include/` (`<stdarg.h>`,
  `<stdatomic.h>`, `<complex.h>`, `<stdckdint.h>`, `<stdbit.h>`, `<limits.h>` and six more).
- The language's own additions run: `:=`, patterns, `name { }` structs and `format`, `print`, `println`
  (`surface.c`), `defer` (`defers.c`), `#cocolog` (`cocolog.c`), `tie` (`tie.c`), `clone` (`clone.c`), `own` and
  `move` (`owners.c`, `own_fields.c`, `btree.c`, `btree_del.c`).
- The safe part refuses each of the 43 programs in `test/c/safe/` with the error that its `.expect` names.

### C++ levels

- `-std=c++17` is the default and the baseline. `-std=c++20`, `c++23` and `c++26` are the levels, and an older level is
  refused (`std(N)`; owner's rule: libc++ as it is, C++17 the baseline, then the next majors) (0.41, 0.42).
- The reader takes every form that C++20, C++23 and C++26 add (0.93; modules since 0.108). A fixture names its level
  in `NAME.flags`.
- The program's own C++ compiles and runs against clang++'s output, one fixture per form in `test/cpp/run/`. Classes,
  virtual functions and templates: `names`, `loops`, `counter`, `shapes`, `templ`, `bag`, `member`, `btree`; the
  reader's `test/cpp/classes.cpp` exits 34 and `test/cpp/templates.cpp` exits 10 (0.32-0.41).
- Lambdas: `lambdas`, `lambdas2`, `capturethis`, `closurecopy`, `closurescope`, `initcapture`, `lambdafp`,
  `lambdamutable` (`mutable`; `test/cpp/lambda_const.cpp` is the refusal) and `lambdanest` (a lambda in a lambda, a
  default capture and `[this]` through the outer closure) (0.117). Constant evaluation: `constexprfn` to
  `constexprfn6`, `consteval`, `ifconsteval` (0.36-0.108).
- Access control and the forms of 0.117: `accessctl` and `accessctl2` (the allowed forms: a member function and a
  friend class, function, function template and operator, a protected member in a derived class, `using` to open a
  base's member, a nested class, a private virtual called through the public function, lambdas in a member function;
  the five `test/cpp/access_*.cpp` are the refusals), `deducethis` (C++23: `this` deduced on a class's methods, CRTP
  without the template), `globalscalar` (a file-scope scalar with a run-time initializer, a static member defined out
  of its class), `localarray2` (an array of arrays of objects, a `static` local array of objects), `placearray`
  (`new (p) T[n]`), `int128` (C++), `rangeforbraced` (C++20: `for (int v : {4, 9, 1, 7})`) (0.117).
- Forms that <complex>, <bitset> and <chrono> asked for (0.117): `userliteral` (the program's own literal operators for
  an integer, a floating, a string and a character literal, overloaded by the literal's kind, in a namespace: `5_km`),
  `friendprefix` (`constexpr friend ...`), `valueparam` (a value template parameter hides a typedef or template of its
  name), `convout` (a conversion function defined out of its class), `convin` (the conversion function whose result is
  the target, a conversion function's name substituted), `returnconv` (a class value returned where a scalar is wanted),
  `shiftwrap` (`intmax_t(1) << 63` folds wrapped), `staticconsttype` (a folded `static const long long` keeps its type),
  `nestedinit` (a nested class member built from a prvalue of its class), `arraybrace` (an array member's braced
  initializer), `specmember` (the members of a partial specialization defined out of its class), `tempinitlist` (a
  braced temporary through the `initializer_list` constructor; a range-for over a class prvalue), `convarith` (a
  built-in operator over a class with a conversion function to an arithmetic type), `baseparam` (a plain struct bound to
  a base-clause parameter; a base named through an alias).
- Forms that <list>, <deque>, <thread> and <atomic> asked for (0.117): `parencast` (`(T())` and `(std::vector<int>(n))`
  are functional casts, `(T)(x)` a cast), `aggmemberinit` (a braced default initializer of a plain struct or union
  member), `membertmpl` (a constructor template and a method template of a plain class, defined out of it), `tmplstatic`
  (a static data member of a class template defined out of its class), `condzero` (a conditional of the literal zero and
  a pointer picks the pointer overload), `underlyingtype` (`std::underlying_type` of enums with and without a written
  base) and `enumsettle` (an enum whose underlying type is a typedef of `underlying_type<...>::type`).
- Forms that <variant> asked for (0.121): `localclass` (named and unnamed local classes with member functions,
  constructors, virtual functions and bases; two functions' `Loc`; a local class as a template argument), `usingbase`
  (`using Base::f;`, a hiding member, the pack form, a virtual name), `overloaded` (C++17's idiom: an aggregate over a
  pack of lambdas through a deduction guide), `memtmplid` (`o.f<T>()`, `p->f<T>()`, a base's template, a static one),
  `narrowing` (a braced list for an array parameter), `fwdmember` (perfect forwarding into members and through
  temporaries; members of xvalues), `unionclass` and `uniondtor` (a union at namespace scope with a constructor, a
  destructor or a method; a union's destructor destroys no member), `varvisit` (the first surface of `std::variant`
  and `std::visit`: a function object, a generic lambda, `std::get`, `index`, `holds_alternative`).
- Forms that libc++ 21 asked for (0.126): `addressfn` (`std::addressof(f)` of a function, `T &` and `const T &` given a
  function, the same through a template's by-value parameter), `commontype` (`std::common_type` of arithmetic types, a
  detection of it), `invokedata` (a pointer to a data member of a PLAIN struct as the callee of `std::invoke`,
  `invoke_result` and `is_invocable`: an object, a `const` object, an rvalue, a pointer), `deduceagree` (a template
  parameter that two function parameters deduce deduces one type: the detection of a call whose second argument names
  another), `bitcount` (`__builtin_clz*`, `ctz*`, `popcount*` in a constexpr function), `enabledecl` (a function template
  declared twice, the default of its SFINAE parameter on the first declaration only: libc++ 21's `complex` operators),
  `strlencast` (a static `constexpr` member built by a constructor that counts through a named pointer cast), `reverseiter`
  (C++20: `std::reverse_iterator` over a string's and a vector's iterator, `ranges::iter_move` of it), `staticfnval` (a
  static member function named bare as a value: a pointer member assigned in a method, a base's initializer with a member
  and a static function of one name, several static functions chosen by the target, a base class's and an enclosing
  class's), `enumscope` (qualified enumerators of enums that share an enumerator's name -- file scope, a namespace, two
  classes' nested enums, an enum nested in a class template -- and a nested enum named bare in a `case` label, declared
  after the member that switches), `unionparen` (C++20: a union member initialized by parentheses from a value of its first
  member's type, a class template's nested union), `reqpack` (C++20: a requires-expression's parameter pack asked inside a
  function that has a variable of that name), `memptrqual` (C++20: `is_base_of<T, T>` of a plain struct, a detection of `*t`,
  `x.*pm` const and xvalue, a dereference of a cast to a pointer reference, a leading-`decltype` overload that dereferences
  its argument), `rawparam` (`std::addressof(ctr_)` in a base's initializer while a block typedef elsewhere is called `_Tp`),
  `crtpclass` (C++20: a CRTP base that requires `is_class_v` of its derived class, and the deduction of
  `derive_from(Closure<T> *)` through a later EMPTY base), `lambdatparam` (C++20: a generic lambda whose template parameters
  are named like a typedef another function declares in a block, called through an alias template of the same names) and
  `formatton` (C++20: `std::format_to_n` and `std::formatted_size` with `<string>` read before `<format>`: one function
  template declared by two summaries is one candidate; libc++ 21 only fails without the rule).
- Forms of 0.127, the "Not done" list of 0.126 taken up: `boolresult` (a comparison, `!`, `&&` and `||` are `bool`; a
  conditional of one arithmetic type keeps it), `enumtype` (an enumerator is of its enum's type), `promotion` (a promotion
  beats a conversion), `byteops` (a scoped enum's operators are the header's), `trailret` (a trailing `decltype` of a
  definition, its SFINAE), `blocktypedef` (a block's typedef is the block's), `lazymember` (a class template's member is
  made where it is used), `accessctl3` (the allowed forms of the access rules of 0.127), `lambdaconst` (what a lambda that
  is not mutable may do), `plainclash` (C++20: a plain struct for a scalar parameter in a detection), `nsenum` (two
  namespaces' enums of one name), `valueinit` (value-initialization zeroes, default-initialization does not), `aggbase`
  (an aggregate's base takes its item) and `shipstatic` (a shipped static member function by its own signature).
- C++20: `cxx20`, `cxx20cmp`, `defaultcmp2`, `concepttraits`, `memberreq`, `ctorreq`, `reqvalue`, `crtpconcept`,
  `deduceguide`, `nounique`, `nounique2`, and the rules `std::format` and the views asked for (`defaultreq`,
  `localconv`, `scopewalk`, `ndpath`, `ctortconv`, `tmpldefaults`, `qualspec`, `prvaluecv`, `autohead`, `automember`,
  `intspell`, `inprogscope`, `arrayref`, `rangesarray`, `charpromote`, `scalarbrace`, `aggdefaults`, `qualmember`,
  `enumbits`, `aggconst`, `memberenum`, `ctadcopy`, `caselabel`, `staticpack`, `staticunused`, `fnptrmember`,
  `ifconstexprcall`, `ctadself`, `moveobj`, `refbyvalue`, `desiganon`, `datasizeof`, `tocharsfmt`, `anonstructunion`,
  `implicitassign`, `constsv`, `localarray`, `lifeext`, `dynvoid`, `enumop`, `constevalm`, `lambdareq`, `globalinit`,
  `looptemp`, `classforms`, `localstatic`, `prvalueinit`, `qualobject`, `basedefault`, `placeplain`, `explicitconv`,
  `memptrdecl`, `oncetarget`, `dtorvt`, `genericfp`, `nestedlambda`, `recself`, `primarybase`, `primarybase2`,
  `viewiter`, `vtobject`, `sentbase`, `friendreq`, `memberunmet`, `constmember`). Traits on the program's classes:
  `abstracttrait`, `enumeq`. C++23: `cxx23`, `cxx23b`. C++26: `cxx26`, `contracts` (contracts enforced at run time)
  (0.42, 0.43, 0.93, 0.108).
- Inheritance and pointers to members: `multibase` to `multibase3`, `virtualbase`, `vbasertti`, `diamond`, `diamond2`,
  `thunkdeep`, `memfnptr`, `memfnadj`, `memptrdata`, and a program class derived from `std::ostream` and from
  `std::iostream` over its own streambuf (`streamderived`, 0.117). RTTI and exceptions: `rtti`, `exceptions`,
  `exceptions2`, `catchvalue`, `noexcept` (0.72-0.110).
- Coroutines: `cogenerator`, `cotask`, `coeager`, `coawait`, `coawaitop`, `cotemplate`, `cotraits`. Modules: `modules`
  (it imports `mathm.cppm`, which imports `basem.cppm`), `headerunit`, `hdrinline`. Also the array cookie
  (`arraycookie`), trailing return types (`trailing`) and CTAD (`stdctad`, `deduceguide`) (0.108, 0.110).
- `test/cpp.sh` checks that twenty-one programs are refused by name (`coro.cpp`, `concept_fail.cpp`,
  `constrained_fail.cpp`, `lambda_const.cpp`, `lambda_method.cpp`, `bind_const.cpp`, the eleven `access_*.cpp`,
  `abstract.cpp`, `modhidden.cpp`, `diamond.cpp`, `basenodefault.cpp`) and that the safe part refuses `escape.cpp`.

### libc++ headers read whole

- `test/libcxx.sh` reads each header in its own process and asserts that it reads whole, to at least a minimum item
  count (`test/readhdr.pl`, libc++ 18's counts) (0.105, 0.109):
  C++17 `<vector>`, `<string>`, `<iostream>`, `<map>`, `<set>`, `<unordered_map>`, `<unordered_set>`, `<optional>`,
  `<memory>`, `<functional>`, `<tuple>`; C++20 `<compare>`, `<vector>`, `<string>`, `<iostream>`, `<set>`, `<map>`,
  `<unordered_map>`, `<unordered_set>`, `<ranges>`; C++23 `<optional>`, `<string>`; C++26 `<optional>`.
- The same pass reads every other header that the fixtures and Cicili's C++ files include, at each fixture's level
  (`ccl_union`: `<algorithm>`, `<array>`, `<atomic>`, `<concepts>`, `<coroutine>`, `<iterator>`, `<iomanip>`,
  `<type_traits>`, `<sstream>` and others). It writes their summaries for the C++ gate and does not assert them whole
  (0.105).

### libc++ modules that compile and run

- Nothing of the standard library is the compiler's own (owner's rule, 0.41). libc++ compiles from its own headers, and
  each fixture `test/cpp/run/NAME.cpp` prints clang++'s output, `NAME.expect`.
- Streams (`<iostream>`, `<istream>`, `<ostream>`, `<iomanip>`): `stdcout`, `stdendl`, `stdcin`, `stdgetline`,
  `stdget`, `stdws`, `stdistream`, `stdistream2`, `stdostream`, `stdmanip`. `cout`, `cin`, `cerr` and `clog` are the
  shipped library's objects. A fixture reads its input from `NAME.stdin` (0.73-0.78). The wide streams `wcout`,
  `wostringstream`, `wistringstream` (`stdwstream`); `seekg`, `tellg`, `seekp`, `tellp` (`stdseek`); `cin >> long
  double` (`stdcinld`) (0.115); the rvalue-stream `getline`, `getline` with a delimiter and `sync_with_stdio(false)`
  (`stdstreammisc`) (0.117).
- `std::stringstream` and `std::wstringstream` (`stdstringstream`: libc++'s basic_iostream is a diamond over basic_ios;
  extraction and insertion through the one object, the `istream &`, `ostream &`, `iostream &` and `ios &` references,
  `getline` with a delimiter, `std::ws`, `tellp`, `rdbuf()` inserted); `std::ofstream`, `std::ifstream` and
  `std::fstream` (`stdfstream`: write, read back by `getline` and `>>`, append, rewrite through an fstream, seek, a file
  that is not there, `open` and `close`); a program class derived from `std::ostream` and from `std::iostream` over its
  own streambuf (`streamderived`) (0.117).
- `std::byte` (`stdbyte`: a vector of bytes, the operators of `<cstddef>`, `to_integer`), `std::span` (`stdspan`, C++20:
  a span over an array, a vector and a `std::array`, subspans, a fixed extent, a `span<int>` passed as a `span<const
  int>`), `std::vector<bool>` (`vectorbool`: the bit-packed specialization and its proxy, `push_back`, `reserve`,
  `resize`, `flip`, `assign`, `insert`, `erase`, the static `swap` of two proxies) and `auto` with several declarators
  (`autodecl`) (0.117).
- `<bit>` (`stdbitcast`, C++20: `std::bit_cast` of a float and an integer, a double, a struct and a `std::array` of
  bytes, `popcount`, `countl_zero`, `countr_zero`, `has_single_bit`, `bit_ceil`, `bit_floor`, `rotl`, `rotr`,
  `bit_width`) (0.117).
- `<bitset>` (`stdbitset`: the one-word specialization and the multi-word primary, set / reset / flip / test, count,
  any / none / all, the operators and the shifts), `<complex>` and `<cmath>` (`stdcomplex`: arithmetic of
  `complex<double>` and `complex<float>`, `abs`, `arg`, `norm`, `conj`, `polar`, the floating functions), and the
  `<string>` and `<string_view>` literals `"x"s` and `"x"sv` (`stdliterals`, C++17) (0.117).
- Strings (`<string>`): `stdstring` (short and long, growth, copy, `==`), `stdstringops` (`+`, `substr`, `find`,
  `insert`, `erase`, `replace`, `compare`, `to_string`), `stdstringfind` (`find_first_of` and kin) (0.63-0.67, 0.84,
  0.100).
- Sequence containers (`<vector>`, `<array>`): `stdvector`, `stdvectorown` (the program's own class), `stdvectorstring`,
  `stdvectorinsert` (`insert`, `erase`, `resize`), `stdvectorstring2` (the same over strings, and `assign`),
  `stdvectorvector` (a vector of vectors, copied and moved), `stdvectorcopy` (a class with a copy constructor and no
  move one), `moveinit`, `stdaggregate`, `stdarray` (0.61-0.70, 0.84, 0.91, 0.100, 0.112).
- `<list>` (`stdlist`: `sort`, `merge`, `splice`, `reverse`, `unique`, `remove`, push and pop at both ends, `insert` and
  `erase` through iterators, `assign(n, v)`, `resize`, `swap`, `==`, a list of strings), `<deque>` (`stddeque`: push and
  pop at both ends, indexing, iteration, `insert`, `erase`, a copy, `resize`, `==`, 3000 pushes through many map
  growths, a deque of strings), `<queue>` and `<stack>` (`stdqueue`: a queue and a stack over a deque, a
  `priority_queue` over a vector with the heap algorithms, and with `greater`), `<numeric>` (`stdnumeric`: `iota`,
  `accumulate`, `partial_sum`, `adjacent_difference`, `inner_product`, `gcd`, `lcm`, `reduce`), and the C library
  through the C++ headers (`stdcstdlib`: `<cstring>`, `<cstdlib>` with `qsort` over a comparison function, `<cctype>`,
  `<cstdint>`) (0.117).
- Associative containers (`<map>`, `<set>`): `stdmap`, `stdmapstring`, `stdmapstring2`, `stdmultimap`, `stdmapinit`,
  `stdmapemplace`, `stdmapown`, `stdset`, `stdset2`, `stdset3`, `stdsetstring`, `stdsetlambda`, `stdnodehandle`, and
  C++20's `contains` and `erase_if` in `stdcontains` (0.79-0.84).
- Unordered containers: `stdunorderedmap`, `stdunorderedmapstring`, `stdunorderedmap2`, `stdunorderedset`,
  `stdunorderedset2`, `stdunorderedhash` (the program's `std::hash`, the bucket interface, `extract`), and C++20's
  `erase_if` in `stderaseif` and `stderaseifuset` (0.81-0.84, 0.99, 0.100).
- Smart pointers (`<memory>`): `stduniqueptr`, `stdsharedptr` (with `weak_ptr`), `stdmemory` (`unique_ptr<T[]>`, a
  custom deleter, an aliasing `shared_ptr`), `stdptrcmp` (the comparisons, `owner_before`), `stdsharedfromthis` (0.86,
  0.99, 0.100). The memory algorithms a program calls itself: `std::allocator` and `allocator_traits` (`stdallocator`),
  `construct_at`, `destroy_at`, `destroy`, `destroy_n` and the `uninitialized_*` family with their `_n` forms, over raw
  storage and over a type that prints its constructors (`stduninit`, C++20) (0.117).
- `<functional>`: `stdfunction`, `stdbind` (`mem_fn`, `invoke`, `ref`), `stdfunctional`, and C++20's `stdinvoke` and
  `stdbindfront` (`bind_front`, `not_fn`). `multibase` and `detectbase` hold its shapes on the program's own classes
  (0.88, 0.99, 0.100). A `std::reference_wrapper` handed to a `T &` parameter, directly, through `std::invoke`, a
  function pointer and a function reference, and a class taken by value through a function pointer (`fnptrargs`); an
  arithmetic value bound to a reference to another arithmetic type (`refwiden`) (0.117).
- `<tuple>`, `<utility>`, `<type_traits>`: `stdtuple` (`get` by index and by type, `tie`, `tuple_cat`, `apply`,
  structured bindings), `stdswap`, `stdtraits`, beside `refrank` (0.45, 0.72, 0.90, 0.91).
- `<optional>`: `stdoptional`, `stdoptionalstring`, `stdoptional2`, `stdhashopt`, C++23's monadic operations in
  `stdoptional3` and `stdoptional4` (`transform` to a string, `and_then` over a conditional), and C++26's `optional<T
  &>` in `stdoptionalref`, which its `NAME.needs` skips below libc++ 22 (0.82, 0.84, 0.95, 0.99, 0.123).
- `<compare>` (C++20): `stdcompare` (`strong_ordering`, `partial_ordering`, a defaulted `<=>`), `stdcompare2`
  (`compare_three_way`, `common_comparison_category`) (0.101, 0.104).
- `<variant>` (C++17): `stdvariant` (construction from a value and in place, assignment between alternatives, copy and
  move of a variant holding a long string, `swap`, `emplace`, the relational operators, `std::visit` with the
  `overloaded` idiom and with two variants, `get_if`, a vector of variants) and `stdvariant2` (`in_place_type`,
  `emplace` by index, `variant_size_v`, `variant_alternative_t`, `std::hash` of a variant, a visit of two variants, a
  class whose copy constructor counts, the alternative the converting constructor chooses: `variant<long, int> v = 5;`
  holds the int); `stdvariantsel` at C++20 (`variant<std::string, bool> v = "text";` holds the string, `std::visit<R>`
  with an explicit result type); `stdvariantcmp` at C++20 (`variant <=> variant`, the relational operators of a variant
  of strings); `stringcmp20` (C++20: `std::string` against `const char *` in both orders, `std::map<std::string, int>`);
  `prvalueinplace` (a `std::function`, a list or a map constructed in place: a local from a prvalue, a returned prvalue
  and a returned local, a call that returns through the hidden pointer, an aggregate member) (0.121).
- `<atomic>`: `stdatomic` (0.100); at C++20 `wait`, `notify_one` and `notify_all` (`stdatomic20`, 0.117).
- `<thread>` and `<mutex>` (`stdthread`: a vector of threads taking a function, `std::ref` and an int, two threads over
  an atomic counter through lambdas, a join, `thread::id` compared; `mutexmember`: `std::lock_guard` and
  `std::unique_lock` of a mutex member declared after the member function that locks it), `<charconv>` (`stdcharconv`:
  `from_chars` of int, long and unsigned in two bases, an invalid string, a value out of range, `to_chars`) (0.117).
- `<algorithm>`: `stdalgorithm`, `stdalgorithm2` to `stdalgorithm9`, `stdalgorithmstr` (0.92, 0.95).
- `<ranges>` (C++20): `stdranges` (`ranges::sort`, `ranges::find`, `ranges::count_if`) (0.109), and `stdviews`:
  `views::filter` called, through the pipe, chained, and its iterators walked (0.112). The views `iota`, `reverse`,
  `transform`, `take_while`, `drop`, `take`, `keys` and the chain `filter | transform | take`, each alone (`viewiota`
  ... `viewchain`) and all in one program (`viewsall`, about 1600 s) (0.115).
- `std::format` (C++20): `stdformat` -- integers in every base, widths, alignment and fill, a double's precision, a
  char, a bool, a `std::string` argument, positional arguments, and `format_to` through a back inserter -- beside the
  fixtures of the program's own shapes it asked for (`lambdafp`, `ctortconv`, `qualspec`, `intspell`, `tmpldefaults`,
  `autohead`, `constsv`, `implicitassign` and others) (0.112). `std::vformat`, `make_format_args`, `formatted_size`
  and `format_to_n` (`stdvformat`); a formatter the program specializes (`stdformatter`); `std::format(L"...")`
  (`stdwformat`); `std::print` and `std::println` at C++23 (`stdprint`) (0.115).

### Benchmarks

- `bench/btree/run.sh`: the B-tree at `-O3` beats Rust's BTreeSet on insert and search and ties it on deletion
  (owner's goal, 2026-09-05; a million keys, min of 11: 94/90/62/92/66 ms against 107/96/60/95/63). Its node holds a
  bounded own array, its key scan is branchless, and deletion fixes only a node left short.

## Not done

### C

- The lowering refuses by name `va_arg` of a struct, a union, a complex or an `__int128` on AAPCS64
  (`va_arg_of_aggregate`; x86-64 expands them, 0.117): no arm64 host or emulator is on this box.
- A decimal floating value converts to and from a 128-bit integer nowhere (`decimal_conversion`): gcc calls
  `__bid_floattidd` and `__bid_fixddti`, which this box's libgcc does not have, and its own link fails. A decimal global's initializer is a literal, its negation or an integer constant; an
  operation in it is refused, `decimal_constant(E)` (gcc folds it) (0.129).

### C++ language

- The program's own static member functions take an unused null `this` as their first parameter (0.37), in the
  desugaring's calls, in their definitions and in the constant evaluator, and a static's name as a value is a thunk,
  `<Name>.fn`, of the plain function type (0.100). It is an inner convention of the program's own functions; a static that
  the shipped library defines is declared and called by its ABI's signature since 0.127 (`'$cpp_static_abi'`).
- A library lambda's requires-clause is kept and not checked (libc++'s `__synth_three_way`); the program's is (0.112).
- A library class's consteval constructor or member keeps its member initializers and runs at run time, its
  compile-time check dropped, as `basic_format_string`'s (0.110); the program's own fold (0.99, 0.112).
- The tail padding of a non-POD base is not reused (the Itanium ABI lays what follows a base at its data size):
  `struct D : B { int y; }` over `struct B { virtual int f(); int x; }` is 24 bytes here and 16 under clang. The
  layout is self-consistent; a class shared with clang-compiled code differs (0.112).
- The diamond has no construction vtables, so a virtual call in a path's constructor or destructor reaches the
  most-derived override (a single chain's and a virtual base's own reach their class's, `dtorvt.cpp`, 0.112). The
  implicit copy of a diamond class is not memberwise (0.110).
- A LIBRARY diamond is built here (libc++'s `basic_iostream`, 0.117: the path bases' `.nv` twins are compiled), but a
  PROGRAM class over two library classes that share a virtual base (`struct X : std::istream, std::ostream`) is
  refused, and so is a diamond over a virtual base with no table: `virtual_base_by_two_paths`
  (`test/cpp/diamond.cpp`) (0.110, 0.117).
- A namespace-scope `using` declaration does nothing, since namespaces flatten. A using-directive's scope is not
  modelled, so `std::rel_ops` is left out of the index (`ccl_flat_items_`) (0.44, 0.112).
- An unfolded call or class static as a template VALUE argument keys its instance by its spelling (`targ_raw`). A
  static that it feeds may be emitted `extern` and fail at the link, not be refused by name (0.97, 0.98).
- The coroutine ramp's return object stays out of the frame only by LLVM's choice. No rule here guarantees it (0.108).

### libc++ modules

- Range views: `filter`, `transform`, `reverse`, `iota`, `take`, `drop`, `take_while`, `keys`, `values` and their chain
  run, alone and in one program (0.115). Every other view and adaptor is untried.
- `std::format` runs (`stdformat.cpp`, 0.112), its compile-time format-string check dropped (0.110): a bad format
  string is caught at run time by the library's own parser. `vformat`, a formatter the program specializes, the wide
  format and `std::print` run (0.115). Untried: chrono and range formatting.
- `optional<T &>` needs libc++ 22 (`stdoptionalref.needs`; 21.1.8 has none). `bad_optional_access` cannot be caught: libc++ keeps its
  no-exceptions configuration and aborts with the message (0.82).
- libc++ keeps its no-RTTI configuration by design, so `shared_ptr::get_deleter`, `dynamic_pointer_cast`,
  `std::function::target` and `target_type` are absent (0.86, 0.88). The program's own `typeid` and `dynamic_cast` run
  (0.108).
- `std::atomic<shared_ptr<T>>` (C++20, P0718) is in neither libc++ 18 nor libc++ 21: clang++ refuses
  `std::atomic<std::shared_ptr<int>>` over both trees, so there is nothing of the library to compile (0.86, 0.128).
  `<atomic>`'s `wait`, `notify_one` and `notify_all` run at C++20 (`stdatomic20.cpp`, 0.117). A program's own calls
  of `std::uninitialized_copy`, `std::construct_at`, the `destroy_*` algorithms and `allocator_traits` run
  (`stduninit.cpp`, `stdallocator.cpp`, 0.117).
- The `less<void>` comparator's `operator()` is emitted where a program never calls it (0.79).
- `std::stringstream`, `std::wstringstream`, `std::ofstream`, `std::ifstream` and `std::fstream` run (0.117). Not tried:
  `std::filesystem` (its `path` methods refuse: `_PathCVT::__append_range` meets `typedef(tmpl(basic_string, ...))`),
  and the wide file streams.
- Tried in the library sweep of 0.117 and NOT finished: `<random>` (a `std::mt19937` with `uniform_int_distribution` is
  killed at its 1500 s cap, about 660 MB, and refuses nothing. A trace of two minutes shows the desugaring descending
  `__log2_imp<unsigned long long, 4294967296, N>` from 63, one instance in two seconds, 5.6 MB of the store written for
  each; libc++'s recursion with its two partial specializations, written out in a program of its own, builds in one
  second in all, and in three with `<random>` included: the instances are slow only when they are made from inside the
  instantiation of the engines, and one `__log2` is 32 of them. The cause is not found); `std::valarray`
  (`instantiation_depth(121, '__slice_expr')`: the expression templates nest past the depth cap). `std::variant` with
  `std::visit` runs since 0.121 (below). `std::bit_cast` runs since the builtin is answered (`__builtin_bit_cast`, a
  `memcpy` into a local of the target type; `stdbitcast.cpp`, C++20).
  `<chrono>`: durations and clocks run, but a build takes 8 to 14 minutes, too slow for a fixture. `std::thread` and
  `std::mutex` run (`stdthread.cpp`), and `std::from_chars` and `std::to_chars` of integers (`stdcharconv.cpp`).
- `std::variant` and `std::visit` run (0.121): the converting constructor and assignment, `in_place_index` and
  `in_place_type`, `emplace`, copy, move and swap, the relational operators, `hash`, `get_if`, `variant_size_v`,
  `variant_alternative_t`, and `visit` with a function object, a generic lambda, the `overloaded` idiom, two variants
  and an explicit result type, and at C++20 `variant <=> variant` and the relational operators of a variant of strings
  (`stdvariantcmp.cpp`); a failed access (`std::get` of the wrong alternative) aborts with the library's message, as
  `bad_optional_access` does (the no-exceptions configuration).
- Streams, untried: the money and time facets and the exceptions mask (0.78). `std::quoted` runs (0.113,
  `stdquoted.cpp`), and so do the rvalue-stream `getline`, `getline` with a delimiter and `sync_with_stdio`
  (`stdstreammisc.cpp`, 0.117).
  `cin`'s tie flushes `cout`, but only the printed lines check it (0.75).
- libc++'s ostreambuf `__pad_and_output` overload loses to the generic one, and output still runs through `std::copy`
  (0.73; not checked since).
- `__builtin_reduce_and` and `__builtin_reduce_or` have no answer. They are latent: only libc++'s vector-utils road
  calls them, and the predefined `__OPTIMIZE_SIZE__` keeps that road off (0.92).

### ABI and hosts

- The arm64 (AAPCS64) ABI is written and not proven: no gate has run on arm64 (M3). `ccl_long_double/1` makes
  `long double` a double on any arm64 host, which is Apple's ABI and not Linux aarch64's (0.108).
- The Itanium mangler spells a function type, a pointer to one, an array and a pointer to member as a parameter
  (`cpp_ita_type_`, 0.117; `c37` checks `PFvizE`, `RA4_i`, `PFvvE`). A type that none of its clauses names keeps this
  compiler's own name, and the link names it.
- macOS has not run the gates since 0.90, so every rule made since 0.91 is gated on Linux and libc++ 18 only.

### The safe part

- A library header's functions are not checked (`cpp_library_function/1`, `'$cpp_libfn'`). This is 0.45's decision,
  and it waits for the owner to confirm or reverse it.
- A closure held in a `std::function` is not followed: it is the library's discipline (0.100).
- `this` handed out of a constructor is not followed (0.37).
- A `goto` in a function that has owners is refused, `goto_with_owners`: the flow walk does not follow it (M3).
- A direct `std::allocator::allocate` and `allocator_traits<A>::allocate(a, n)` are accepted: a library member's or
  static function's plain pointer result borrows the object it takes by reference (`ck_borrows_from`, 0.91, 0.117;
  `stdallocator.cpp`).

### Tools and performance

- `bin/cicilang` accepts and ignores `-W`, `-f...` and `-pedantic` (owner's rule: clang's arguments, no new flags).
  `-g` gives line tables only (0.128): no variable, type or lexical scope is described, so a debugger stops at a line
  and steps, and `print x` has nothing to read; a C++ function's subprogram carries this compiler's name
  (`Counter.bump.int`), not the source's qualified name, so `break Counter::bump` finds nothing. `-D` and `-U` define
  and undefine (0.112); a run with either keeps no C store.
- A C++ read never uses the store: `cicilang++` runs `--no-kb` (M5). The C++ cache is the summary and the AST beside it
  (0.35, 0.45).
- A READ SERVED FROM A STORE HOLDS ITS FLOATS WITH 15 DIGITS: cocolog writes a float with `%.15g` (its `lib/term.cicili`, whose
  comment says 15 digits read every double back, which is not so), so a literal that needs 16 or 17 digits comes back another
  double from the C store or from a C++ summary -- a silent wrong answer -- and the largest double comes back an infinity, on
  which the lowering's normalization recurses without end (`hexfloat.c` built a second time over one store: 7.3 GB). Found by
  0.129's re-gate; a request to cocolog's owner, and a workaround here, are the next step's.
- cocolog has no `oom` check in its step loop (1.8.41), so a refused allocation gives a wrong answer. Its heap
  collector (1.8.36) does not run inside a nested engine (`findall/3`, `forall/2`). These are requests to cocolog's
  owner, never changes here (owner's rule) (0.46, 0.112).
- One cocolog process's store write grows quadratically past about 30,000 rows, undiagnosed. For this reason no C++
  header goes into the store (M5; measured at cocolog 1.2.16).
- The check's cost is its expression walk. The next cut needs the state as a per-function table, or the lookups in C
  (2026-09-06).
- A C++ build's time was its first deductions and its instantiations (0.98), and, found at 0.120, the COPIES of the
  desugaring's own tables and class records (the Time and memory topic): the slowest fixture, `viewsall.cpp`, took 1760 s
  of the C++ gate's 2400 s cap in the gate's pool at 0.115 and 1357 s at 0.118, and takes 211 s now; the sum of the 388
  fixtures' builds went from 11,775 s to 2,936 s, the gate from 2989 s to 908 s over four lanes, its pool's peak from 9034
  MB to 1675 MB (0.120). What is left is mostly the reader's own cold flattening of a header (`stdatomic20.cpp`, 277 s,
  gained nothing).
