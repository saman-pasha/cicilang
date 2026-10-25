# cicilang -- how this repository is worked on

cicilang is a **Safe Modern C compiler to LLVM, written on cocolog**: a new implementation of Cicili's philosophy. It
reads C and C++, checks them and lowers them to LLVM IR; no C is ever emitted.

This file states how the work is done: the owner's rules, the versions, the build and the proof, and where things are.
`RULES.md` states the rules of the code as they hold now, by topic -- the gates, each pass, what runs and what is not
done. One bullet is one rule: what the code does, the predicates that do it, the standard's clause where one applies,
the fixture that gates it, and why. The bullet ends with the version that made the rule or last changed it.
`HISTORY.md` keeps the record of every step: what it did, what it found, its measurements and its gate numbers.
`README.md` tells a user what runs; `DESIGN.md` gives the architecture and the milestones. A step that changes a rule
edits the rule in `RULES.md`, in its topic, and writes its entry in `HISTORY.md`. Read the topic of `RULES.md` that
covers the code before the code is changed.

At 0.204 the versions are: the module 0.204 (`ccl_p_version` in `module/cicilang.cicili`, `bin/cicilang --version`),
the reader 154 (`ccl_reader_version/1`, `library/ccl_syntax.pl`) and the lowering 116 (`ccl_lowering_version/1`,
`library/ccl_ir.pl`).

Build and prove, always in this order (or all of it, `sh test/gates.sh`):

```sh
CICILI=~/Projects/GitHub/cicili COCOLOG=~/Projects/GitHub/cocolog sh module/build.sh
sh test/flow.sh
sh test/reader.sh
sh test/compile.sh
sh test/driver.sh
sh test/objects.sh
sh proof/run.sh
sh test/cross.sh
sh test/libcxx.sh
sh test/cpp.sh
```

## Contents

- The owner's rules and how the work is done
- Where things are

In `RULES.md`:

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
- Exceptions, RTTI, coroutines, modules, contracts and source locations
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

- Each addition to the language is an owner's rule, described in `RULES.md`'s topic of the language's own forms: `name
  := expr;` and a pattern on its left, `name { members }` at file scope, `defer(a, b) { ... }`, a `.pl` file included as
  a macro file, and `#cocolog ... #end`. (from the start)
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
  without a word. At 0.144, 124 predicates broke it, each a `discontiguous` line of `test/flow.expect`; 0.160 brought
  each one's clauses together at the place of its first, in their order, the comments directly above a clause with it (a
  mechanical move over the files' top-level terms: the same IR, byte for byte, for 82 C and 32 C++ fixtures), and none
  breaks it now: a NEW split is RED (`RULES.md`'s flow gate). A second DEFINITION of a name hides among such splits,
  joined to the first: `cpp_derives/2` until 0.112, and `cpp_thunk_params/4` and `cpp_param_types/2` until 0.141 -- the
  secondary-table thunks and the instance thunks each wrote their own `cpp_thunk_params/4`, the first answered every
  call, and each pair gave a second answer on backtracking, up to 2^n of them; each is written once now, the thunks'
  parameters named as the first one named them. The chart names such a pair `defined_twice` (a later place of the
  clauses repeats an earlier clause, or an earlier fact covers it) and every other split `discontiguous`. (0.103, 0.140,
  0.141, 0.144, 0.160)
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
- Every edit to the library is followed by `sh test/flow.sh`, a minute, before anything longer runs: a call to a name
  that a rename left behind, a helper given a name already taken, a clause that a cut above it makes dead -- each
  named at its line, where the chain met it an hour later or never. A fixture that fails is asked `sh test/why.sh
  FILE` before any trace is written: it names the call that gave up. (0.144)
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
- `HISTORY.md` keeps each step's entry: what it did and found, its measurements, its gate numbers. `RULES.md` keeps only
  the rules that are true now, by topic, and `CLAUDE.md` the owner's rules, how the work is done and where things are; a
  step that changes a rule edits that rule in place. The two were one file until 0.204, a megabyte that every session
  read whole. (0.112, 0.204)

### Caps and guarded runs

- Every cocolog run has a memory cap AND a time cap, a small fixture included (owner's rule, "the one rule this
  repository does not bend"). The owner set 2800 MB for one run on the 16 GB Mac; the gates' pool sums all runs
  against 9000 MB and 14000 MB. (0.46, 0.71, 0.92, 0.105)
- A cap kills the whole process tree. cocolog is the command's grandchild, so a kill of the shell alone leaves it
  running. `timeout -s KILL` signals the process group it leads; `test/cpp.sh` uses `ccl_kill_tree`. A C++ build's
  processes for its cold headers (0.188, `RULES.md`'s driver topic) run in sessions of their own (cocolog's
  `proc_spawn/2`), out of the build's process group: a cap finds the tree by parent id and sums it (`ccl_kill_tree`,
  `ccl_xkill`, `ccl_cocolog_rss`), and each such process holds its own CPU time with `ulimit -t 1800`. (0.46, 0.93,
  0.188)
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
- Never commit build output or scratch: `library/*.so`, `module/*.c` (but `module/bidrt.c`, a source: `.gitignore` excepts it, 0.138), `module/*.o`, `module/sdk.cicili`,
  `module/ccl_uninames.h`, `proof/forty2`, `proof/*.o`, `KB/`, `*.log` (`.gitignore`). (from the start, 0.103)

## Where things are

```
CLAUDE.md                   this file: the owner's rules, how the work is done, where things are
RULES.md                    the rules of the code as they stand, by topic
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
module/bidrt.c              a decimal floating value to and from a 128-bit integer, in C (0.137)
module/gen-bidrt.sh, gen-bidrt.pl
                            compile bidrt.c with cicilang and write library/ccl_bidrt.pl
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
library/ccl_bidrt.pl        the decimal conversions of a 128-bit integer as IR text, generated from module/bidrt.c
library/ccl_uninames.pl     the \N{NAME} table, generated: Unicode 15.0.0's names and aliases, loaded on the first \N{
library/cicilang.so, ccl_llvm.so
                            built by the two module scripts, never committed
library/include/            the compiler's own freestanding headers: each COCOLOG_LIBRARY directory's include/, after
                            libc++'s in C++, ahead of the C library's; guards _CICILANG_<NAME>_H, stdatomic.h's
                            __CCL_STDATOMIC_H
  complex.h                   the C library's, then I, CMPLX, CMPLXF, CMPLXL over __builtin_complex
  float.h                     the floating limits from the predefined macros; FLT_ROUNDS the current direction; C23's
                              signaling NaNs, normalized maxima and IEC 60559 marks
  iso646.h, stdalign.h, stdbool.h, stdnoreturn.h
                              the small C headers
  limits.h                    the limits from the predefined macros, then the C library's through #include_next
  stdarg.h                    va_list and va_* over __builtin_va_*; answers glibc's __need___va_list
  stdatomic.h                 C11 7.17 over the __c11_atomic_* builtins: atomic_* types, memory_order, atomic_flag
  stdbit.h                    C23's bit utilities over the bit builtins, the generic forms by _Generic
  stdckdint.h                 C23's ckd_add, ckd_sub, ckd_mul over the overflow builtins
  stddef.h                    size_t, ptrdiff_t, NULL, offsetof; nullptr_t and unreachable() at C23 only
  tgmath.h                    C17 7.25's type-generic macros over <math.h> and <complex.h>, by _Generic (0.194)

test/config.sh              sourced by every gate: the neighbours, this library first on COCOLOG_LIBRARY, the store
test/gates.sh               every gate in one chain
test/parlib.sh              the memory-gated pool: ccl_pool, ccl_cocolog_rss, ccl_lpt_order, ccl_time_record
test/flow.pl, flow.sh       the flow gate: every library file charted by cocolog's library(flow/chart), nothing run
test/flow.expect            the findings the flow gate holds the library to, a key a line
test/why.pl, why.sh         where a build gave up: the build run under library(flow/debug), the failed call named
test/prof.pl, prof.sh       where a build's steps and time go: windows along its run, by library(flow/debug)
test/reader.pl, reader.sh   the reader's gate
test/compile.pl, compile.sh the compiler's gate
test/driver.sh              the command's gate
test/objects.sh             the objects layer's gate
test/cross.sh               another machine's gate: every C run fixture and the ABI on aarch64 Linux, under qemu
test/cpp.pl, cpp.sh         the C++ gate
test/libcxx.sh              the library read: the asserted headers read whole, and the C++ cache's warm
test/readhdr.pl             one asserted header read whole at a level, in its own process
test/libcxx.pl              the library read's old one-process form; no gate runs it
test/warm.sh                a shim that runs test/libcxx.sh
test/census.pl, census.sh   where the reader stops in a header or in a flattened file, and what it read
test/c/                     the reader's fixtures: hello.c, rich.c, lexer.c, macros.c with macros.pl, pp.c ...
test/c/inc/                 the -I fixture: uses_box.c over box.h
test/c/link/                two files linked into one program; the ABI against clang-built code (abi_main.c,
                            abi_helper.c), variadic calls (va_main.c, va_func.c, va.h), the decimal ABI against gcc
test/c/run/                 C programs built and run: NAME.c, NAME.expect, NAME.std; pp_defs.h, fileconst.h, embed.txt,
                            empty.txt
test/c/safe/                C programs the safe part refuses: NAME.c, NAME.expect
test/cpp/                   the C++ reader's fixtures and the refusals; hidem.cppm for modhidden.cpp
test/cpp/link/              the C++ ABI checks of the C++ gate and the cross gate: abi_helper.cpp and memptr_helper.cpp
                            built by clang++, abi_main.cpp and memptr_main.cpp by cicilang++, abi.h, memptr.h; the C++
                            gate's two units, units_a.cpp and units_b.cpp over units.h, both by cicilang++, units.expect
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
  `fixture-times`, `header-times` and `flow-times` keep the pools' timings, outside the `cpp/` that the library read
  wipes. (0.105, 0.144)
- The neighbours' checkouts are `$CICILI` and `$COCOLOG`, by default `~/Projects/GitHub/<name>`. Nothing names
  ZiguratIP's checkout: it is reached only as cocolog's store. (from the start)
- The guard, watchdog, probe and trace scripts that `HISTORY.md` names (`scratchpad/guard.sh`, `watch.sh`, `gate.sh`,
  `probe.sh`, `trace.sh`, `fx.sh`, `ipfull.sh`) were session scratch and are not in the repository. (0.105)
