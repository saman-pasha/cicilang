# cicilang -- the record of the steps

This is the chronological record of how cicilang was built, one entry per step, as `CLAUDE.md` carried it up to
0.111: the rules each step added, the defects it found, its measurements and its gate numbers, kept VERBATIM.
`CLAUDE.md` states the rules as they hold now, by topic; this file is the history behind them. A statement here can
be superseded by a later step -- the later entry says so, and `CLAUDE.md` has the current rule. The version of an
entry is the module's (`bin/cicilang --version`); the entries are in version order (0.94's, which sat after
`CLAUDE.md`'s commit rules, is in its place). The whole `CLAUDE.md` as it stood at 0.111, with its reference sections
on the preprocessor, the lowering, the check and the findings, is `git show 5ddd0b0:CLAUDE.md`. From 0.112 on, each
step writes its entry here and its rules into `CLAUDE.md`'s topics.

## Index

One row per step, in version order: the step's title, what it did and its gate numbers or key measurement.
`grep -n '^## 0.79 ' HISTORY.md` finds a step's entry.

| Version | Title | What the step did | Gates and measurements |
|---|---|---|---|
| M2b | unions, bitfields, static locals | shape from the C layout | -- |
| M3 | structs by value; owners in structs | `ir_abi/2`; path keys | x86-64 both ways |
| M4 | IR in the store | `dr_ir/3`, folded signature | -- |
| M5 (before 0.32) | the C++ reader, `cicilang++` | C++ mode behind `ccl_cpp`, qualified names and template-ids, C++ library headers flattened once and summarized to `~/.cicilang/cpp`, linked by c++ | test/cpp.pl; hello.cpp served from the summaries |
| -- (2026-09-06) | one expression rule (owner's rule) | the binary levels as one precedence-climbing rule, one-look unary/primary/postfix | 30 -> 8 token matches a token; 2000 tokens 0.3 -> 0.1 s |
| 2026-09-05 | B-tree benchmark | gep inbounds, nsw, bounded own array | 94/90/62/92/66 vs 107/96/60/95/63 ms |
| 2026-09-06 | LLVM type with the value | `ir_expr/4` and kin | lowering 0.21 -> 0.19 s |
| reader 28 | user's file preprocessed | `ccl_pp_top/3`; macros by name | B-tree read 0.47 s (C++), 0.46 s (C) |
| 0.14 | warnings become errors | `untied`, `unconsumed` (owner) | -- |
| 0.32 | C++ as C | Namespaces flatten; bool, refs, new/delete, array range-for. | names, loops |
| 0.33 | Classes | Structs + functions over `this`; ctors, dtor defers, operators. | counter |
| 0.34 | virtual | Slots, `$vptr`, tables, dispatch. | shapes; classes 34 |
| 0.35 | Templates | Instantiated on use, deduced, named `N.key`. | templ; templates 10 |
| 0.36 | Lambdas | Closure class `lambda.K`. | lambdas |
| 0.37 | B-tree | `fresh`/`dying` marks for the check. | btree |
| 0.38-0.41 | Own containers | Library rule, own headers, overloads, move. | bag; reader 31 |
| 0.40 | owners passed by value | to the callee's copy | `safe/by_value_move.c` |
| 0.41 | Class members | Member ctors/dtors, aggregates. | member |
| 0.42 | C++20 | Levels, concepts, `<=>`, suffixes. | c22-c28; 202002; reader 32-33 |
| 0.43 | C++23 | if consteval, explicit `this`, `a[i,j]`. | c29-c33; 202302; reader 34 |
| 0.43, 0.93 | pp forms | `#elifdef`; `__VA_OPT__`, `#embed` | -- |
| 0.44 | road to libc++ | libc++'s forms; header facts; lazy classes; budget | `<vector>`/`<string>` 441/434 items; vector 26 loads |
| 0.45 | `std::swap` | ttp; C++ template choice; traits; AST beside the summary; library unchecked | reader 35; 0.8 s vs 8 s; vector 43 |
| 0.46 | allocator, memory | `\+ \+`; two-pass detection; typedef in its definer; refusals | 3.1 GB→564 MB, 1033→440 MB; vector 67 |
| 0.47 | `__to_address` | scope restored on a throw; unary operators; scope walk; member aliases; ellipsis last | vector 156 |
| 0.48 | nested classes | `Enclosing.Nested`; pattern qualifiers; variable-template arguments; `op.call` | vector 177 |
| 0.49 | badly keyed instance | no read-time `auto` from a dependent type; `cpp_where/2` | reader 36; vector 182 |
| 0.50 | exceptions off | libc++ without exceptions; prvalue temporaries; builtins; bool keys | reader 37, lowering 9 |
| 0.51 | detection trait | `declval`; member-call refusal; member signature in its class | allocate and max_size compile |
| 0.52 | lazy instances | `cpp_lazy_instance/2`; inherited enclosing types | 177→83 instances; C++ gate 855→615 MB |
| 0.53 | anon struct, C++ shape | flatten `class(struct, anon, ...)`; phases name themselves | anoninit.cpp |
| 0.54 | prototypes, empty class | bodyless items lower to nothing; empty class is `i8`; items named in errors | vector<int> stops in `__destroy_vector` |
| 0.55 | out-of-class members | `\+ ccl_in_block`, `cpp_temp_call`, `enum_base`, float clamp, `'$cpp_mdef'`, result SFINAE (reader 38, 39) | first object (9816 B); C++ 773 MB, libc++ 1596 MB |
| 0.56 | free overloads | `'$cpp_fn'` pre-pass, `F.<keys>`, exact beats template | freeoverloads, aliastype; 7 GREEN |
| 0.57 | C23, C's own level | `'$ccl_c_std'`; C23 macros first; C23 keywords read at the level; constexpr constants; static_assert checked in C; `typeof` resolved; `0b` and digit separators in both lexers | reader version 40; c23.c, k87, k88; seven gates GREEN |
| 0.58 | six defects to the lambda | alias -> instance, lazy header fns, takes, incomplete instance, nested ask, statics (lowering 12) | 7 GREEN |
| 0.59 | lambda capturing `this` | `'$this'` member, default capture (lowering 13) | capturethis.cpp |
| 0.60 | vector<int> compiled | eleven forms (reader 41) | 34 KB object, 4 undefined; libcxxforms; 7 GREEN |
| 0.61 | Itanium names, vector<int> runs | mangled declarations, bound refs, placement new, reference casts (reader 42, lowering 15) | stdvector.cpp; C++ 1037 MB warm, 2803 cold |
| 0.62 | vector of own class | temporaries' lifetime, elision, alias category, stmt_expr place (lowering 16) | stdvectorown.cpp; 7 GREEN |
| 0.63 | std::string compiled | thirteen rules (lowering 17) | stdstring 557 MB; C++ 1581 MB |
| 0.64 | memory: a loop | self-typedef guard, `'$cpp_iname'` (lowering 18) | `s += "def"` 2936 -> 495 MB; C++ 1581 -> 752 MB; libc++ 1882 |
| 0.65 | params in class words | scoring in the callee's class | classwords.cpp; C++ 752 -> 861 MB |
| 0.66 | callable member; string grows | six rules (lowering 20) | callable.cpp; C++ 846 MB |
| 0.67 | library operator template | `op.eq.2`, free-function road (reader 43, lowering 21) | C++ cold 2803 killed, 1057 warm; libc++ 2445 MB |
| 0.68 | instantiation in `\+ \+` | `cpp_arg_type`, no-clash resort, emission refusal (lowering 22) | vector<string> 2824 -> 1091 MB, 108 -> 9 s; libc++ 1902 |
| 0.69 | noted when emitted | `'$cpp_making'`, move forms first (lowering 23) | vector<string> desugared+checked, 10 s, 713 MB |
| 0.70 | vector of strings | no-clash via `cpp_param_ref`; converting ctors for temporaries (lowering 24) | stdvectorstring.cpp 825 MB; C++ 805 MB |
| 0.71 | the road to `<iostream>` | 11 reader gaps; the AST writer chunked and traced; `cout` the shipped global; nested enums; empty extra bases; null pure slots | reader 47; `<iostream>` whole (662); `cout << "hello"` 236 loads, 9 s/816 MB, stops at pair; 7 GREEN (C++ 2245, libc++ 1743 MB) |
| 0.72 | the constexpr function | one-`return` constexpr calls fold; 24 forms to the link: two dtor slots, virtual-base layout, own-table dispatch, base offsets, pointer fit | lowering 27; five symbols short at the link, 11 s/~1000 MB; 7 GREEN (C++ 1140, libc++ 1811 MB) |
| 0.73 | the mangler's second half; `cout` runs | substitutions, nested names, instances; `cpp_mangle/4`; nested out-of-class members; inline variables; nontrivial classes by invisible reference | lowering 28; stdcout 19 s/~950 MB; 7 GREEN (C++ 2125, libc++ 1833 MB) |
| 0.74 | `std::endl` | a function template's name deduced from the target; function pointers fit their own type; function types keyed by types | stdendl 18 s/917 MB; C++ gate 1694 MB |
| 0.75 | `std::cin` | extern templates shipped; operators mangled; statics through objects; `m()`; bitfield widths; `NAME.stdin` | reader 52; stdcin 34 s/895 MB; 7 GREEN (C++ 1407 MB, 103 checks) |
| 0.76 | `std::getline` | `auto &`/`auto *`; a held candidate's refusal is the call's; memchr; member-template and member defaults; closures enclosed | 43 s/1354 MB; C++ gate 1173 MB, 104 checks |
| 0.77 | `cin.get()` and kin | no new rule | 15 s/871 MB; C++ gate 2143 MB, 105 checks |
| 0.78 | the standard streams' surface | owner's rule (module at once); hidden friends, free operator sets, header names join, forwarding references, conversion operators, `char` literals | lowering 29; 5 fixtures; 7 GREEN (C++ 2519 MB, 110 checks, 457 s; libc++ 1747 MB) |
| 0.79 | `std::map` whole | int and string maps, multimap; ~36 rules (deferred bindings, begin/end range-for, inheriting ctors, const methods apart) | 1.2.12: C++ 114 checks, 602 s, 2407 MB; 1.2.13: C++ 673 s, 1398 MB, reader 85 MB |
| 0.80 | `std::set` whole, memory | four set fixtures; built initializer lists, memberwise `= default`, emission inside `\+ \+` | C++ 118 checks, 798 s, 1220 MB; check heap 1.85 GB -> 186 MB |
| 0.81 | unordered containers | five fixtures; first-return locals, libm builtins, member templates ahead, member constness | C++ 123 checks, 1111 s, 1258 MB |
| 0.82 | `std::optional` whole | three fixtures; implicit copy on demand, inherited ctor templates, ref-qualified members | C++ 126 checks, 1127 s, 1013 MB |
| 0.83 | node handles | `stdnodehandle`, `stdmapinit`; move kept on classes, the converting constraint, copy pass on temporaries | C++ 128 checks, 1237 s, 1090 MB (fourth run) |
| 0.84 | not-done lists, levels whole | ten fixtures; promoted structs, aggregates, implicit assignment, C++20 reader, CTAD | 1.2.14: C++ 138 checks, 2157 s, 1350 MB; libc++ 15 reads, 909 s |
| 0.85 | a gate that dies says so | A gate prints its query's exit status and raw tail when no GREEN or RED line comes back; cocolog's refused allocation is a wrong answer (a finding, no step entry) | -- |
| 0.86 | `<memory>` whole, no RTTI | three fixtures; pointer-to-member node, free names, self-typedef guard, atomics | 1.2.15: C++ 141 checks, 1885 s, 1480 MB; libc++ 16 reads, 829 s |
| 0.87 | the result type of an uninstantiated template; first Linux port | `cpp_raw_type` widened; breadcrumb stack; LLVM-C name, multiarch, nullability with arguments; reader 68 | 7 GREEN (cocolog 1.2.16): reader 94/39 s/388 MB; C++ 141 checks 1995 s/1441 MB; libc++ 16 reads 859 s/2278 MB. Linux C++ gate reached 83 checks, 6 failing |
| 0.88 | `<functional>` whole | memptr noexcept, braced assign, `.*`/`->*`, namespace keys, function-type patterns, slots by arity, bases with storage, global const folding; reader 69, lowering 33 | 7 GREEN: C++ 146 checks at 1623 MB (16655 s, asleep); libc++ 17 reads 945 s/2306 MB; `<functional>` 472 items (libc++ 21) |
| 0.89 | layout rules | empty class 1 byte, empty base no sub-object, `alignas`, `[[no_unique_address]]`, no-storage moves, struct-as-base promoted; reader 71, lowering 34 | 7 GREEN warm: reader 6 s/99 MB; C++ 149 checks 6147 s/1739 MB; libc++ 17 reads 993 s/2035 MB |
| 0.90 | `<tuple>`, conversion via `operator T()` | cast-to-reference offset, tuple protocol, `cpp_type_called`, array-bound deduction, static arrays, fold anywhere, `std::ignore`; reader 72, lowering 35 | 7 GREEN at 1.2.16: C++ 154 checks 6850 s/1760 MB; libc++ 18 reads 1096 s (`<tuple>` 182 items). At 1.2.18: C++ 6460 s, libc++ 1242 s |
| 0.91 | `tuple_cat`, `<array>`, `<algorithm>` read | rvalue prefers `T &&` (template road), dependent packs, no reader `auto` over a function-template call, library borrows, brace elision, three reader forms; reader 73-74, lowering 36 | no gates (owner); 16 fixtures pass one at a time; `<algorithm>` 375 -> 522 items |
| 0.92 | `<algorithm>`, fifteen rules | member fn templates ahead, explicit targs, shipped instance symbols, spec defaults, `__OPTIMIZE_SIZE__`, generic lambdas, wide chars, null constants, conditional lvalue, struct operators; reader 76, lowering 38 | no gates; stdalgorithm 39 s/350 MB, stdalgorithm6 431 s/1245 MB, stdalgorithm3 ~1670 s |
| 0.93 | C17/C23 whole, C++20/23/26 to their ends, the Linux port | Closed the levels' forms, made the predefined macros the host's, found Debian's libc++, added 55 rules for libc++ 18 (std::function, containers, tuple_cat) | Linux, reader 80, lowering 40: reader 95, compile 76, driver 25, objects 29, proof GREEN; libc++ gate GREEN (18 reads, 5513 s); C++ gate RED 152 ok / 31 failed in 21064 s |
| 0.94 | 64-bit constants; streams and containers on libc++ 18 | `big(Atom)` literals, a 64-bit limb evaluator and 12 overload/mangling/lowering/check rules | reader 95 9 s; compile 78 7 s; driver 25; objects 29; proof; C++ RED 180 ok/7 fail 22047 s, 5881 MB; libc++ GREEN 5489 s, 3218 MB; reader 81, lowering 41 |
| 0.95 | the two-range algorithm cost; qualified type keys | ordering asked `once`, cv keys, constexpr result fold, args bound as is, constexpr globals, void cond, `.needs`, stdalgorithm8 | C++ GREEN 189 + 1 skip 6775 s, 3750 MB; libc++ GREEN 5156 s; reader 82, lowering 42 |
| 0.96 | empty member's address; constexpr statements; the warm | ABI placement of empty no_unique_address members; statement evaluator, 200000 steps; warm.sh 40 headers | C++ GREEN 191 6488 s, 3771 MB; libc++ GREEN 5390 s; lowering 43 |
| 0.97 | constexpr aggregates; the cost of `std::get` | aggregates, switch, range-for, global aggregates, one budget; candidate-set and holding-set memos | stdtuple 235 -> 134 s; C++ GREEN 192 6108 s; libc++ GREEN 5533 s |
| 0.98 | constexpr pointers, aggregate results, `this` | reduction, read-only pointers, aggregate answers, const members; local value args refused; counter defaults to 0 | C++ GREEN 194 6179 s, 3766 MB; libc++ GREEN 5518 s |
| 0.99 | The not-done lists closed | Evaluator cells and constructors, C11 atomics, and 34 older items | reader 95, compile 84, driver 25, objects 29, proof; C++ 211 ok, 4499 s, 3779 MB; libc++ 21 reads, 8422 s (C++20 vector 898, string 846, iostream 884) |
| 0.100 | The repository is cicilang | The rename, then fourteen not-done items | reader 95, compile 85, driver 25, objects 29, proof; C++ 225 ok, 5284 s, 3791 MB; libc++ 21 reads, 8524 s |
| 0.101 | `<compare>`, imaginaries, Annex G, closures | Closed 0.100's list: libc++ orderings, imaginary literals, `__muldc3`, `__real__` places, float builtins, copied captures, base renames | reader 95 in 15 s; compile 86 in 21 s; C++ 228 ok in 5935 s, 3804 MB; libc++ 22 reads in 8957 s |
| 0.102 | numbers | Recorded 0.101's libc++ numbers | — |
| 0.103 | `_Complex int`, NaN, `\N{NAME}` | Integer complex; NaN members unordered; `\N` in both lexers; `sizeof` of a literal | reader 95 in 15 s at reader 88; compile 87 in 9 s |
| 0.104 | suffixes, aliases, categories | `imagi(Specs, N)`; Unicode 15 via Perl; four rules behind `__get_comp_type` | reader 13 s; compile 88 in 20 s; serial chain stopped by the owner |
| 0.105 | gates in parallel | Memory-gated LPT pool; library read is the warm; fixtures four at a time; `gates.sh` | 12 fixtures 245 s vs 420 s; library 3277 s vs 19112 s |
| 0.106 | lost ASTs, eaten jobs | Directory made first; AST before summary; validity needs the AST; jobs read `/dev/null` | libcxx 3168 s; C++ RED 3718 s (9 fails, 2 defects); chain 6935 s |
| 0.107 | chain measured | `ccl_needs_met` variables renamed | libcxx 2705 s; C++ GREEN 1395 s, 229 ok; chain 4181 s vs ~25000 s |
| 0.108 | C parts, C++ gaps | trigraphs, x87, varargs, K&R…; cookie, contracts, RTTI, EH, polymorphic bases, modules, coroutines, CTAD | libcxx 2828 s cold; C++ GREEN 1482 s, 246 checks after the refusal list was updated |
| 0.109 | ranges, `<ranges>`, `tie` | Constrained algorithms; nested namespaces; candidate checks in `\+ \+` | libcxx 3387 s (23 headers); C++ 1815 s, 251 checks; stdranges 1169 s, 3.1 GB |
| 0.110 | not-done lists | noexcept, trailing returns, coroutine traits, catch-by-value, vbase, diamond, exports, header units | libcxx 3240 s cold; C++ 2010 s, 271 checks |
| 0.111 | numbers | Recorded 0.110's numbers: all seven GREEN | — |
| 0.112 | views, `std::format`'s road, `CLAUDE.md` by topic | `views::filter` and the pipe; the rules `std::format` asked for, each with its fixture; four suspected defects fixed; `CLAUDE.md` rewritten by topic, this file made | not run (a save point) |
| 0.113 | the views one by one, `std::quoted` | `std::quoted` linked; transform, reverse, iota, take, drop, take_while, keys, values and a chain each run alone; eight rules with their fixtures; all views in one program still stop | not run (a save point) |
| 0.114 | the gates over 0.113, cocolog 1.8.41 | `member.cpp` made valid C++; a member template's instance named from its substituted qualifiers (`.rq<fold>`); cocolog 1.8.41 reviewed | reader 5 s, compile 13 s, driver 6 s; libcxx 1241 s; C++ about 1300 s, 356 checks, 300 of 301 fixtures; all seven GREEN |
| 0.115 | all the views in one program, `std::format` and the streams not tried | Views fixtures; raw strings; reversed `==`; a call statement on a temporary; the caller's object set aside in an emission; constructor templates and `is_convertible` by the argument's type; wide literals in constants | reader 11 s, compile 23 s, driver 11 s; libcxx 2211 s cold; C++ 3283 s, 384 checks, 328 of 329 fixtures; all seven GREEN |
| 0.116 | the rename | `cocolang` is `cicilang`: files, library, doors, variables, cache, answer lines, header guards | reader 95, compile 101 in 13 s, driver 26, objects 29; libcxx 1558 s cold; C++ 2542 s, 384 checks ok and one skip; all seven GREEN |
| 0.117 | the "not done" list, worked; a library sweep | Mangler, placement `new[]`, arrays of arrays, VLA `{}`, `va_arg` of a struct, the SysV register budget, `__int128`; access control, `mutable`, deducing `this`; the streams over files and strings; user-defined literals; `<complex>`, `<bitset>`, `std::span`, `std::list`, `std::deque`, `<thread>`, `<charconv>`, `<atomic>` at C++20, `<bit>`; the defects those programs found (the reference binding, the conversion functions that yield a reference, the calls through a pointer or a reference to function, the SFINAE of a scalar typedef and of the parameters a call leaves out) | not run (a save point) |
| 0.118 | the gates over 0.117, two defects found | The C++ gate refused `sentinelpair.cpp` (`friend class S<!C>;` of a member class template) and `rangesarray.cpp` ran away at 8.7 GB (the alias clause of `cpp_type` followed a typedef naming a template parameter); both fixed, each fixture seen to pass | reader 5 s, compile 8 s, driver 7 s, objects 3 s, proof, libcxx 958 s: GREEN over 0.117; the C++ gate was running over the corrected tree (a save point) |
| 0.119 | the C++ gate over 0.118 | One stale check of `test/cpp.pl` (c20: `throw Err{t}` is a `braced_temp` since 0.117) edited; the library is 0.118's | C++ gate over 0.118's tree: 388 of 389 fixtures ok (the skip is `stdoptionalref`), 2989 s over four lanes, peak 9034 MB, RED by the one stale check; `test/cpp.pl` alone GREEN, 48 ok in 15 s |
| 0.120 | the desugaring four times faster | The class record split in two (a light one for the lookups that do not want the members), seven registries made facts, the file scope, the typedefs and the tags in 128 buckets each; found by a flat profile | reader 5 s, compile 9 s, driver 7 s, objects 2 s; libcxx 1001 s; C++ 908 s (2989 s at 0.118), 388 of 389 fixtures, the pool's peak 1675 MB (9034 MB); all seven GREEN |
| 0.121 | std::variant and std::visit, and what they needed | Union templates, base packs and using-declared methods, local classes, member templates through pointers, value categories, narrowing, `<=>` rewritten through free operators, objects built in place; twenty defects met in turn | reader 6 s, compile 10 s, driver 7 s, objects 3 s, proof GREEN; libcxx 836 s, C++ gate 938 s (404 fixtures, no FAIL, 1 skip); all seven GREEN |
| 0.122 | the numbers of 0.121 | A save point: 0.121's gate numbers recorded | — |
| 0.123 | a member built in place, libc++ 21 begun | A member from a prvalue of its class constructed in it; the move of a plain struct an xvalue; libc++ 18, 21 and 22 side by side, the link names the tree read | not run (committed while the chain ran) |
| 0.124 | libc++ 21, the first failures | The library read's floors under both trees; a class-scope alias with an attribute noted ahead | not run (committed while the chain ran) |
| 0.125 | libc++ 21, the partial ordering | A parameter that stands twice deduces one type in the partial ordering of function templates | not run (committed while the batch ran) |
| 0.126 | libc++ 21, the failures that were left | Fifteen rules, each with a reduction and a fixture: `common_type`, `addressof` of a function, the bit builtins in the evaluator, the poison pills, a requires-expression's pack, static functions as values, qualified enumerators, the views' CRTP bases, duplicate candidates, a generic lambda's own parameters | 18: reader 5 s, compile 9 s, driver 7 s, objects 2 s, libcxx 771 s, C++ 836 s (424 of 425); 21: libcxx 750 s, C++ 667 s; all GREEN |
| 0.127 | the C++ language items of "Not done" | `bool` comparisons, enumerators of their enum, promotions ranked, trailing `decltype`, block typedefs scoped, lazy program instances, the rest of access control, const closures, value-initialization, aggregate bases, shipped static functions | 18: reader 5 s, compile 10 s, driver 7 s, objects 3 s, libcxx 1055 s, C++ 820 s (438 of 439); 21: libcxx 1031 s, C++ 740 s; all GREEN |
| 0.128 | line tables, the vacuum, unsigned constants | `-g` gives DWARF line tables; the C store vacuumed every 64th run and before each gate; an unsigned constant operation done in its type, `#if` in `uintmax_t`, one evaluator for an enumerator's value | 18: reader 5 s, compile 10 s, driver 7 s, objects 4 s, libcxx 1123 s, C++ 929 s (438 of 439); 21: libcxx 940 s, C++ 644 s; all GREEN |
| 0.129 | `__int128` in C++, the decimal floating types | `__SIZEOF_INT128__` in C++ too; a 128-bit constant typed; explicit specializations of function templates; floating constants folded under integer casts; C23's `_Decimal32`, `_Decimal64`, `_Decimal128` over libgcc's BID runtime, with gcc's ABI | 18: reader 5 s, compile 10 s, driver 7 s, objects 3 s, libcxx 1327 s, C++ 1128 s (442 of 443); 21: libcxx 1141 s, C++ 794 s; all GREEN after the width fix |
| 0.130 | `-g`: the variables, their types, the blocks, C++'s names | Every named local, parameter and global a DWARF variable of its described type; lexical blocks; each function's type; C++'s methods, namespaces, template instances and statics by their names; no location in the prologue; `-gline-tables-only` and kin | a save point: reader 5 s, compile 11 s, driver 11 s (30 checks), objects 5 s, proof; the C++ gates are 0.132's |

## M5 — the C++ mode

**The C++ mode (M5, `bin/cicilang++`):** `'$ccl_lang'` is c or cpp, set
from the file's extension by `ccl_read_file` (`.cpp .cc .cxx .C .hpp .hh
.hxx`) or forced by the driver's `lang(cpp)` (`'$ccl_lang_forced'`, which
`cicilang++` sets through `CICILANG_LANG=cpp`). Every C++ rule in
`ccl_syntax.pl` is guarded by `ccl_cpp` (`{ ccl_lang(cpp) }`) and placed
BEFORE the C clause it extends, so a .c reads as it did; the keywords are
mode-dependent (`ccl_keyword/1`: C's, plus `ccl_cpp_keyword/1` in cpp;
`override` and `final` stay identifiers), and `::` lexes only in cpp. The
vocabulary is README's table. Names: `ccl_qname//3` reads `::a::b<args>::c`
into an atom, `tmpl(N, Args)` or `scoped(Path, Last)` (`global` first for
a leading `::`), taking `N <` as a template-id when N is a known template
(`'$ccl_templates'`, seeded with the STL's, grown by every `template`
item) or, in a type context, when the arguments read as such and end
before a declarator (`ccl_targs_ahead/2`, a scan to the matching `>`,
`>>` closing two: `ccl_tclose/2` leaves one). In `ccl_specs` a compound
qualified name is a type (`ccl_cpp_type//3`), a plain one is left to the
C heuristics; in a block it must be followed by what a declarator starts
with (`std::cout << x` is an expression). A class's name joins the global
env at its declaration (`ccl_add_env/1`), its body parses under
`'$ccl_class'` so a constructor is known by the class's own name. A LESSON
that cost an evening: `( A, ! ; B )` inside a DCG body cuts the WHOLE
CLAUSE, so it is only for a choice that decides the clause -- `( inline,
! ; [] )` before `namespace` killed every inline function, and a
qualifier hook ending in `!` in the function-definition rule killed every
prototype at file scope. An optional word is `( ccl_kw(inline) ; [] )`,
no cut. The C++ items reach the bulk noter (`ccl_collect_item`: extern_c,
namespace by its bare name, template; `class` as a tag; `param/3`; refs)
and `ccl_note_item`. A C++ library header (`system(_)` or `next(_)` spec,
kind kept in `'$ccl_inc_kind'`) is flattened by the preprocessor
(`ccl_pp_parse/4`) and read once (`ccl_read_unit`), never raw -- raw, `<sstream>`'s
hundreds of headers each failed and got preprocessed in turn: ten
minutes -- and `#include_next` looks past the including file's directory
(`ccl_resolve_include(next(_), …)`). **The summary cache:** a flattened
library header is summarized to `~/.cicilang/cpp/<name>-<fold>.sum`
(`ccl_sum_file/2`, two folds of the path), one term per line: `sum(Path,
key(ReaderVersion, cpp))` and a `dep(File, Time)` per file the
preprocessor pulled, then `decl(N, T)`, `typedef(N, T)`, `tag(Tag,
Ms)` (bodies dropped by `ccl_sum_slim/2`), `enum(N, V)`, `tname(N)` (the
names the parser's Env needs: typedefs and tags), `template(N)` -- what
`ccl_collect_items` and `ccl_items_typedefs` give (`ccl_sum_write/4`). A
valid summary (`ccl_sum_valid/1`: the version, every dep's time) makes the
include node `include(L, Spec, summary(F))`, and each consumer reads it
where it would walk a unit: `ccl_include_typedefs` (the Env),
`ccl_include_scope` → `ccl_sum_note/1` (the four tables, the templates,
the global env), `ccl_collect_item` (the bulk rebuild before the check
and the lowering), `dr_items_deps` (the IR signature). The driver reads
`.cpp .cc .cxx .C` through `dr_c`, skips the check and the lowering under
`-fsyntax-only` in cpp mode (M6's), and `ccl_link` uses `c++`. `cicilang++`
runs `--no-kb`: see the findings.

## 0.32 — M6's first step

**M6, the check and the lowering of the C++ forms, in steps; the first
(0.32): C++ that is C with names.** A namespace FLATTENS to bare names
(the noters already did so: `namespace`, `extern_c` items are their
items; `ir_item` walks them; `using` is nothing; `scoped(_, N)` in an
expression is `id(N)` in the check, the inference and the lowering;
two namespaces declaring one name collide, unhandled). `bool` is a byte
(`ir_base`, `ccl_basic_size`, rank 0), a conversion TO bool an `icmp ne`
+ `zext` (`ir_to_bool`, first in `ir_convert/6`), `bool(true)` /
`nullptr` constants and global initializers; `ccast(_, T, E)` is
`cast(T, E)`; `enum_class(Tag, Es)` an enum (`ir_base`, the bulk noter's
`ccl_collect_spec` collects it -- it did not, and `Color c` failed as
`typedef('Color')`), and a C++ TAG's name resolves as a type
(`ccl_resolve_base([typedef(N)])` in cpp mode through `ccl_tag_type/4`,
told by the members' shape: enumerators, plain members, a class's).
`for_each(L, Decl, Range, S)` over an ARRAY is rewritten ONCE for both
passes, `ccl_for_each_as_for/2` in `ccl_infer`: `for (int i = 0; i < N;
i++) { T x = xs[i]; S }`, an `auto &` a `ref` to the element; a range
that is not an array is `range_for_over_non_array`. **A reference is a
pointer bound once:** the reader gives `ref(Q, T)` / `rref(Q, T)`;
`ccl_type_of` DECAYS it (`ccl_unref/2` in the id, call, member, arrow,
index, deref clauses), `ir_type_` makes it `ptr`, a local's slot holds
the address (`ir_locals`: `ir_ref_of/2` of the initializer -- an lvalue
form's address, or a call's reference result as it is), a use of the name
loads that address first (`ir_ref_slot/4` in `ir_expr(id)` and
`ir_lval(id)`), a reference parameter takes the argument's address
(`ir_args_`), a reference result returns one (`ir_stmt(return)`,
`ir_lval(call)` for `alias(y) = ...`) and is loaded through where a value
is asked (`ir_expr(call)`). The CHECK sees the pointer: `ck_ref_params/2`
and `ck_ref_decl/5` map `ref` to `ptr` -- a parameter a borrow, a local
bound to an lvalue a borrow of its address (`addr(Init)`: an anchor, an
array's element), one bound to a call not followed -- and keep the
function's reference names in `'$ck_refs'`, since a use of such a name
is a use of the referent: `x = v` is `*x = v` (the assign clause first),
`&x` the pointer held, the value borrows only when the referent's type
carries a pointer, and `return x` from a reference-returning function
(`'$ck_ret'`) is checked as a borrow out (`borrow_escapes` for a
reference to a local, `ck_no_escape`). `new T` is
`(T *) malloc(sizeof(T))`, `new T(v)` stores v through a statement
expression, `new T[n]` `malloc(n * sizeof(T))`, `delete p` / `delete[]
p` `free(p)` (`ir_new/3`; `malloc` and `free` declared by
`ir_cpp_prelude` when the file did not, before the check, which consumes
at a delete as at a free and takes `new` as a fresh value). A form of a
later step is REFUSED BY NAME, never dropped: `class(N)` at its
declaration and where a variable has the type, `member_of_class(N)`,
`operator(Op)`, `constructor`, `destructor`, `method(N)`, `template`,
`lambda`, `throw`, `try` (the check's last `ck_stmt` clause throws the
lowering's `not_lowered(F)` with its place); the noters skip a member
defined out of its class (`Counter::made`, `Shape::scale`: a compound
name), which crashed `atom_concat` before. Gated by `test/cpp.sh`:
`test/cpp/run/names.cpp` and `loops.cpp` built through `cicilang++`, run
against their `.expect`, and `control.cpp`, `classes.cpp`,
`templates.cpp` refused with `try`, `virtual`, `template`. Not done: two
namespaces with one name, a reference member, a reference to a class,
`auto` the reader could not infer (`ir_fail(auto)`).

## 0.33 — M6's second step

**M6's second step (0.33): classes, DESUGARED to that C** by
`library/ccl_cpp.pl`, one typed rewrite of the units that `ccl_ir_units`
runs in cpp mode between the first symbol-table build and the check
(`ccl_cpp_units/2`; the table is built again from what comes out, since
the classes became structs). The design rule: every C++ form of the
steps to come is a rewrite to the C the check and the lowering have,
never new lowering, so the safe part reads C++ programs as it reads C.
`cpp_register_units/1` collects `'$cpp_classes'` (`C-cls(Base, Data,
Members, Statics, Defaults)`) from the `declare(_, base(_, [class(...)]))`
items, refusing `virtual(C)` and `multiple_inheritance(C)`, and DECLARES
every method, constructor, destructor, static member and free operator
in the table under its mangled name at once, so a rewritten call has a
type while the walk goes on. Names: `C.m.k` (k the arity), a
constructor `C.C.k`, the destructor `C.dtor.0`, an operator by its word
(`cpp_op_word/2`: `C.op.plus_assign.1`, a free one `op.plus.2`), a
static member `C.N` -- dots only, so LLVM takes them unquoted and no C
name collides. A class item becomes `declare(L, base(Q, [struct(C,
Data)]))` with the base's sub-object the first member, `'$base'`, then
`extern` declarations of the statics, then a function per method (`this`
the first parameter, `const C *` for a const method), per constructor
(void; its body the base's constructor over `&this->$base`, then every
data member from its initializer, else its `default_init`, in the
members' order, then the body), and the destructor; a class with no
constructor but defaults or a constructed base gets `C.C.0`
(`cpp_implicit_ctor`). Out of class: `int Counter::made = 0` is the
global `Counter.made`, `Shape::scale` and `Counter::~Counter`
(`dtor_def/4`) the functions. Bodies are walked with the symbol table's
scopes kept as the check keeps them (`cpp_method_body`, `cpp_stmt`,
`cpp_expr`, bottom up), so `ccl_type_of/2` tells a class-typed operand:
inside a method an unqualified data member is `this->n`, an inherited
one `(*this).$base.n` (`cpp_data_member/3` gives the hops), a static
`id('C.N')`; `o.m(a)` is `C.m.k(&o, a)` and `p->m(a)` `C.m.k(p, a)` with
the default arguments filled (`'$cpp_defaults'`, by mangled name), an
inherited method over the base sub-object's address, an unqualified
`m(a)` inside a method over `this`; `Counter(v)` and the functional cast
build a temporary in a statement expression; `o += v`, `o[i]`, `a + b`
go to the class's member operator, else a free one registered
(`'$cpp_free_ops'`), else stay the form. A local of a class with a
constructor becomes a `'$splice'` of the declaration, the constructor
call over its address (from `ctor(As)`, `init(Items)`, no initializer,
or a single value not of the class -- a value of the class is COPIED,
`Counter e = c + d`), and, when the class has a destructor, a
`defer(L, [], block([expr(L, call(id('C.dtor.0'), [addr(id(N))]))]))`:
the existing defer machinery runs it at every exit of the scope, last
declared first, as C++ does. `new C(As)` is a statement expression
constructing into `new(T, [])`'s block (the check: a loose pointer out,
as before), `delete p` of a class with a destructor
`comma(call(dtor, [p]), delete(p))` (a temporary for a non-name, since
the check would see a borrow freed). `ccl_members_of/2` answers a
class's data members (the raw `class(...)` spec, before the rewrite;
statics excluded) so member types resolve during the walk. Gated by
`test/cpp/run/counter.cpp`: two classes with a base, initializers,
defaults, a static, `operator+=`, `operator[]`, a free `operator+`, a
temporary returned by value, `new`/`delete`, destructors counted -- the
numbers agree with clang++'s.

## 0.34 — M6's third step

**M6's third step (0.34): `virtual`, the same way.** The registry's
`cls/6` carries the class's SLOTS (`cpp_slots/4`: the base's, then each
own virtual method -- or one overriding a base slot, `override` being
implicit -- appended by name and arity, `'$dtor'` for a virtual
destructor). The class that introduces slots over a non-polymorphic base
(or none) gets `'$vptr'` as its first data member (after `'$base'`), a
pointer to `struct 'C.vt'`, which `cpp_vt_struct` declares before the
class's struct: a function-pointer member per slot over the OWNER's
`this` type (`cpp_vt_owner/2`: the first polymorphic class up the
chain). After the functions comes the table, `static struct 'C.vt'
'C.vtable' = { the most derived implementation per slot }`
(`cpp_vtable`, `cpp_slot_impl/4`: the class's own method, else the
base's; the destructor slot `cpp_dtor/2`, which answers the base's when
the class has none, since the base sits at offset 0). Every constructor,
an implicit one included (`cpp_implicit_ctor_needed` counts a polymorphic
class), stores `this->$vptr = (struct Owner.vt *) &C.vtable` right after
the base's constructor (`cpp_vptr_store/3`; the walk finds the hops to
the member). A destructor's body ends with the base's destructor over
`&this->$base` (`cpp_dtor_body`). A call `p->m(a)` whose method has a
slot is `p->$vptr->m(p, a)` (`cpp_dispatch/5`); `o.m(a)` dispatches only
when `o` is a reference or `*p` (`cpp_static_object/1`: a named value
or a member of one has its static type); an unqualified `m(a)` inside a
method dispatches through `this`; `delete p` with a virtual destructor
destroys through the slot (`cpp_destroy`). Single inheritance keeps the
base at offset 0, so `this` is never adjusted. The lowering's constants
take a function's address and a global's (`ir_gconst(id(F))`,
`ir_gconst(addr(id(G)))`), and the check counts `&global` as static, so
the store in the constructor is no fresh value. Gated by
`test/cpp/run/shapes.cpp` (two overrides, one inherited slot, a virtual
destructor chained, a static counted) and the reader's `classes.cpp`
built and run (exit 34). Not done: a pure virtual method (refused,
`pure_virtual`), a member of class type with a constructor, an array or
a global of a class with a constructor, a temporary's destructor,
`operator=` and copy constructors (a struct copies), nested classes,
`static` methods, `friend`, access control (ignored), a method called
before the class is complete, `dynamic_cast`, RTTI.

## 0.35 — M6's fourth step

**M6's fourth step (0.35): templates, instantiated on use.** The
registry keeps `'$cpp_templates'` (`Name-tmpl(TParams, Item)`, from the
`template(L, TParams, Item)` items, a function or a class), the
instances made `'$cpp_instances'` (`Name-Template`) and their items
`'$cpp_instance_items'`, which `cpp_flush_instances/2` appends to the
unit's items at its end (walking an instance may make more). EVERY TYPE
the walk meets goes through `cpp_type/2` -- a declaration's, a
parameter's, a member's, a cast's, `sizeof`'s, `new`'s, a typedef's --
and a template-id there, `typedef(tmpl(N, Args))` or the scoped form,
becomes its instance's name: `cpp_instantiate_class/3` binds the
parameters (`cpp_bind_targs`, defaults filled), names the instance
`N.key.key` (`cpp_instance_name`, `cpp_type_key/2`: `Buf.int.4`,
`max2.double`, a pointer `int_p`), and, once, substitutes the bindings
through the item (`cpp_subst/3`: a type parameter's `typedef` becomes
the argument with the qualifiers kept, a non-type parameter's `id` the
value), registers the class (`cpp_register_class`, so its members'
types go through the hook too: nested instantiation) and desugars it
like a class written out -- under `cpp_isolated/1`, the symbol table's
open scopes set aside so the instance's walk sees no local of the
function that met it and its declarations go to the file scope. A call
`max2<int>(1, 2)` (the reader's `call(tmpl(F, TArgs), As)`) or `max2(3,
4)` of a function template goes to `cpp_instantiate_function/4`: the
type arguments explicit, then DEDUCED from the arguments' types
(`cpp_match/5`: a type parameter's `typedef` takes the argument's type
decayed, through `ptr`, `ref`, `rref`), then defaulted, else
`cannot_deduce(P)`; the instance is declared in the table and walked
like a function. The table built before the walk holds a template-id
RAW (`Ints` = `typedef(tmpl(Buf, ...))`): `ccl_resolve_base` leaves a
compound typedef name as it is (an `atom(N)` guard before the cached
lookup, which would have `atom_concat`ed it), `cpp_class_of_type_`
instantiates such a one on sight, and a rewritten `typedef` item is
noted at once (`ccl_note_typedefs`). The template item itself is
nothing in the output; a template from a header's summary has no body
and is refused, `template_without_body(N)`. Gated by
`test/cpp/run/templ.cpp` (a class template with an array member, a
constructor and methods, instantiated twice and through an alias, a
function template deduced and explicit) and the reader's
`templates.cpp` built and run (exit 10; its `std::vector` is its own
namespace's). Not done: partial and explicit specializations, a
non-type argument deduced, `template` inside a class, a template
template parameter, `typename T::x`, SFINAE.

## 0.36 — M6's fifth step

**M6's fifth step (0.36): lambdas, a class of the captures.** The
reader gives `lambda(Caps, Params, Ret | none, Body)` with `cap(val, N)`,
`cap(ref, N)`, `cap(default, '=' | '&')`, `cap(this)`. `cpp_lambda/6`
makes the class `lambda.K` (`'$cpp_lambdas'` counts): a member per
capture -- by value the local's type (decayed), by reference
`ref([], T)` -- and the method `operator()` over the parameters with
the body as written, registered and desugared like a class written out
under `cpp_isolated` (so inside the body the captured names are
members, `this->k`, and an enclosing local NOT captured is undeclared,
as C++ has it); the expression becomes `compound_lit(base([],
[typedef('lambda.K')]), init([...]))` of the captures' values, `&t` for
a reference. A default capture takes every enclosing local the body
names (`cpp_lambda_free/3`: the body's `id`s minus its parameters and
its own declarations, kept when `cpp_local`); the result type is the
first `return`'s, typed under the parameters (`cpp_lambda_ret/3`), or
void. `auto f = <lambda>` -- `auto` the reader could not infer -- takes
the initializer's type in `cpp_decl_pieces` (the initializer rewritten
once; any `auto` does: a method's or a template's result). A call `f(a)`
of a local whose class has `operator()` is `lambda.K.op.call.n(&f, a)`
(the first `cpp_call` clause), which also serves a function template's
parameter of the closure's type: `apply(addk, 1)` copies the closure
(its reference member still the caller's `t`). THE LOWERING reads a
REFERENCE MEMBER through (`ir_ref_member/4` in `ir_lval(member)` and
`ir_lval(arrow)`: the slot's address loaded, then the referent), while
an initializer stores the address as any pointer; the check's
`ccl_type_of` already unrefs a member's type. Gated by
`test/cpp/run/lambdas.cpp`. Not done: `[this]` (refused,
`capture_this`), a lambda inside a template's body before its
instantiation, `mutable` (every capture is mutable), a lambda's
destructor, `std::function`.

## 0.37 — M6's sixth step

**M6's sixth step (0.37): a real program under the safe part** --
`test/cpp/run/btree.cpp`, the B-tree of `bench/btree` as a class over
`own` pointers (`own node *root`, the nodes' `own node *C[nc]`), a
constructor, a destructor, const methods, `own BTree *t = new BTree()`
and `delete t`; it prints the C version's numbers. What it taught the
check, THE OBJECT'S LIFECYCLE: the desugaring marks a constructor's
`this` `ptr([], base([fresh], [typedef(C)]))` and a destructor's
`[dying]` (`cpp_this_type/4`, in the function, its declaration and the
table's `$dtor` slot alike), and the check reads the marks
(`ck_this_marker/2`): under `fresh` the pointee's own fields start
UNSET (`ck_param_owners`: garbage, not complete), so `root = new_leaf()`
is no overwrite, and `ck_complete_owners` still demands them live or
null at every return -- a constructor that forgets an own field is
refused; under `dying` the fields are exempt from that demand
(`'$ck_dying_fields'`), so `~BTree() { free(root); }` passes, and the
CALLER of a destructor -- `delete p` as `comma(dtor(p), free(p))`, a
local's defer over `&c` -- takes the object's own fields as moved
(`ck_args_`: `ck_dying_param/2`, `ck_arg_base/2`, `ck_own_under`), so the
free that follows finds nothing leaked. `new T` of a struct without a
constructor is malloc's bytes to the check (`ck_alloc_mode`: `new(_,
[])`, `new_array`, and through a `cast`), `new C(args)` a complete
object (its constructor was made to be). `bench/btree/btree_cicilang.c`
built with `-O1` at 20000 keys gives the expectation. Not done: a
constructor that delegates, `this` handed out of a constructor, a
destructor's effect on a struct member of class type, arrays of
objects, `static` methods (a `this` is passed and unused).

## 0.38-0.40 — M6's seventh to ninth steps

**M6's seventh to ninth steps (0.38-0.40, redone in 0.41 over the
program's own classes -- THE OWNER'S RULE: nothing of the standard
library is the compiler's own; the C freestanding headers were the one
exception, on the C side; the C++ side compiles against libc++ as it
is, C++17 the baseline then the next majors, and libc++'s containers
await the forms their bodies use).** What the three steps built stays,
exercised by `test/cpp/run/bag.h` (a `Name` over an `own char *` and a
`Bag<T>` over an `own T *`, a LOCAL header read whole) and `bag.cpp`:
(1) a header the program wrote gives its classes and templates to
every unit that includes it (`cpp_register_header/1` from the include
node's raw unit, `file(_, _, unit(Is))`; its class, struct and enum
class NAMES join the includer's Env, `ccl_items_typedefs` in cpp mode,
so `Name &s` parses): a class registered and EMITTED as an instance
is, its functions `linkonce` (`cpp_linkonce/2` in
`cpp_add_instance_items`; the lowering spells `define linkonce_odr`),
so two units link; a library header's summary keeps names only, and a
template of libc++'s is refused, `template_without_body(N)`. A
range-for over an object whose class has `size()` and `operator[]` is
rewritten by the desugaring (`cpp_stmt(for_each)`) into the `for` over
an index, the element type the operator's result unreferenced; the
range must be an lvalue form. `cpp_subst` turns `sizeof(id(T))` (read
as an expression while T was only a name) into `sizeof_type` of the
argument and `T(x)` into a functional cast; a scoped type name
flattens in the type hook (`typedef(scoped([std], string))` is
`typedef(string)`); a class's STRUCT form is in the tags table from
its registration (`cpp_register_class` notes it), so `this->d[i]`'s
element has a type while the instance's own methods are walked. (2)
OVERLOADS BY TYPE: a name carries its parameters' type keys
(`cpp_params_key/2`: `Name.op.plus_assign.char`,
`Name.op.plus_assign.char_p`, `Counter.add.int`, a nullary `C.m.0`),
and `cpp_method/5` and `cpp_ctor/3` take the ARGUMENTS, keep the
overloads whose arity fits and pick the one whose parameter types fit
the arguments' best (`cpp_pick/3`, `cpp_arg_fit/3`: the same class 3,
both pointers 2, both arithmetic 2, an unknown type 1). THE RULE A
DESTRUCTOR BRINGS: a class with one is never copied, since two owners
of one buffer free it twice and the check cannot see the destructor's
free -- refused as `copy_of_a_class_with_destructor(C)` (a local
initialized from an lvalue of the class),
`assignment_to_a_class_with_destructor(C)` (`s = t`, unless the right
side is a `move(...)` into the holder's fresh slot),
`class_with_destructor_by_value(C)` (an lvalue handed to a by-value
parameter, `cpp_no_copies/1` after every call),
`return_of_a_class_with_destructor(C)` (an lvalue returned by value;
`'$cpp_ret'` holds the function's result type through
`cpp_method_body/5`; a temporary, a call's result, is fine and moves).
`ccl_members_of` of a raw `class(...)` spec keeps pointer-typed
members; a tag noted TWICE -- the raw class from an include, the
desugared struct from the emitted items -- resolves to the struct
(`ccl_tag_type` through `ccl_tag_struct/2`, cached under `'$ccl_ts:'`);
a parameter's own field RETURNED AS A PLAIN POINTER (`c_str`) is a
borrow out, the caller's still, not a move (`ck_consume_or_use`, first
clause). (3) MOVE SEMANTICS: `std::move(x)` is Cicili's `move(x)`
(`cpp_call`: `scoped([std], move)`, a semantic mapping, no header
needed); the LOWERING's `move(E)` of a struct lvalue whose type holds
owners loads the value and stores null into every own pointer field of
the source, nested structs recursively (`ir_null_own_fields/2`,
`ir_has_own_fields/1`), so the source's destructor, run at its scope's
end, frees nothing; the CHECK's `move(E)` of a struct by value with
owners moves its fields out (`ck_expr(move)`, first clause), and
`ck_kind(move(E))` gives such a value its own kind; a struct with
owners handed BY VALUE hands them to the callee's copy (the check's
rule in the safe part above); `move(x)` of a value without owners is
`x` (`cpp_holds_owners/1`: a template's `T` an int); after a call with
a `fresh` parameter the argument's own fields are LIVE
(`ck_fresh_param/2` in `ck_args_`, the constructor's contract read back
by the caller), so `std::move(a)` after `Name a = "alpha"` finds fields
to move; a constructor's or destructor's argument may be a member's
address (`ck_arg_base(addr(E), K)` takes any path). AN EXPLICIT
DESTRUCTOR CALL, `x.~T()` and `p->~T()`, is read as `call(member(x,
dtor(T)), [])` (`ccl_postfix_p`, cpp only) and desugared (the first
`cpp_call` clauses) to the class's destructor over its address,
nothing for a class without one -- what a container of the program's
own writes where its elements leave (`Bag::pop`, `~Bag`); `d[n] =
move(x)` is how it stores. A moved-from object keeps its plain fields
(only owners are nulled): its state is unspecified, as C++ has it.
Reader version 31 (for `.~T()`). Gated by `test/cpp/run/bag.cpp`, run
under `leaks` and MallocScribble. Not done: the forms libc++'s
`<vector>` and `<string>` use (allocators, `enable_if`, partial
specializations, `constexpr`, `noexcept`, rvalue reference overloads
chosen by value category, exceptions), which are the road to compiling
them as they are.

## 0.41 — M6's tenth step

**M6's tenth step (0.41): members of class type.** A data member whose
class has constructors is CONSTRUCTED in every constructor of its
holder (`cpp_member_inits`, the class clause: from its `init(N, Args)`
entry, else its default initializer, else the member's default
constructor, else `member_not_constructed`), and a holder without a
constructor gets the implicit one for it (`cpp_implicit_ctor_needed`
counts such a member); a member whose class has a destructor is
DESTROYED by every destructor of its holder, the members in reverse
order, then the base (`cpp_dtor_body`), and a holder with none gets an
implicit destructor (`cpp_implicit_dtor_needed/1`, `cpp_implicit_dtor/3`,
emitted with the class; `cpp_own_dtor` counts it, so `delete`, the
scope's defer and the table's slot find it). An AGGREGATE initializer
of a class whose only constructor is the implicit one constructs each
member from its item (`cpp_decl_pieces`' first clause,
`cpp_aggregate_inits/5`: `Person p = { "ann", 30 }` is
`string.string.char_p(&p.name, "ann"); p.age = 30;`), then the
destructor's defer. The check's constructor and destructor effects
reach a member's address: `ck_arg_base(addr(E), K)` takes any path
(`&this->name`, `&p.name`), so the member's own fields go live after
its constructor and moved after its destructor, and the holder's
`fresh`/`dying` rules hold through the nesting (`ck_pointee_fields`
recurses into members held by value). Gated by
`test/cpp/run/member.cpp` (a struct with a `Name`, a class with a
`Name` and a `Bag` of the structs, a member initializer, an aggregate,
a move into the bag; zero leaks). Not done: a member's default
initializer of class type (`std::string s = "x";` in a class body),
an array member of objects, a union of objects.

## 0.42 — M6's eleventh step

**M6's eleventh step (0.42): C++20.** THE LEVEL: `-std=c++17|20|23|26`
(`bin/cicilang`: `std(N)` in the options; older levels refused as
unsupported, C's `-std` ignored) sets `'$ccl_std'` (default 17;
`ccl_std/1` reads it), and the preprocessor answers the level's macros
first (`pp_predef_macro`: the tables `cpp26`, `cpp23`, `cpp20` by
`pp_std_table/2`, then `any`, the arch, `cpp`; the tables at the end
of `ccl_pp.pl`, from the reference compiler's `-dM -E` at each level,
taken once: `__cplusplus` 202002L/202302L/202400L, the `__cpp_*`
feature tests -- concepts, consteval, constinit, char8_t, the three-way
comparison, coroutines, modules, `using enum` ...). A summary is one
level's (`ccl_sum_file` folds `Path@Std`, the `sum` line's key is
`cpp(Std)`), the store's key `cpp(Version, Std)`. THE READER (version
32): the keywords `concept requires co_await co_yield co_return
consteval constinit char8_t` in both lexers (`ccl_lx_cppkw` in the
module), `<=>` a punctuator in both (`ccl_lx_p3`) and a binary
operator at level 7.5 -- below the relational, above the shifts;
`concept N = E;` an item (`ccl_note_template(N)`, so `C<T>` reads as a
template-id), a `requires` clause on a template's head kept as
`requires(E)` among the parameters (the binders skip it), a
`requires` expression a primary with its requirements (`type(T)`,
`compound(E, C)`, `nested(E)`, `expr(E)`), `co_return` a statement and
`co_await`/`co_yield` unaries, `using enum E`, a range-for with an
initializer as a block, `if constexpr` its own node, an attribute
before a statement dropped, `auto` a TYPE in C++ declarations (C's
storage class it is not) so `auto f(auto x)` reads, a template lambda
with `tparams(Ps)` among its captures, `explicit(cond)`. THE
DESUGARING: a concept is registered (`'$cpp_concepts'`,
`N-concept(TPs, E)`) and CHECKED where a template is instantiated
(`cpp_constraints_hold/3` after the bindings; `cpp_satisfied/1`: `&&`,
`||`, `!`, a concept-id through `cpp_concept_holds/2`, a
`requires_expr` whose requirements type-check under its parameters --
an expression rewritten by the desugaring has a type, a type resolves,
a compound's type satisfies its concept, a nested one holds -- else a
constant expression; a trait with no body here is
`constraint_unknown`), refusing `constraint_not_satisfied(N)`; an
abbreviated function template becomes a template of invented
parameters `$A1, $A2 ...` at registration (`cpp_auto_params/4`, through
pointers and references) and its item is nothing; a function's `auto`
result is deduced from its first return (`cpp_lambda_ret`, at the item
and at an instance); `if_constexpr` is decided by `cpp_const_bool/2` (a
constant, a `bool`, a concept-id) and one branch kept, else a plain
`if`; `bin('<=>', A, B)` on scalars is `(A > B) - (A < B)`, an int
where C++ has `std::strong_ordering` (a class's `operator<=>` when it
has one, else `three_way_comparison_of_a_class`); `using enum` is
nothing (the enumerators are global names already); `co_return`,
`co_await`, `co_yield` are `coroutine`, a template or generic lambda
`generic_lambda`; `char8_t` is a byte. Gated by `test/cpp/cxx20.cpp`
read (c22-c28), `test/cpp/run/cxx20.cpp` built with `-std=c++20`
(`test/cpp/run/NAME.flags` gives a fixture its flags) printing
`__cplusplus` 202002, and `coro.cpp` and `concept_fail.cpp` refused by
name. Not done: modules (`import`/`export`), `consteval` evaluated at
compile time (it runs at run time like `constexpr`), coroutines,
`std::strong_ordering` and defaulted `operator<=>`, generic lambdas,
constrained `auto` (`Number auto x`), `requires` clauses on a
non-template function, C++23's and C++26's forms beyond their macros.
**An integer literal's suffix is read** (found by this step: `1L` was
`int(1)`, so a template deduced `int` from it and `%ld` of it read
garbage): both lexers give `tok(uint|long|ulong, N, L)` for `u`, `l`,
`ul` in either case and order (`ccl_int_suffix//1` in the DCG,
`ccl_lx_int_suffix` and `x->sfx` in the native one), the parser the
nodes `uint(N)`, `long(N)`, `ulong(N)`, typed, folded, lowered and
keyed (`cpp_type_key`: `Nu`, `Nl`, `Nul`) beside `int(N)`; reader
version 33; `k59` and `k65` read `0xFFul` and `1u << 4`.

## 0.43 — M6's twelfth step

**M6's twelfth step (0.43): C++23.** The level's macros were there
(`-std=c++23`, `pp_std_table`); this step is the forms. THE READER
(version 34): `if consteval { } else { }` and `if ! consteval` are
`if_consteval(L, no | yes, T, E)`; an explicit object parameter, `this
Self &self` (`ccl_param`, cpp only), is `param(this(T), N)` first among
the parameters (`ccl_declare_params` strips the mark); `a[i, j]` at
`-std=c++23` (`ccl_std_at_least/1`) is `index(A, args(Is))`, a single
index the `index/2` it was -- one clause reads `ccl_args` and chooses,
no re-parse; `auto(x)` and `auto{x}` are `decay_copy(E)`; a lambda
takes an attribute after its captures and its specifiers with or
without the parentheses (`ccl_lambda_specs`: `mutable`, `constexpr`,
`consteval`, `static`, `noexcept(...)`); `using T = type;` in an
init-statement (`ccl_for_init`'s alias clause, `ccl_init_stmt` makes
the `typedef` item) and -- C++11's, missing -- in a block; `if (init;
c)` and `switch (init; e)` (C++17's, missing) are a `block` of the
initializer and the statement, as the range-for with an initializer
is; a label may end a block (`ccl_label_body`: `label(L, N, empty)`).
BOTH LEXERS: the suffix `z`/`Z` (`4uz`) is a long, `size_t` under
LP64; the escapes `\x{...}`, `\o{...}`, `\u{...}` and the universal
character names `\uXXXX`, `\UXXXXXXXX` (not read before), the last
two put into a string as UTF-8 (`ccl_utf8/3`, `ccl_lx_put_utf8`), a
code point in a char literal; octal `\NNN` up to three digits (before,
`\101` read as `\1` then `01`); `\N{NAME}` is not read. THE
PREPROCESSOR: `#elifdef X` and `#elifndef X` (`pp_cond_word`,
`pp_defined_body/3` spells them as `defined(X)` for the group skipper);
`#warning` stays nothing. THE DESUGARING: `cpp_norm_members/2` at
`cpp_register_class` turns the marked parameter into the qualifier
`explicit_this(N, T)`, so arity, overload choice, mangling and slots see
the parameters a caller passes; `cpp_declare_members` and
`cpp_member_fns` declare and emit such a method with `param(T, N)`
first instead of `param(ThisT, this)` and walk its body under `Ctx =
none` (no implicit `this`: C++23 has it so, `self.n`), `this auto` on a
class's method refused as `deduced_this(C)` (a member template);
EVERY CALL SITE passes the object through `cpp_object_arg/3`: the
declared function's first parameter named `this` takes the address as
before, any other name takes the object itself (`B` for `addr(B)`,
`deref(P)` for a pointer) -- a reference parameter takes its address in
the lowering, a by-value one a copy, refused for a class with a
destructor by `cpp_no_copies`. A lambda's `this auto self` is the
closure by value (`cpp_self_type/3`: `auto` becomes the closure's type,
an rvalue reference a reference), its method marked `closure`, and its
body walked under `Ctx = self(C, SN)` so a capture named bare is
`member(id(self), N)` (`cpp_expr(id)`'s second branch) -- the recursive
lambda, `n * self(n - 1)`, states its result type, since the first
return's type is asked before the closure's class exists. `if
consteval` keeps the run-time branch (nothing here is evaluated at
compile time); `decay_copy(X)` is `cast(T, X)` of the decayed type, the
value itself for a class (a copy of one with a destructor refused as
before); `index(A, args(Is))` goes to the class's `operator[]` over the
arguments, else `subscript_arity(N)`. FOUND BY THIS STEP: a typedef
inside a block was noted by the reader and forgotten by the passes
(the symbol table is rebuilt from the top-level items) -- `T x` was
`not_lowered(typedef(T))` in C too; `ccl_collect_item(function)` now
walks the body's statements for `typedef` items (`ccl_stmt_typedefs`,
by statement shape, not into expressions), one table for the function
(a name typedef'd in two blocks must agree); `test/c/run/typedef_block.c`.
Gated by `test/cpp/cxx23.cpp` read at the level (c29-c33: `unit_at/3`
sets `'$ccl_std'` for the read), `test/cpp/run/cxx23.cpp` built with
`-std=c++23` (`.flags`) printing `__cplusplus` 202302, and
`deduced_this.cpp` refused. Not done: deducing `this` with a deduced
type on a class's method (CRTP: `template` inside a class), `static
operator[]`, `\N{...}`, the extended floating-point suffixes (`1.0f16`),
`#warning` printed, `[[assume]]` told to LLVM, trailing whitespace
before a line splice, `consteval` at compile time, modules; C++26's forms.

## 0.44 — M6's thirteenth step

**M6's thirteenth step (0.44): the road to libc++, its first stretch.**
FOUND FIRST: the reader had never read a libc++ header -- it stopped at
`<vector>`'s first item (a conversion operator) and `ccl_read_unit`
takes a PARTIAL read silently (`partial(U, line(L), near(F))`), so every
library summary held nothing but macros. THE LOOP: `cicilang++ -E f.cpp -o
flat.cpp` (clang's flag; `dr_preprocess`: `ccl_pp_file/3` standalone,
spelled back by `ccl_pp_spell/2` in ccl_pp -- a token a word, a string
with `\NNN` escapes, a line per source line, an infinite float as
`1e999`), then `sh test/census.sh flat.cpp` (test/census.pl: the read
through `cicilang_ast/3`, the stop line, the farthest line and the tokens
around both, then a histogram of the AST's functors with the template
shapes apart) -- a few seconds a turn where a flatten is twenty. THE
READER (version 34 still; every rule guarded by `ccl_cpp`): a
conversion operator `operator T()` (`ccl_conv_type`: specifiers and
pointers only, `int ()` would read as a function type) as
`method(L, Qs, T, operator(conv(T)), [], false, Body)`; class-scope
`typedef` and `using x = T` as `typedef` members whose names join the
global env; `ccl_sto_pick/2` chooses the deciding storage word (`static
inline constexpr` lost `static`); attributes anywhere (`[[...]]` before
an item, a member, among the prefix words, after a lambda's parameters,
`alignas(...)`); packs: `tparam(pack, N, D)`, `tparam(vpack(T), N,
none)`, `param(pack(T), N)`, `pack(X)` for an expansion in a template
argument, a call argument, a base, an initializer item, a constructor
initializer, `sizeof_pack(N)`, `fold(Op, dots, E)` / `fold(Op, E,
dots)` / `fold(Op, A, dots, B)`; a template argument is a full
expression (`ccl_targ_expr`: `'$ccl_targ'` counts the depth and
`ccl_op_open/1` makes `>` and `>>` closers, parentheses reset it); a
template's parameters are types for the item's whole text
(`ccl_tparam` adds each to the global env as read, `ccl_tparams_enter/3`
and `ccl_tparams_leave/1` around the item, `'$ccl_tmpl_depth'` making
the item's own name a template inside its body, `ccl_note_if_template`);
`struct X<Args>` is `class(K, tmpl(X, Args), Bs, Ms)` (`ccl_class_targs`;
the noters skip a compound tag), a declarator `X<T>::f`, `v<T>`,
`operator+<...>` is `name(Q)` where a declarator may end
(`ccl_declarator_id_end`: `(is_x<T>::value && y)` is no cast); `typename
T::x`, `X<T>::template f<U>`, `decltype(e)` as a name's segment and
`decltype(auto)`; the compiler's traits: `builtin_type(N, Args)` for the
type-yielding ones (`ccl_builtin_type_name`: a fixed list, since the
SDK's `(__istype(c, m))` is a call) and `call(id('__is_same'), [type(T),
type(U)])` for the tests (`ccl_builtin_trait`); `noexcept(e)`,
`alignof(T)`, `void()`, `int{}`, `typename X::y()` as `construct(T, As)`,
`::new`, `::operator new`, `p.operator->()`, `operator""sv`, `f(...)
= delete` at file scope, a member template's name noted, `template <int
&...>`, `template <class...> class F = X`, `if (T x = e)` and `while` as
a block of the declaration and the test, `return { a, b }`, `struct I
{...};` inside a class as `nested(Base)`, `friend(L, Ms)` with the
member read (a friend's body has semicolons), `extern template ...;`
and `template class X<char>;` as `extern_template(L, I)` and
`explicit_instantiation(L, I)`, a deduction guide as
`deduction_guide(L, N, Ps, T)`, an out-of-class `X<T>::X(...)` with
`inline` and attributes before it (`ccl_class_base/2`), an unnamed
template parameter, `typename T::x = 0` told from a type parameter
(`ccl_tparam_end`), the threaded env MERGED into the global one at every
item (`ccl_env_sync/2`: before, a typedef's item replaced the global env
and dropped every class name added on the side). THE VEXING PARSE: `S
b(std::move(a));` had read as a function declaration; a qualified name
is a type where its last name is known as one (`ccl_qname_typish`) or a
declarator follows (`ccl_declarator_follows`: `ns::what &w`), an
expression where `(` does. BOTH `<vector>` AND `<string>` READ WHOLE
(441 and 434 items; `test/libcxx.sh`, a fresh HOME so nothing is served
from a summary, about a minute).

THE DESUGARING (`library/ccl_cpp.pl`), on the program's own classes:
`test/cpp/run/generic.cpp`, `copies.cpp`, `bindings.cpp`. Packs:
`cpp_bind_targs_` gives a pack parameter `P-pack(Rest)`; `cpp_subst`
expands `pack(X)` wherever a list holds it (`cpp_subst_elems`: an
argument, a template argument, `base(A, pack(Q))`, `item(D, pack(V))`,
`param(pack(T), N)` into `N$1..N$k` with `N-vpack([id(N$1) ...])` bound
by `cpp_param_packs` for the body) -- ONLY for packs that are bound
(`cpp_pack_names`), so a member template's own expansion inside an
instantiated class waits for its own instantiation; folds
(`cpp_fold_right/left`, empty ones as the standard has them);
`sizeof_pack`; a trailing parameter pack deduced element by element
(`cpp_deduce_pack`); `cpp_type_key(pack(L))` joins the keys. SPECIALIZATIONS:
`'$cpp_spec'(N, TPs, Pattern, Item)` from `cpp_spec_name`;
`cpp_instantiate_class_` binds the primary's parameters (defaults
merged from the other declarations of the name, `cpp_merge_defaults`,
their parameters renamed), names the instance, records
`'$cpp_inst'(Name, inst(N, FullArgs))`, then `cpp_pick_spec`: every
specialization whose pattern matches (`cpp_match_pattern`: a type
parameter binds, a value parameter compares by `ccl_const_eval`, a
template-id pattern matches an instance of that template through its
recorded arguments, `cpp_instance_of`), the most specialized of them
(`cpp_more_special`: X's pattern as arguments matches Y's); the
injected class name is bound to the instance (`Self`). FUNCTION
TEMPLATES are candidate sets: `cpp_instantiate_function` tries each in
declaration order, `cpp_signature_holds` inside a `catch` as a
condition -- a `cpp_refuse` in binding, deduction or the resolution of a
value parameter's type (`enable_if<c, int>::type`, no `type` member:
`no_member_type`) is no candidate (SFINAE); the first candidate's
refusal is the diagnostic when none fits (`'$cpp_first_refusal'`);
overloads get `F.cK` in their instance names. MEMBER TEMPLATES:
`'$cpp_mt'(C, Key, TPs, M)` from `cpp_register_class_extras`;
`cpp_method` falls back to `cpp_member_template_call` (deduced from the
arguments, or `o.f<T>(...)` given), `cpp_ctor` to
`cpp_member_template_ctor`; the instance is declared and emitted at the
call. DEPENDENT NAMES: `'$cpp_class_types'` (a class's typedefs, from
its `typedef` members) answers `cpp_type(typedef(scoped(Path, N)))`
through `cpp_scope_class` (a class, an instance, a namespace prefix
skipped) and REFUSES `no_member_type` when the class has no such type;
`cpp_subst` substitutes inside a scoped name's path (`C::value_type`
with C bound); a class's own typedef names resolve inside its members
through `'$cpp_class_ctx'` (`cpp_in_class`, set while a class is
declared, walked or emitted); `cpp_targ_value` tells `X<T>::value` (a
static member) from `X<T>::type` by what the class has; `X<T>::f(args)`
calls a static method with a null this; `X<T>::value` folds to the
static's constant (`'$cpp_static_inits'`); `decltype(e)` types the
expression desugared; `__is_same` and a dozen traits are decided
(`cpp_trait`, `cpp_builtin_type`). AUTO RESULTS of methods are deduced
through the desugaring (`cpp_method_ret`: the first return desugared,
then typed -- the inference knows no instance's call). COPIES: a
constructor from the class itself (`cpp_copy_ctor(C, ref | rref)`)
makes an lvalue initializer construct through it and `move(x)` through
the move one, the argument x itself (a reference parameter takes the
address, `cpp_ref_args_of` strips `move` there); `cpp_arg_fit` scores
the value category (`cpp_category_mismatch`: an rvalue reference binds
no lvalue, a plain one no rvalue; an rvalue prefers `C &&`); `a = b` goes
to `operator=`; a by-value parameter of a class with a destructor takes
`cpp_copy_temp` at the call (the copy constructor into a temporary) and
the callee destroys it (`cpp_param_defers`, a defer first in the body);
`return x` of such a local moves out into a temporary; a prvalue moves
bitwise (C++17 elides that copy). THE CHECK: `r.f` with r a reference
is keyed `r->f` (`ck_path`), a conditional returns either arm
(`ck_no_escape`), `&c.f` borrows what `&c` does. BINDINGS: `auto [a, b]
= e` is Cicili's pattern by another spelling (`ccl_destructure`, an
array's elements by index, `ccl_bind_refs` for `auto &`). A braced
temporary of a plain struct is a compound literal; deleted and defaulted
members are dropped at `cpp_norm_members`, a pure one marked; an
abstract class registers and is refused only where constructed
(`cpp_not_abstract`). THE LIBRARY: a flattened header's items are
indexed by name into FACTS, `'$cpp_hdr'(Name, Item)` (`cpp_index_header`;
`cpp_hdr_load/1` registers every item of a name on the first miss of
`cpp_class`, `cpp_template`, `cpp_class_template`); a header's class is
LAZY (`'$cpp_lazy'`: the struct emitted, `cpp_use_member` emitting a
member when `cpp_method`, `cpp_ctor` or `cpp_own_dtor` first names it);
a header's inline function is emitted linkonce when loaded; an alias
template instantiates as its type (`cpp_instantiate_type`; the class
definition wins a name over `std::pmr::vector`, an alias sharing the
flattened name, and alias and variable templates stay out of the C
typedef table, `ccl_collect_item`); the registries that hold BODIES
are facts too (`'$cpp_cls'`, `'$cpp_tmpl'`, `'$cpp_spec'`, `'$cpp_mt'`,
`'$cpp_inst'`, `'$cpp_out'`, reset by `cpp_reset/1`): as lists in
globals they were copied at every lookup, megabytes each once libc++
was in them. THE BUDGET: `cpp_spend/1` counts loads and instances,
`cpp_deeper/1` the nesting; past 3000 or 120 the compile stops with
`instantiation_budget` / `instantiation_depth`, since one unbounded run
of `std::vector<int>` took the machine's memory (the owner saw it);
`'$cpp_trace'` prints each spend for the loop. `std::vector<int> v;`
loads vector, allocator, allocator_traits, numeric_limits,
initializer_list, `__wrap_iter`, `__vector_layout` and `__split_buffer`
(26 loads and instances, two minutes: the declaration of a library
class's hundred methods resolves every dependent type in them, a road
of its own to profile) and stops at `template_without_body('_Layout')`:
a template template parameter (`template <class, class, class> class
_Layout`) bound to a template's name and used as one, the next form. NOT DONE: the AST cache beside a summary (a program that
instantiates a library template needs the header read again, twenty
seconds: `template_without_body` on a summary-served run), the forms
libc++'s bodies use past that point, `std::pmr` and other namespace
collisions (the flattening), a lambda pack capture, `\N{...}`, nested
classes as types, `using` declarations, a friend's scope.

## 0.45 — M6's fourteenth step

**M6's fourteenth step (0.45): libc++'s first function compiled from its
own body, `std::swap`.** THE TEMPLATE TEMPLATE PARAMETER, `template <class,
class, class> class _Layout = __split_buffer_pointer_layout`: bound to a
template's NAME, `tname(X)` (`cpp_tname_arg/3`: an atom, a namespace
flattened away, another such parameter's binding passed on --
`__split_buffer<_Tp, _Allocator, _Layout>`); `cpp_subst` turns
`base(Q, [typedef(P)])` into the name and `tmpl(P, Args)` into `tmpl(X,
Args)` (in a scoped path too), the key is the name, a specialization's
pattern matches one (`cpp_match_one`), `f(H<T>)` deduces H from an
instance (`cpp_match`'s template-id clause), and `ccl_skip_to_close`
counts nested `<>` in the parameter's own list. `__split_buffer`'s base,
`_Layout<__split_buffer<_Tp, _Allocator, _Layout>, _Tp, _Allocator>`
(the CRTP through the parameter), instantiates; `test/cpp/run/ttp.cpp`.
FUNCTION TEMPLATES AS C++ CHOOSES (`cpp_instantiate_function`): the
candidates are every DEFINITION of the name in declaration order (a
prototype is a `declaration` item; the registry is assertz -- the
`reverse` from the global-list days put the last declared first); a
signature holds when the arity fits (`cpp_arity_holds`: defaults, a
pack), the explicit arguments bind, the parameters deduce, the defaults
fill, the constraints hold, AND every class-typed parameter accepts its
argument (`cpp_params_accept`: the class itself, an instance of the
template, a class derived from it, else a class with a one-argument
constructor; a scalar parameter takes no class without a conversion
operator; an argument the inference cannot type passes) -- before, the
first candidate whose parameters deduced was taken, `__swap_allocator(a1,
a2, true_type)` for a `false_type`; a template-id parameter whose
argument is no instance of the template, nor a base of the argument's
class (`cpp_instance_or_base`), is `deduction_failed(N)`, no candidate --
before, it bound nothing and the defaults filled: `swap(tuple<_Tp...> &,
...)` held for two pointers with `_Tp` an empty pack; an ALIAS template's
template-id (`__type_identity_t<_Tp> *`) is a non-deduced context, the
alias substituted once `_Tp` is bound explicitly and the parameter
checked then; of the candidates that hold, the FEWEST CONVERSIONS win
(`'$cpp_conversions'`: a derived object to a base's reference, a value
through a constructor), then the MOST SPECIALIZED (`cpp_fn_more_special`:
Y's parameter types deduce from X's taken as arguments with X's own
parameters opaque, `$opaque.P`), the first declared among equals; the
trace prints `candidate(F, K, holds(Conv) | refused(Why))`;
`test/cpp/run/overloads.cpp` (thirteen choices, clang++'s). THE TRAITS
over two or more types are decided (`cpp_trait_n`: constructible,
assignable, convertible, base_of, over the registry -- a scalar converts
as C++ converts, a class through its constructors, conversion operators
and bases; the nothrow forms are the plain ones, the trivial ones ask no
user-written special member) and the rest of the one-type ones
(`cpp_trait_of`: scalar, fundamental, object, empty, polymorphic,
aggregate, trivially copyable, trivially destructible ...);
`ccl_builtin_trait` is a FIXED list of the compiler's -- libc++ has
functions in the same spelling (`__is_overaligned_for_new(__align)`),
read as the calls they are. A DATA MEMBER's type is resolved under the
class's own typedefs at registration (`cpp_member_types`: `pointer
__begin_` is `int *`; the trace `member_type_unresolved`), so
`this->__front_cap_` has the type a call deduces from. A static
inherited from a base folds (`cpp_static_const` walks the bases:
`is_move_constructible<T>::value` is `integral_constant`'s), and a static
WITH its initializer in the class is its own definition, `linkonce`
(`cpp_static_decls`; `ir_globals` spells `linkonce_odr global`) --
`integral_constant::value` was the undefined symbol at the link. A
conversion operator mangles `op.conv_<key>`. A type without a
constructor direct-initialized, `_Tp __t(std::move(__x))`, `int n{}`,
takes the value or the type's zero (`cpp_plain_init`). `std::move` of a
value without owners is the value, through `cpp_expr(move(X))`, the one
door. A namespace-qualified call, `std::swap(a, b)`, `std::swap<int>(a,
b)`, resolves as the bare name would and never as a member. THE READER
(version 35): a FUNCTION template's name is a template (`move<int>(x)`
reads as a template-id) but no type (`'$ccl_fn_templates'`,
`ccl_note_if_fn_template` at the definition, a summary's `ftemplate(N)`
line, `ccl_qname_typish` excluding them): `_Tp __t(std::move(__x))` had
read as a function declaration taking a `std::move`, the vexing parse
C++ resolves by knowing what `std::move` is. THE AST BESIDE THE
SUMMARY (the thirteenth step's open item): `<name>-<fold>.ast.pl` holds
one clause per named item of the flattened header, `'$cpp_hdr_ast'(Name,
Item)`, written by `ccl_ast_write` with the summary and consulted
(`ensure_loaded/1` takes a two-megabyte clause in 0.2 s under `--local`,
where `term_to_atom/2` fails past tens of KB a line) by `cpp_load_ast`
when the include node is `file(_, summary, summary(F))`; `cpp_hdr_item/2`
answers from the index and the file alike, so the second run of a
program that instantiates a library template needs no flatten (0.8 s
where the first took 8). THE LIBRARY'S FUNCTIONS ARE NOT CHECKED -- the
decision this step took, for the owner to confirm or reverse: libc++'s
bodies keep raw pointers by their own discipline (a vector's begin, end
and capacity; a swap of two pointers through references), which the safe
part refuses at every line (`a borrow stored where it cannot be
followed`, swap's first statement); a function that comes from a library
header -- an inline one, a lazy class's member, an instance of the
header's template, whatever such a walk emits -- is `'$cpp_libfn'(Name)`
(`cpp_as_lib/2` around the emissions, a template's origin `'$cpp_lib'(N)`
from `cpp_hdr_load`) and the check skips it (`cpp_library_function/1` in
`ck_items`); the program's own functions, its own templates' instances
wherever they are instantiated from, are checked as always, and the
lowering lowers both. THE PROBE (`scratchpad/probe.sh SRC HOME LOG
SECS`): the HOME is REMOVED first -- twice a run showed no spend and
`template_without_body(vector)` because a leftover summary was served
and nothing reached the index -- and `test/config.sh` is sourced by a
shell whose `$0` sits in `test/`, since it finds the checkout from `$0`.
THE LAYOUT FORMS libc++ builds its containers from: an ANONYMOUS
STRUCT member's members are the class's own and an anonymous UNION's are
reached through the one member it becomes (`cpp_norm_members_`, a hop in
`cpp_data_member`; libc++'s compressed pair is such a struct) --
`test/cpp/run/anon.cpp`; `__builtin_offsetof` is decided from the layout
the compiler already computes (`cpp_offsetof/4` over
`ccl_members_layout`, a dotted path walked), which is how libc++ finds a
type's data size, the offset of a `char` placed after it --
`test/cpp/run/offsetof.cpp`; an ARRAY'S BOUND is an expression the
desugaring must rewrite like any other (`cpp_array_bound/2` in
`cpp_type`), since `char __padding_[sizeof(_ToPad) -
__datasizeof_v<_ToPad>]` needs its variable template instantiated and
folded -- it was passed through untouched and the array came out empty;
and a CLASS'S OWN TYPEDEF now wins over a namespace's of the same name
inside the class, as C++ looks names up (the `\+ ccl_typedef_of(N, _)`
guard in `cpp_type` inverted that order) -- `test/cpp/run/padding.cpp`.
FOUND ON THE WAY, older than this step: `malloc(sizeof(T))` did not
compile in C++ mode at all. libc++ spells `size_t` as
`decltype(sizeof(int))`, the lowering has no `decltype`, and resolving it
through `ccl_type_of` turns in a circle, since the type of a sizeof IS
`size_t`: `ccl_resolve_base` answers a `decltype` of a sizeof with the
concrete `unsigned long` and any other with the expression's type
(`ccl_sizeof_expr/1`, cpp only). Gated by `test/cpp/run/stdswap.cpp`: `<utility>`'s `std::swap` over
pointers and over ints, its result type through `__enable_if_t`,
`is_move_constructible` and `is_move_assignable`, C++'s numbers on the
first run and on the summary-served one. `std::vector<int>` now reaches
43 loads and instances (26 at 0.44) and stops inside libc++'s compressed
pair, `_FirstPaddingByte<pointer>`: the layout class's own `pointer`,
`typename __alloc_traits::pointer`, does not resolve through
`allocator_traits`'s own meta, so the instance is keyed by the unresolved
name and has no members -- the allocator machinery is the next stretch.

## 0.46 — M6's fifteenth step

**M6's fifteenth step (0.46): the allocator machinery, and the memory
that had to come first.** THE MEMORY: cocolog has no collector (the
finding below): a `cicilang++` run of `std::vector<int>` peaked at 4.5 GB
and, with a runaway of mine on top, restarted the owner's machine. The
preprocessor runs each file inside `\+ \+` (3.1 GB -> 564 MB for the
flatten), the parser reads EACH ITEM inside `\+ \+` (`ccl_externals/4`:
the item and the count of tokens left kept through a global, the
position recovered by that count -- the parse of the flattened
`<vector>` 1033 -> 440 MB, of which the top pass is 355), the name sets
the parser asks at every identifier are buckets (`ccl_set_has/2`), a
class's tag is noted without its bodies, and a gate's harness runs each
check inside `\+ \+`; every run of mine is under `scratchpad/guard.sh`
or `watch.sh`, and the module is rebuilt after a cocolog update (the
engine went 1.2.5 -> 1.2.12 under this step). THE DETECTION IDIOM, which
libc++'s allocator traits are built on (`__pointer` is
`__detected_or_t<_Tp *, __pointer_member, _Alloc>`): a partial
specialization's pattern is matched in TWO PASSES (`cpp_match_pattern`:
`cpp_match_deducible`, then `cpp_match_later`) -- the deducible elements
bind the parameters, then every NON-DEDUCED element (an alias template's
template-id such as `__void_t<_Op<_Args...>>`, a name qualified by a
parameter, a decltype; `cpp_non_deduced/2`) is substituted, resolved and
compared with its argument, a refusal in that resolution being no match:
the SFINAE that picks `__detector<_Default, __void_t<_Op<_Args...>>, _Op,
_Args...>` only where `_Op<_Args...>` has a type; a pattern element that
still names a free parameter is no match; a template-id pattern over a
template template parameter deduces the template too (`cpp_match_tmpl`,
`_Sp<_Tp, _Args...>`); an alias template's template-id in a FUNCTION
parameter is a non-deduced context as well (`cpp_match`); a PLAIN STRUCT
is a scope (`cpp_path_class`: `NoPtr::pointer` is refused as
`no_member_type`, never flattened to a namespace's bare name), an enum's
name is not (`Color::Green` is its enumerator); `test/cpp/run/detect.cpp`
(found and not found, clang++'s). A TYPEDEF IS RESOLVED IN THE CLASS THAT
DEFINES IT (`cpp_class_typedef/4` gives the defining class, `cpp_in_class`
around the resolution in `cpp_type`, `cpp_path_class`): `allocator_traits`
writes `pointer` as `typename __base::pointer` with `__base` its own
alias, which the asking class did not know -- and a scope the resolver
does not find flattens SILENTLY as a namespace (`cpp_type`'s last scoped
clause), which the trace now prints as `flatten(Path, N)`; the probe
showed `flatten([__base], pointer)` nineteen times. AND THE CLASSES THE ALLOCATOR
DRAGS IN, each a defect of its own: a class DECLARED and not defined
(`class bad_alloc;`) was indexed under its name and registered as the
class, with no members, so the real definition never registered
(`cpp_index_name` requires a body of a class as it always did of a
struct; `cpp_lazy_class` skips a bodyless one); a CONSTRUCTOR that is
declared and not defined -- libc++'s `bad_alloc()` lives in the shipped
binary -- had no clause in `cpp_member_fns`, where a method and a
destructor had one, and became a declaration now; a member of a class
whose only constructors are a defaulted one and a converting TEMPLATE
(`std::allocator`) is default-initialized with nothing to call
(`cpp_trivial_default/1`) and copied from its own class by the implicit
copy, the template never preferred over it (`cpp_ctor`'s guard), and a
CONSTRUCTOR'S PARAMETERS are in scope while its member initializers are
built (`a_(a)` has to type `a` to choose) -- `test/cpp/run/alloc.cpp`;
`__is_constructible` and `__is_assignable` unref the ARGUMENT and count a
constructor template and a defaulted constructor, so `std::allocator` is
move-constructible as C++ says (it read false, and the `enable_if` behind
`std::swap`'s result type then had no `type`); `auto` deduces ANY type
and not only a plain one (`ccl_add_quals`), where `auto __new_begin =
__begin_ - __size` -- a POINTER -- silently failed
(`test/cpp/run/autoptr.cpp`); a specialization is picked only where it
HAS a body. AND THE SILENT FAILURES BEHIND ALL OF THEM: a registration
or an emission that merely FAILED left the class half-registered -- its
`'$cpp_cls'` fact asserted, its members never emitted, and
`cpp_class/2`'s own load then failing -- so every later lookup lied;
each is a refusal now (`class_not_registered`, `class_not_emitted`,
`instance_not_emitted`, `base_not_registered`, `members_not_split`,
`member_types`), and the steps of a class's registration and emission
trace under `'$cpp_trace'` (`item_member_fns`, `method_body_failed`,
`instantiate_failed`, `want(Name)` ...), which is how each of these was
found. FOUND ON THE WAY: a missing input file compiled to `cicilang: ok`
(`dr_input` refuses it now, `no such file or directory`).
`std::vector<int>` now reaches 67 loads and instances (43 at 0.45, 26 at
0.44) -- through the exception classes, the compressed pair, the
allocator's traits and `std::swap`'s result type -- and stops in
`__to_address`, `cannot_deduce('_Tp')`, the next stretch.

## 0.47 — M6's sixteenth step

**M6's sixteenth step (0.47): `__to_address` and the uninitialized-memory
algorithms.** THE ONE THAT PAID FOR THE REST: `cpp_isolated/1` set the
symbol table's open scopes aside and restored them on success and on
failure but NOT ON A THROW -- and SFINAE throws and catches by design
(`cpp_holding_candidates` catches `not_lowered` to reject a candidate),
so after a candidate was rejected the CALLER's own locals had no types.
`__to_address(__first)` deduced and `__to_address(__last)`, the next
argument of the same call, did not (`cannot_deduce('_Tp')`, the argument
traced as `unknown`); a `catch` that restores and rethrows, as
`cpp_in_class` and `cpp_as_lib` already had. It took the probe from 67
loads to 97. THE FORMS: a UNARY operator on a class goes to the class's
operator, as a binary one already did (`cpp_expr` on `deref`, `preinc`,
`predec`, `postinc`, `postdec` -- postfix passing the `int` C++ marks it
with -- `not`, `neg`, `bitnot`, all through `cpp_operator/5`), without
which libc++'s `addressof(*__first)` could not be typed
(`test/cpp/run/unaryops.cpp`); a temporary of a class TEMPLATE's
instance written with explicit arguments, `Guard<A, I>(a, i, j)`, which
only a plain class had (`cpp_call`'s `tmpl` clause, guarded by
`cpp_targs_settled/1` so an argument that did not fold never names an
instance by its spelling); a QUALIFIED PATH of two or more class
segments walked segment by segment, each named inside the one before
(`cpp_scope_walk/3` behind `cpp_scope_class/2`, the old last-segment
rule tried first), which is how `allocator_traits<A>::propagate_on_container_swap::value`
folds; a MEMBER ALIAS TEMPLATE registered (`cpp_member_key` had only
methods and constructors) and resolved through its class,
`_IfImpl<C>::template _Select<A, B>` -- and its clause sits BEFORE
`cpp_type`'s template-id clause, since `cpp_template_id/3` strips a
scope to a bare name for `std::vector<int>`'s sake and swallowed this;
a member initialized from `std::move(x)` chooses its constructor on the
RAW initializer, so the choice looks through the move
(`cpp_init_arg_class/2`). AND THE DETECTION
`iterator_traits` IS BUILT ON, `__has_iterator_typedefs<It>::value`
deciding between two static member function TEMPLATES -- one taking
`...`, one taking five defaulted `__void_t<typename _Up::X> *`
parameters -- read through `decltype` of the call: an ELLIPSIS takes any
number of arguments and is C++'s WORST match, so a variadic candidate is
tried last and only where nothing else fits (`cpp_variadic_member/1`,
the flag threaded into `cpp_signature_holds/7` and `cpp_arity_holds/3`);
a member TEMPLATE named unqualified with explicit arguments,
`__test<_Tp>(nullptr, ...)`, resolves inside its own class with a null
`this`, as `X<T>::f(args)` already did; a `decltype(...)` is a SCOPE
(`cpp_path_class`), so `decltype(__test<_Tp>(...))::value` names the
class the expression has; a static const's initializer is DESUGARED in
its class's own words before it is folded (`cpp_fold_static/4`, a guard
per name since folding may ask for itself), where only a literal
constant folded before; and `typename _Up::X` on a class that has
neither such a type NOR such a member REFUSES (`cpp_targ_value`), which
is the SFINAE that rejects the candidate -- it had quietly become a
value named after the class, so the wrong overload won.
`test/cpp/run/detect2.cpp` (found and not found, clang++'s).
`std::vector<int>` now reaches 156 loads and instances (67 at the start
of this step, 43 at 0.45) -- through `__to_address`,
`__uninitialized_allocator_relocate`, the exception guard,
`__allocator_destroy`, `reverse_iterator`, `__wrap_iter` and
`iterator_traits` -- and stops on a NESTED CLASS, `vector`'s own
`__destroy_vector`, which is not registered as a type: the next stretch.

## 0.48 — M6's seventeenth step

**M6's seventeenth step (0.48): nested classes, and what vector asked for
next.** A NESTED CLASS is a type of the class that holds it and a class of
its own under the mangled name `Enclosing.Nested`: its NAME is registered
first (`cpp_nested_names/2`, so a member of that type resolves before the
nested class exists), the class itself after the enclosing one is
registered (`cpp_nested_classes/3`, so its own members may name the class
that holds it -- libc++'s `vector` destroys itself through
`__destroy_vector`, which holds a `vector &`), and the enclosing class's
typedefs are copied into it (`cpp_enclosing_types/2`), as C++'s scoping
has them. It is reachable three ways: as a type (`Plain::Nested` outside,
`Nested` within, both through `cpp_class_typedef`), as a temporary
through the enclosing name, and named BARE inside its own class
(`__destroy_vector(*this)`); a class with no constructors takes braced
AGGREGATE initialization rather than a constructor
(`cpp_temporary`'s first clause, beside the empty `__less<>()` case) --
`test/cpp/run/nested.cpp`. AND THREE DEFECTS IT UNCOVERED, each older
than this step: a specialization's pattern QUALIFIERS were ignored, so
`numeric_limits<const _Tp>` matched every argument and the class derived
from ITSELF (`cpp_pattern_quals/3`: the argument must carry every
qualifier the pattern names, and binds without them); a VARIABLE
template used as a template argument was read as a type and instantiated
as a class (`cpp_variable_template/1` in `cpp_targ_value`,
`integral_constant<bool, __is_floating_point_impl<T>>`); and an OPERATOR
member template could not be named at all -- `cpp_instance_name`
concatenated `operator('()')` as if it were an atom and threw a type
error (`cpp_instance_base/2` spells it `op.call`), which `__less<>`'s
templated `operator()` needs. `std::vector<int>` now reaches 177 loads
and instances (156 at 0.47, 43 at 0.45) and stops on an instance keyed
by names that did not resolve, `__allocation_result.pointer.size_type`
beside the good `__allocation_result.int_p.size_t`: a template
instantiated where its arguments' class scope was not in hand, which is
a name-resolution defect rather than a missing form, and the next thing
to chase.

## 0.49 — M6's eighteenth step

**M6's eighteenth step (0.49): the name resolution behind a badly keyed
instance.** `std::vector<int>` had made TWO instances of one template,
`__allocation_result.pointer.size_type` beside the good
`__allocation_result.int_p.size_t`: the first keyed by names that never
resolved. THE CAUSE was in the READER, not the desugaring. `auto r =
std::__allocate_at_least(a, n)` was deduced AT READ TIME by
`ccl_auto_decl/5`, from the symbol table's declaration of
`__allocate_at_least` -- and a function template is declared there under
its RAW, unsubstituted signature (`ccl_collect_item` walks into a
template's item), so the deduced type was `__allocation_result<typename
_Traits::pointer, typename _Traits::size_type>` with `_Traits` free.
The desugaring then resolved it, could not find `_Traits` as a scope, and
FLATTENED it as if it were a namespace (`cpp_type`'s last scoped clause),
giving `pointer` and `size_type` as the arguments. A type that still
carries a DEPENDENT name is not deduced yet (`ccl_dependent_type/1`: a
`scoped/2` anywhere in it): `auto` stays, and `cpp_decl_pieces` deduces
it once the call is instantiated, which is the only place that knows.
Reader version 36. `test/cpp/run/autodep.cpp`. THE TOOL that found it,
worth keeping: `cpp_where/2`, a SCOPED breadcrumb of what the desugaring
is working on -- `class(N)`, `fn(F)`, `load(N)`, `member(C, M)`,
`sig(F)`, `subst(F)`, `body(C)`, `auto(N)`, `call(F)`, `args(F)`,
`stmt(Functor, Line)` -- printed by every trace that would otherwise be
silent (`flatten(Path, N, in(Where))`). An unscoped first attempt named
the last thing ENTERED and sent me to the wrong class twice; scoped, it
named the statement. And the reproduction is the other half: the shape
cut down to thirteen lines runs in ONE SECOND where the probe takes
fifty, which is what made the last four defects quick. `std::vector<int>`
now reaches 182 loads and instances (177 at 0.48) and stops in the
EXCEPTION classes -- `__throw_length_error` pulls `length_error`,
`logic_error`, `basic_string` and `char_traits`, whose primary is
declared and whose `char` specialization the index does not hold -- which
is the road to `<string>` and, behind it, the question of exceptions
themselves.

## 0.50 — M6's nineteenth step

**M6's nineteenth step (0.50): EXCEPTIONS, by not having them.** libc++
asks the COMPILER whether the language has them -- `#if
defined(__cpp_exceptions) && __cpp_exceptions >= 199711L` decides its
`_LIBCPP_HAS_EXCEPTIONS` -- so the two predefined macros
(`__cpp_exceptions`, `__EXCEPTIONS`) are simply not predefined any more
(`ccl_pp.pl`, commented with the reason). The library then compiles its
OWN no-exceptions configuration, as it ships and as `-fno-exceptions`
gives it: `<vector>`'s flattened text went from nine `throw`s and three
`try` blocks to NONE, and a thrower aborts with a message instead. This
is the honest configuration for a compiler whose safe part has no
unwinding to offer, and a program that writes `throw` or `try` of its own
is still refused by name. Reader version 37, since every summary was
flattened with exceptions ON and must be read again. WHAT IT UNCOVERED,
each a defect of its own: a PRVALUE bound to a `const` reference had no
address, and C++ materializes a temporary -- `ir_ref_of` allocates one
and stores the value (`v.push_back(1)`, the user's own line, was the
first thing to reach it); the COMPILER'S OWN BUILTINS that libc++ calls
are answered as this compiler can (`cpp_builtin_call/3`:
`__builtin_is_constant_evaluated` is FALSE, since nothing here is
evaluated at compile time; `__builtin_operator_new` and `delete` are the
malloc and free the lowering already has, at any arity, an alignment
request dropped; `__builtin_launder`, `__builtin_addressof`,
`__builtin_expect`, `__builtin_assume_aligned`); a VARIABLE template read
as a TYPE in an expression is evaluated (`!__has_max_size_v<const _Ap>`
-- the reader cannot tell a type from a value there, and unevaluated the
negation came out false); and a bool template argument KEYS AS ITS NUMBER
(`cpp_type_key`), so `true` and `1` name one instance where they had
named two -- the same duplicate-instance defect as 0.49's, from the other
side. Lowering version 9. `std::vector<int> v; v.push_back(1);` now
reaches `allocator_traits<allocator<int>>::max_size`, whose two overloads
are chosen by `__has_max_size_v<const _Ap>` and its negation: a variable
template of TWO parameters whose specialization is a `decltype` of a
member call, where both conditions come out false and neither overload is
picked. The isolated shapes all work (a negated variable template, a
`const` argument, static member templates with `enable_if` defaults,
`test/cpp/run/` fixtures), so what is left is that two-parameter
detection, and it is the next thing.

## 0.51 — M6's twentieth step

**M6's twentieth step (0.51): the detection trait, and the allocator
through.** `__has_max_size_v<_Alloc, class = void>`, whose specialization
is matched by `decltype((void) declval<_Alloc &>().max_size())`, decides
which `allocator_traits::max_size` libc++ uses. It asked four things,
each a defect: a function template DECLARED and never defined
(`template <class T> T &&declval();`) must still instantiate, for its
TYPE is all a decltype wants (`cpp_fn_item/2` normalizes a declaration
item into a function with no body, the call clauses take it, and the
instance is emitted as a DECLARATION) -- without it the call fell to the
class-template clause and refused `instance_without_body(declval)`; a
member call on a type that HAS members but not that one REFUSES
(`cpp_call`'s member clause), which is the rejection a detection needs,
where it had been left alone and `(void) <unknown>` was void either way,
so the trait was true for everything; a member of a REFERENCE is a member
of what it refers to (`cpp_class_of_type` unrefs), since `declval<C &>()`
names one; and a member template's signature is checked IN ITS OWN CLASS
(`cpp_in_class` around `cpp_signature_holds` in `cpp_try_member`), since
`const allocator_type &` is written in the traits class's words and read
in the caller's -- it refused `argument_mismatch`.
`test/cpp/run/detect3.cpp` (found, not found, and through a `const`).
AND WHAT THE ALLOCATOR NEEDED BEHIND IT: `::operator new` and `delete`
written out are the malloc and free the lowering already has
(`cpp_operator_new/3`, any arity); a tag with NO members takes no
initializer, so `__element_count(n)` -- an empty scoped `enum class` --
is a CAST (the enum-ness of an empty enum is not in the tag table, and
the members decide); and a class-scope typedef naming a scalar is a
functional cast, `size_type(~0)`, beside the nested-class case that
clause already had. TWO OF THOSE CUT TOO WIDE, and the gate
said so: unreffing inside `cpp_class_of_type` made a REFERENCE-typed
type count as its class, and the rules that turn on the value category
(`return_of_a_class_with_destructor` and kin) then fired on returns of
references -- six fixtures failed, and the unref belongs in
`cpp_class_of_type_of`, the class an EXPRESSION has, never in the
type-level test; and making a declaration a candidate let the
DECLARATION of `std::swap` win over its definition, which linked to
nothing, so a declaration is a candidate only when nothing is defined
(`cpp_defined_first/2`, before the specialization ordering). `std::vector<int> v; v.push_back(1);` now compiles
`allocator<int>`'s `allocate` and `max_size` whole and stops in
`__swap_allocator`, on an `integral_constant<bool, false>` that reaches
the lowering without being instantiated.

## 0.52 — M6's twenty-first step

**M6's twenty-first step (0.52): A LIBRARY TEMPLATE'S INSTANCE IS LAZY.**
A class instance emitted EVERY member function it had, so
`std::vector<int> v; v.push_back(1);` compiled vector's hundred members
and stopped at the first one this compiler could not take --
`__swap_allocator`, reached through a `swap` the program never calls. A
library header's plain class already emitted members only as they were
named (`'$cpp_lazy'`, `cpp_use_member/2`); an instance of a LIBRARY
template does so too now (`cpp_lazy_instance/2` before `cpp_item`), which
is what the standard says a template instantiates. The program's OWN
templates stay eager: their instances are the program's code and the safe
part must see all of it. It took the probe from 177 instantiations to 83,
and every form still to be found is now one the program actually uses.
WITH IT: a NESTED class sees the enclosing class's types INCLUDING the
inherited ones -- `'$cpp_enclosing'` records which class holds a nested
one and `cpp_class_typedef/4` falls back to it, where copying the
enclosing class's direct entries missed `pointer` on
`__split_buffer::_ConstructTransaction`, whose enclosing class gets it
from its layout base. `std::vector<int> v; v.push_back(1);` now stops on
`__vector_layout`'s `__alloc()`, an accessor emitted lazily whose
`__alloc_` is a member of the class's ANONYMOUS STRUCT and is not found
there: the flattening that `test/cpp/run/anon.cpp` proves works on a
struct written plainly does not reach this one, whose members carry
`[[no_unique_address]]` and default initializers and sit last in the
class. The gates' peaks fell with the laziness (the C++ gate 855 -> 615
MB).

## 0.53 — M6's twenty-second step

**M6's twenty-second step (0.53): an anonymous struct in C++'s own
shape, and a phase that says its name.** An anonymous struct whose
members carry DEFAULT INITIALIZERS reaches the desugaring as
`class(struct, anon, [], Ms)` and not the plain `struct(anon, Ms)` that
`test/cpp/run/anon.cpp` covers, so its members were not flattened into
the holder and `__vector_layout`'s `__alloc()` could not find `__alloc_`
(`cpp_norm_members_` takes both shapes now) --
`test/cpp/run/anoninit.cpp`. AND THE DIAGNOSTIC that found the next one:
`ccl_ir_units` ran the desugaring, the check and the lowering as one
conjunction, so any of them merely FAILING left the driver with nothing
to say but `the check or the lowering failed without saying why`; each
phase names itself now (`ir_fail(phase(desugaring | check | lowering))`).
`std::vector<int> v; v.push_back(1);` stops in the LOWERING, around the
declared-only `declval` instance that 0.51 taught the desugaring to make.

## 0.54 — M6's twenty-third step

**M6's twenty-third step (0.54): the lowering of what libc++ declares
but never defines, and the EMPTY CLASS.** A function item with NO BODY is
a PROTOTYPE: nothing to define, its `declare` line coming from the
externals a call names (`ir_item`'s first function clause) -- the
lowering had only the defining clause and merely failed. And
`std::declval` is not bodyless after all: libc++ gives it a body of one
`static_assert` and no return, so the function falls off its end, which
the lowering already closes with a zero of the return type -- but the
return type is `allocator<int>`, an EMPTY class, and an empty aggregate
has no leaves, so it classified as `direct([])`, pieces with no LLVM type
at all. C++ gives an empty class size ONE and one byte crosses a call
(`ir_abi_`'s first clause, `ir_pieces_type([], i8)`); empty classes are
everywhere in C++ -- an allocator, a comparator, a tag. AND TWO
DIAGNOSTICS, both of which earned themselves at once: `ir_items` names
the ITEM it cannot take (`ir_item_name/2`: the function or declaration
and its name, a body as its functor) and ATTACHES THE ITEM to any error
raised inside it (`ir_item_error/2`, a `not_lowered` passing through
unchanged), which turned a bare `type_error(atomic, scoped([global],
deallocate))` into the item that raised it. `std::vector<int> v; v.push_back(1);` now stops in
`vector`'s NESTED `__destroy_vector`, on `__alloc_traits::deallocate(...)`
whose scope arrives as `[global]` rather than the enclosing class's
typedef: the nested class reaches the enclosing class's TYPES now, and
this says its qualified NAMES do not follow the same road.

## 0.55 — M6's twenty-fourth step

**M6's twenty-fourth step (0.55): a qualified name inside a nested class,
a temporary called, an enum that is a strong typedef, and the members
libc++ defines OUT of their class.** (1) THE VEXING PARSE, ONE SCOPE
DEEPER: `traits::take(x);` as a statement inside a nested class's method
read as a DECLARATION of a globally qualified name -- `ccl_direct`'s
`name(Q)` clause takes a compound qualified name as a declarator-id, which
is right at file scope (`Shape::area`, `vector<T>::vector`, a
specialization `f<int>`) and never inside a function body, where such a
declarator declares nothing: `\+ ccl_in_block` (`ccl_locals/1` non-empty)
now says so. Reader version 38; `test/cpp/run/qualstmt.cpp`. (2) A
TEMPORARY'S `operator()`: `__destroy_vector(*this)()` is how libc++'s
vector destroys itself -- the callee is no function but an object built
in the same expression, so the call goes INSIDE the block that builds it
(`cpp_temp_call/3`, tried by the last `cpp_call` clause once the callee
is desugared), where that object has an address; `(*p)(a)` and `fs[i](a)`
take their own (`cpp_addressable/1`), no temporary. `test/cpp/run/tempcall.cpp`.
(3) A SCOPED ENUM'S UNDERLYING TYPE: libc++ writes `enum class
__element_count : size_t { }` as a strong typedef for a count, and the
reader kept nothing of `: size_t` while an enum with NO enumerators has
the members' shape of an empty struct -- so the tag resolved to
`%struct.__element_count = type {}` and the cast back to a count came out
as `sext` from a struct, which LLVM refused. An enum's members now carry
`enum_base(T)` first (`ccl_enum_members//3`, a scoped enum without a
written base marked `int` all the same), `ccl_is_enum_tag/1` is the ONE
test for them (the type resolution `ccl_tag_type/4`, the functional cast
`__element_count(n)`, the scope walk that must not take `Color::Green`
for a class's member), and the size (`ccl_size_align`) and the LLVM type
(`ir_base`) are the underlying type's. Reader version 39;
`test/cpp/run/strongenum.cpp`. (4) A FLOAT LITERAL PAST A DOUBLE --
`__LDBL_MAX__`, which every long double header writes and this compiler
lowers as a double -- is the largest finite double (`ccl_finite_float/2`
at the parser's one float-literal door, so both lexers agree): cocolog
WRITES an infinity as `inf.0` and its own reader refuses that, so the AST
beside a summary would not consult (`its clauses would not consult`, no
line) and the header was flattened and read again at every run, fifty
seconds against three. (5) A CLASS TEMPLATE'S MEMBER DEFINED OUT OF ITS
CLASS, `template <class _Tp, class _Allocator> void __vector_layout<_Tp,
_Allocator>::__set_bound_using_pointer(pointer __p) noexcept { ... }`,
which is how libc++ writes half of a container's members: the item was
DROPPED at registration (neither a specialization's name nor a
template's), so the instance's member kept the class's declaration, the
lowering made it a prototype and the linker said the symbol was undefined
(`nm -u` named `__size`, `__capacity`, `__end_ptr`,
`__set_bound_using_pointer`). Every such definition is kept by its
CLASS's name (`'$cpp_mdef'(Class, Key, TParams, Pattern, Member)`,
`cpp_mdef_item/4`: a method, a MEMBER TEMPLATE whose own parameters wait
for the call, a constructor, a destructor -- the reader gives the last
two the class's bare name, so their parameters bind in order), indexed
under it (`cpp_index_name`, which is also what `ccl_ast_write` writes
by), and an instance takes the definition whose pattern matches its
arguments (`cpp_match_pattern`) and whose parameters key alike
(`cpp_member_defs/5`, before the instance's class is registered).
`test/cpp/run/outofclass.cpp`. (6) THE RESULT TYPE IS PART OF THE
SIGNATURE, C++'s immediate context: `typename
__sfinae_underlying_type<_Tp>::__promoted_type __convert_to_integral(_Tp)`
is no candidate for a `_Tp` that is no enum, and the refusal its
resolution raises must make it none -- before, the candidate was chosen
on its parameters alone and the refusal came out as an error
(`cpp_result_holds/2` inside the candidate's own catch; only a DEPENDENT
QUALIFIED name is resolved there, the one shape written to fail, since an
`auto` or a `decltype` result is deduced later from the body and a plain
type or a template-id would cost a refused candidate an instantiation).
WHERE `std::vector<int> v; v.push_back(1); return (int) v.size();`
STANDS: with (1) to (4) it passed the desugaring, the safe part and the
LOWERING whole and made an object file of 9816 bytes -- the first time
the program reached one -- whose link named seven undefined symbols, the
four layout accessors and two vector members defined out of their class
among them; with (5) those bodies are found, and the walk that now enters
them stops in the DESUGARING at `__convert_to_integral(__n)`, where every
template overload of the name is refused, rightly, and the plain
overloads beside them are not candidates at all: a free function's
OVERLOADS are neither chosen by their arguments nor mangled apart (the
first definition of a name is emitted and every call goes to it), which
is the next stretch. Seven gates GREEN (the C++ one at 773 MB, libc++'s
at 1596).

## 0.56 — M6's twenty-fifth step

**M6's twenty-fifth step (0.56): FREE FUNCTION OVERLOADS, chosen by their
arguments and mangled apart.** C++ tells `int f(int)` from `double
f(double)` by the arguments and gives each its own symbol; C has one name
one function, which is what this compiler emitted -- so of libc++'s ten
`__convert_to_integral` overloads, one per integer type, only the FIRST
got a body and every call went to it, whatever it passed (a `size_t`
through the `int` one). Every free function is noted by name, by the key
of its parameters AS WRITTEN and by whether it has a body
(`'$cpp_fn'(Name, Key, Params, Defined)`), in a PRE-PASS over every unit's
items before anything is registered -- and, for a library header, over
every item of a name before any of them is (`cpp_note_fns/1` in
`cpp_hdr_load`) -- so a name is known to be overloaded or not before any
call to it is read. A name with TWO definitions of different parameters
mangles each `F.<keys>` (`cpp_fn_name/4`), as a method already did; a name
with ONE definition keeps it, so every C function, every `main` and
everything a linker must find by name is untouched, and so is a
DECLARATION of an overload (we may name only what we define) and anything
inside `extern "C"` (`'$cpp_cnames'`). The same name is used where the
function is DECLARED in the table, where it is EMITTED (`cpp_item`) and at
the CALL (`cpp_free_call/5`), from the one predicate. THE CHOICE: an
overload whose parameters take the arguments EXACTLY -- both resolved,
their top-level qualifiers dropped, and equal (`cpp_arg_exact/2`) -- wins
over any template, which is C++'s rule for a non-template that needs no
conversion (`__convert_to_integral(__n)` with `__n` a `size_t` takes the
`unsigned long` overload, where the two templates rightly refuse); else
the templates as before; and where NO template holds, the plain overloads
of the name, which are one overload set with them (`cpp_fn_best/4` over
`cpp_pick`, the methods' own scoring). A library header's inline function
is emitted once per OVERLOAD rather than once per name. Gated by
`test/cpp/run/freeoverloads.cpp` (six `kind` overloads chosen by type and
by arity, an exact `unsigned long` beating a template that would have
taken it, a static declared before it is defined) and
`test/cpp/run/aliastype.cpp` (the overloads a libc++ container is written
on: an alias of a class template's instance as the parameter type, free
and as a member). `std::vector<int> v; v.push_back(1); return (int)
v.size();` passes `__convert_to_integral` and stops where
`vector::__copy_assign_alloc(const vector &, false_type)` takes an ALIAS
of a class template's instance as a parameter: a library header's typedef
reaches the tables raw, and the passes rebuild them from the summary, so
the name must carry its instance to the lowering. Seven gates GREEN.

## 0.57 — C23, the C side's own level

**C23 (`-std=c23`), the C side's own level (0.57).** C's level is not C++'s
-- 17 and 23 are both languages' -- so it is a global of its own,
`'$ccl_c_std'` (`cstd(N)` in the driver's options, `-std=c23|gnu23|c2x|gnu2x`;
c17, c11 and c99 accepted, c89 and c90 refused), read by `ccl_c_std/1` and
asked in the grammar as `ccl_c23//0` (and `ccl_c_or_cpp//0` for a form C23
took from C++, read in C++ at every level). THE PREPROCESSOR answers the
level's macros first (`pp_c_std_table(S, c23)` before C17's table, as the
C++ levels already had it): `__STDC_VERSION__` is 202311L there and
201710L without, beside the `__STDC_*_H__` and `__STDC_EMBED_*` facts.
**THE FORMS ARE READ AT THE LEVEL, not lexed at it:** the keyword tables
are the LANGUAGE's, not the level's, and they are the native lexer's too
(k84 compares the two token for token), so C23's new keywords arrive as
the identifiers C17 has and the grammar takes them at `-std=c23` --
`bool` a type specifier, `true`, `false` and `nullptr` primaries,
`constexpr` an object's `const`, `thread_local` a storage word,
`alignas(...)` an attribute, `typeof_unqual` beside `typeof`. A C23
`constexpr` object is a CONSTANT: its name joins the enumerators' table
(`ccl_note_constants/2`, the same `'$ccl_enums'`), so an array's bound and
a static assertion fold it. `static_assert(e)` and `static_assert(e,
"msg")` are read in C as C++ already read them (`_Static_assert` too, C11's
spelling), at file scope and in a block, and A STATIC ASSERTION IS NOW
CHECKED where it folds -- IN C ONLY, since a C++ template may write
`static_assert(false, ...)` in a branch no instantiation takes, which
C++23 allows and a reader-time check would refuse. `[[attributes]]`, an
enum's underlying type (`enum E : unsigned char`) and `auto` deducing are
C++'s rules read in C from C23 (`ccl_c_or_cpp`). AND `typeof` IS RESOLVED:
nothing resolved it before (`ccl_resolve_base([typeof(X)], ...)`, a type
taken as it is and an expression through `ccl_type_of`), so a `typeof`
reached the lowering as a specifier it could not take; `typeof(K)` of an
OBJECT is its expression, where C's heuristics took a lone identifier for
a typedef name. **BOTH LEXERS** read C23's binary literal `0b1011` (which
is C++14's too) and the DIGIT SEPARATOR `1'000'000` in every scan --
decimal, hex, binary, a fraction and an exponent -- the native one
dropping it from the value it accumulates and from the text it spells for
`strtod` (`ccl_lx_puts_num`); the PP-NUMBER takes it as well
(`ccl_pp_number//1`, `ccl_lx_pp_number`), without which the preprocessor
read `1'000'` as a character literal and the line did not lex. Reader
version 40. Gated by `test/c/run/c23.c` (built at the level: a fixture's
`NAME.std` names it, as `NAME.flags` does in the C++ gate) and the
reader's `k87` and `k88`, with the new numbers in `test/c/lexer.c` under
`k84`. The rest -- `#embed`, `_BitInt(N)` lowered, `__VA_OPT__`, `#warning`, `__has_c_attribute`, `unreachable()`, `nullptr_t`, `typeof_unqual`, the `wb` suffix, the decimal types refused by name -- is 0.93's, below; `%b` is the C library's business.

## 0.58 — M6's twenty-sixth step

**M6's twenty-sixth step (0.58): six defects between the overload set and
the lambda, and the cleanup that hid them.** Following the vector probe
past `__convert_to_integral` turned up six, each its own rule: (1) an
ALIAS of a class template's instance carries the INSTANCE, not the name
(`typedef integral_constant<bool, false> false_type` taken as a parameter
type, which is how libc++ writes `vector::__copy_assign_alloc(const vector
&, false_type)`) -- the passes rebuild the tables from the summary, where
a library header's alias is raw, so a note behind the name does not
survive to the lowering, and only an alias whose WHOLE definition is a
template-id is resolved, since a name like `type' is some class's and the
global table's entry for it is another's; (2) A LIBRARY HEADER'S FREE
FUNCTION IS EMITTED WHERE IT IS CALLED (`'$cpp_fn'`'s origin
`lazy(Item)`, `cpp_use_fn/3`), as its classes and templates already were,
since libc++'s ten `__convert_to_integral` overloads include two over
`__int128_t` that nothing here lowers and a program calls one; (3) A TAG'S
OR A CLASS'S NAME CALLED WITH MORE ARGUMENTS THAN IT CAN TAKE is no
temporary (`cpp_tag_takes/2`, `cpp_class_takes/2`): namespaces flatten to
bare names here and libc++ has both `_Algorithm::__fill_n`, an empty tag
struct used as a template argument, and `std::__fill_n(first, n, value)`,
so the call built an aggregate of three items for a type with no members;
(4) A CLASS TEMPLATE DECLARED AND NEVER DEFINED is an INCOMPLETE TYPE a
template argument may name (`cpp_incomplete_instance/2`: the instance is
its name and its arguments, which is what a specialization's pattern
matches on) -- `__single_iterator<_It>` is declared only, a tag for the
algorithm dispatch; (5) THE ENCLOSING CLASS'S OWN REGISTRATION CAN ASK FOR
A NESTED CLASS, since declaring vector's members resolves types that
instantiate templates whose bodies call vector's members whose bodies name
`_ConstructTransaction` -- all before `cpp_nested_classes`, which comes
last so a nested class sees the enclosing one registered: the name is
recorded when the TYPE is and the class is registered on the first ask
(`'$cpp_nested'`, `cpp_nested_ready/1` in `cpp_class/2`); (6) a STATIC
member's type is resolved IN ITS CLASS (`cpp_in_class` around
`cpp_static_decls`, `cpp_resolved_type/2`), where `static constexpr const
type __max` reached the lowering as the global table's `type`, which is
some other class's. AND IN THE LOWERING: a call's VALUE bound to a const
reference gets the temporary C++ materializes for it (`ir_ref_of`, where
only a reference RESULT was taken and anything else refused), which
`std::min<size_type>(a.max_size(), n)` needs; and `initializer(I)` names
the TYPE that has no such member. Lowering version 12.
THE CLEANUP THAT HID THEM: this work was written, then reverted when two
fixtures failed in ways none of it explained -- a local with a plain
initializer had no type at its call. The cause was a single edit of mine
that removed a debugging trace: the replacement line put its `%` comment
BEFORE the rest of the clause, so `cpp_expr(...), ccl_declare(N, T)` was
commented out and no such local was ever declared. A comment inside a
clause ends the LINE, so a line is never rewritten with one in the middle;
and a regression that no change explains is a mis-edit until proved
otherwise. Seven gates GREEN. `std::vector<int> v; v.push_back(1); return
(int) v.size();` now stops in a LAMBDA inside one of vector's members,
on `__emplace_back_assume_capacity` named there: a lambda in a member
function must reach the enclosing class through the captured `this`, which
this compiler refuses (`capture_this`) -- the next stretch.

## 0.59 — M6's twenty-seventh step

**M6's twenty-seventh step (0.59): A LAMBDA CAPTURING `this`.** It was
refused by name (`capture_this`) since the fifth step, and libc++'s
`vector::emplace_back` writes one: `std::__if_likely_else(size() !=
capacity(), [&] { __emplace_back_assume_capacity(...); ++__end; }, ...)`.
The closure keeps the enclosing object as a REFERENCE member, `'$this'`,
which is what a `[&x]` capture already is -- the lowering reads a
reference member through and the check counts it as one -- and its
initializer is `this` itself; `'$cpp_closure_this'` records which closure
holds whose class. Inside the closure's `operator()` the enclosing class
is reached through it: a data member named bare is `this->$this.member`
(`cpp_closure_member/3`), a method called bare takes
`&this->$this` as its object (`cpp_closure_object/2`, the base's hops
with it, a virtual one dispatched as ever), a static is its global, and
`this` written out is `&this->$this`. A lambda captures it where `[this]`
says so and, under a DEFAULT capture, where the body names anything of the
enclosing class -- a data member, a static, a method, a MEMBER TEMPLATE
(which is how vector's lambda names `__emplace_back_assume_capacity`) or
`this` itself (`cpp_captures_this/4`, `cpp_has_member/2`). The closure's
RESULT TYPE is deduced from the first return DESUGARED IN THE ENCLOSING
CONTEXT (`cpp_lambda_ret/4`, as a method's `auto` result already was),
since a member named in the body has a type only once it is the call or
the access the desugaring makes of it -- and where the lambda stands, the
enclosing locals and `this` are still in scope. THE CHECK takes the
captured object as it takes a reference capture: the item of a `'$this'`
slot is walked, not refused as a borrow stored where it cannot be followed
(`ck_init_slots_`), the closure being scope-bound here. WITH IT, two more
of libc++'s forms: a FILE-SCOPE TYPEDEF called by its own name is a
temporary of the class it names or the cast it looks like
(`false_type()`, `size_t(n)`), which only a class-scope typedef had; and
`cpp_has_member/2` looks through a member template. Lowering version 13.
Gated by `test/cpp/run/capturethis.cpp` (a member named bare, a method
called, `this->` written out, a default capture taking it, a static),
clang++'s numbers. Not done: a closure that ESCAPES its scope with a
captured reference or `this` is not followed by the safe part (the hole a
`[&x]` capture already had), `[*this]` (the object by value), a lambda
capturing `this` inside a nested class's method reaching the enclosing
enclosing one. `std::vector<int> v; v.push_back(1); return (int)
v.size();` now stops in `std::forward`'s instance, on an argument that
still names a template parameter -- an instance keyed by an unresolved
name, the defect 0.49 met from the other side.

## 0.60 — M6's twenty-eighth step

**M6's twenty-eighth step (0.60): eleven forms between the free name and
the object file, and `std::vector<int>` COMPILED.** Following the probe
from the instance keyed by an unresolved name to the link:
(1) A TYPE THE READER CANNOT SETTLE stays `auto` -- 0.49 kept a qualified
name; a name the tables do not know, INSIDE A TEMPLATE, is another
template's own parameter come from the declaration the type was read off
(`auto __guard = std::__make_exception_guard(...)` takes that function's
result `__exception_guard<_Rollback>`), and deducing it keyed an instance
by that free name (`ccl_free_name/1`, reader version 41).
(2) A TYPEDEF IN A BLOCK IS SUBSTITUTED INTO THE STATEMENTS THAT FOLLOW,
as a template's parameter is: the typedef TABLE is one per unit, and half
a dozen libc++ functions each declare their own `_ValueType` -- one entry
survived, another function's, whose parameter was free.
(3) AN INITIALIZER IS WALKED ONCE: the `auto` clause desugared it to learn
the type and handed the RESULT to the pieces, which desugared it again --
a statement expression's temporary was declared twice (`no_constructor(C,
0)` where the second walk found it bare) and a lambda made a second
closure for nothing (`'$cpp_walked'/1`, the marker the pieces pass
through).
(4) THE MEMORY BUILTINS are the C library's functions (`__builtin_memcpy`
and kin, declared by `ir_cpp_prelude` when the file did not), and
`__builtin_constant_p` is FALSE, an assumption and a prefetch nothing.
(5) THE BIT COUNT folds where its argument does (`__builtin_popcountg`),
which is how libc++ writes a type's `digits`; cocolog's integers are
61-bit, so `~0` is -1 and the count is taken from the type's WIDTH.
(6) `__make_unsigned` and `__make_signed` answer (`cpp_signedness/3`).
(7) A C++ CAST FOLDS (`ccl_const_eval(ccast(...))`), without which
`type(~0)` stopped every constant behind it.
(8) A STATIC CONST NAMED BARE inside its class folds to its value, as
`C::value` already did -- `numeric_limits<ptrdiff_t>::__max` is built from
three such constants, and a static that does not fold is emitted `extern`
and the linker finds nothing.
(9) A TYPE'S NAME CALLED is one predicate for the three names a type has
(`cpp_type_call/3`): a class-scope typedef, a file-scope one, and an ALIAS
TEMPLATE's template-id (`__make_unsigned_t<type>(0)`).
(10) A PRVALUE USED AS A PLACE gets the temporary C++ materializes for it
(`ir_lval(call(...))`, where only a reference result was taken): `end()[-1]`
is vector's `back()`, and `f().x` is everyday C++.
(11) A LIBRARY HEADER'S FUNCTIONS ARE LOADED ON THE FIRST ASK from the
overload path too (`cpp_fn_ready/1`, whose load now throws through rather
than swallowing a refusal), and a lazy emission that FAILS is a refusal
(`function_not_emitted`), never a call with no definition behind it.
WHERE IT STANDS: `std::vector<int> v; v.push_back(1); return (int)
v.size();` compiles to an OBJECT FILE of 34 KB whose only unresolved
symbols are `malloc`, `free`, `memcpy` and libc++'s own
`std::__libcpp_verbose_abort` -- and that last one is C++-MANGLED in the
shipped library (`__ZNSt3__122__libcpp_verbose_abortEPKcz`), where this
compiler emits every name unmangled. ITANIUM NAME MANGLING FOR WHAT A
LIBRARY HEADER ONLY DECLARES is the next stretch, and the last thing
between the program and a binary that runs. Gated by
`test/cpp/run/libcxxforms.cpp` (a block typedef per function, a prvalue as
a place, an alias template called, a static const folding, the bit count),
clang++'s numbers; seven gates GREEN.

## 0.61 — M6's twenty-ninth step

**M6's twenty-ninth step (0.61): ITANIUM NAME MANGLING, and `std::vector<int>`
RUNS.** Four things between 0.60's object file and a binary that gives C++'s
answers, the first of them the name itself. (1) THE MANGLING, for what a
library header only DECLARES: this compiler emits every name it DEFINES
unmangled -- its own C-shaped symbols, `C.m.k`, `F.<keys>`, which nothing
else knows -- but a name it only CALLS must be the one the shipped library
EXPORTS, and libc++ declares `std::__libcpp_verbose_abort(const char *, ...)`
and ships it as `_ZNSt3__122__libcpp_verbose_abortEPKcz`. So a function that
a library header declares and never defines, that is not `extern "C"' and
whose namespace path is known, is called by its Itanium name
(`cpp_mangled_name/3`, chosen in `cpp_fn_name/4` where the overload mangling
sits): `_ZN`, the namespace path (`cpp_mangle_ns/2`, `St` for std), the name
length-prefixed, `E`, then the parameters (`cpp_mangle_params/4`,
`cpp_mangle_type/3` over `P` `R` `O` `K` and `cpp_mangle_basic/2`'s builtin
codes, `v` for `f()`, `z` for the ellipsis). WHAT IS NOT MANGLED keeps its
plain name, so the linker names the symbol rather than a wrong one being
found: a class-typed parameter (this compiler's class names are its own
mangling, not C++'s), a type no code encodes, and ANY signature whose
substitutable components repeat (`cpp_no_repeats/1`) -- Itanium writes the
second occurrence of a component as `S_`, `S0_` ..., and a straight
re-encoding would be a different symbol. A HEADER'S NAMESPACE PATH is
recorded as the items are indexed (`cpp_index_items/2` threads it,
`'$cpp_hdr_ns'(N, Path)`; `extern_c` is the path `c`) and written beside the
AST for a summary-served run (`'$cpp_hdr_ast_ns'`), since the namespaces
flatten to bare names everywhere else here; the declaration itself is
emitted once, `cpp_use_mangled/3`, with the ellipsis kept
(`cpp_fn_variadic/1`, `cpp_fn_arity_fits/3`). (2) A REFERENCE MEMBER IS
BOUND, never constructed and never assigned: its slot takes the object's
ADDRESS and every later use reads through it (`ir_ref_member/4`, which a
lambda's `[&x]` capture already relied on). libc++'s `vector` destroys
itself through a nested `__destroy_vector` that holds a `vector &`, and
taken as a member of a class with constructors that member initializer
became `operator=` into an uninitialized reference -- `vector::assign`,
`fill_n`, SIGSEGV. `cpp_member_inits`' first clause makes it
`bind_ref(arrow(this, N), E)`, which is `ir_bind_ref/2` in the lowering (the
address into the SLOT, where an assignment would write through it) and a
plain walk in the check, the object outliving its holder the way a reference
capture's does -- neither followed by the safe part. (3) PLACEMENT NEW,
which is what `std::__construct_at` is and every container's way of making
an element: the reader read the placement arguments and THREW THEM AWAY, so
`::new ((void *) __p) _Up(args)` was the allocating new it looks like, called
malloc and dropped the block -- a vector's size grew and its elements were
never stored. They are kept now, `new_at(Ps, new(T, As))` (reader version 42;
`ccl_new_node/3`), and the desugaring builds what the form means
(`cpp_new_at/4`): the class's constructor over the given address, or the
value stored through it, or a refusal by name (`placement_new`). (4) A CAST
TO A REFERENCE TYPE IS A BIND, not a conversion -- `static_cast<_Tp &&>(__t)`
is `std::forward`'s whole body, and as a value conversion it loaded the int
and made a pointer of it (`inttoptr`), so every element a container
constructed held the low half of an address. The value of a reference is its
address (`ir_expr(cast(T, E))` and `ir_ref_of/2` for `cast` and `ccast`
alike, `ir_lval` for the bind as a place), and a reference where a VALUE is
wanted is read through (`ir_convert/6`'s first clause), which is what the
rest of the lowering had done only at a call's result. Lowering version 15.
Gated by `test/cpp/run/stdvector.cpp`: ten `push_back`s through the slow
path, the split buffer and the relocation, `size`, `capacity`, `operator[]`,
`front`, `back`, and `std::vector<double>` for the whole machinery again --
clang++'s numbers, and `leaks` finds none. Seven gates GREEN (the C++ one
1037 MB warm, 2803 cold after the reader bump, which tripped a 2800 MB
watchdog on the first run and read as a RED: the finding below, again). NOT
DONE: the substitutions `S_`, `S0_` (a repeated component refuses instead), a
class-typed parameter in a mangled name, a mangled name for a TEMPLATE
libc++ ships instantiated, `new (p) T` told from `new (p) T()` (the reader
gives both no arguments, and the value-initialized form is what is meant), a
placement new of an aggregate with no arguments, `std::string` and the rest
of the containers.

## 0.62 — M6's thirtieth step

**M6's thirtieth step (0.62): A VECTOR OF THE PROGRAM'S OWN CLASS.** 0.61's
vector held ints: the elements were scalars, nothing was constructed in place
and nothing destroyed. `std::vector<Name>`, over a class with an `own` pointer,
a destructor and a move constructor, is where libc++'s container holds objects
the safe part owns -- and it asked three things, the first of them older than
libc++. (1) A TEMPORARY DIES AT THE END OF ITS FULL EXPRESSION. It was on
0.34's not-done list ever since ("a temporary's destructor"): a local of a
class with a destructor got the scope's defer and a temporary got nothing, so
`v.push_back(Name("a"))` left the object alive for good and a class over an
own pointer leaked one buffer per call. The full expression here is the
STATEMENT, so `cpp_stmt/3` is a wrapper around the walk (`cpp_stmt_/3`, every
old clause): it opens `'$cpp_temps'`, and `cpp_temporary` registers a
temporary of a class with a destructor there instead of declaring it in its
own block -- only the construction stays where the evaluation order puts it.
An EXPRESSION or a DECLARATION statement then takes the declarations before it
and plain destructor CALLS after it (`cpp_temp_scope`, spliced: C++'s point of
destruction exactly, in construction order and destroyed in the reverse); ANY
OTHER statement holds statements of its own, past which an early exit would
walk, so its temporaries get a DEFER at the end of a block wrapped around it --
which a `return` needs in any case, the defers running after its value is
computed. A LOOP's condition and step are evaluated at every turn and one slot
cannot hold a temporary per turn, so a temporary there is refused by name
(`cpp_expr_once/4`, `temporary_in_a_loop_condition`). (2) AND A TEMPORARY WHOSE
VALUE INITIALIZES ANOTHER OBJECT of its class is ELIDED, as C++17 guarantees:
the object it builds IS the by-value parameter or the result, and whoever holds
it destroys it (`cpp_temp_elide/2` at the two places that know -- a class-typed
by-value parameter in `cpp_copies_`, and `return`). The gate found this one:
destroyed at both ends, `v.push(Name("gamma"))` freed one buffer twice
(bag.cpp aborted) and `return Counter(n)` counted a destruction that never
happened (counter.cpp's numbers moved by one). (3) A PARAMETER'S TYPE IS READ
THROUGH AN ALIAS to see its VALUE CATEGORY (`cpp_param_ref/2` at the head of
`cpp_arg_fit`): libc++ writes `push_back(const_reference)` beside
`push_back(value_type &&)`, and no category can be read off the alias's own
name -- the const lvalue overload won every temporary, which then had to be
copied into it, and a class with an owner had two holders. (4) A STATEMENT
EXPRESSION IS A PLACE when it ends with one (`ir_lval(stmt_expr(...))`,
`ir_lvalue_form`), which is what every temporary this compiler builds is
(`({ C $tmp; ctor(&$tmp); $tmp; })`), so a reference binds to the OBJECT;
materialized as a prvalue instead, the temporary was copied and the copy's
owner was freed under the vector that had taken it. Lowering version 16. WHAT
RUNS: `std::vector<Name>` pushes temporaries by move, grows its buffer three
times relocating the objects, subscripts, calls their methods, is walked by a
RANGE-FOR (`for (const Name &x : v)`, which the desugaring's rewrite over
`size()` and `operator[]` already served) and destroys them all -- clang++'s
numbers, `leaks` finds none, and a `std::vector<Tag>` counts its constructions
and destructions to the same totals C++ gives. Gated by
`test/cpp/run/stdvectorown.cpp`; seven gates GREEN. NOT DONE: a class with a
COPY constructor rather than a move one in a vector (libc++ copies where it
cannot move), `v.insert`, `v.erase`, `v.resize` (a placement new of a class
with no arguments is refused by name), a temporary whose lifetime is extended
by binding it to a named reference, a temporary in a loop's condition,
`vector<vector<T>>`.

## 0.63 — M6's thirty-first step

**M6's thirty-first step (0.63): `std::string` from libc++, COMPILED FROM ITS
OWN BODY.** The SHORT-STRING OPTIMIZATION is what the type is built on, and
what it asked for first: `union __rep { __short __s; __long __l; }` with four
constructors. (1) **A UNION WITH CONSTRUCTORS IS A CLASS whose members share
storage**, so it goes a class's whole road -- registered, its methods emitted,
its constructors chosen -- while its LAYOUT stays a union's. `'$cpp_union'(C)`
says which, the class's tag carries the marker `union_tag` first and
`ccl_is_union_tag/1` is the ONE test for it (as `enum_base` and
`ccl_is_enum_tag` already told a scoped enum from an empty struct, 0.55); the
emitted declaration is `union(C, [union_tag|Data])` so the tag noted FROM it
agrees, `ccl_tag_type/4` answers a union spec, and `cpp_class_of_type_` takes
that spec as its class all the same. A UNION'S CONSTRUCTOR initializes AT MOST
ONE member and leaves the others alone (`cpp_union_inits`) -- they share the
bytes, and default-constructing the rest would overwrite them and demand
constructors none of them have. (2) A **NESTED UNION** is a nested TYPE of its
holder (`cpp_nested_name`, `cpp_nested_spec`): with constructors it is the
class above, with only data members a plain union emitted once under the
mangled name. (3) A **LAYOUT IS OVER DATA MEMBERS**: a C++ class's tag carries
its constructors, methods and typedefs beside them, and a nested one reaches
`ccl_members_layout_`/`ccl_union_layout` as the reader gave it -- both skip
what is not a `member/3` now. (4) A **NESTED TYPE NAMED AS A TYPE is registered
on the first ask**, whatever its kind (`cpp_type`, `'$cpp_nested'`): a LAZY
library instance never runs the enclosing class's nested registrations, and
`basic_string` names its own `__rep` as a template argument -- that union's
members name `__short` and `__long`, two more of its nested types. (5) A
**CLASS-SCOPE ENUMERATOR is a constant of the class**, as a static const is
(`cpp_class_enums`, kept RAW and folded in the class's words like a static's):
`enum { __min_cap = (sizeof(__long) - 1) / sizeof(value_type) > 2 ? ... : 2 }`
is named bare in members and in an array's bound. (6) A **NESTED CLASS SEES THE
ENCLOSING CLASS'S STATICS**, as it already saw its types (`cpp_static_const`
through `'$cpp_enclosing'`): `__long`'s constructor divides by its holder's
`__endian_factor`. (7) A **SCOPED NAME, FLATTENED, GOES THROUGH THE TYPE HOOK
AGAIN**: `std::string` is an ALIAS of a template-id, and flattened to the bare
name and left there it reached the lowering as `basic_string<char>` itself.
(8) **`C() = default;` IS the implicit default constructor** and keeps the
class default-constructible where its other constructors would have suppressed
it (`'$cpp_default_ctor'`, `cpp_trivial_default`) -- `__rep` writes it beside
three others. (9) A **CANDIDATE WHOSE ARGUMENT DOES NOT FIT IS TRIED LAST**,
after every template (`cpp_args_fit` in `cpp_method` and `cpp_ctor`; the
arity-only set stays the last resort, so nothing that resolved before resolves
differently): libc++ writes `explicit basic_string(const allocator_type &)`
beside the constructor TEMPLATE that takes a `const char *`, and the plain one,
alone in fitting the ARITY, won every `std::string s = "abc"' -- which came out
empty. (10) A **DEFAULT ARGUMENT IS DESUGARED WHERE IT IS FILLED IN**, which is
where C++ evaluates it (`cpp_fill_defaults`): it is kept raw from the
declaration, and `const _Allocator & __a = _Allocator()` on that same template
reached the lowering as a call to a type; `cpp_subst` turns a bound `T()` into
the type's name called, the temporary road a class's name already takes.
(11) A **`const` LOCAL OF INTEGRAL TYPE WITH A CONSTANT INITIALIZER IS A
CONSTANT EXPRESSION**, as C++ has had it since C++98 (`cpp_note_const`, noted
after the initializer is DESUGARED, since the class constants in it fold only
then; C gained this at C23, `ccl_note_constants`). (12) An **EXPLICIT TEMPLATE
ARGUMENT IS EVALUATED WHERE IT BINDS** (`cpp_bind_explicit`, `cpp_bind_targs_`
through `cpp_targ_value`), whatever road brought it: the class path evaluated
first and the FUNCTION and MEMBER template paths handed the argument over raw,
so `__align_it<__boundary>(n)` -- libc++'s alignment step over that `const`
local -- keyed its instance by the NAME and left it in the body. (13) A
**SPECIALIZATION'S DEFINITION BEATS ITS OWN FORWARD DECLARATION**
(`cpp_pick_spec`, through `cpp_template_class_def`): libc++ declares
`struct char_traits<char>;` early and defines it later, both matching `[char]`
and equally specialized, so the empty one won and every `traits_type::copy`
was a call to nothing; a declared-only specialization still stands where none
is defined (0.58's incomplete type). The alias resolution TRACES what it
catches (`alias_refused(N, W)`), which is how (8) was found -- it had been
swallowed into a silent fallback. Lowering version 17. Gated by
`test/cpp/run/stdstring.cpp`: a SHORT string in the object's own bytes and a
LONG one in a buffer the destructor frees, `size`, `c_str`, `operator[]`,
`empty` -- clang++'s numbers, `leaks` finds none, 557 MB to build. Seven gates
GREEN (the C++ one 1581 MB).
NOT DONE, AND MEASURED: **the MUTATING operations do not fit in memory here.**
`s += "def"` alone peaks past 2800 MB in 17 s and was killed -- and it is no
runaway: 120 instantiations, 46 of them distinct, with
`__allocator_traits_base.allocator.char` asked 283 times and
`allocator_traits.allocator.char` 267. It is the no-GC accumulation of the
finding below over a hundred library instantiations, not a loop, so the way
through is the compile's memory and not a budget. Also not done: `push_back`,
`operator==`, a string COPIED, `operator+`, `substr`, `find`, iterators,
`std::string` as a member or in a container.

## 0.64 — M6's thirty-second step

**M6's thirty-second step (0.64): THE COMPILE'S MEMORY -- a loop, not a
weight.** 0.63 left `s += "def"` peaking past 2800 MB in 17 s on a 16 GB
machine, and read it as the no-GC accumulation of a hundred library
instantiations. MEASURED, it was nothing of the kind. THE PHASES, taken apart
(`cicilang++ -fsyntax-only` against the whole build, then `ccl_cpp_units` alone
under the guard): the READ is 48 MB and 0.9 s, and the DESUGARING is all 2900
of the rest -- so the question was never the reader's. Two guesses failed
before the measurement paid: scoping every class instantiation inside `\+ \+`
moved the peak by nothing (its results are facts and globals, which survive a
scope, and its intermediates were not the weight), and the desugaring's lookup
tables are SMALL (`'$cpp_class_types'` 127 entries after a `std::string` build,
`'$cpp_lazy'` 51). What found it was the trace at a LOW cap, which names what
is in flight when the memory goes: the last event was always
`instance(initializer_list.value_type)` -- an instance keyed by a FREE NAME,
0.49's defect once more -- and then silence while the machine filled. THE
CAUSE: substituting `_Ep := value_type` into `initializer_list<_Ep>` turns its
own `typedef _Ep value_type` into **`typedef value_type value_type`**, a
typedef that IS its own definition, and `cpp_type`'s class-scope clause
resolved that name in that class by asking for itself, without end and without
a trace. A TYPEDEF THAT IS ITS OWN DEFINITION IS NOW LEFT ALONE
(`cpp_self_typedef/2`, the guard on that clause): the name stays as written and
whatever needs it refuses by name, as everything else here does. 2936 MB and
16 s become 495 MB and 4 s. AND AN INSTANCE ASKED FOR AGAIN ANSWERS ITS NAME
AND NOTHING ELSE (`'$cpp_iname'(N, Args, Name)`, the arguments compared with
`==` so an unbound one matches nothing): a clause retrieval COPIES the term it
answers, and `cpp_instantiate_class_` fetched a template's whole item -- one of
libc++'s containers is hundreds of members -- to recompute a name it had
computed before, 267 times for `allocator_traits<allocator<char>>` alone. The
asks fall from 550 to 51 and the peak by a further tenth. WHAT IT BOUGHT, all
measured on this machine: the desugaring of `s += "def"` 2936 -> 495 MB;
`test/cpp/run/stdstring.cpp` built through `cicilang++` 557 -> 422 MB; THE C++
GATE 1581 -> 752 MB. The libc++ gate stays at 1882 MB, the biggest number left
and the READER's -- a flatten and a parse of `<vector>` and `<string>` under a
fresh HOME, one-time per header and cached after. Lowering version 18. Seven
gates GREEN; no new fixture, since the shape that looped needs an argument no
valid C++ can write, and the gates' peaks are the measurement. NOT DONE: why
`initializer_list<value_type>` is asked with a free name at all (the class-scope
typedef did not resolve where `basic_string` declares that constructor) -- the
loop is gone but the badly keyed instance remains; the reader's 1882 MB; and
`s += "def"` still refuses, now by name (`undeclared('__func_')` in a scope
guard), which is a form and no longer a wall.

## 0.65 — M6's thirty-third step

**M6's thirty-third step (0.65): A CANDIDATE'S PARAMETER TYPE IS READ IN ITS
OWN CLASS'S WORDS.** 0.64 stopped the loop and left the question it hung on:
why is `initializer_list<value_type>` asked for at all? THE INSTRUMENT first,
since the obvious one lies: `cpp_where` keeps only the innermost breadcrumb, so
a trace inside `cpp_instantiate_class` reports `in(class(initializer_list))` --
the ask naming itself. Read BEFORE the wrap, with the class context beside it,
it named the caller at once: `ask(initializer_list, [typedef(value_type)],
from(stmt(expr, 3)), ctx(none))` -- the statement `s += "def"` in `main`, no
class in context at all. THE CAUSE: libc++ gives `basic_string` five
`operator+=` overloads, one of them `operator+=(initializer_list<value_type>)`,
and `cpp_method` scored every candidate AT THE CALL SITE, where the context is
the caller's or none. A parameter type is written in ITS CLASS's words:
`value_type` there is `basic_string`'s, and read in `main` it resolved to
nothing and instantiated `initializer_list` under the free name. The scoring
and the pick now run inside `cpp_in_class(C, ...)` in `cpp_method` and
`cpp_ctor` -- the rule a member template's signature has had since 0.51 ("a
parameter written `const allocator_type &' is in the traits class's words, not
the caller's"), for the plain overloads too. With it, `std::string s; s +=
"def";` makes 45 instances and NOT ONE keyed by a free name (it asked for four
before); its build is 495 -> 455 MB. The C++ gate goes the other way, 752 ->
861 MB, and rightly: resolving a parameter in its class is real work that was
being skipped. 0.64's self-typedef guard stays as the net under it. Gated by
`test/cpp/run/classwords.cpp`, which EARNS its line -- without the fix the
`List<char>` overload wins a `List<int>` argument (both candidates score zero,
so the first declared takes it) and LLVM refuses the call; with it, clang++'s
numbers.

## 0.66 — M6's thirty-fourth step

**M6's thirty-fourth step (0.66): A DATA MEMBER THAT IS CALLABLE, and the
string that GROWS.** A local of a class with `operator()` has been callable
since M6's fifth step; a MEMBER was not, and libc++'s `__scope_guard` holds
the closure it was made with and writes `__func_()` in its destructor -- which
is the whole of how `basic_string` unwinds an append. The member is reached the
way every bare member name is (`this->f_`, a base's hops with it) and its own
class's `operator()` takes its address, the local's road one scope further in.
FIVE MORE the growing string asked for, each its own rule. (1) A PRVALUE OF THE
CLASS IS THE OBJECT, elided, as C++17 guarantees -- no constructor runs and
none is looked for: `auto __guard = std::__make_scope_guard(f);` handed a
`__scope_guard` to the only constructor `__scope_guard(_Func)` has, which takes
the closure, and LLVM refused the store; the temporary that built it is the
object too, so the statement must not destroy it (`cpp_temp_elide`, as a
by-value parameter and a return already did). (2) A CONVERTING CONSTRUCTOR AT A
CALL (`cpp_converting_ctor`, in `cpp_copies_` beside the copy): libc++ hands a
`__long` where a `__rep` is wanted, and `__rep(__long)` is how a string becomes
long. It converts only where the argument's type is KNOWN and is not already
the parameter's class -- what cannot be typed is never converted, which is the
guard `bag.cpp` earned when a `Name` temporary, whose type nothing could tell,
was wrapped in a second `Name`. (3) A PARAMETER IS RESOLVED IN ITS CLASS BEFORE
IT IS SCORED (`cpp_param_ref` through `cpp_type`): 0.65 put the SCORING in the
class, but the fit test resolves with the INFERENCE, which knows typedefs and
tags and no class scope, so `__rep(__long __r)` -- two of `basic_string`'s
nested classes by their short names -- still fitted nothing. (4) THE SAME TYPE
FITS ITSELF, registered class or not: two plain structs alike scored zero,
since only a registered class was compared. (5) A MEMBER INITIALIZED FROM A
CALL takes its class from the DESUGARED form where the raw one cannot tell it:
libc++'s copy constructor writes
`__alloc_(__alloc_traits::select_on_container_copy_construction(__str.__alloc_))`,
and unasked it read as a member with no constructor to take it. AND (6) A
DEFAULT ARGUMENT BELONGS TO THE DECLARATION, which C++ forbids an out-of-class
definition to repeat -- so taking the definition whole (0.55) threw the
defaults away, and `__grow_by_without_replace(a, b, c, d, 0)`, five arguments
to six parameters, found no member of that arity at all (`cpp_keep_defaults`,
`cpp_member_params`). FOUND ON THE WAY, older than this step: a temporary
hoisted out of its own block (0.62) was DECLARED nowhere until the statement
that holds it was walked, so nothing could type the value the block yields;
`cpp_temporary` declares it where it registers it. AND A LESSON THE GATE
TAUGHT: two clauses of `cpp_keep_defaults` both matched the empty case, which
made `cpp_member_def` nondeterministic, so `findall` gave the member twice and
a constructor was emitted twice -- `invalid redefinition of function`. A
refusal now TRACES its breadcrumb (`refuse(What, in(W))` under `'$cpp_trace'`),
which is how two of these were found. Lowering version 20. WHAT RUNS:
`std::string` appends (`+=`, a `const char *` and in a loop), `push_back`s,
grows out of its own bytes into a heap buffer, and is COPIED into a string with
a buffer of its own -- clang++'s numbers, `leaks` finds none. Gated by
`test/cpp/run/callable.cpp` (a callable member with two overloads, a converting
constructor, a default argument on the declaration) and an extended
`test/cpp/run/stdstring.cpp`. Seven gates GREEN (the C++ one 846 MB). NOT DONE:
`operator+`, `substr`, `find`, iterators (`operator==` is 0.67's).

## 0.67 — M6's thirty-fifth step

**M6's thirty-fifth step (0.67): A FREE OPERATOR TEMPLATE OF A LIBRARY
HEADER.** `s == "abc"` is how a string compares, and libc++ writes it as
`template <class _CharT, class _Traits, class _Allocator> bool operator==(const
basic_string<...> &, const _CharT *)` -- a free function TEMPLATE. It reached
nothing here: `'$cpp_free_ops'` holds the operators the PROGRAM writes out, and
a header's item is indexed by NAME, which for `operator('==')` is a compound
that `cpp_template_name` would not take -- so the template was neither indexed
nor registered, and the `==` stayed a raw one on a struct, which LLVM refused.
Two halves. (1) A FREE OPERATOR TEMPLATE IS NAMED as a written-out one already
is, by its word and arity (`cpp_free_operator`, `op.eq.2`): with a name, a
library header indexes it, `cpp_hdr_load` registers it and `'$cpp_tmpl'` holds
it. (2) AT THE CALL, `cpp_operator`'s free branch falls through to THE
FREE-FUNCTION ROAD (`cpp_call(none, id(Name), [A|Args], E)`) -- its lazy load
by name, its candidate set, its deduction, all of which the plain free calls
have had since 0.56 -- and the answer is taken ONLY where the callee comes back
DECLARED; otherwise the form stays as it was, so a scalar `==` is untouched and
a name that resolves to nothing is refused where it always was. THE NAMING IS
WHAT A SUMMARY'S AST HOLDS, so `ccl_reader_version` is bumped (43) and every
summary and AST is rewritten: without that, a cached header keeps the old index
and the operator is invisible. Reader version 43, lowering version 21. Gated by
`test/cpp/run/stdstring.cpp`, which now compares (`1 0`); with it the probe
this whole stretch began from -- a string constructed, appended to, pushed back
on, grown into a heap buffer, COPIED and COMPARED -- matches clang++ line for
line. Seven gates GREEN. A NOTE ON THE COLD RUN, beyond the finding below: the
C++ gate peaked at 2803 MB twice after the version bump and was KILLED at the
2800 cap both times -- and a killed run writes no summary, so it stays cold for
ever. The way through is to warm the cache OUTSIDE the gate, one fixture build
at a time (836 and 699 MB here), and then run it (1057 MB). The libc++ gate,
which runs under a fresh HOME and is therefore always cold, went 1883 -> 2445
MB, the operator templates being part of what it now writes.

## 0.68 — M6's thirty-sixth step

**M6's thirty-sixth step (0.68): AN INSTANTIATION INSIDE `\+ \+`, and the type
an argument has.** `std::vector<std::string>` -- libc++ holding libc++ -- took
2824 MB and 108 s and was killed at the cap. THE MEASUREMENT FIRST: the READ is
102 MB and 1.3 s, so the desugaring is all of the rest; the trace at a low cap
shows 185 spends and 80 DISTINCT instances with nothing asked twice, so it is
genuine breadth and no loop. AND THE FIX IS THE ONE 0.64 TRIED AND MEASURED AS
NOTHING: an instantiation's whole body -- substituted, registered, its members
walked and emitted -- now runs inside `\+ \+`, whose results (facts and
globals) survive the scope while every intermediate is reclaimed, cocolog
reclaiming on backtracking and by nothing else. 0.64's conclusion ("its
intermediates were not the weight") was drawn while the LOOP dominated and is
CORRECTED here: with the loop gone they are most of it. `vector<string>`'s
desugaring 2824 -> 1091 MB and 108 -> 9 s; THE C++ GATE 1057 -> 847 MB and THE
LIBC++ GATE 2445 -> 1902, the biggest number this repository has.
THREE DEFECTS the probe turned up on the way. (1) THE TYPE AN ARGUMENT HAS is
one predicate now (`cpp_arg_type/2`: through a `move' in either spelling, else
through the DESUGARED form), and `cpp_arg_fit` asks IT rather than the
inference: a member initializer and a call's arguments are both RAW when they
are scored, and libc++ writes `__rep_(std::move(__str.__rep_))' -- which the
inference cannot type, so every candidate scored the 1 an unknown type earns
and the FIRST constructor won, `__rep(__short)' for a `__rep', storing a union
into a byte. `cpp_init_arg_class/2` is that predicate plus the class, one rule
where there were two. (2) THE ARITY ALONE IS THE LAST RESORT, but never a
CLASS-typed parameter for an argument of ANOTHER class (`cpp_args_no_clash/2`,
in `cpp_ctor`'s and `cpp_method`'s fallbacks): that is no conversion this
compiler makes. (3) AN UNNAMED TEMPLATE PARAMETER HAS NO NAME TO LOOK UP --
libc++ writes its SFINAE guard as one -- and `memberchk(P-A, B)` with P unbound
takes whatever is FIRST in the bindings, so an instance was named one way where
it was emitted and another where it was called; it contributes no key and binds
nothing, in both places alike. AND a member TEMPLATE's instance that fails to
emit is a REFUSAL (`member_instance_not_emitted`), the name being noted DONE
before the emission runs -- 0.46's rule, which had never reached this path.
Lowering version 22. NOT DONE: `std::vector<std::string>` does NOT run. It
compiles through the desugaring in 10 s at 1144 MB, where it could not be
compiled at all, and stops at
`undeclared('allocator.S.construct.S.S.S_p.S_rr')`: the member template
`allocator<string>::construct` is NOTED as an instance and never EMITTED, so
the call names a definition that is not there. The refusal above does not fire
for it, which says the emission is not failing but being SKIPPED -- the name is
already noted when the first ask arrives -- and that is where the next step
starts. AND A LESSON FROM THE SAME AFTERNOON: two further rules tried here --
"no argument whose type is KNOWN may score zero" in the last resort, and the
`move' forms before the general type lookup in `cpp_arg_type' -- BROKE
`stdstring.cpp` and were reverted. The overload rules interact, and a change to
one is worth no more than the gate it passes. Seven gates GREEN.

## 0.69 — M6's thirty-seventh step

**M6's thirty-seventh step (0.69): A NAME IS NOTED WHEN IT IS EMITTED, NOT
BEFORE.** 0.68 left `std::vector<std::string>` stopping at
`undeclared('allocator<string>::construct...')` -- the member template NOTED as
an instance and never EMITTED -- and the refusal added there did not fire,
which said the emission was not failing but being SKIPPED. THE ANSWER: a
member template's instance is made wherever its call is MET, and that can be
INSIDE another candidate's signature check, whose catch swallows the refusal
and rejects the candidate -- SFINAE, by design, since 0.44. The note was taken
BEFORE the emission (to stop a recursive ask looping) and SURVIVED the
abandonment, so every later ask answered with a definition that had never been
emitted and the lowering met a call to nothing. The name is IN PROGRESS while
the emission runs -- which is all a recursive ask needs -- and NOTED only once
it is done; a throw clears it, as `cpp_isolated` and `cpp_in_class` already
restore what they set aside (`'$cpp_making'`, `cpp_make_member/9`). THE SAME
SHAPE SAT IN `cpp_use_member`, a LAZY class's member emitted where it is first
named (`cpp_make_lazy/5`): that is how `basic_string`'s own MOVE CONSTRUCTOR
was lost. TWO MORE from the same probe. A type that is KNOWN but names no class
-- a library template's raw, unsubstituted result -- no longer hides the
DESUGARED form from `cpp_init_arg_class`, which 0.66 taught to ask it and 0.68's
`cpp_arg_type` had short-circuited. And the MOVE FORMS come before the general
type lookup in `cpp_arg_type`: `<utility>` arrives with every container, so
`std::move` is a DECLARED template whose raw result type would otherwise win --
tried in 0.68, reverted with an innocent change beside it, and measured alone
here. AND BOTH CANDIDATE FILTERS ARE DETERMINISTIC NOW: `cpp_args_fit` and
`cpp_args_no_clash` each had two base clauses that matched the empty case, so
`findall` returned a candidate TWICE -- 0.66's lesson (`cpp_keep_defaults`) in
two more places. Lowering version 23. WHERE IT STANDS:
`std::vector<std::string>` compiles through the desugaring AND the safe part
whole, in 10 s at 713 MB, emitting `allocator<string>::construct` and
`basic_string`'s move constructor -- two defects further than 0.68 -- and stops
in the LLVM it emits, inside that move constructor: `__rep_(std::move(
__str.__rep_))` still picks `__rep(__short)` by arity where the implicit
bitwise copy is meant. The member-initializer overload choice is the next step.
Seven gates GREEN; no new fixture, the libc++ fixtures being what these rules
are measured by (each broke while they were wrong).

## 0.70 — M6's thirty-eighth step

**M6's thirty-eighth step (0.70): A VECTOR OF STRINGS -- libc++ holding
libc++.** Two rules, both about reading a parameter for what it is. (1) A
MEMBER INITIALIZER'S OVERLOAD CHOICE READS ITS PARAMETER IN ITS OWN CLASS'S
WORDS. `cpp_args_no_clash`, the filter on the arity-only last resort, tested the
RAW parameter type, and libc++'s union-class writes `__rep(__short __r)' with
its holder's NESTED names -- which the inference cannot resolve, so
`cpp_class_of_type` failed, the clash went unseen and
`__rep_(std::move(__str.__rep_))' took `__rep(__short)' by arity: a union stored
into a byte. It goes through `cpp_param_ref` now, the door `cpp_arg_fit` has
used since 0.66 -- the same rule as 0.65's and 0.66's, in the one place that
still missed it. (2) A CONVERTING CONSTRUCTOR SERVES A PARAMETER THAT BINDS A
TEMPORARY, not only a by-value one: a const lvalue reference or an rvalue one,
for which C++ materializes one (`cpp_param_takes_class/2`). And TEMPLATE
constructors count (`cpp_converting_ctor`'s second clause, over `'$cpp_mt'`),
since libc++ writes `basic_string(const _CharT *, const _Allocator & =
_Allocator())' as one -- which is the whole of how `v.push_back("alpha")' makes
a string out of a `const char *'; without it the `const char *' went to
`push_back(const_reference)' as though it were a string, and the vector held a
pointer to a literal. A clash that a converting constructor BRIDGES is no
clash, which is what keeps `__reset_internal_buffer(__long)' -- `__rep(__long)'
-- alive beside (1). Lowering version 24. WHAT RUNS: `std::vector<std::string>`
pushes four strings, one of them past the short-string bytes, grows its buffer
twice relocating them, subscripts, is walked by a RANGE-FOR and destroys them
all -- clang++'s numbers, `leaks` finds none, 825 MB to build. Gated by
`test/cpp/run/stdvectorstring.cpp`. Seven gates GREEN (the C++ one 805 MB).
NOT DONE: `vector<string>`'s `insert`, `erase` and `resize`; a `string` as a
class's member; `std::map` and the associative containers; `<iostream>`.

## 0.71 — M6's thirty-ninth step

**M6's thirty-ninth step (0.71): THE ROAD TO `<iostream>` -- read whole,
`std::cout` named by its symbol, and fourteen forms between the include and
the locale.** THE READER (version 47), by the census loop, eleven gaps:
C23's `_BitInt(N)`; the GNU spellings `__signed`, `__const`, `__volatile`,
`__restrict`, `__inline` and their `__x__` forms (`ccl_gnu_word/2`, one clause
per word, one rule for all); a NESTED CLASS DEFINED OUT OF ITS ENCLOSING CLASS,
`class locale::facet : public __shared_count { ... }`, read as `class(K,
scoped([locale], facet), ...)` (`ccl_class_qual`, and `ccl_current_class` sees
through the scoping); an enumerator with attributes; `virtual` on either side
of the access word in a base clause; a member template's name after
`template`; `new T[n](args)` and `new T[n]{...}` as `new_array_init` (refused
by name); `__int128_t` and `__uint128_t` in the typedef seed; `extern "C++"`
TRANSPARENT -- its items spliced where it stood (`'$splice'`, the door macros
use), where `extern "C"` keeps its block -- both spellings had been one item,
and libc++'s `<math.h>` wrapping `namespace std` in one put a namespace under
the C marker, on which `ccl_flat_items` FAILED and the header's AST beside the
summary was never written (the stale one of an older, 74-item read served,
and `cout` was not in it -- the silent failure that hid everything below); and
A TYPE TEMPLATE ARGUMENT NAMES NO DECLARATOR (`ccl_targ_type`): `__conditional_t<
is_copy_assignable<first_type>::value && is_copy_assignable<second_type>::value,
pair, __nat>` read `...::value &&` as an rvalue reference whose declarator-id was
the second half, and libc++'s `pair` lost half its condition. THE AST BESIDE
THE SUMMARY: a failed write is traced (`ast_not_written`), `ccl_flat_items`
keeps the C marker under a namespace, the text is built A HUNDRED ITEMS AT A
TIME inside `\+ \+` (`ccl_ast_chunks`; the cold read of `<iostream>` 2598 ->
1987 MB, the same bytes) and the summary's sections are lists of TERMS made
into text the same way (`ccl_sum_chunks`); and since its content follows
`cpp_index_name/2`, A CHANGE THERE BUMPS THE READER VERSION TOO -- the only
stamp the file has, and a stale one served the old index silently. THE EXTERN GLOBAL: `extern ostream cout;` is
indexed (`cpp_index_name` on an extern declaration), registered on the first
ask (`cpp_lazy_var`) under the symbol libc++ exports, `_ZNSt3__14coutE`
(`cpp_mangled_var`: the header's namespace path `[std, __1]` from
`'$cpp_hdr_ns'`, checked against `nm` of `libc++.tbd`), and `cpp_global_var/2`
gives `std::cout` and a bare `cout` that name. THE DESUGARING, seven forms,
each with a ten-line reproduction that ran in a second where the probe took
ten: (1) A NESTED ENUM is a type of the class that holds it, as a nested class
is (`cpp_nested_enum`: one tag `Enclosing.Name` at file scope, its enumerators
global names as every enum's are) -- `ios_base::seekdir`; and a scope path ENDS
at a nested enum (`cpp_scope_walk`), where `B::strong::two` had become the
static member `B.two`. (2) A NESTED CLASS DECLARED IN ITS HOLDER AND DEFINED
OUT OF IT: `scoped([locale], facet)` is `locale.facet` in the index, the
registrations and the emission (`cpp_class_item_name`), the forward
declaration `class facet;` names the type (`cpp_nested_name`'s `class(N,
none)` clause, no class registered for it), and the holder's types are in
scope inside (`cpp_encloses`). (3) MULTIPLE INHERITANCE WHERE EVERY BASE AFTER
THE FIRST IS EMPTY -- no data, no slots, nothing to construct: C++'s empty base
optimization gives it no bytes, so it is a SCOPE and no sub-object here
(`cpp_extra_bases`, `cpp_empty_class`, `'$cpp_extra'`), and `cpp_base_scope/2`
is the one door every base lookup goes through -- typedefs, static consts,
static members, `cpp_has_member`, a method (`cpp_extra_method`, the object's
own address being the base's); a second base WITH storage or slots is refused
as before. `ctype<char> : public locale::facet, public ctype_base`. (4) A PURE
VIRTUAL SLOT NOTHING OVERRIDES holds a NULL in the table (`cpp_slot_def`), where
the link named `SC.zero.0` and nothing defined it -- `__shared_count::
__on_zero_shared() = 0`; `cpp_not_abstract` still never fires, since
`cpp_slot_impl` answers the pure declaration, a gap older than this step. (5)
THE DEFAULT-ARGUMENT DROP RAN OFF THE END: a method's recorded defaults do not
count `this`, and a call the desugaring had already built carries it, so
`cpp_drop` had no clause and the whole constructor walk FAILED -- silently --
on `facet(size_t __refs = 0) : __shared_count(static_cast<long>(__refs) - 1)`
(`cpp_drop(_, [], [])`; `ctor_walk_failed` prints the body now). (6) THE
IMPLICIT DEFAULT CONSTRUCTOR C++ DELETES: a member whose class has no default
constructor leaves its holder without one, and the class stays the aggregate
it was written as (`cpp_members_default`, `cpp_default_ctor_exists`, a test
that emits nothing) -- `__in_out_result` holding an `ostreambuf_iterator`,
built `return { a, b }`; making the constructor refused the whole class. (7)
AN ALIAS NAMED AS A BASE names the INSTANCE (`cpp_base_name` asks `cpp_class`
of the atom first): `__libcpp_is_contiguous_iterator<char *> : true_type`.
Lowering version 25 (the null slot). WHERE `std::cout << "hello"` STANDS: the
desugaring goes through `basic_ostream<char>`, `basic_ios`, `ios_base`,
`basic_streambuf`, `locale::facet`, `__shared_count`, `ctype<char>`,
`__pad_and_output` and `std::copy`'s `__unwrap_range` -- 236 loads and
instances, 1166 trace lines, 9 s and 816 MB warm -- and stops at
`std::pair<char *, char *>`'s constructors: every one is a template whose
parameter `__enable_if_t<_CheckArgsDep::template __is_pair_constructible<_U1,
_U2>(), int> = 0` asks a CONSTEXPR STATIC MEMBER FUNCTION TEMPLATE to be
EVALUATED AT COMPILE TIME (its body one `return is_constructible<_T1,
_U1>::value && ...`); taken for a class template it refuses
`template_without_body(__is_pair_constructible)`, and every two-argument
constructor is rejected. A constexpr function of one `return` could fold as a
static const's initializer does (`cpp_fold_static`: instantiate, desugar in
the class's words, `ccl_const_eval`) -- the next stretch, and named. Gated by
`test/cpp/run/nestedenum.cpp` (plain and scoped, as a member's type in a
template) and `test/cpp/run/facet.cpp` (the facet shape whole: declared in,
defined out, an abstract first base, an empty second, a defaulted base
constructor, the slot filled by the derived class), clang++'s numbers; and
`<iostream>` read WHOLE in `test/libcxx.pl` (662 items). Seven gates GREEN
(the C++ one 2245 MB, the libc++ one 1743 MB with `<iostream>`; a cold read
of `<iostream>` alone 2009 MB, under the 2800 MB cap the owner set).

## 0.72 — M6's fortieth step

**M6's fortieth step (0.72): THE CONSTEXPR FUNCTION, and the road to a running
`std::cout` -- `cicilang: ok` to the link, five symbols short.** THE STEP ASKED
FOR: a constexpr function of ONE `return' FOLDS where a constant is wanted
(`cpp_const_value/2`, the door `cpp_targ_value` and `cpp_fold_static` now take
constants through): the instance is emitted as any member template's is, its
body read back from the emitted item (`'$cpp_out'`), already desugared in its
class's words so the traits in it are constants, its parameters bound to the
call's arguments (`cpp_param_binds`, `cpp_replace_ids`; `this' to the null it
was passed), the return's expression folded -- bounded in depth, since such a
function may call itself. With it, TWO READINGS the class knows better than
the reader: `X::template f<U>()' in a template argument reads as a FUNCTION TYPE
returning `X::f<U>' (the reader cannot know f is a member function template;
the class can: `cpp_targ_value`'s `fn(scoped(_, tmpl(M, _)), [], false)`
clause makes it the call), and a qualified member template call with its
arguments given (`cpp_call`'s `scoped(Path, tmpl(M, TArgs))` clause). libc++'s
`pair` chooses every constructor by `__enable_if_t<_CheckArgsDep::template
__is_pair_constructible<_U1, _U2>(), int> = 0', and `std::pair<char *, char *>
q(p, p)` runs. Gated by `test/cpp/run/constexprfn.cpp` (the shape on the
program's own classes, a static const from a constexpr call with an argument,
the same function called at run time) and `stdtraits.cpp`.
THE ROAD, followed from there to the link, twenty-three forms, each with its
reproduction: (1) a pack in a BUILTIN TRAIT's arguments expands
(`type(pack(T))` in `cpp_subst_elems`: `__is_constructible(_Tp, _Args...)`);
(2) an AGGREGATE TEMPORARY's `operator()` (`cpp_temp_call` for a compound
literal: `_Algorithm()(a, b, c)`, its block made here) -- `aggcall.cpp`; (3)
`__remove_cv`, `__remove_const`, `__remove_cvref` of a POINTER
(`cpp_strip_quals`: they took only a specifier list, and `is_void<char *>` is
`_BoolConstant<__is_same(__remove_cv(_Tp), void)>`); (4) `X::f(args)' ON A
CLASS WITHOUT SUCH A MEMBER REFUSES (`no_member(C, M, K)`), the rejection the
detection `decltype((void) pointer_traits<P>::to_address(...))` needs --
flattened to a global name it was void either way and every pointer had a
`to_address`; (5) `typename _Tp::x' WITH `_Tp` A SCALAR, a pointer, a reference,
a function: the segment carries the type (`nonclass(A)`, `cpp_subst_path`) and
resolving the name refuses (`cpp_type`, `cpp_expr`), where the parameter's name
stayed in the path and flattened as a namespace into a FREE NAME (unique_ptr's
deleter, a function pointer, asked for `::pointer`); (6) a `static' POINTER or
ARRAY member is a static (`cpp_static_type`: the word sits in the innermost
base's qualifiers, and `static const char __src[33]' was DATA, so a class of
statics alone was no empty base) -- `staticbase.cpp`; (7) A LAZY POLYMORPHIC
CLASS EMITS ONLY WHAT ITS TABLE NAMES (`cpp_slot_fns`: its own slot
implementations, IN PROGRESS while their bodies are walked -- uflow calls
underflow -- and noted after), where it emitted every member: `std::cout <<
"hello"' walked 234 members, `operator<<(double)`, `swap`, the whole input
side, and the run fell 363 -> 113 instances, 17 -> 6 s (the trace
`make_lazy(Name)` says which member a program pulls in); (8) a slot's RESULT
type resolved in its class (`cpp_slot_ret`: `virtual int_type uflow()` reached
the lowering raw in the table's struct); (9) A DESTRUCTOR A LIBRARY HEADER
DECLARES AND THE SHIPPED LIBRARY DEFINES is called by its Itanium name
(`cpp_dtor_name`: `_ZNSt3__18ios_baseD1Ev`, `_ZNSt3__16localeD1Ev`, a nested
class by its segments; a template instance's nested class keeps its own name,
`cpp_plain_lib_class`); (10) THE VIRTUAL DESTRUCTOR TAKES TWO SLOTS
(`'$dtor_del'`), the Itanium layout -- and it must, since a virtual call INTO an
object the library made (cout's streambuf, its `overflow`) indexes that
object's own table, and with one entry every slot past the destructor was off
by one; (11) VIRTUAL INHERITANCE, as the ABI lays a COMPLETE OBJECT out
(`'$cpp_vbase'`, `cpp_base_layout`): the class's own table pointer first, its
own members, the shared base LAST -- `basic_ostream : virtual public basic_ios`,
where cout is the ostream's vptr and the basic_ios at offset 8 (measured with
clang++: 160 = 8 + 152) and every field we read sat eight bytes off; the
class's table holds its own virtuals (`cpp_vbase_dtor_slots`: the base's
virtual destructor makes its own slots, first), a destructor is virtual by
`override' too, and a class with a virtual base and no destructor gets the
implicit one (its base's runs on the sub-object where it lies); the reader
KEEPS `virtual' on a base (`base(virtual(A), Q)`, reader version 48) --
`virtualbase.cpp` (clang++'s offsets and size); (12) A DISPATCH READS THE
OBJECT'S OWN CLASS'S TABLE (`cpp_dispatch` casts the pointer to `C.vt`, the
tables laid out base first: `ctype<char>::widen` found no `do_widen` in
`__shared_count.vt`); (13) `return { a, b }' builds the RESULT TYPE's object,
through its constructor or as the aggregate; (14) A NESTED CLASS OF A LAZY
CLASS IS LAZY (registered eagerly, `sentry' walked its constructor, which
calls flush(), whose body declares a sentry -- mid-registration, so the ask
failed and the local was a plain value), and `cpp_nested_ready` clears its
in-progress mark on a throw (0.69's rule); (15) A NESTED CLASS DEFINED OUT OF
ITS CLASS TEMPLATE, `template <...> class basic_ostream<_CharT,
_Traits>::sentry { ... }' (`cpp_mdef_item`'s class clause, `cpp_member_shape`
for `nested(...)`: kept by the class's name like a member's body and merged
into the instance's forward declaration; reader version 49, since the index
changed); (16) A POINTER PARAMETER TAKES BY WHAT IT POINTS TO
(`cpp_pointer_fit`: `void *' any object pointer, a FUNCTION pointer only a
function, a class one a class -- scored as any two pointers, the manipulator
inserter `operator<<(basic_ostream &(*)(basic_ostream &))' took `cout <<
"hello"', and the literal was CALLED: SIGBUS at the literal's address); (17) A
FREE OPERATOR THAT FITS EXACTLY BEATS A MEMBER THAT NEEDS A CONVERSION
(`cpp_member_exact`, `cpp_free_operator_call`: C++ weighs them together, and
`cout << "hello"' is the free template over `const _CharT *', never the member
over `const void *'); (18) A SCALAR PARAMETER NEVER TAKES A CLASS ARGUMENT
without a conversion operator, in the arity-only last resort too
(`cpp_args_no_clash`: `__s = std::copy(...)' on an ostreambuf_iterator took its
`operator=(char)' and the struct was sign-extended to a byte); (19) A CLASS
VALUE WHERE A BOOL IS WANTED converts through its `operator bool'
(`cpp_to_bool`: if, while, do, for, `!', `&&', `||' -- the contextual
conversions, an explicit one included: a stream's sentry, `if (__s)'); (20) THE
SPECIALIZATION ORDERING takes a template-id over opaque names as an INCOMPLETE
INSTANCE (`cpp_opaque_types`, 0.58's shape): `ostreambuf_iterator<$opaque._CharT,
...>' instantiated refused, so that `__pad_and_output` was no more special than
the generic one and the tie went to the first declared; (21) `__to_address` and
`std::is_void` on pointers, `is_copy_assignable`, all C++'s answers now
(`stdtraits.cpp`); (22) ON THE C SIDE, a global char array initialized from a
SHORTER literal is zero-filled to its bound (`ir_str_tail`: `char s[33] =
"abc"' was refused by LLVM, `[17 x i8]` into `[33 x i8]`); (23) the AST beside
the summary bumped the reader version twice more, as the rule says; (24) IN THE
LOWERING, A POINTER OR A REFERENCE TO A DERIVED OBJECT CONVERTS TO ITS BASE BY
THE BASE'S OFFSET (`ir_convert`'s class-pointer clause, `ir_base_path`,
`ir_base_hops` over the `$base' members; `ir_ref_to` at the three binds -- a
local reference, a reference parameter, a cast to a reference): every base
sat at offset 0 until now, so `A *base = &x' copied the pointer unchanged and
`base->twice()' read `b''s bytes, the gate's first RED of this step; a null
pointer is not spared the offset (not done). Lowering version 27 (the
table's shape, the conversion). WHERE `std::cout << "hello"' STANDS: it
desugars, passes the safe part, lowers and reaches the LINK -- `cicilang: ok' up
to it -- FIVE SYMBOLS SHORT, each named: the constructor and the destructor of
`basic_ostream<char>::sentry`, members of a nested class DEFINED OUT OF ITS
CLASS TEMPLATE (the member-definition index keys them under the nested name
alone, and the merge does not reach into a nested class's members);
`__num_put_base::__identify_padding(char *, char *, const ios_base &)`, a
declared-only STATIC MEMBER of a plain class, shipped as
`_ZNSt3__114__num_put_base18__identify_paddingEPcS1_RKNS_8ios_baseE` -- the
SUBSTITUTIONS `S1_` and `NS_...E` that 0.61 left undone; `ctype<char>::do_narrow(char,
char)`, a declared-only member of a template SPECIALIZATION,
`_ZNKSt3__15ctypeIcE9do_narrowEcc` -- a template's instance in a mangled name,
also undone since 0.61; and `__to_chars_integral`'s instance
`.c1.unsigned_long.0`, noted and never emitted. The next stretch is the
Itanium mangler's second half and the nested class's out-of-class members. The
build is 11 s and about 1000 MB warm; the cold read of `<iostream>` 1425 MB.
Gated by `test/cpp/run/constexprfn.cpp`, `aggcall.cpp`, `staticbase.cpp`,
`virtualbase.cpp` and `stdtraits.cpp`, clang++'s numbers. Seven gates GREEN
(the C++ one 1140 MB, the libc++ one 1811 MB).

## 0.73 — M6's forty-first step

**M6's forty-first step (0.73): THE ITANIUM MANGLER'S SECOND HALF, and
`std::cout << "hello, cicilang++\n"` RUNS.** THE MANGLER (`cpp_ita_*`): what
0.61 spelled -- `_ZN', a namespace, a name, `E', builtin parameters, refusing
any repeat -- is spelled with the ABI's SUBSTITUTION TABLE threaded through
(`cpp_ita_sub`, `cpp_ita_note`: every prefix, nested name and non-builtin type
a candidate in order, its second occurrence `S_', `S0_', `S1_' ... in base 36),
a class a NESTED NAME (`N <prefix> <len>name E'; `St' for std, no candidate;
`St3__1' one), a template instance `<len>name I <args> E' (its template-name
prefix a candidate; as a TYPE the instance itself, as a member's PREFIX the
template-id too -- the two cases clang++ told apart: `ff(string, string)' ends
`S5_', `tw<char>::two(ct2<char>, ct2<char>)' `S3_'), `K' after `_ZN' for a const
method, a function directly in std UNSCOPED (`_ZSt19uncaught_exceptionsv'),
`C1' and `D1' for a constructor and a destructor (0.72's `cpp_dtor_name`
folded in). MEASURED against clang's own symbols for six shapes, all six equal.
AT ONE DOOR, `cpp_mangle/4`: a member a library header DECLARES and the shipped
library DEFINES (`cpp_shipped_member`: no body in the class's list AND no
out-of-class definition in the header, `cpp_defined_out_of_class`; the
parameters RESOLVED IN THE CLASS before spelling, `do_narrow(char_type, char)'
being written in ctype's words) is named by its symbol where it is declared,
called and slotted -- `__num_put_base::__identify_padding',
`ctype<char>::do_narrow', `locale::use_facet'; a shipped STATIC DATA MEMBER
alike (`cpp_static_name': every facet's `static locale::id id',
`_ZNSt3__15ctypeIcE2idE'). What the encoder cannot spell keeps its own name, and
the link names it. ON THE WAY TO THE LINK AND PAST IT, twelve more: (1) THE
MEMBERS OF A NESTED CLASS DEFINED OUT OF ITS CLASS TEMPLATE, `template <...>
basic_ostream<_CharT, _Traits>::sentry::sentry(basic_ostream &)': the reader
keeps the enclosing path on such a constructor or destructor (`ctor_def(L,
scoped([tmpl(basic_ostream, ...)], sentry), ...)`, reader version 50; the bare
name had lost which class's sentry it was), the index keys them under the
enclosing class (`in_nested(N, M)', the key `nested_member(N, K)'), and the
merge reaches into the nested class's members once the class is whole
(`cpp_nested_defs`, `cpp_member_def_key`); (2) A PLAIN CLASS'S OUT-OF-CLASS
BODIES, `inline ios_base::fmtflags ios_base::flags() const { ... }', indexed
by the class's name, noted BEFORE the batch registers (`cpp_note_hdr_mdefs`:
the class item comes first in the header) and merged in `cpp_lazy_class` --
unindexed, `flags()' took the mangled road and libc++ hides it from its ABI;
(3) a nested class KNOWN BY NAME ALONE (`class locale::id', forward-declared,
defined out of class) loaded when its name resolves as a type
(`cpp_touch_nested`), so its struct exists for the lowering; (4) A HEADER'S
INLINE VARIABLE -- C++17's, defined in the header with its initializer,
exported by no library: libc++'s digit tables, `__digits_base_10',
`__pow10_64' -- indexed and emitted as a `linkonce' global by the program
that names it (`cpp_lazy_inline_var`, its items desugared; reader version 51,
the index changed); named through the summary alone it was an `external
global' and the link named five; (5) 0.69's RULE IN ITS THIRD AND FOURTH
PLACES: a function template's instance (`cpp_instantiate_function_`) and a
library free function's overload (`cpp_use_fn`) are noted when EMITTED, in
progress while they emit -- `__to_chars_integral' was declared and never
defined; (6) A HEADER'S LOAD DECLARES AT FILE SCOPE (`cpp_isolated` around
`cpp_register_lazy`): met inside a function's body walk, a load declared the
header's functions into that function's open frame -- `ccl_declare` takes the
innermost -- and they went with it: `__convert_to_integral.unsigned_long'
declared in one walk, undeclared at the next call, its type unknown and
`_Size' undeducible; (7) A FUNCTION TEMPLATE'S REDECLARATION TAKES THE DEFAULTS
OF ITS FIRST DECLARATION (`cpp_fn_merge_defaults` over the candidates with the
same template parameters, kind for kind and name for name, through 0.44's
`cpp_merge_defaults`): C++ lets a default template argument stand on the first
declaration only, and libc++'s definition of `__to_chars_integral' refused
`cannot_deduce(anon)' while its prototype held and was emitted as a declare;
(8) A NAME QUALIFIED BY A PARAMETER IS A NON-DEDUCED CONTEXT in a function
parameter too (`cpp_path_dependent` in `cpp_match`): `typename
_IterOps<_AlgPolicy>::template __difference_type<_InIter> __n' binds nothing
and resolves once the others bind it -- taken for a class template by its last
segment it refused deduction_failed; (9) NO STANDARD CONVERSION between a
pointer and an arithmetic parameter in a template's acceptance
(`cpp_scalar_mismatch`: a bool takes a pointer, nothing else does) --
`cout << "hello"' took the CHAR inserter and passed the literal's address
truncated to a byte; (10) A QUALIFIED CALL INSIDE A CLASS PASSES `this'
through the base sub-objects, never virtual (`cpp_base_hops`; a static
method keeps its null): libc++'s basic_ios forwards `good()' as `return
ios_base::good();', and it went out with a null this -- SIGSEGV in
`ios_base::good'; (11) THE BIT BUILTINS AT RUN TIME are LLVM's intrinsics
(`ir_bit_builtin`: `__builtin_clz*', `ctz*', `popcount*' and the generic `g'
forms with their second argument, over the argument's own width, a raw
`declare' line since `i1' has no C spelling) -- 0.60 folded them where the
argument was a constant, and `__countl_zero' calls one at run time; (12) A
CLASS THAT IS NOT TRIVIALLY COPYABLE OR DESTRUCTIBLE CROSSES A CALL BY
INVISIBLE REFERENCE and comes back through a hidden pointer, WHATEVER ITS
SIZE -- the Itanium C++ ABI's rule on both architectures, which the shipped
library follows: `ios_base::getloc()' returns a `locale', one pointer wide with
a destructor, through sret, and taken as a register value the library wrote
its result over `this' -- SIGSEGV in `locale::locale(const locale &)'. The
desugaring marks such classes (`'$cpp_nontrivial'`, `cpp_note_nontrivial`: a
destructor, a copy or move constructor, a virtual function, or a base or a
member that is such) and the lowering classifies them `indirect'
(`ir_nontrivial_class` in `ir_abi_`); the program's own classes follow the
same rule on both sides of every call. Lowering version 28. WHAT RUNS:
`std::cout << "hello, cicilang++\n"' -- the library's own object, written to
through libc++'s basic_ostream, its sentry, ostreambuf_iterator,
`__pad_and_output', std::copy and the streambuf's virtuals into libc++'s
`__stdoutbuf' -- and a chained `<< "one " << "two\n"'; 19 s and about 950 MB
warm, the cold read of `<iostream>` 1498 MB. Gated by
`test/cpp/run/stdcout.cpp` and the mangler's check in `test/cpp.pl` (clang's
six symbols). Seven gates GREEN (the C++ one 2125 MB, of which the fixture
itself is 917 -- the peak is the cold flatten of `<sstream>` and ten more
headers the reader's fixtures pull in after the version bump, rewritten inside
the gate; the libc++ one 1833 MB). NOT DONE: the ostreambuf `__pad_and_output' still loses to the
generic one (a conversion counted on the temporary; it works through
std::copy); `std::endl', a number inserted (`num_put', walked and untested),
`std::cin'; a function-type or array parameter in a mangled name; a null
pointer converted to a base at an offset; explicit constructors in the
acceptance test.

## 0.74 — M6's forty-second step

**M6's forty-second step (0.74): `std::endl` -- A FUNCTION TEMPLATE'S NAME AS
AN ARGUMENT.** `cout << "hello" << std::endl' hands `endl' -- a function
TEMPLATE, `basic_ostream<C, T> &endl(basic_ostream<C, T> &)' -- to the member
`operator<<(basic_ostream &(*)(basic_ostream &))', and C++ deduces the
template's arguments from the TARGET, the function type the pointer parameter
names ([temp.deduct.funcaddr]); everywhere else a template's name is a
NON-DEDUCED CONTEXT ([temp.deduct.call]/6). Here the inference typed
`std::endl' as the template's RAW signature (a function template is declared
under it, 0.49), `basic_ostream<_CharT, _Traits>' with both names free, and
`_Traits' met a stray BLOCK TYPEDEF of another template's body (`using _Traits
= __segmented_iterator_traits<_SegmentedIterator>' in `__for_each_segment',
in the unit-wide table since 0.43 kept a function's block typedefs there):
`basic_ostream<_CharT, __segmented_iterator_traits<_SegmentedIterator>>' was
instantiated on the free names, then `basic_ios', `basic_streambuf' after it,
115,000 flattens and 412 s to the 2800 MB cap. THE RULE, at the one door an
argument's type has (`cpp_arg_type`): a name that is a function template's
and no local's (`cpp_fn_template_ref`, `id(F)' or `std::F') is `tmplfn(F)',
no type of its own; a candidate's FUNCTION-POINTER parameter (or a reference
to a function, or a function type) DEDUCES it -- `cpp_target_deduces`,
`cpp_target_bindings`: the template's parameter types against the target's,
reference for reference (`cpp_match_target`, since a target is matched
exactly where a call's argument decays), then its result, the defaults and
the constraints, the first candidate of the name that holds, a refusal
inside being no candidate -- and scores it EXACT (`cpp_arg_fit_` 3,
`cpp_arg_exact`, `cpp_param_accepts`); any other parameter takes it not at
all (0); a call's deduction binds nothing from it (`cpp_deduce_one`); and
where the candidate is chosen (`cpp_ref_args_`, the door the member call and
the operator form share) the argument BECOMES THE INSTANCE'S NAME, emitted as
any instance is (`cpp_deduce_target` -> `cpp_instantiate_function_`). Of
basic_ostream's three manipulator inserters only the `basic_ostream &(*)
(basic_ostream &)' one deduces `endl'; the `basic_ios &' and `ios_base &'
ones refuse. TWO MORE it uncovered: A FUNCTION POINTER TAKES ONLY A FUNCTION
OF ITS TYPE (`cpp_pointee_fit` through `cpp_fn_types_agree`: parameter for
parameter and the result, the names dropped; a function DECAYS to a pointer
in `cpp_pointerish`) -- 0.72's `cpp_pointer_fit` let a function pointer take
any function, and `std::hex', `ios_base &(ios_base &)', would have gone to the
first inserter and been called on the wrong sub-object; and A FUNCTION TYPE
KEYS BY ITS RESULT AND ITS PARAMETERS' TYPES, never their names
(`cpp_type_key(fn(...))', `fn_<result>_<params>_p') -- the generic flattening
put the parameter NAMES in, so `(*pf)(basic_ostream &)' declared and
`(*__pf)(basic_ostream &__os)' defined out of class were two members. WHAT
RUNS: `endl' from its own body -- `__os.put(__os.widen('\n'))' through a
sentry and an ostreambuf_iterator, `__os.flush()' through `rdbuf()->pubsync()'
into the streambuf's virtual `sync' and libc++'s `__stdoutbuf' -- and the
inserter's `return __pf(*this);', a call through a function-pointer
parameter; `std::flush' is the same road. Gated by `test/cpp/run/stdendl.cpp`
(after a literal, chained twice, `std::flush', `endl' alone), clang++'s lines;
18 s and 917 MB warm, no more than the hello; the C++ gate GREEN at 1694 MB,
the only gate the change touches. Reader version 51 and lowering version 28
unchanged. NOT DONE: an OVERLOAD SET of plain functions as an
argument (C++ picks by the target; here a name has the one declared type);
`std::hex' and kin scored by type now but not gated; `<iomanip>''s
manipulators, which are classes; a number inserted (`num_put'), `std::cin'.

## 0.75 — M6's forty-third step

**M6's forty-third step (0.75): `std::cin` -- THE EXTERN TEMPLATE'S INSTANCE IS
SHIPPED, and the string's true layout.** `cin >> n' in clang's own object is a
call to `_ZNSt3__113basic_istreamIcNS_11char_traitsIcEEErsERi' -- the library
holds `basic_istream<char>' whole (`extern template class basic_istream<char>;'
in the header), and the num_get machinery behind the extractor is never
compiled by a program. THE SAME HERE: an `extern template class X<Args>;' item
of a library header is indexed by the template's name and noted at the load
(`cpp_note_extern`, `'$cpp_extern'(N, Args, all)`); an instance of N with those
arguments first (the defaults fill the rest) does NOT take its out-of-class
member definitions at the merge (`cpp_member_def_key` asks `cpp_extern_shipped`),
so they stay DECLARED, and a declared member of a library class is called by its
Itanium name (0.73's `cpp_shipped_member`, now for an operator member too, whose
clause had sat before the door with a cut). WHICH MEMBERS: libc++ hides a member
from its ABI with `_LIBCPP_HIDE_FROM_ABI', which this preprocessor spells as
visibility hidden plus always_inline; every such out-of-class definition of the
four stream classes is written `inline' and every exported one without it
(measured on the flattened `<iostream>`: 41 + 29 + 16 definitions, no
exception), so the `inline' the reader keeps (`cpp_mdef_item`'s Qs) is the mark,
no attribute kept; a member with its body in the class stays compiled (libc++
writes those hidden without exception); never a nested class's definition, never
a member TEMPLATE (a second template wrapper: no explicit instantiation covers
one). The other spelling, `extern template void basic_string<char>::__init(const
value_type *, size_type);' -- libc++ lists its string's exported members one by
one -- names ONE member by its name and its parameters as written
(`'$cpp_extern'(N, Args, member(M, K))`). WHAT THE INDEX CHANGE COST: reader
version 52, every summary rewritten. THE MANGLER, twice more: an operator member
by the ABI's code (`cpp_ita_op`: `rs', `ls', `pL' ...; a member with no
parameter the unary one, `cpp_ita_unary`), and THE KEY OF A CLASS TYPE IS ITS
CHAIN'S OWN, as a prefix level's is -- the ABI counts `basic_istream<char>' the
prefix and the type as ONE entity, and with `N ... E' around the type's key the
sentry's constructor spelled its parameter afresh (`RNS0_IcS2_EE') where the
library has `RS3_'; c34 spells nine symbols now, the two sentries and
`operator>>' among them, checked against the shipped library's export list.
THREE MORE THE FIXTURE ASKED: (1) A STATIC NAMED THROUGH AN OBJECT, `__ct.space'
(`cpp_static_through_object` in the member and arrow clauses of `cpp_expr`):
ctype_base's masks through the facet, which C++ allows and the lowering met as a
data member that was not there; (2) `m()' WRITTEN OUT IN A MEMBER INITIALIZER IS
VALUE-INITIALIZATION, which ZEROES a class whose default constructor is not
user-provided (`memset' over the member, `cpp_member_inits`): basic_string's
`: __rep_()' left the union as garbage, its `__is_long_' bit read long and
`clear()' wrote through a null pointer; (3) A BITFIELD KEEPS ITS WIDTH
(`cpp_split_members` had replaced every member's third argument with `none';
`cpp_bit_width` folds it in the class's words as an array's bound is): libc++'s
string is `__is_long_ : 1; __size_ : 7' in its short form and `__is_long_ : 1;
__cap_ : 63' in its long one, and with the widths dropped each was a whole byte
or word -- the string 40 bytes where the library's is 24, self-consistent, so
the string fixtures never knew; the library's own `push_back' wrote by its
layout and our `size()' read by ours. `sizeof(std::string)' is 24 now, as
clang's. THE GATE reads a fixture's input from `NAME.stdin' when it exists, else
nothing (`/dev/null'). WHAT RUNS: `test/cpp/run/stdcin.cpp` -- `cin >> n >>
word', `cin >> d', `cout << n * 2 << " " << word << endl', `cout << d + 0.5 <<
endl' -- an int, a word and a double read through the shipped extractors (the
string's through libc++'s hidden template compiled here: the istream sentry
shipped, `rdbuf()->sgetc()' and `sbumpc()' into the streambuf's virtuals,
`ctype<char>::is', the shipped `push_back'), the numbers written through the
shipped inserters; clang++'s lines, 34 s and 895 MB warm. Not one C++ symbol
in the object is outside the library's export list. Seven gates GREEN (the C++
one 1407 MB, 103 checks; the libc++ one 1753 MB; the cold read of `<iostream>`
1949 MB with the extern items in its AST). NOT DONE: `std::getline',
`cin.get()', `cin.fail()' as a test, the manipulators (`std::hex', `setw'),
formatted floating input past a plain double, `std::cin' tied flushing checked
only through the lines printed.

## 0.76 — M6's forty-fourth step

**M6's forty-fourth step (0.76): `std::getline` -- six forms in libc++'s own
body.** `std::getline(cin, line)' is a hidden template compiled from the header
(`getline(basic_istream<C, T> &, basic_string<C, T, A> &, C)': a sentry, the
buffer's `gptr()' and `egptr()' span, `char_traits::find' over it, an append,
a lambda that bumps the stream), and the member `cin.getline(buf, n)' the
shipped `basic_istream<char>::getline(char *, streamsize, char)' (0.75's
rule). Following the template's body: (1) `auto' UNDER A REFERENCE OR A POINTER
is deduced from the initializer (`cpp_auto_deduce`: `auto &__buffer =
*__is.rdbuf()' the referent's type, nothing decayed; `const auto *__first =
__buffer.gptr()' the pointee's, the qualifiers kept; `cpp_has_auto` finds the
`auto' under the layers) -- only a plain `auto' was, and everything read
through the reference local could not be typed; (2) A REFUSAL INSIDE A HELD
CANDIDATE'S BODY IS THE CALL'S (`instance_refused(Name, W)' out of
`cpp_instantiate_function__`; the template road of `cpp_call` and
`cpp_free_operator_call` never fall through on it): the getline that held and
whose body refused (1) fell to the plain overloads of the name, where C's
`getline(char **, size_t *, FILE *)' won by arity and the stream and the string
went to it as pointers -- LLVM refused the cast, and would not have for a
looser one; (3) `__builtin_char_memchr' is `memchr' (`cpp_builtin_call`), what
`char_traits<char>::find' is written on; (4) NO POINTER FOR AN ARITHMETIC
PARAMETER IN THE LAST RESORT EITHER (`cpp_args_no_clash` asks 0.73's
`cpp_scalar_mismatch`): `__str.append(__first, __last)' took the shipped
`append(const char *, size_type)' by arity, the pointer as the SIZE, and the
library asked for a string the size of an address (`std::bad_alloc' at run
time); C++ takes the member template `append(_InputIterator, _InputIterator)',
which the emptied candidate set now reaches; (5) A MEMBER TEMPLATE'S
DECLARATION LENDS ITS TEMPLATE-PARAMETER DEFAULTS to the out-of-class
definition at the merge (`cpp_keep_tdefaults` through 0.44's
`cpp_merge_defaults`, 0.73's rule for a free template's redeclaration):
libc++ declares `template <class _ForwardIterator, __enable_if_t<..., int> =
0> void __init(_ForwardIterator, _ForwardIterator);' and defines it without the
`= 0', and taken whole the definition refused cannot_deduce(anon) -- the
iterator-pair append constructs a string through it; (6) A MEMBER'S DEFAULT
ARGUMENT IS DESUGARED IN ITS CLASS (`cpp_default_ctx` from the declared `this'
parameter, `cpp_in_class` around it in `cpp_fill_defaults`), where C++ looks
its names up: `__reset_internal_buffer(__rep __new_rep = __short())' names the
string's nested `__short', and filled with no context it named nothing; AND A
CLOSURE IS ENCLOSED BY THE CLASS IT IS MADE IN (`cpp_lambda_scope`,
`'$cpp_enclosing'`), as a nested class is, so the enclosing class's types,
statics and enumerators are in scope in a lambda's body whether or not `this'
is captured (the record 0.59 kept only for the captured object). WHAT RUNS:
`test/cpp/run/stdgetline.cpp` -- a line, a comma-delimited field, the member
`getline' into a char array, `while (std::getline(cin, line)) n++' to the end
of input (the stream's `operator bool' through 0.72's contextual conversion,
the failed read clearing the string) -- clang++'s lines, 43 s and 1354 MB warm;
the C++ gate GREEN at 1173 MB, 104 checks, the only gate the change touches
(reader version 52 and lowering version 28 unchanged). NOT DONE: `cin.get()', `cin.ignore()', `std::ws', the manipulators, the
rvalue-stream `getline(basic_istream &&, ...)' overloads (declared, untried),
wide streams.

## 0.77 — M6's forty-fifth step

**M6's forty-fifth step (0.77): `cin.get()` and the unformatted input family --
no new rule.** `int_type get()', `peek()', `get(char_type *, streamsize,
char_type)', `ignore(streamsize, int_type)', `putback(char_type)' and
`unget()' are shipped members of the extern instance (0.75), `get(char_type &)',
`get(char_type *, streamsize)', `ignore()' with its two defaults (`1',
`traits_type::eof()', desugared in the class, 0.76) and `gcount()' the hidden
inline wrappers over them, `std::char_traits<char>::eof()' a static call on a
specialization, `cin.eof()' and `cin.fail()' basic_ios's through the base
hops -- every form went through the rules already there, the first fixture of
the stream work to ask nothing. Gated by `test/cpp/run/stdget.cpp` (a
character as an int, one into a char, a bounded read and its count, a
delimited one and a peek, ignore, unget, putback, a loop to the end of input
and the stream's state after it), clang++'s lines, 15 s and 871 MB warm; the
C++ gate GREEN at 2143 MB, 105 checks, the only gate the change touches. NOT DONE: `std::ws', `cin.read()', `readsome()', `tellg()' and
`seekg()' (`fpos', untried), the manipulators, wide streams.

## 0.78 — M6's forty-sixth step

**M6's forty-sixth step (0.78): THE STANDARD STREAMS' SURFACE, in one step --
`std::ws' asked for, and the module done whole (the owner's rule, 2026-09-13:
a module at once, not function by function).** `std::ws' ran as it stood (the
manipulator's road of 0.74, the whitespace loop of 0.76); the rest of what
`<istream>', `<ostream>', `<ios>' and `<iomanip>' offer a char stream came in
four more fixtures, and asked sixteen forms, each named: (1) THE HIDDEN
FRIEND, a function defined in a class body that only argument-dependent lookup
finds -- how `<iomanip>' writes every manipulator's inserter and how a program
prints its own class -- is split out of the members at registration
(`cpp_split_friends`) and registered as the free function it is
(`cpp_register_friends`: a template as a template, a plain one of a library
class as a lazy function of the header, a plain one of the program's class
declared at file scope and EMITTED WITH THE CLASS, `'$cpp_friends'`); (2) A
FREE OPERATOR IS AN OVERLOAD SET like a function's (0.56): noted by its word,
named by its parameters where two definitions share it, chosen by the
arguments through the free-function road (the `'$cpp_free_ops'` branch of
`cpp_operator` is gone) -- two classes' friend inserters are both
`operator<<(ostream &, ...)', and the first took the second's argument; (3) A
HEADER'S TEMPLATES AND FUNCTIONS OF A NAME JOIN THE PROGRAM'S (`cpp_hdr_join`
in `cpp_template` and `cpp_fn_ready`): loaded on the first ask whether or not
the program has one -- the friend registered `op.shl.2' first, the lookup
found it and never loaded libc++'s inserters, and every string went to the
`const void *' member; (4) FORWARDING REFERENCES: `T &&' with T a parameter,
given an LVALUE, deduces T as the argument's type AS A REFERENCE
(`cpp_deduce_one`, the `_Args &&...' packs alike, a call returning a reference
counted an lvalue, `cpp_lvalue`), with REFERENCE COLLAPSING in `cpp_type`
(`cpp_collapse_ref`) -- so `std::forward<T>' hands an lvalue back as one, and
the rvalue-stream inserter's `is_base_of<ios_base, _Stream>' is false for
`basic_ostream &'; deduced as the plain class it was viable for an lvalue
stream, and, the friend unknown, called itself until the stack ran out; (5) A
HEADER'S INLINE FUNCTION IS DECLARED WITH ITS TYPES RESOLVED
(`cpp_resolved_params`), and THE UNIT'S OWN ITEMS COME FIRST in the bulk noter
(`ccl_own_first` in `ccl_items_note`, the includes after), so an emitted
definition shadows a summary's raw declaration of the same name -- the passes
rebuild the tables from the summary, where `setiosflags(ios_base::fmtflags)'
is raw, and the lowering converted the call's argument to `ios_base::fmtflags';
(6) A CLASS VALUE WHERE A SCALAR IS WANTED converts through its CONVERSION
OPERATOR (`cpp_conv_to`: a declaration, an argument, a cast; scored exact
after it where the operator's result is the parameter's type, else 1,
`cpp_arg_fit_`) -- fpos's `operator streamoff()', `streamoff off =
cin.tellg()', `cout << cout.tellp()'; a CAST admits an explicit one and a cast
to bool takes the contextual road (`cpp_cast_to`: `(bool) cin'); (7) A
CHARACTER LITERAL IS A `char' IN C++ (the inference and the lowering, C's
`int' kept in C; lowering version 29): `cout << ' '' printed 32; (8) AN
INTEGER TYPE'S SPELLING IS ONE where sameness and exactness are judged
(`cpp_canon_specs`: `unsigned' is `unsigned int'): the member
`operator<<(unsigned int)' was no exact match for an `unsigned', every
arithmetic member tied at 2, `operator<<(bool)' won the tie and the free
`unsigned char' template took the call; (9) A FUNCTION FITS ONLY A FUNCTION
POINTER, in the fit (`cpp_pointee_fit`), the template acceptance
(`cpp_scalar_mismatch`) and exactness (a function decays, `cpp_arg_exact`):
the character-string inserter took `std::hex' and printed the manipulator's
code bytes, the char extractor took `std::noskipws' and wrote into code; (10)
A HEADER'S FUNCTION NAMED AS A VALUE, bare or `std::'-qualified, is emitted
as a call would emit it (`cpp_lazy_fn_value`): nineteen manipulators the link
named; (11) `T()' with T bound to a builtin or a pointer is the type's zero
(`cpp_subst`): `*__s = _CharT()' ends the char extractor's string; (12) a
class-scope typedef CALLED THROUGH ITS CLASS, `ios_base::fmtflags(0)', takes
the type-call road (a cast for a scalar, a temporary for a class); (13) THE
ARITY-ONLY LAST RESORT, free and member alike, refuses a class parameter for a
scalar argument and a pointer for an arithmetic one (`cpp_args_no_clash`,
`cpp_fn_best`); (14) a parameter is RESOLVED before exactness is judged
(`cpp_arg_exact` through `cpp_type_or_self`): a program's `operator<<(
std::ostream &, const P &)' is noted raw, and `std::ostream' is nothing to the
inference; (15) an operator function's RESULT type is resolved at declaration
and emission as a plain function's is; (16) the auto forms and the getline
forms of 0.76 carried the rest. WHAT RUNS, five fixtures against clang++'s
lines: `test/cpp/run/stdws.cpp` (`getline(cin >> ws, line)', `ws' before a
character, before a word, at the end); `stdistream.cpp` (the extractors for
short, unsigned short, int, unsigned, long, unsigned long, long long,
unsigned long long, float, double, bool, char and unsigned char, a `char *'
word, `getline', `read', `gcount', `readsome'); `stdistream2.cpp' (`sync',
`tellg' through fpos, `(bool) cin', `noskipws' and `skipws', `hex' and `dec'
on input, a `void *' extracted, a failed read, `clear', `ignore', `eof');
`stdostream.cpp' (a program's plain and template friend inserters, the
inserters for every arithmetic type, `bool', `char', `unsigned char', `signed
char', `const void *', `nullptr', a string and its `c_str()', `write', `put',
`flush', `cerr' and `clog' redirected through `rdbuf(streambuf *)', `tellp',
the state queries, `tie'); `stdmanip.cpp' (`hex', `oct', `dec', `showbase',
`uppercase', `boolalpha', `setw', `left', `right', `internal', `setfill',
`fixed', `scientific', `defaultfloat', `setprecision', `showpos', `showpoint',
`setbase', `setiosflags', `resetiosflags', and `width', `precision', `fill',
`setf', `unsetf', `flags' called). Not one form of the surface for a char
stream is outside them but `long double' (lowered as a double where the
library's is x87), the money and time facets, `quoted', `seekg'/`seekp' (a
pipe has no position), `sync_with_stdio', the exceptions mask, and an
overload SET of plain functions named as a value. Reader version 52 unchanged,
lowering version 29. Seven gates GREEN (the C++ one 2519 MB, 110 checks, 457 s;
the libc++ one 1747 MB); the two input fixtures peak near 2.4 GB each, which is
why the extractors and the stream's state are two fixtures and not one.

## 0.79 — M6's forty-seventh step

**M6's forty-seventh step (0.79): `std::map`, whole -- the int map's surface, a
map of strings walked by structured bindings, and `std::multimap`.** The owner's
rule of 0.78 (a module at once, not function by function) applied to `<map>`:
`test/cpp/run/stdmap.cpp` (`operator[]` reading and writing, `insert` of a braced
list and of a `make_pair`, `find` with `->first`, `count`, `erase`, `size`,
`empty`, `at`, `lower_bound`, `clear`, a range-for with `auto &`, an iterator
loop `begin()`/`end()`/`++`/`->`) and `stdmapstring.cpp` (string keys, `+=` and
`++` through `operator[]`, `for (const auto &[k, v] : w)`, `find` and `count`
with a `const char *`, `erase`, and `std::multimap` with `insert({k, v})`,
`count` and `equal_range` walked -- three fixtures, `stdmapstring.cpp` the
writing half, `stdmapstring2.cpp` the reading half, `stdmultimap.cpp`, for the
memory reason below) match clang++ line for line, and `<map>` is read WHOLE in
`test/libcxx.pl`. What the two asked, thirty-odd forms, each with
its reproduction (the piecewise `pair` probe first, then the map's own road):
THE READER (version 57): (1) a STRUCTURED BINDING whose right side the reader
cannot type -- unknown, dependent, or `auto` -- is DEFERRED to the desugaring
(`bindings(L, Ref, Ns, E)`, `ccl_bind_names`, `ccl_declare_autos`, `ccl_auto_type`),
where 0.44's read-time destructuring refused `cannot_infer(pattern)` on
`auto [__parent, __child] = __find_equal(__key)`; and a binding may be a
range-for's declaration (`ccl_range_decl(_, bindings(Ref, Ns))`); (2) a class
member `using Base::Base;` keeps its name (`using(L, name(Q))`); (3) `const'
KEPT on a member DEFINED OUT OF ITS CLASS, as `const(Sto)' in the storage slot
(`ccl_sto_quals`; the desugaring's `cpp_sto_quals` reads it): dropped, the
const overload's body attached itself to the non-const declaration; (4) a C++
`constexpr' OBJECT is a `const' one, the C23 rule, and the clause sits BEFORE
the qualifier clause that would take the word: `inline constexpr
piecewise_construct_t piecewise_construct' carried `constexpr' in its TYPE, and
`is_same<__remove_const_ref_t<decltype(piecewise_construct)>,
piecewise_construct_t>' was false, so libc++'s key extraction for a map's
piecewise emplace fell to its fallback.
THE DESUGARING, the pair's piecewise road first: (5) the bindings statement
(`cpp_stmt_(bindings)`: the value typed through `cpp_arg_type`, a temporary
`$bind` -- a reference when `auto &' binds an lvalue -- and one `auto' (or
`auto &') per name from its member by POSITION; A BINDING TO A REFERENCE
MEMBER IS A REFERENCE, [dcl.struct.bind], `cpp_binding_vt`: libc++'s
`__find_equal' answers `pair<__end_node_pointer, __node_base_pointer &>' and
the tree STORES THE NEW NODE THROUGH `__child' -- copied, the pointer went
nowhere and `__tree_balance_after_insert' walked a null root); (6) A RANGE-FOR
OVER AN OBJECT WITH `begin()' AND `end()' is C++'s (`auto __b = r.begin(), __e
= r.end(); for (; __b != __e; ++__b) { decl = *__b; body }', the iterator's `!=',
`++' and `*' the class's own -- a map's are hidden friends), placed BEFORE
0.38's `size()'/`[]' rewrite, which is this compiler's shortcut for a container
indexed by position: a map has both, and indexed it would have inserted the
keys 0, 1, 2; a prvalue range is bound to `auto &&' first, a structured binding
as the declaration becomes the statement above; (7) INHERITING CONSTRUCTORS
(`cpp_inherit_ctors`: one per base constructor but the copy and the move,
handing its parameters to the base -- libc++'s tree node destructor is
`struct __generic_container_node_destructor<...> : __tree_node_destructor<_Alloc>
{ using __tree_node_destructor<_Alloc>::__tree_node_destructor; }'); (8) TWO
OF CLANG'S BUILTIN TEMPLATES, `__make_integer_seq<S, T, N>' = `S<T, 0 .. N-1>'
(libc++'s index sequences) and `__type_pack_element<I, Ts...>' = the I-th of Ts
(tuple_element, which `get<I>' is typed by), in `cpp_instantiate_type`; (9) A
CONSTRUCTOR TEMPLATE'S SIGNATURE IS CHECKED IN ITS CLASS (`cpp_try_ctor`, as a
member template's is since 0.51; `unique_ptr''s `template <class _Deleter =
deleter_type, ...>' bound its default unresolved), and every step of a
candidate that FAILS says so under the trace (`ctor_candidate', `ctor_holds',
`ctor_no', `member_refused', `member_error', `sig_failed(F, explicit | deduce |
defaults | constraints | accept)'), where a candidate that neither held nor
refused cost an afternoon; (10) A TRAILING PACK IN A TEMPLATE-ID ARGUMENT
takes every argument left (`cpp_match_targs`: `tuple<_Args1...>' against
`tuple<int &&>'), DEDUCTION THROUGH AN ALIAS (`cpp_alias_pattern`,
`cpp_alias_binds`: `__index_sequence<_I1...>' is `__integer_sequence<size_t,
_I1...>'), a specialization's pattern deducing through an alias of a class
template-id too (`cpp_alias_through`: `__tuple_impl<__index_sequence<_Indx...>,
_Tp...>' -- held non-deduced, the tuple's base stayed the declared-only
primary, an incomplete type); A PACK BINDING HOLDS A LIST and an expansion
`pack(id(_I1))' handed through an alias's own pack is an ELEMENT
(`cpp_pack_list` asks `is_list'), and an expansion over packs of DIFFERENT
LENGTHS REFUSES (`pack_lengths_differ') where it failed without a word; (11)
A DELEGATING CONSTRUCTOR (`cpp_ctor_body`: the other constructor over `this'
and nothing else initialized -- pair's piecewise one delegates to its private
one with the index sequences); (12) THE TYPE AN ARGUMENT HAS, FOR DEDUCTION,
comes through the desugaring where the inference cannot tell it
(`cpp_deduce_type` over 0.68's `cpp_arg_type`, the temporaries that walk
registers dropped again): `__index_sequence_for<_Args1...>()' is a call of an
alias template's instance, and typed unknown its pack `_I1' stayed empty
beside a bound `_Args1'; (13) AN EXPLICIT TEMPLATE ARGUMENT'S KIND IS CHECKED
(`cpp_bind_explicit`, `kind_mismatch'): `get<0>(tup)' is no candidate of the
by-TYPE `get', whose `_T1' bound to 0 instantiated
`__find_exactly_one_t<0, ...>' without end (412 s to the cap); (14) AN UNNAMED
TEMPLATE PARAMETER IS NAMED BY ITS POSITION at the three registration doors
(`cpp_name_anon`, `$anon1' ...): libc++ forward-declares `template <size_t,
class> struct tuple_element;' with neither named, and two bindings of one name
`anon' answered the first to both, keying `tuple_element<0, tuple<int &&>>'
as `tuple_element.tuple.int_rr.tuple.int_rr'; (15) AN EXPANSION OVER A CLASS'S
PACK AND A MEMBER TEMPLATE'S OWN WAITS FOR THE MEMBER'S INSTANTIATION
([temp.variadic]: every pack in one pattern expands together): the member's
pack is marked `$later' when the class's bindings shadow it (`cpp_shadow`),
and the pattern travels with the class's packs bound, `pack_zip(Bound, X)'
(`cpp_subst_elems`), expanded once all are -- `__tuple_impl' constructs
`__tuple_leaf<_Indx, _Tp>(std::forward<_Args>(__args))...' with `_Args' the
constructor's own, and expanded over the class's packs alone the `...' was gone;
(16) A LAMBDA'S OWN PARAMETER PACK expands with the enclosing template's
bindings (`cpp_subst(lambda)`, `cpp_param_packs`): `[this](_Args &&...
__args2) { ... }' inside `__tree::__emplace_unique'; (17) AN EMPTY MEMBER
INITIALIZER VALUE-INITIALIZES ([dcl.init]/8: a scalar's zero, a class without
constructors zero-filled), which pair's piecewise constructor writes as an
empty pack expansion (`second()') -- left alone it was the member's garbage;
(18) `x->m' WITH x A CLASS OBJECT goes through its `operator->', again until a
pointer (`cpp_arrow_object`: a unique_ptr's node, `__h->__get_value()'); (19) A
CALL WHOSE RESULT IS A REFERENCE NAMES AN OBJECT (`cpp_addressable`) and
`decltype' OF A CALL IS THE FUNCTION'S DECLARED RESULT, its reference kept
(`cpp_decltype_of`: `std::declval<T>()' is `T &&', and the inference DECAYS
every reference, so declval gave the closure by value and its `operator()'
found no object -- the type `__try_key_extraction' returns); (20) A C++ CAST TO
A REFERENCE is typed as its object (`ccl_type_of(ccast)' unrefs, as every
other lvalue is) and a cast to an lvalue reference is an lvalue
(`cpp_lvalue(ccast)`): `std::addressof(const_cast<value_type &>(*__p))' had
deduced `_Tp' as a reference and refused; (21) A VALUE OF THE CLASS ITSELF
PLACED where the class writes no copy or move constructor of its own and holds
nothing that needs one is the implicit copy of the bytes
(`cpp_trivial_copy_init` in `cpp_new_at`): a map's node takes its
`pair<int, int>' so through `std::__construct_at'; (22) A BRACED ARGUMENT to a
class-typed parameter list-initializes a temporary of the class
(`cpp_copies_`; scored as a class it constructs, or an `initializer_list<T>'
whose items fit T, `cpp_arg_fit_`): `m.insert({4, 40})' builds the pair, an
`initializer_list' argument the compiler alone can build is refused by name;
(23) A FOR'S DECLARATION IS A DECLARATION IN THE FOR'S OWN SCOPE
([stmt.for]/1: `{ init; for (; c; step) s }'), so `auto it2 = m.begin()' is
deduced and a class local constructed there; (24) `sizeof' OF AN INCOMPLETE
TYPE REFUSES (`cpp_incomplete_class`), which in a template argument is the
substitution failure libc++'s `__has_default_three_way_comparator<L, R,
sizeof(__default_three_way_comparator<L, R>) >= 0>' detects by, and A VALUE
PATTERN NAMING A PARAMETER IS EVALUATED ONCE THE OTHERS BIND IT
([temp.deduct.type]/5; `cpp_non_deduced`, `cpp_match_later`'s value branch)
-- compared raw it folded to true for every pair of types, and the eager
comparator called an `operator()' of nothing; (25) A TEMPLATE-ID RESULT TYPE
IS SUBSTITUTED IN THE IMMEDIATE CONTEXT ([temp.deduct]/8, `cpp_sfinae_result`):
libc++'s conjunction is `__expand_to_true<__enable_if_t<_Pred::value>...>
__and_helper(int)' beside `false_type __and_helper(...)', and unresolved at
the check the first held for a false predicate -- every `_And' was true; and A
PARAMETER USED AS A PATH SEGMENT is seen by the expansion (`cpp_names_in`:
`__enable_if_t<_Pred::value>...' names the pack); (26) a block alias CALLED
OVER SEVERAL ARGUMENTS is the class's temporary (`cpp_subst`: `using _Pair =
pair<...>; return _Pair(__end, __end->__left_);'); (27) A FREE OPERATOR SET'S
NAME, `op.eq.2' exactly, IS ALWAYS AN OVERLOAD SET (`cpp_fn_overloaded`): the
first hidden friend `operator==' registered -- `__tree_iterator''s, alone at
that moment -- was declared under the bare name, and once the others arrived
the call's `op.eq.2.<keys>' named nothing and `__i == end()' stayed a
comparison of two structs; an INSTANCE of one, `op.lt.2.c21.char...', is one
function under its own name; (28) A CONST METHOD IS ANOTHER FUNCTION
([over.match.funcs]: the implicit object parameter differs): its name ends
`.c' (`cpp_mangle_q`, at every door the plain name had; a shipped member keeps
its Itanium symbol, which spells the const itself), the out-of-class merge
matches constness (`cpp_member_const`), and the OVERLOAD IS CHOSEN BY THE
OBJECT'S CONSTNESS where the parameters tie (`cpp_method_on`, `cpp_pick_q`,
`'$cpp_obj_const'`: a non-const object takes the non-const overload, a const
one the const overload; unsaid, the first declared) -- libc++ declares
`iterator find(const key_type &)' beside `const_iterator find(const key_type &)
const', and under one name the const one's result type was declared last and
won every `auto it = m.find(3)' while the body emitted was the other's: a
const_iterator cast from an iterator, which LLVM refused; (29) A VALUE OF
ANOTHER TYPE RETURNED converts through the result class's converting
constructor, as a call's argument does (`cpp_stmt_(return)`: `map::find'
returns `__tree_.find(__k)', a `__tree_iterator' where its iterator is a
`__map_iterator' holding one), a constructor TEMPLATE written over its own
parameters converts through the template road (`cpp_converting_ctor`'s third
clause: `pair(const pair<_U1, _U2> &)', no fit readable off the raw type) and
an EXPLICIT constructor never converts implicitly ([class.conv.ctor]:
`explicit basic_string(const _Tp &)' from a string_view); (30) A DERIVED OBJECT
WHERE ITS BASE IS TAKEN BY VALUE IS SLICED to the base sub-object
(`cpp_copies_`): `__priority_tag<1>()' to the `__priority_tag<0>' fallback of
`__try_key_extraction_impl'; (31) A MEMBER TEMPLATE CALLED BARE WITH EXPLICIT
ARGUMENTS passes `this' unless it is static (0.47's null was for the static
detection helpers): `__lower_upper_bound_unique_impl<true>(__v)' inside
`__tree' read the tree through a null this; (32) A CLASS VALUE WHERE ANOTHER
CLASS IS WANTED converts through its CONVERSION OPERATOR, at the fit
(`cpp_arg_fit_`), the clash (`cpp_args_no_clash`), a template's acceptance
(`cpp_type_accepts`), the argument (`cpp_ref_args_`, `cpp_conv_to` to a class
target too) and a temporary of the class from such a value (`cpp_temporary`,
[over.match.copy]): `compare(__self_view(__str))' is basic_string's
`operator basic_string_view()' -- taken for the `const char *' constructor,
the string was cast to a pointer; and `typename X::y(args)', the reader's
`construct/2' since 0.44, is desugared at last (the type resolved, then the
type-call road); (33) TWO CLASS TYPES ARE THE SAME BY CLASS (`cpp_same_type`:
a struct spec resolved by one road carries its members one way and by another
another) and the remove-qualifier builtins keep a NAMED type; (34) the
template acceptance looks through EVERY reference layer (`cpp_unref_all`: a
forwarding `_Tp &&' bound to an lvalue is `T & &&' before it collapses); (35)
THE COPY PASS RUNS ON AN OPERATOR'S CALL TOO (`cpp_operator`): `w["apple"]'
hands `const char *' to `operator[](const key_type &)', which takes it only
through the string's converting constructor -- passed raw, the key was a
pointer read as a string; (36) IN THE METHOD ROAD THE ARITY ALONE IS THE LAST
RESORT, after every member template (0.63's rule, which `cpp_ctor' had and
`cpp_method' did not): basic_string's `compare(const _Tp &)' template takes a
string_view, and the arity-only `compare(const basic_string &)' took it first
and called itself. THE CHECK: A LIBRARY CLASS'S VALUE IS OPAQUE
(`ck_carries_`, `ck_library_class`): its pointers are libc++'s own discipline,
as its functions' bodies are since 0.45 -- a map's iterator, `auto it =
m.find(3)', holds a node pointer the safe part cannot follow and need not,
where it refused `no owner behind'; and THE ADDRESS OF A PATH UNDER A
REFERENCE THE CHECK DOES NOT FOLLOW IS NO FRESH VALUE (`ck_ref_rooted` in
`ck_fresh_value`): a reference bound to a call has no state, and `const auto
&[k, v] = *it' binds v to a member of it -- a plain value, never a loose
pointer refused at the scope's end. THE LOWERING: a global initialized by an
EMPTY CLASS TEMPORARY (`ir_gconst(compound_lit(...))`: `inline constexpr
piecewise_construct_t piecewise_construct = piecewise_construct_t();'), `int{}'
a scalar's zero, and under the C++ trace the whole item the lowering refuses
is printed (`ir_item_error`), which is how three of the above were found.
Lowering version 30. Seven gates GREEN, twice: under cocolog 1.2.12 (the
C++ one 2407 MB, 114 checks, 602 s; the libc++ one 1953 MB, `<map>` 430
items) and, the module rebuilt, under 1.2.13 with its store compaction (the
C++ one 1398 MB, 673 s; the libc++ one 1374 MB; the reader's 85 MB and 6 s
where it was 329 MB and 39 s), every fixture's output the same; the int map builds in 18 s at about 1.1 GB, each string-map half in
35 s at 1.0-1.4 GB. AND A FINDING THAT COST THE EVENING, and was read wrong here first: the
string map's two halves were ONE fixture, which the gate's watchdog killed at
2876 MB twice while the same file built alone at 1.7 GB by the same counter;
four runs under `/usr/bin/time -l' gave 3252, 1821, 1728 and 3506 MB for
identical work. I read a heap growing by doubling. cocolog's owner's session
measured it: macOS's counters READ LOW after a realloc remap (the high number
is the honest one), and the honest cost was 2.9 GB, half of it the STORE's
dead rows -- a hundred thousand `nb_setval' overwrites whose old values
nothing reclaimed -- which cocolog 1.2.13 compacts away (the finding below).
The cap stays (the owner's rule); the fixture stays split near a gigabyte a
half; the module is rebuilt against 1.2.13. NOT DONE: `emplace',
`insert_or_assign', `try_emplace', `extract' and node handles, `merge',
`std::set' and the unordered containers, a map of the program's own class, an
`initializer_list' argument (refused by name), a class whose members need a
MEMBERWISE copy placed by the implicit one (refused as `no_constructor'), an
array member value-initialized, the `less<void>' transparent comparator's
`operator()' emitted where a program never calls it, and the fallback
key-extraction road (`__without_key', reached by `emplace' with non-key
arguments), which crashed at a null before the piecewise candidate held and
is untested since.

## 0.80 — M6's forty-eighth step

**M6's forty-eighth step (0.80): `std::set`, whole -- and the compile's memory
taken apart again, honestly this time.** THE MODULE: `test/cpp/run/stdset.cpp`
(an int set: `insert`, `size`, `empty`, `count`, `find`, `erase` by key and by
iterator, `lower_bound`, `upper_bound`, `clear`, a loop over `begin()`/`end()`,
a set from an initializer list and from a vector's range, `std::multiset` with
`equal_range`), `stdsetstring.cpp` (string keys), `stdset2.cpp` (a set COPIED,
`==` and `!=`, `emplace`, a hint insert, an erase over a range, `swap`,
`std::greater<int>` as the comparator, `key_comp()` called, `rbegin()`/`rend()`,
a multiset's `emplace` and `rbegin`) and `stdset3.cpp` (`insert(first, last)`,
`insert({...})`, `emplace_hint`, `cbegin`, `crbegin`/`crend`, `<` on two sets,
`value_comp`, `max_size`, `merge`, a TRANSPARENT comparator `std::less<>` on a
set of strings looked up with `const char *` keys, `equal_range`,
`erase(begin())`) match clang++ line for line, and `<set>` is read WHOLE in the
libc++ gate. THE FORMS, each named: (1) AN INITIALIZER LIST IS BUILT BY THE
COMPILER (`cpp_init_list`): a backing array `$il_k[N]` of the element type and
libc++'s private two-argument constructor over its address and its length,
where `initializer_list_argument` had been refused by name; a class with a
constructor taking one (`cpp_il_ctor`) takes a braced initializer and a braced
argument through it (`cpp_ctor_args`), an item of another type converts
through the element class's converting constructor (`cpp_il_item`: `{"bob",
"amy"}' for strings, the temporaries dying with the statement as the array does
in C++), and the items are collected ONCE -- a `findall' over a goal with a
second answer registered a second temporary and the array held both, one of
them declared nowhere; (2) `C(const C &) = default' and `C(C &&) = default'
ARE MEMBERWISE (`memberwise(S, Kind)' in the constructor's initializer slot at
`cpp_norm_members`, `cpp_ctor_body`: every data member from the source's,
moved under a move, a union as one assignment), where the dropped declaration
left `set(const set &) = default' to the rule that refuses a copy of a class
with a destructor; `cpp_user_ctor` tells such a marker from a written one
(`cpp_trivial_class`, `cpp_note_nontrivial`); (3) A PARAMETER'S CLASS WITH A
CONSTRUCTOR TAKING THE ARGUMENT'S CLASS accepts it (`cpp_class_converts` in
`cpp_type_accepts`; [over.ics.user]): libc++'s tree copies itself through
`unique_ptr<__node, __tree_deleter>(node, __node_alloc_)', the deleter made of
the allocator; (4) `__builtin_invoke(f, args...)' is the call (`cpp_builtin_call`),
which `__invoke_result_impl' asks; (5) A CALL RETURNING A CLASS BY VALUE,
CALLED -- `g.key_comp()(3, 1)' -- materializes the prvalue in a temporary of
the statement and calls its `operator()' over it (`cpp_temp_call`'s third
clause), where the lowering met a call whose callee was a call; (6) A CLOSURE
HAS NO IMPLICIT CONSTRUCTOR (`cpp_closure_class`, in `cpp_implicit_ctor_needed`):
it is built from its captures, and libc++'s `[this, __p]' captures an iterator
BY VALUE, a class with constructors, whose implicit one was walked under the
closure's `this' -- the enclosing object's -- and named a member the tree has
not; (7) AN ASSIGNMENT FROM ANOTHER CLASS CONVERTS through the target's
converting constructor (`cpp_expr(assign)`, as an argument and a return do):
`__f = erase(__f)' stores an `iterator' into a `const_iterator', and taken raw
the lowering cast one struct to the other; (8) A FREE OPERATOR SERVES A CLASS
ON EITHER SIDE (`cpp_free_operator_call`): `"amy" < s' is
`operator<(const _CharT *, const basic_string &)', which the transparent
comparator writes as `std::forward<_T1>(__t) < std::forward<_T2>(__u)', and
with the class on the right only the form stayed raw -- a pointer compared with
a struct; (9) THE COPY AND THE MOVE CONSTRUCTOR CONVERT NOTHING
(`cpp_own_class_param` in `cpp_converting_ctor`): `__self_view(__str)' fitted
string_view's defaulted copy constructor (now synthesized, (2)) THROUGH the
string's conversion operator, and the copy took the string's bytes for a
string_view's -- `memcmp' at a wild address; the conversion operator is the
road; (10) `decltype(*p)' AND `decltype(a[i])' ARE `T &' ([dcl.type.decltype],
`cpp_decltype_of`): `using __reference = decltype(*__first)' is
`const string &', and read as the plain type the range insert's
`forward<__reference>' handed an rvalue on and the MOVE constructor took each
element out of the caller's range. THE MEMORY, measured with cocolog 1.2.13's
`statistics/2' -- `globalused', `store_used', the honest instrument where the
process's RSS read low (0.79's finding) -- printed on every trace line
(`cpp_trace_mem`, `ir_mem`, `kb(Heap, Store)') and at each phase
(`phase(check)', `phase(lowering)', `phase(assemble)' in `ccl_ir_units`, and
`lower(Item, Mem)' per item): stdset2's desugaring left 1.85 GB of heap behind
it, and the check and the lowering added ten megabytes -- a deterministic run
keeps every intermediate (the no-GC finding), and 0.68 had scoped only a class
instantiation. EVERY EMISSION ROAD RUNS INSIDE `\+ \+' NOW: a lazy member
(`cpp_make_lazy`), a header's free function (`cpp_use_fn`), a function
template's instance (`cpp_instantiate_function_`), a member template's
(`cpp_make_member`), a nested class (`cpp_nested_class`) and a header's load
(`cpp_hdr_load`) -- their results are facts and globals, which survive the
scope, and their walks are reclaimed; so does each lowered item (`ir_items`)
and each checked function (`ck_items`), and a function's text is a global of
its own (`'$ir_fdef:K'`, `ir_add_fdef`), where a list of every text so far was
copied at each addition. 1.85 GB -> 186 MB at the check, and the build's RSS
2.8 GB (killed at the cap twice) -> 650 MB. `stmt_out(S)' traces the program's
own statements as they come out. NOT DONE: node handles (`extract',
`insert(node_type &&)') hold a `std::optional<allocator>', and `<optional>' is
a module of its own (`base_constructor(__optional_iterator_base)' is where it
stops); C++20's `contains' and `erase_if' (the level's fixtures); a lambda as
the comparator; a program's constructor taking `std::initializer_list<std::string>'
is keyed by the raw template-id (`typedefscopedstdtmplinitializerlist...'), which
works and is ugly. Seven gates GREEN (the reader's 94 checks, 6 s and 78 MB;
the compile gate's 73 at 213 MB; the driver's 23; the objects' 29; the proof;
the C++ one 118 checks, 798 s, 1220 MB; the libc++ one 279 s and 1269 MB,
`<set>` read whole, 426 items); the four set fixtures build in 40 to 90 s at
630 to 920 MB each.

## 0.81 — M6's forty-ninth step

**M6's forty-ninth step (0.81): THE UNORDERED CONTAINERS, whole.** THE MODULE:
`test/cpp/run/stdunorderedmap.cpp` (an int map: `operator[]` writing and
reading, `insert({k, v})`, `find`, `count`, `erase`, `size`, `empty`, a
range-for, `at`, `+=` through `operator[]`, `bucket_count`, `clear`),
`stdunorderedmapstring.cpp` (string keys: `operator[]`, `+=` and `++`, `find`
and `count` with a `const char *`, `erase`, `at` with a string, a range-for),
`stdunorderedset.cpp` (`unordered_set<int>` from an initializer list, `insert`,
`count`, `erase`, a range-for, `find`; `unordered_set<std::string>`: `insert`,
`count`, `erase`, `empty`, `clear`), `stdunorderedmap2.cpp` (a map from an
initializer list, COPIED, `==`, `emplace`, `insert` returning its pair,
`erase(iterator)` returning the next, `insert(first, last)` from a vector of
pairs, `reserve`, `bucket_count`, `load_factor`, `rehash`, `unordered_multimap`
with `equal_range`, `clear`) and `stdunorderedset2.cpp` (`unordered_multiset`:
an initializer list, `insert`, `emplace`, `count`, `equal_range`, `erase`; a set
of strings copied and compared, `erase(find(...))`, `reserve`) match clang++
line for line, and `<unordered_map>` and `<unordered_set>` are read WHOLE in
the libc++ gate. THE FORMS, each named: (1) THE LOCALS DECLARED ON THE WAY TO
THE FIRST RETURN are in scope when a lambda's or an `auto' method's result is
deduced (`cpp_declare_before`, in `cpp_lambda_ret` and `cpp_method_ret`): the
hash table's emplace lambda writes `pair<iterator, bool> __r = ...; if (...)
...; return __r;', and with the parameters alone declared `__r' had no type
(`lambda_result_type'); every declaration before the return -- in its block,
the blocks around it, a for's own -- is desugared for its declarations only,
and the refusal behind such a failure is traced (`lambda_ret_refused'); (2)
THE MATH BUILTINS ARE LIBM'S FUNCTIONS (`cpp_builtin_call` through
`cpp_math_fn`, a table of stems and their arities): libc++'s `<cmath>` wrappers
are `inline float ceil(float __x) { return __builtin_ceilf(__x); }', which
the rehash calls, the prototype is emitted once where no header declared it
(`cpp_math_declared`, as a mangled declaration is), and the long double form
goes to the double one (a long double is lowered as a double here); (3) A
MEMBER TEMPLATE IS A TEMPLATE THROUGHOUT ITS CLASS'S BODY ([class.mem]: a
member function's body is a complete-class context) -- THE READER (version
58, `ccl_member_templates_ahead`) scans the class body's tokens for `template
< ... >' declarators before the members are read, attributes and `[[...]]'
skipped, and notes each name: libc++ calls `__rehash<true>(__n)' a hundred
lines before it declares `template <bool> void __rehash(size_type)', and read
in order the call was the comparison `(__rehash < true) > (__n)'; (4) `void()'
IS THE VOID VALUE (the reader's functional cast of nothing, `cpp_expr`):
`for (__pp = __cp, void(), __cp = ...)' keeps an overloaded comma out, and
desugared to nothing the lowering met a missing operand; (5) A CONDITIONAL
WITH A `nullptr' ARM TAKES THE OTHER ARM'S TYPE ([expr.cond],
`ccl_type_of(cond)`), unknown included: typed `void *' by its nullptr while
the other arm was still unknown, `__nbc > 0 ? allocate(...) : nullptr' chose
the array unique_ptr's `reset(nullptr_t)' and the buckets were never kept; (6)
THE ARGUMENTS ARE TYPED IN THE CALLER'S WORDS (`cpp_as_callee` at every
overload door, `cpp_caller_ctx` in `cpp_arg_type`): a candidate's parameters
are read in the callee's class (0.65's rule) and an argument that must be
DESUGARED to be typed is read in the caller's -- `__pointer_alloc_traits::
allocate(__npa, __nbc)' names the hash table's own alias, which resolved to
nothing in unique_ptr's words; (7) `nullptr_t' TAKES A NULL POINTER CONSTANT
AND NOTHING ELSE ([conv.ptr]; `cpp_nullptr_param` in `cpp_arg_fit` and
`cpp_args_no_clash`): resolved to `void *' it took every pointer; (8) A MEMBER
CLASS TEMPLATE, WITH ITS PARTIAL SPECIALIZATIONS (`cpp_nested_template_put`,
`'$cpp_nested_tmpl'`, `cpp_nested_template`; refused as
`template_without_body' since the fourth step): `template <class _From> struct
_CheckArrayPointerConversion : is_same<_From, pointer> {};' and its
`<_FromElem *>' specialization guard the array unique_ptr's `reset(_Pp)'; it is
a class template under the enclosing class's name (`C.N', as a nested class
is named), its specializations with it, the bare name resolves in the class,
its nested classes and its bases AT THE INSTANTIATION DOOR ITSELF
(`cpp_instantiate_type`, since the scope walk of `_CheckArrayPointerConversion<
_Pp>::value' asks there and not through `cpp_type`), and an instance is
ENCLOSED by the class, so `pointer' and `element_type' are in scope in its
members; (9) A MEMBER OF A CONST OBJECT IS CONST ([dcl.type.cv],
`cpp_obj_const`): `__table_.begin()' inside `unordered_map::begin() const' is
the const begin, where the member's own type -- no const of its own -- chose
the non-const one and a `__hash_iterator' was stored as a const one; a
REFERENCE member keeps its referent's own constness (`cpp_member_own_const`);
(10) THE OBJECT'S CONSTNESS ORDERS THE MEMBER TEMPLATES too (`cpp_prefer_const`,
0.79's rule for the plain overloads): libc++ writes `template <class _Key>
iterator find(const _Key &)' beside its const twin, and `find' inside
`unordered_map::find(...) const' took the non-const one first. The unordered
map's `__try_key_extraction', its `__hash_value_type', the bucket list as an
array `unique_ptr' with its deallocator, `__constrain_hash', the rehash
loop and `std::hash<std::string>' (libc++'s murmur, compiled from the header)
all went through the rules already there. Seven gates GREEN (the reader's 94
checks, 37 s and 277 MB cold after the version bump; the compile gate's 73;
the driver's 23; the objects' 29; the proof; the C++ one 123 checks, 1111 s,
1258 MB; the libc++ one 357 s and 1344 MB, `<unordered_map>` 322 items and
`<unordered_set>` 318 read whole); the five fixtures build in 50 to 95 s at
620 to 1200 MB each, the string-keyed ones the heaviest. NOT DONE: `std::hash' of
a program's own type (a specialization the program writes), `extract' and
node handles (`<optional>', as `<set>''s), the bucket interface (`begin(n)',
`bucket_size', `bucket'), `max_load_factor' set, C++20's `contains'.

## 0.82 — M6's fiftieth step

**M6's fiftieth step (0.82): `std::optional`, whole.** THE MODULE:
`test/cpp/run/stdoptional.cpp` (an `optional<int>`: empty and engaged,
`has_value`, `*`, `value`, `value_or`, assigned a value, `reset`, returned
from a function as a value and as `std::nullopt`, `emplace`, compared with a
value, COPIED, `==` and `<` on two optionals, tested in an `if`),
`stdoptionalstring.cpp` (an `optional<std::string>`: a long string engaged,
`->`, `value_or` with a `const char *`, assigned a literal, `reset`
destroying the string, returned, `emplace("...")`, copied and compared,
`std::make_optional`, `swap`) and `stdoptional2.cpp` (an optional of the
program's own struct returned by `return P{n, n * 2}`, of a `double`, of a
`pair` from `make_pair`, assigned `nullopt`, compared with `nullopt`,
assigned an optional temporary, MOVED from, `>` with a value) match clang++
line for line, and `<optional>` is read WHOLE in the libc++ gate. THE FORMS,
each named: (1) A MEMBER ALIAS TEMPLATE NAMED BARE IN ITS CLASS resolves
(`cpp_nested_alias` at the instantiation door, as a member class template
does since 0.81): optional's `_CheckOptionalArgsCtor<_Up>::template
__enable_implicit<_Up>()' guards every converting constructor, and 0.47 had
resolved such an alias only through `C::template _Select<A, B>'; (2) THE
IMPLICIT COPY AND MOVE CONSTRUCTORS ARE MADE ON DEMAND, memberwise
([class.copy.ctor]; `cpp_implicit_copy_ctor` in the constructor road,
`'$cpp_implicit_copy'`, the marker of 0.80's `= default' synthesis, so they
count as no user-written special member): optional's `__optional_iterator_base'
inherits its base's constructors, which brings no copy constructor, and the
memberwise copy of `optional' asked its base for one; (3) A CONSTRUCTOR
INITIALIZER NAMING THE BASE THROUGH AN ALIAS (`cpp_alias_base_init`): `using
__base = __optional_iterator_base<_Tp>; ... : __base(in_place, ...)' -- dropped,
the base was default-constructed and the optional never engaged; (4)
INHERITING CONSTRUCTORS TAKE THE BASE'S CONSTRUCTOR TEMPLATES TOO
(`cpp_inherit_ctors`, `cpp_named_params_t`; [namespace.udecl]), a pack
forwarded as an expansion: the storage chain inherits `template <class...
_Args> __optional_destruct_base(in_place_t, _Args &&...)' level by level, and
`using __base::__base;' through the class's own alias (`cpp_alias_names_base`);
(5) AN ANONYMOUS UNION'S MEMBER INITIALIZED BY NAME (`cpp_member_inits`,
`cpp_union_member_init`): `union { char __null_state_; value_type __val_; };
... : __val_(std::forward<_Args>(__args)...), __engaged_(true)' named no
member of the class itself, the initializer was dropped and the value read
back was garbage; (6) A HEADER'S INLINE GLOBAL OF AN EMPTY CLASS IS ITS ZERO
BYTES, its constructor not run (`cpp_lazy_inline_var`): `inline constexpr
nullopt_t nullopt{nullopt_t::__secret_tag{}, nullopt_t::__secret_tag{}}' is a
tag with nothing to construct, and this compiler runs no dynamic
initialization; (7) A CAST TO A CLASS IS ITS CONVERTING CONSTRUCTOR
([expr.static.cast]/4; `cpp_cast_to`): `value_or' returns
`static_cast<value_type>(std::forward<_Up>(__v))', a string from a `const char
*', which the lowering met as a pointer cast to a struct; (8) A RETURN OF A
CONDITIONAL OVER CLASS ARMS RETURNS EACH ARM ON ITS OWN ([class.copy.elision]:
the chosen arm's prvalue IS the result object; `cpp_stmt_(return)`): `return
has_value() ? __get() : static_cast<value_type>(...)' as one value copied the
lvalue arm BITWISE and destroyed the temporary arm under the caller; (9) A
FORWARDING REFERENCE'S ARGUMENT IS JUDGED ON ITS DESUGARED FORM
(`cpp_lvalue_deep` in `cpp_deduce_one` and the pack road of `cpp_deduce_args`):
`std::forward<_That>(__opt).__get()' is a member call whose instance returns
`const value_type &', read raw it was no lvalue, `_Args' deduced the plain
string and the copy of an optional MOVED the source's string out (its size read
0 after the copy); (10) REF-QUALIFIED MEMBER FUNCTIONS ([dcl.fct]/6,
[over.match.funcs]/5): the reader keeps `&' and `&&' after the parameters
(`refq(lvalue | rvalue)' in the qualifiers, `ccl_method_quals`, reader version
59), the name carries them (`.r', `.rr' after the `.c', `cpp_mangle_q`), and
the overload is chosen by the OBJECT'S VALUE CATEGORY (`cpp_obj_cat`,
`cpp_ref_bonus` in `cpp_best_q`, `'$cpp_obj_cat'` beside the constness; a
member template alike in `cpp_prefer_const`): optional's storage writes
`__get() &', `const &', `&&' and `const &&', and on one name the last
declared won -- `const &&', whose result no lvalue test took for one. Reader
version 59; the module rebuilt as 0.82. Seven gates GREEN (the reader's 94
checks, 39 s and 224 MB cold; the compile gate's 73; the driver's 23; the
objects' 29; the proof; the C++ one 126 checks, 1127 s, 1013 MB; the libc++
one 366 s and 1356 MB, `<optional>` read whole, 222 items); the three optional
fixtures build in 12 to 24 s at 240 to 460 MB. NOT DONE: node handles
(`set::extract', `map::extract', `insert(node_type &&)'): with `<optional>`
through, the probe builds `<set>`, `<map>` and `<string>` together in 189 s
at 1.26 GB and stops at `no_constructor(pair<string, int>, 1)' inside
`std::__construct_at' -- the map's node handle placing its value with `_Args'
deduced as `const pair *', a POINTER where the value was meant (the trace:
`call_types(__construct_at, [__p - pair *, forward<pair *>(__args$1) - const
pair *])') -- which is the next thing; `optional<T &>' (C++26), `and_then',
`transform', `or_else' (C++23), `std::hash<optional>', `bad_optional_access'
caught (exceptions are off: it aborts with its message).

## 0.83 — M6's fifty-first step

**M6's fifty-first step (0.83): NODE HANDLES, and the value category of
`std::move`.** `<set>`'s and `<map>`'s not-done item since 0.80, taken up once
`<optional>` compiled: `test/cpp/run/stdnodehandle.cpp` (`set::extract` by key,
the handle's `empty`, `value` and `operator bool`, `insert(node_type &&)` into
another set, an extract that finds nothing, `map::extract`, `key()` rewritten
and `mapped()`, the handle inserted back) and `stdmapinit.cpp` (a map of strings
from an initializer list of braced pairs, walked and looked up) match clang++
line for line. THE FORMS, each named: (1) `std::move` OF A CLASS VALUE KEEPS ITS
MOVE ([expr.xvalue]; `cpp_expr(move)`): 0.40 had made `move(x)' of a value
without owners the value itself, and the value category was gone before
overload resolution -- `t.insert(std::move(nh))' found no `insert(node_type &&)'
and took `insert(const value_type &)' through the handle's `operator bool'; the
class an expression has looks through the move (`cpp_class_of_type_of`), a
by-value parameter of a class with a destructor given `std::move(x)' takes the
MOVE constructor into the callee's copy (`cpp_move_temp` in `cpp_copies_`; the
copy one over the object where the class has no move), `return std::move(x)'
of a local likewise, and a reference bound to a move binds the object
(`ir_ref_of`); (2) A NON-CLASS ARGUMENT CONVERTS TO A CLASS PARAMETER ONLY
THROUGH A CONSTRUCTOR WHOSE PARAMETER TAKES ITS KIND (`cpp_converting/2` in
`cpp_type_accepts`): any one-argument constructor let `const pair *' pass for a
map's `const_iterator', so `insert(__il.begin(), __il.end())' in the map's
initializer-list constructor took `insert(const_iterator, _Pp &&)' over the
range template, and a node was built from a pointer to a pair; (3) A BRACED
ITEM OF AN INITIALIZER LIST list-initializes the element class through its
constructors (`cpp_il_item`): `{{"a", 1}, {"b", 2}}' for a map builds each
`pair<const string, int>', which as an aggregate of the backing array stored
the literal's pointer into the string; (4) THE COPY PASS RUNS ON A TEMPORARY'S
CONSTRUCTOR CALL TOO (`cpp_temporary`): `pair(const T1 &, const T2 &)' took
the literal raw for the `const string &', and the map's keys were the
pointer's bytes; the temporaries register is read AGAIN after the pass, since
the pass registers temporaries of its own (a string for that parameter) and the
list read at the head dropped them (`undeclared('$tmp_8')'); on a MEMBER's
constructor call the same pass LOOPED through the string's allocator member
(`__alloc_(std::move(__str.__alloc_))' converting into itself without end, 4.3
GB in 486 s to the cap) and is not run there; (5) AN AGGREGATE WHOSE MEMBER
CONSTRUCTS IS BUILT MEMBER BY MEMBER, as a temporary and as a braced return
(`cpp_temporary`, `cpp_stmt_(return)`, through 0.41's `cpp_aggregate_inits`):
the tree's `_InsertReturnType{end(), false, _NodeHandle()}' put a
`__tree_iterator' into a `__tree_const_iterator' member bitwise, where its
converting constructor was meant; (6) THE MEMBERWISE COPY OF AN ANONYMOUS UNION
IS ITS BYTES (`cpp_member_inits`): the implicit copy constructor of optional's
storage assigned the union, and the lowering converted its bytes as a pointer;
(7) A VALUE OF THE CLASS ITSELF TAKES ITS COPY OR MOVE CONSTRUCTOR, written or
implicit, and never another constructor taking a class ([over.best.ics];
`cpp_ctor`'s first clause): the C++ gate's first run of this step was RED on
all ten stream fixtures (exit 139), and the backtrace led into `std::copy''s
unwrap road, where (5) built `__in_out_result{__first, __rewrap_iter(...)}'
member by member and the fit set gave the `ostreambuf_iterator' member
`ostreambuf_iterator(ostream_type &)' for an ostreambuf_iterator argument --
the stream buffer's pointer was the iterator's bytes; and the second run RED
on the three `getline' fixtures by a slip of (2): the one-argument
`cpp_converting/1' the traits' `is_convertible' still asks was gone with the
two-argument one, an existence error the driver reported as the file's
(restored beside it); and the third RED on the node-handle fixture itself, by
(8) AN ARGUMENT TYPED BY A FUNCTION TEMPLATE'S RAW SIGNATURE IS NOT TYPED
(`cpp_raw_type` in `cpp_arg_type`): the inference types a call of a function
template from the raw signature a summary declares it under (0.49), so
`std::exchange(__other.__alloc_, nullopt)' in the node handle's move constructor
was a `_T1', optional's `optional(_Up &&)' deduced `_Up' as that free name, and
an allocator was built from a `_T1' -- a type naming a parameter the tables do
not know now falls to the desugaring, which instantiates the call and types it.
A trace names the member template instance an overload set settles on
(`member_holds(C, Name)'), which is how (2) was found. The module rebuilt as
0.83. Seven gates GREEN (the reader's 94 checks, 5 s and 84 MB; the compile
gate's 73 at 209 MB; the driver's 23; the objects' 29; the proof; the C++ one
128 checks, 1237 s, 1090 MB on its fourth run, GREEN at last; the libc++ one
415 s and 1348 MB, unchanged by a desugaring step); the node-handle fixture
builds in 100 s at 1.0-1.2 GB, the map one in 50 s at 0.5. NOT DONE: `unordered_map::extract' and the unordered node
handle (its `__hash_node_handle'), `merge' between a set and a multiset, a node
handle's `get_allocator'.

## 0.84 — M6's fifty-second step

**M6's fifty-second step (0.84): THE NOT-DONE LISTS OF THE CONTAINER MODULES,
closed -- and the levels' headers read whole.** The owner asked for every
not-done item of 0.79 to 0.83 at once. THE MODULES' REMAINDERS, five C++17
fixtures matching clang++ line for line: `test/cpp/run/stdmapemplace.cpp`
(`emplace`, `insert_or_assign`, `try_emplace`, `merge`, `emplace_hint`, a node
handle's `get_allocator`), `stdmapown.cpp` (a map of the program's own struct
as the key and as the value; `emplace` on a string map without the key, the
`__without_key` road; a braced subscript `pm[{1, 2}]`; a copy of the value),
`stdsetlambda.cpp` (a lambda as the comparator; `merge` between a set and a
multiset, both ways), `stdunorderedhash.cpp` (`std::hash` specialized by the
program for its own key; the bucket interface -- `bucket_count`, `bucket_size`,
`bucket`, `begin(n)`/`end(n)`, `load_factor`; `max_load_factor` set, `rehash`,
`reserve`; `unordered_map::extract` and the hash node handle; an
`unordered_set<string>` extract) and `stdaggregate.cpp` (a plain struct holding
a string pushed into a vector by the implicit copy, an array member
value-initialized, an aggregate with fewer items than members, a nested braced
list, an array of strings as a member, a constructor taking
`initializer_list<string>`). Three of those (the lambda comparator, the merges,
the whole hash surface) asked nothing: they ran as they stood. THE FORMS, each
named: (1) A PLAIN STRUCT WHOSE MEMBER IS A CLASS IS A CLASS
(`cpp_struct_promotes`, `'$cpp_promoted'`, at registration and in the program's
own header): the reader keeps a C++ `struct` of data members as C's
(`ccl_make_class`), and `struct Rec { std::string name; int n; }` had a member
the tables never resolved and no constructor, destructor or copy for the string
it holds; promoted, it goes a class's whole road, and a struct of plain members
has its member types resolved in place (`cpp_plain_members`); (2) AN AGGREGATE
IS A CLASS WITH NO CONSTRUCTOR WRITTEN (`cpp_aggregate_class`,
[dcl.init.aggr]): the implicit constructor made for a member that constructs
does not count, where `Val{"beta", 2}` had asked for `Val(const char *, int)`;
the rest of an aggregate's members are VALUE-INITIALIZED where fewer items are
given (`cpp_aggregate_inits`, `cpp_value_init`: `Grid2 g2{}` names nothing and
gets its array zeroed and its string default-constructed), a nested braced
list fills an array member element by element or a nested aggregate through
its own list (`cpp_member_from`), and a class member from a braced list goes
through its constructors; (3) AN ARRAY MEMBER OF OBJECTS (0.41's not-done):
constructed element by element by the implicit constructor, copied element by
element by the implicit copy and move (a plain array as its bytes), destroyed
in reverse (`cpp_member_dtor`), `: cells()` zeroing it where it had been `cells
= 0`, an int into an array; `cpp_elem_class` looks through the array for the
class the members' rules ask -- and THE RESOLVER LEAVES AN ARRAY AS IT IS, so
its element is resolved before its size is taken (`ccl_size_align`), where
`std::string s[2]` had no size, the whole layout failed silently and the empty
layout was cached (`no_member(s, ...)` in the lowering, found by asking the
layout directly after the build); (4) THE IMPLICIT MEMBERWISE ASSIGNMENT
([class.copy.assign], `cpp_implicit_assign`, `'$cpp_implicit_assign'`): a class
with a destructor and no `operator=` written assigns each member through its
own -- a string member takes basic_string's, an array its bytes, a base its
sub-object -- the move form moving each, made once per class and kind as a
method written out would be; never for a class holding owners of its own,
whose plain copy the safe part refuses as ever (`vm[1] = Val{"alpha", 1}`);
(5) THE IMPLICIT COPY AND MOVE MADE ON DEMAND FOR A LOCAL (`cpp_ctor_args`:
`Grid2 g4 = g3`), where only the constructor road had them (0.82); (6) A
MEMBER TEMPLATE'S CANDIDATES ARE RANKED BY THE FEWEST CONVERSIONS
([over.match.best]; `cpp_ctor_holding`, `cpp_member_holding`, the free-function
road's rule since 0.45): the FIRST that held won before, and libc++'s pair
declares `pair(const _T1 &, const _T2 &)` before `pair(_U1 &&, _U2 &&)` --
given a `char *` the first held through the string's converting constructor,
where the second is exact, and `emplace("one", 1)` on a map of strings built
its node from the pointer's bytes; the copy pass runs on placement new's
constructor call too (`cpp_new_at`); (7) THE CLASS'S OWN VALUE IS READ OFF THE
DESUGARED FORM where the inference cannot type the raw one (`cpp_own_value` in
`cpp_ctor`'s first clause, 0.66's rule): pair's piecewise constructor hands
`std::forward<_Args2>(std::get<_I2>(args))`, a `Val &&`, to Val's member
initializer, refused as a copy; (8) A NESTED CLASS OF A LIBRARY CLASS IS THE
LIBRARY'S (`cpp_lib_class` through `'$cpp_enclosing'`): basic_string's `__rep`'s
implicit move constructor was emitted as the program's and checked (`move of a
non-owner`); (9) a scoped template-id parameter keys by its name and arguments
(`cpp_spec_key`: `initializer_list.string`, where the term was spelled letter
by letter, 0.80's ugliness); (10) a braced list as a subscript, `pm[{1, 2}]`
(the reader, `ccl_postfix_p`). THE READER (version 61), THE C++20 STRETCH by
the census loop over the level's flattened headers -- `<set>` at C++20 had
stopped at line 792 of 15,650, and every summary of a level held a tenth of
its header, silently: `X<T>::template f` alone as a template template
argument (`ccl_qrest`); a requires-clause on a MEMBER template's head, a
TRAILING one after a function's parameters (a member's, a definition's, a
prototype's: `ccl_method_quals`) and on a LAMBDA, after its template parameters
and after its declarator (dropped: a generic lambda is refused by name anyway);
THE CONSTRAINT GRAMMAR, primary expressions joined by `&&` and `||`
([temp.pre]; `ccl_constraint`), where the full expression took `[[nodiscard]]`
after a concept-id for a subscript; a CONSTRAINED TYPE PARAMETER, `template
<__exchangeable _Tp>`, `Concept<A> T`, `ns::Concept T` (`ccl_tparam_c`: a type
parameter and its concept-id as a requires entry of the head, conjoined with a
written one by `ccl_gather_requires` so the binders meet one entry, last),
read before as a value parameter of type `__exchangeable`; `f.template
operator()<I>()` (`ccl_member_name`); a MEMBER VARIABLE TEMPLATE, `template
<class _Up> static constexpr bool __check = ...;`, its name noted as a template
so `__check<_Up, _Up &>` reads as a template-id in the requires-clauses beside
it; a CONSTRAINED `auto`, `__integer_like auto operator()(...)` (`ccl_specs`: a
template's name before `auto` is a concept, dropped); LLVM 21's builtin traits
(`__builtin_lt_synthesizes_from_spaceship` and kin, answered false: no
`operator<=>` synthesizes a comparison here); a CONCEPT INDEXED BY ITS NAME
(`cpp_template_name(concept(...))`, registered on the first ask,
`cpp_hdr_join_concept`). WITH THEM `<set>` (482 items where C++17 reads 426),
`<map>` (486), `<unordered_map>` (377) and `<unordered_set>` (373) read WHOLE at
C++20, `<optional>` (272) and `<string>` (492) at C++23, `<optional>` (273) at
C++26 -- seven checks of the libc++ gate, a header at a level being a check of
its own (`at(H, Std)`, the level set for the read as `test/cpp.pl`'s `unit_at`
does) AND THE UNITS READ SO FAR FORGOTTEN BEFORE IT (`'$ccl_unit_paths'`): a
header is read once per process by its PATH (`ccl_unit_cached`), so the C++17
read was served to the level's check -- seven identical item counts, which is
what said so. THE DESUGARING AT THE LEVELS: a concept-id as a
template argument is its truth (`cpp_targ_value`: `conditional_t<
__primary_template<iterator_traits<...>>, ...>`, C++20's iterator_traits); a
VARIABLE template in a requires-clause is its value (`cpp_satisfied`: `requires
(!is_same_v<...> && is_constructible_v<_Tp &, _Up>)` on optional<T &>, taken
for a concept-id and refused `concept_without_body(is_same_v)`);
`__reference_constructs_from_temporary` and kin answer false; THE BLOCK
TYPEDEFS BEFORE THE FIRST RETURN are substituted into it before its type is
asked (`cpp_body_typedefs` in `cpp_method_ret` and `cpp_lambda_ret`, 0.60's rule
at walk time beside 0.81's declarations): libc++'s `transform` writes `using
_Up = remove_cv_t<invoke_result_t<_Func, _Tp &>>; ... return optional<_Up>(...)`,
and the first return typed raw instantiated `optional<_Up>` on the free name,
its bases refused one by one. THE LEVELS' FIXTURES, matching clang++ line for line:
`test/cpp/run/stdcontains.cpp` at C++20 (`contains` on a set, a map and the unordered
pair; `erase_if` on a set and on a map), `stdoptional3.cpp` at C++23 (the monadic
`and_then`, `transform`, `or_else`, the two chained, `value_or` on an empty optional)
and `stdoptionalref.cpp` at C++26 (`optional<int &>`: bound, written through, rebound,
an empty one's `value_or`). AND THREE MORE OF THE OLDER LISTS, closed by the same
work: `stdstringops.cpp` (0.66's `operator+`, `substr`, `find`, and the rest of the
string's surface: `rfind`, `append`, `push_back`, `insert`, `erase`, `replace`,
`compare`, `front`, `back`, `at`, `npos`, a range-for over the characters, `to_string`)
and `stdctad.cpp` (class template argument deduction, in an expression and in a
declaration). AND WHAT THE LEVELS' PROBES ASKED FOR, each
its own rule: (11) THE ARGUMENT PASS RUNS ON A TEMPLATE'S INSTANCE TOO (`cpp_call`'s
template clauses, the free road's since 0.79) -- a class value where the parameter
wants another class goes through its conversion operator, and libc++'s
`std::__concatenate_strings(a.get_allocator(), __lhs, __rhs)', whose parameters are
`__type_identity_t<basic_string_view<...>>', stored a basic_string's bytes into a
string_view, which LLVM refused; (12) A FUNCTION THE SHIPPED LIBRARY ONLY DECLARES
gets its result and parameters RESOLVED (`cpp_use_mangled`, 0.58's rule for an inline
one): `string to_string(int)' is declared under the raw alias, and `std::to_string(x)
+ "!"' deduced nothing for `operator+(const basic_string<...> &, const _CharT *)';
(13) CLASS TEMPLATE ARGUMENT DEDUCTION ([over.match.class.deduct], [dcl.type.class.deduct]:
`cpp_ctad_args' at the expression road and at a declaration) -- a class template's name
written with arguments deduces them from the IMPLICIT GUIDES, each constructor taken as a
function template over the class's own parameters, else an aggregate's data members in
order: libc++'s C++23 `__allocate_at_least' returns `__allocation_result{__res.ptr,
__res.count}', and with the bare name deduced its `.ptr' had no type; (14) A DEDUCED
RESULT'S CONDITIONAL is the arm the other converts to ([expr.cond]/4, `cpp_deduced_ret');
(15) A CANDIDATE'S RESULT TYPE IS RESOLVED ONLY WHERE ITS NAMES ARE BOUND
(`cpp_result_holds', [temp.deduct]/2): `__invoke_result_t<_Args...>' resolved with the
pack free instantiated `__invoke_result_impl<void, _Fn>' on that name; (16) A FILE-SCOPE
ALIAS IS THE CLASS IT NAMES in a path (`cpp_path_class'): `std::string::npos' was
flattened to the bare `npos'; (17) A STATIC CONST NAMED BARE AS A TEMPLATE ARGUMENT
folds to its value (`cpp_targ_value', 0.60's rule for an expression), which is how
libc++'s find calls `__str_find<value_type, size_type, traits_type, npos>'; and (18) IN
THE LOWERING, A REFERENCE TO A FUNCTION IS THE FUNCTION'S ADDRESS, with nothing to load
([conv.func]; `ir_convert' and the call's reference result): `std::forward<_Func>(__f)'
over `optional<int> (&)(int)' loaded the first eight bytes of the code and called them.
AND THREE THE GATE FOUND, each a defect of this step's own making:
(19) THE IMPLICIT DEFAULT CONSTRUCTOR IS NOTED WHERE THE CLASS EMITS IT, so a later
naming does not emit it again (`cpp_item`; `cpp_use_member' takes a lazy class's written
`C()' by the same name -- two identical definitions, which LLVM refuses); (20) A UNION'S
MEMBERWISE COPY IS ITS BYTES, copied by `memcpy' from the source's ADDRESS (0.83's rule
for an anonymous union member, here for a union class): as an assignment the two sides
were typed by two roads and basic_string's `__rep' loaded its source as `[0 x i8]' where
the slot was `{ i64, [16 x i8] }'; and (21) the implicit copy made ON DEMAND for a local
is THE PROGRAM'S OWN classes' (`cpp_ctor_args'), a library class's special members coming
through its own lazy road. Lowering version 31; reader version 63.
Seven gates GREEN under cocolog 1.2.14 (the module rebuilt for it: the reader's 94
checks, 6 s and 96 MB; the compile gate's 73 at 175 MB; the driver's 23 at 68; the
objects' 29; the proof; the C++ one 138 checks, 2157 s, 1350 MB; the libc++ one's 15
reads, 909 s, 1858 MB), and the C++ gate RED twice before them, each failure this step's
own (the three above); the libc++ gate died ONCE with no output at all, 155 s in and a
third of the way, straight after the C++ gate's 2157 s -- its script keeps only the lines
that match, so a crash leaves nothing to read, and the same query run alone gave the same
fifteen reads (896 s, 1980 MB) as the rerun did. AND WHAT 1.2.14 BOUGHT, warm against warm on the same fixtures:
the reader's peak 179 -> 96 MB, the compile gate's 326 -> 175, the driver's 83 -> 68,
the C++ one's 1489 -> 1350 -- the compaction's own peak, which the engine's owner cut by
sizing the new cell array at the live length instead of letting it double into place.
NOT DONE: the C++23 optional's
`transform` to a STRING and its `and_then` whose lambda returns a conditional over
`optional<int>` and `nullopt` (both stop at `__invoke_result_impl<void, _Fn>`, an
instance asked while the pack is free -- the trace `free_name_instance' names every
such ask now); `std::hash<optional>` (a local's `operator()' on that specialization);
`find_first_of` (`__str_find_first_of' cannot deduce its `_BinaryPredicate'); the
unordered containers' `erase_if`; `<vector>`, `<string>` and `<iostream>` read at
C++20 (only the associative containers and `<optional>`/`<string>` are); a program's
own `operator<=>`, `std::format`, the ranges.

## 0.86 — M6's fifty-third step

**M6's fifty-third step (0.86): `<memory>`, whole -- `std::unique_ptr`,
`std::shared_ptr` and `std::weak_ptr` compiled from libc++'s own bodies.** THE
MODULE: `test/cpp/run/stduniqueptr.cpp` (a `unique_ptr<int>` over `new`, `*`,
`get`, `operator bool`, `reset`, `make_unique`, MOVED from and the source left
empty, a `unique_ptr` of the program's own class with a destructor counted, a
method through `->`, `release` and the raw pointer `delete`d, a default-built one
assigned from a `make_unique`), `stdsharedptr.cpp` (`make_shared<int>` with
`use_count` through a copy's scope, `make_shared` of a class with a destructor,
a `weak_ptr` from it, `expired`, `use_count`, `lock` into a second owner,
`reset` destroying the object and the weak pointer expiring with it,
`shared_ptr<int>(new int(12))` and its `operator bool`) and `stdmemory.cpp` (a
`unique_ptr<int[]>` over `new int[4]` and over `make_unique<int[]>(n)` with
`operator[]`, a CUSTOM DELETER whose parameter is `own`, `swap` as a member and
as `std::swap`, the comparisons with `nullptr`, `addressof`, a `unique_ptr` as a
class's member built in its constructor's initializer, an ALIASING `shared_ptr`
into the object's own member keeping it alive, two `weak_ptr`s and the object
outliving its first owner) match clang++ line for line, and `<memory>` is read
WHOLE in the libc++ gate. THE FORMS, each named:
(1) A POINTER TO MEMBER, `_Rp (_Cp::*)()` and `int C::*` ([dcl.mptr]), its own
node (`memptr(Class, Quals)`, `ccl_pointers`, `ccl_apply_pointers`) so it can
never be taken for a plain pointer: libc++'s `__weak_result_type` specializes
over one for every member-function shape, and the reader stopped at
`<memory>`'s line 4317 of 8957 on the first of them. Nothing lowers one; a
program that writes one is refused by name, and a specialization's pattern over
one matches nothing a program has. (2) AND ONLY A POINTER TO MEMBER FUNCTION
TAKES THE CV- AND REF-QUALIFIERS AFTER ITS PARAMETERS, `_Rp (_Cp::*)() const`
and `() &&` (`ccl_memptr_quals` in `ccl_decl_syntax`, the declarator's own
memptr the test) -- read in `ccl_suffix_quals`, where a function TYPE's
`noexcept` is dropped, they take a METHOD's own `const` with them, which is the
method rule's (`ccl_method_quals`): every const method in the language lost its
mark, the const overload, the const ordering and the `K` of a shipped member's
Itanium name with it (the link named
`__shared_weak_count::__get_deleter(const type_info &)` without it). The gate
did not find this -- our own mangling is `.c` on both sides of a call and
agrees with itself; the shipped library's does not. (3) A MEMBER CLASS
TEMPLATE'S NAME IS NOTED AHEAD with the member function templates' (0.81's
`ccl_member_templates_ahead`, now `struct`/`class`/`union` after the parameter
list): `shared_ptr` uses `__shared_ptr_default_delete<_Tp[], _Yp>` two hundred
lines before it declares it, which a complete-class context allows
([class.mem]/6), and read in order it was a pair of comparisons. (4) A TYPE THE
READER CANNOT SETTLE STAYS `auto` OUTSIDE A TEMPLATE TOO (`ccl_free_name`:
inside one every name the tables do not know is some parameter's, which is
0.60's rule unchanged; outside one a name the tables know as a typedef, a tag,
a template or an env entry is settled and anything else is somebody's
parameter): 0.60 asked the question only inside a template, and `auto q =
std::make_unique<int>(7)` written in `main` took `unique_ptr<_Tp>` off the raw
declaration a summary holds a function template under, with `_Tp` free -- the
lowering met `typedef(_Tp)`. The two branches are kept apart on purpose: a
template's own parameters ARE in the global env while its item is read, so
testing the env inside one would have made them settled and undone 0.60. (5) `typeid` is read
as its own node and refused by name. Reader version 67.
AND NO RTTI, the question 0.50 asked of exceptions asked again: libc++ decides
its `_LIBCPP_HAS_RTTI` by `#if defined(__cpp_rtti) && __cpp_rtti >= 199711L`,
and this compiler emits no `type_info` object for any type, so neither
`__cpp_rtti` nor `__GXX_RTTI` is predefined any more (`ccl_pp.pl`, commented
with the reason) and the library compiles its own no-RTTI configuration, as
`-fno-rtti` gives it. `shared_ptr`'s control block writes
`__t == typeid(_Dp) ? addressof(__deleter_) : nullptr` in an override; without
RTTI the override is not there and the base's shipped one answers null. Four
headers change (`any`, `exception_ptr`, `shared_ptr`, `function`) and the
VTABLES do not -- `__shared_weak_count::__get_deleter` is declared
unconditionally and only the derived override is guarded -- so our control
blocks lay out as the shipped library's. A program's own `typeid` and
`dynamic_cast` are refused by name with it: the cast had been passed through as
a plain one, which is a WRONG ANSWER for a downcast rather than a missing form.
THE DESUGARING: (6) A CLASS TYPEDEF THAT ASKS FOR ITSELF WHILE IT IS BEING
RESOLVED IS LEFT AS WRITTEN, a guard per (class, name) as `cpp_fold_static` has
one: libc++'s `type_info` writes `typedef __type_info_implementations::__impl
__impl` over a NAMESPACE, and the namespace flattening makes that `typedef
__impl __impl`, which asked for itself without end (139,393 flattens, 140 s to
2803 MB). THE SHAPE IS NO TEST, which is how this was first written and what
cost the day: `allocator_traits` writes `typedef typename __base::pointer
pointer`, the same spelling through a scope that DOES resolve, and refusing it
by shape left every `pointer`, `size_type` and `allocator_type` parameter of
the allocator traits raw at the lowering (`not lowered yet: typedef(pointer)`).
The guard is 4 s and 140 MB and resolves both. (7) `nullptr_t` TAKES A NULL
POINTER CONSTANT AND NOTHING ELSE in the TEMPLATE road too ([conv.ptr];
`cpp_param_accepts`, where 0.81 had put it at the fit and the arity-only last
resort): libc++ writes `unique_ptr(nullptr_t)` beside `explicit
unique_ptr(pointer)` as two constructor templates under one guard, both held
for `unique_ptr<int> p(new int(5))`, the first declared won, and `*p` read a
null. (8) `std::move(x)` NAMES AN OBJECT and is no temporary to elide
([basic.lval]: an xvalue, not a prvalue; `cpp_decl_pieces`' elide guard):
elided, `auto r = std::move(q)` made `r` the bytes of `q`, both unique_ptrs
held the pointer and both freed it. (9) THE ARRAY AND REFERENCE TRAITS
(`cpp_builtin_type`): `__remove_extent` and `__remove_all_extents`
([meta.trans.arr]), `__add_pointer`, and `__add_lvalue_reference` and
`__add_rvalue_reference` with REFERENCE COLLAPSING, where they had unreffed
first -- `shared_ptr`'s `element_type` is `__remove_extent_t<_Tp>`. (10) `new
T[n]()` and `new T[n]{}` VALUE-INITIALIZE every element ([expr.new]/24), which
for a scalar is its zero bytes -- `calloc` exactly, and `make_unique<_Tp[]>(n)`
is `unique_ptr<_Tp>(new _Up[__n]())`, the one place the form is asked for;
refused by name since 0.71.
THE CHECK: (11) A LIBRARY CLASS'S VALUE MAY BE MOVED (`ck_moves_library` in
`ck_expr(move)` and `ck_kind(move)`): what it holds is libc++'s own discipline,
as its pointers already are (0.79's `ck_carries_`) and its functions' bodies
are (0.45), and `auto r = std::move(q)` over a `unique_ptr` is the ordinary way
to use one -- refused as `move of a non-owner`, since the check has no owner
behind it and needs none.
THE LOWERING: (12) THE ATOMIC BUILTINS ARE LLVM'S OWN INSTRUCTIONS, never a
call to anything (`ir_atomic_rmw` and kin): `__atomic_add_fetch(p, -1,
__ATOMIC_ACQ_REL)` is how `shared_ptr` counts its owners
(`__libcpp_atomic_refcount_decrement`), and the compiler is asked for it by
name. An `atomicrmw` answers the OLD value, so a `*_fetch` form applies the
operation once more to it and a `fetch_*` form takes it as it is; `exchange`,
`load`, `store` and the two fences go with them, the load and the store
carrying the type's alignment beside the ordering. The memory order is the constant the header
spells, clang's own numbering, which this preprocessor predefines
(`__ATOMIC_RELAXED` 0 .. `__ATOMIC_SEQ_CST` 5); anything that does not fold is
sequentially consistent. Lowering version 32.
Seven gates GREEN, warm, at cocolog 1.2.15 (the reader's 94 checks, 40 s and
429 MB; the compile gate's 73 at 364 MB, 35 s; the driver's 23 at 68 MB; the
objects' 29; the proof; the C++ one 141 checks, 1885 s, 1480 MB; the libc++
one's 16 reads, 829 s, 2316 MB, `<memory>` 324 items) -- and the cache was
warmed OUTSIDE them first, one header a process at each of the four levels
(21 summaries), since the reader's version moved twice in this step and a cold
first run peaks far above the steady state. The three fixtures build in 6 to
50 s at 150 to 870 MB; `leaks` finds none.
NOT DONE: `shared_ptr::get_deleter` and `dynamic_pointer_cast`, which are not
there without RTTI -- what `-fno-rtti` means; `enable_shared_from_this`,
`owner_before` and `std::atomic<shared_ptr>` (untried); `make_unique<T[]>` of a
CLASS, whose elements need their constructor run over each and their destructor
over each at `delete[]`, which needs the ABI's ARRAY COOKIE (the count written
before the first element) that nothing here writes -- refused by name
(`new_array_of_objects`), with `new T[n]{a, b}` beside it; a program that calls
`std::allocator::allocate` directly, whose raw pointer the safe part refuses as
a loose one, exactly as it refuses a bare `malloc` with no `own` slot behind it;
`std::uninitialized_copy` and the `destroy_*` algorithms called by a program;
`std::unique_ptr`'s ordering operators; a POINTER TO MEMBER lowered (the reader
takes one, nothing else does); and `<atomic>`'s own surface -- the
compare-exchange builtins, the waits and the fences' scopes -- which is a module
of its own.

## 0.87 — M6's fifty-fourth step

**M6's fifty-fourth step (0.87): THE RESULT TYPE OF AN UNINSTANTIATED TEMPLATE, and
the first LINUX port.** TWO PIECES, the first a defect three steps had named and none
had caught. `std::optional`'s C++23 `transform` to a class, its `and_then` over a
conditional and `std::hash<optional>` all stopped at
`no_member_type('__invoke_result_impl.void._Fn_', type)` -- an instance keyed by `_Fn`,
which is `std::invoke`'s OWN template parameter. THE RULE: `cpp_class_of_type_of`, the
class an EXPRESSION has, must not take a RAW type -- the guard `cpp_arg_type` has had
since 0.83 -- and `cpp_raw_type` now knows two more shapes: a template-id whose argument
is a free name, and one sitting in a SCOPED PATH, which is what `invoke_result_t<_Fn,
_Args...>` is once the alias is followed (`typename invoke_result<_Fn, _Args...>::type`,
whose last segment is `type` and whose scope carries the free name). Left raw, the value
falls to `cpp_init_arg_class`, which desugars the call, instantiates it, and reads the
instance's concrete result. WHY IT WAS FATAL rather than merely wrong: resolving that
type instantiated the traits on a free name, and the SFINAE specialization -- whose first
element is a `void_t<decltype(...)>`, matched in the non-deduced pass (0.46) -- cannot
match one, so the PRIMARY was chosen and the primary deliberately has no `type`.
THE INSTRUMENT THAT FOUND IT, and the reason 0.65's lesson had to be learned twice:
`cpp_where` kept ONE frame, so a trace inside an instantiation reported the ask naming
ITSELF (`in(class(__invoke_result_impl))`). It is a bounded stack now, six frames, kept
only while `'$cpp_trace'` is on -- an ordinary build pays nothing, since `nb_setval`
copies what it stores and the breadcrumb is entered at every statement -- with a frame on
the scope walk and the class context beside the free-name trace. It took the reproduction
from fourteen seconds over all of `<optional>` and `<string>` to a TWENTY-LINE program
that fails in one second at 3 MB, and three ingredients are necessary and sufficient: a
function template whose declared result is a dependent alias over its own parameters, a
class template whose constructor initializes a CLASS-typed member from a call to it, and
a specialization whose first pattern element is a SFINAE `void_t<decltype(...)>`. Drop
the third and it runs; drop the second as well and the bad ask never happens.
AND THE FIRST LINUX PORT, on a Colab runtime over an ssh tunnel: Ubuntu 24.04.4,
x86_64, two cores, clang 18.1.3, LLVM 18, SBCL 2.2.9, libc++ from the distribution.
Three things in THIS repository were macOS-shaped, each found by running and none by
reading. (1) `module/build-llvm.sh` linked `-lLLVM-C`, which is Homebrew's layout;
Debian keeps the C API inside the one `libLLVM` and the link simply fails ("cannot find
-lLLVM-C"). The name is read off disk now (`llvm-config --libdir`, `libLLVM-C.*` if it is
there, else `-lLLVM`), with the rpath following it. (2) THE INCLUSION PATH NEVER LOOKED
IN THE MULTIARCH DIRECTORY: Debian and Ubuntu split the C library's headers, `<bits/...>`
and `<sys/cdefs.h>` living in `/usr/include/<triplet>`, which clang searches BEFORE
`/usr/include` (`clang -E -v` lists it there). Without it the closure of `<stdio.h>` was
146 lines against clang's 828 over 35 files, and `__BEGIN_DECLS`, `__THROW`, `__wur` and
`_Nonnull((1))` reached the reader unexpanded; with it, 514 and every one expanded
(`ccl_multiarch_dirs`, both triplets offered and `ccl_existing_dirs` keeping whichever is
there, so macOS is untouched). (3) A NULLABILITY WORD MAY CARRY AN ARGUMENT LIST. glibc's
`__nonnull(params)` reaches this reader as `_Nonnull ( ( 1 ) )`, a spelling no compiler
emits on purpose -- and it is OURS: the predefined table is clang's, so `__clang__` is
defined, while `__has_attribute` answers 0 (the preprocessor's plainest path), and
`sys/cdefs.h` then takes a branch neither compiler would. Read as the bare qualifier
Apple's headers write, that `((1))` stopped the read of `<stdio.h>` at `fclose`, 69 lines
before `printf` was declared. Reader version 68.
WHAT THE SYMPTOM LOOKED LIKE, and it looked like nothing of the kind: `undeclared(printf)`
for a two-line program, because A PARTIAL READ IS SILENT (0.44) -- a reader that stops two
thirds of the way through a header leaves a unit that simply lacks the rest. The bisect
that settled it is worth keeping: the declaration ALONE, `extern int printf(const char *
__restrict, ...);`, compiles and runs, so the reader was stopping short and not reading
and dropping. Those are different defects and only a measurement tells them apart.
AND A TRAP THAT COST A WRONG CONCLUSION mid-chase: `cicilang++ -fsyntax-only` PASSES on that
same file on Linux, because in C++ mode the driver skips the check and the lowering under
that flag. A flag that skips the stage under test passes for a reason that has nothing to
do with the question, so it reads as evidence of health and is evidence of nothing; the
tell is that the good news arrived too cheaply.
Seven gates GREEN, at cocolog 1.2.16 and reader 68, the cache warmed OUTSIDE them first at
all four levels (21 summaries), since the reader's version moved and a cold first run peaks
far above the steady state: the reader's 94 checks, 39 s and 388 MB; the compile gate's 73 at
370 MB; the driver's 23 at 68; the objects' 29; the proof; the C++ one 141 checks, 1995 s,
1441 MB; the libc++ one's 16 reads, 859 s, 2278 MB.
NOT DONE: the Linux gates. cicilang compiles and runs C and C++ there, and the C++ gate
reaches 83 of its checks where before the three fixes it reached none, but six fail and each
is its own glibc gap -- `stdcin.cpp' stops at `template_without_body(basic_string)', a
template body that did not survive into the summary, which says `<iostream>''s closure is
short there as `<stdio.h>''s was. The libc++ gate has not run there at all. AND THE RULE THAT
DID NOT TRAVEL WITH THE GATES: every cocolog run of mine on the Mac goes through a watchdog
that samples resident size and kills past 2800 MB, and the Linux chain was written without
one -- an hour of gates with no cap on a box whose `/sys/fs/cgroup/memory.max' reads `max'
from inside, so the real ceiling is imposed from outside and invisible to the obvious check.
Nothing of ours was killed (the OOM took a 9.7 GB neighbour and the notebook's own node), but
that was luck and not design; the cap goes in before Linux runs again, and a gate that dies
with no output is `dmesg | grep -i "killed process"' before it is anything else.

## 0.88 — M6's fifty-fifth step

**M6's fifty-fifth step (0.88): `<functional>`, whole -- `std::function`, `std::bind`
and the callable adaptors compiled from libc++'s own bodies.** THE MODULE:
`test/cpp/run/stdfunction.cpp` (a `std::function<int(int)>` from a function pointer, a
lambda, a functor and an empty one; `operator bool', the null comparisons, a copy, an
assignment, `swap'; a void result, two arguments, a capturing lambda, and a vector of
them walked by a range-for), `stdbind.cpp` (`std::bind' with the placeholders, one
reordering its arguments and one repeating a placeholder; `mem_fn' of a nullary and of a
one-argument method; `std::invoke' of a free function, of a pointer to member and of one
with an argument; a pointer to member written out and called with `.*' and `->*';
`std::ref' into a `std::function'; a member function bound to an object) and
`stdfunctional.cpp` (the arithmetic, comparison, logical and bitwise function objects, the
transparent `less<>' and `plus<>', `reference_wrapper' with `ref', `cref', `get' and a
rebind, `std::hash' of an int and of a string, a function object as a set's comparator)
match clang++ line for line, and `<functional>` is read WHOLE in the libc++ gate (472
items). THE READER (version 69), by the census loop: (1) A POINTER TO MEMBER FUNCTION
TAKES THE NOEXCEPT-SPECIFIER after its cv- and ref-qualifiers ([dcl.fct]/1, the order cv,
ref, noexcept), which `__strip_signature<_Rp (_Gp::*)(_Ap...) const noexcept>` and its
fifteen siblings spell -- 0.86 read the cv- and ref- ones and stopped there, and the header
died at line 4421 of 18167; `ccl_suffix_quals' is the one rule for `noexcept' and `throw(...)',
and the member-pointer qualifiers now end in it. (2) THE RIGHT SIDE OF AN ASSIGNMENT MAY BE
A BRACED LIST ([expr.ass]/9: `x = {}' value-initializes, `x = {a, b}' list-initializes),
which is how `__policy_func''s move constructor empties the one it moved from,
`__f.__func_ = {};'. (3) `x.*pm' AND `p->*pm' ([expr.mptr.oper]) are read from the two
punctuators the lexers already have -- no C writes `.' before `*' and none writes `->'
before one -- so NEITHER LEXER CHANGES and k84 still compares them token for token; only a
CALL of the node means anything here. (4) `__alignof' and `__alignof__' beside `alignof',
and `alignof(T)' FOLDS to the alignment the layout already computes (nothing evaluated it
before: the reader made the node and no pass took it).
TWO NAMESPACES OF ONE FLATTENED NAME, the open item since M6's first step: `<functional>`
declares `std::__maybe_derive_from_unary_function<_Tp, bool>' -- what `__weak_result_type'
derives from, named unqualified -- and `std::__function::__maybe_derive_from_unary_function<_Fp>'
-- what `std::function' derives from, written `__function::...' -- and flattened to one bare
name the first won both, so `function<int(int)>' took the two-parameter one, whose defaulted
second argument asks a detection over a member pointer that nothing could answer. THE
OUTERMOST NAMESPACE KEEPS THE BARE NAME (an unqualified use from there is what C++ finds);
every deeper namespace's items are indexed under `<innermost namespace>.<name>' with the
name inside the item rewritten (`cpp_ns_quals', `cpp_qualify_item'), and a use QUALIFIED by
that namespace resolves to it (`cpp_ns_key', in `cpp_type'). The decision is a function of
the header's own items, so the index and the AST beside the summary reach it alike without
either telling the other -- and it is the reader version's business, since the AST's keys
change. Measured on `<functional>`: exactly two names collide.
THE DESUGARING, each form named: (5) A PARTIAL SPECIALIZATION'S PATTERN MAY BE A FUNCTION
TYPE, `function<_Rp(_ArgTypes...)>' ([temp.deduct.type]/8: the result type and the parameter
types are deduced elements of their own, a trailing pack taking every parameter left) --
`function', `__func', `__value_func', `__policy_func' and `__alloc_func' are each a primary
template declared and never defined beside one specialization over a function type, and
without it every one of them fell to the primary and the instance was an incomplete type; a
function type as a TEMPLATE ARGUMENT is matched exactly, never decayed. (6) A FUNCTION TYPE
DECAYS TO A POINTER TO FUNCTION ([conv.func]), as an array does to a pointer to its element:
`std::function<int(int)> f = twice' hands `twice' to `function(_Fp)', whose `_Fp' is `int
(*)(int)' -- deduced as the FUNCTION type, `__decay_t<_Fp>' kept it, and `__func<int(int),
int(int)>' held its callable in a member of function type whose ADDRESS was then called
instead of its value; and a function CONVERTS to a pointer to itself, which is what
`is_constructible<_Fd, _Gp>' asks of `std::bind''s `int (&)(int, int, int)'. (7) A VIRTUAL
OVERLOAD SET: a slot is named by the method AND ITS ARITY, since `__base''s `virtual __base
*__clone() const' and `virtual void __clone(__base *) const' are two slots -- named alike,
the table's struct had the member twice, the dispatch took the first, and a COPY of a
`std::function' called the nullary clone with two arguments. (8) A VIRTUAL `operator()'
DISPATCHES, as a named method already did: `std::function' calls what it holds through
`(*__f_)(std::forward<_ArgTypes>(__args)...)', whose `__base::operator()' is PURE, and
called directly the link named it. (9) MULTIPLE INHERITANCE WHERE A BASE AFTER THE FIRST HAS
STORAGE OF ITS OWN ([class.derived]: the non-virtual bases in declaration order, then the
class's own members): each is a sub-object `$base$2', `$base$3' ... laid out after the first
base, constructed and destroyed with it, reached by the member lookup, the hops and the
lowering's base walk (`ir_base_route', one route found and walked where two walks found
their own); an EMPTY extra base is still a scope and no bytes (0.71), and only a POLYMORPHIC
one is refused, since two tables need a `this' adjusted at every call. `std::tuple' is built
this way -- `__tuple_impl<__tuple_indices<_Indx...>, _Tp...> : public __tuple_leaf<_Indx,
_Tp>...', one base per element -- and `std::bind' stores its bound arguments in one.
(10) A POINTER TO MEMBER FUNCTION keeps its shape through the passes (`memptr(C, Q, T)'),
so the deduction and the thirty specializations `__weak_result_type' writes over it read it
as it stands, and only the lowering turns it into what it is here: the ADDRESS of the one
function this compiler emits for that method, whose first parameter is the object. `&C::m'
is that address cast to the member-pointer type; `__builtin_invoke(pm, obj, args...)' and
`(obj.*pm)(args)' are the indirect call. A pointer to a VIRTUAL member (which would have to
carry a table index), to a DATA member (an offset) and an OVERLOADED member's address
(no target here to choose by) are refused by name. (11) A DECLTYPE'S EXPRESSION AND A
TEMPLATE ARGUMENT ARE WALKED IN THE CLASS they are written in, where C++ looks their names
up: `using type = decltype(__find_base(static_cast<_Tp *>(nullptr)))' names a static member
of that class, and `aligned_storage<sizeof(__buf_)>::type __tempbuf' names a member of the
enclosing one -- walked with no context both stayed as written and neither had a type.
(12) A STATIC METHOD NAMED BARE inside its class takes a null `this', as a static member
template has since 0.47, and AN ELLIPSIS IS C++'S WORST MATCH for a plain overload too
([over.ics.ellipsis]): `static void __find_base(...)' is the answer where the template
beside it deduces nothing, and it is tried after every other overload and every template.
(13) A FILE-SCOPE `const' OBJECT OF INTEGRAL TYPE WITH A CONSTANT INITIALIZER IS A CONSTANT
EXPRESSION ([expr.const]; the rule 0.63 gave a `const' LOCAL): libc++ writes `inline const
size_t __aligned_storage_max_align = alignof(__max_align_impl<...>);' and every
`aligned_storage' asks for that name inside a variable template's initializer, where only a
constant will do. The initializer is desugared before it is folded, under a guard per name,
and only a SUCCESS is remembered -- asked once from inside a candidate whose walk is
abandoned, a remembered failure would stand for ever. (14) A CLASS WHOSE ONLY CONSTRUCTOR IS
A TEMPLATE takes arguments as a temporary: libc++'s `bind' writes `typedef __bind<_Fp,
_BoundArgs...> type; return type(f, args...)', and counted by its data members the call took
more than the class has and was left as a call to the class's own name. (15) A DATA MEMBER OF
FUNCTION-POINTER TYPE IS CALLED THROUGH, as C calls one, where the refusal `no_member' is
for a name the class does not have at all. (16) `cpp_is_type' knows a pointer to member, so
the two-pass pattern matching puts one where it belongs.
Reader version 69, lowering version 33. Gated by the three module fixtures above and by
`test/cpp/run/multibase.cpp` (two bases with storage and an empty one, the offsets, a
deeper derivation and the memberwise copy) and `detectbase.cpp` (the detection idiom
`__weak_result_type' is written on: a variadic static member function beside a template one,
read through a decltype at class scope).
NOT DONE: `alignas' is still dropped, so `__aligned_storage_max_align' folds to 1 and
`std::function''s inline buffer is 24 bytes aligned 1 where clang's is 32 aligned 16 -- self
consistent, and in practice 8-aligned by its place in the object, but not the ABI's layout;
`sizeof' OF AN EMPTY CLASS IS 0 here and 1 in C++ ([class]/4), which cannot be fixed by
itself, since the empty base would then take a byte where C++'s optimization gives it none
-- the pair belongs to one step of its own; `sizeof' a pointer to member function is 8 and
not the ABI's 16, the price of refusing the virtual case; an UNQUALIFIED use of a colliding
name from inside the deeper namespace still finds the outer one (libc++ qualifies every one
of them); `std::function::target' and `target_type' (RTTI is off, 0.86); `std::not_fn',
`std::identity' and `std::bind_front' (C++17/20, untried); `std::invoke' of a pointer to
DATA member; `std::bind' of a member function pointer as the callee with `std::ref'ed
arguments; and `<tuple>' as a module of its own, which the multiple inheritance above is
the road to.
Seven gates GREEN at cocolog 1.2.16, the cache warmed OUTSIDE them first at all four levels
(22 summaries, `<functional>` the new one), since the reader's version moved: the reader's 94
checks, 38 s and 396 MB; the compile gate's 73 at 358 MB; the driver's 23 at 77; the objects'
29; the proof; the C++ one 146 checks at 1623 MB; the libc++ one's 17 reads, 945 s, 2306 MB.
AND THE C++ GATE'S CLOCK IS NOT A NUMBER THIS TIME: it read 16655 s against 0.87's 1995, and
`pmset -g log` says the machine was ASLEEP for 173 of those 278 minutes -- a clamshell sleep on
battery at 16:05 for eighty minutes, then five maintenance sleeps. The gate measures elapsed
time with `date +%s`, so it measured the lid. I read the number as an eight-fold REGRESSION
and named a cause before measuring; the owner said sleep, and the log said sleep. What the
regression would have looked like was in front of me and I passed it twice: the sampled rate
was four fixtures in one half-hour and twelve in the next, and a slowdown in the compiler is
evenly slow. The measurement that settles it is one fixture against a recorded number, awake,
with the CPU time beside the wall clock: `test/cpp/run/stdmap.cpp` builds in 28.3 s of user
time at 489 MB (18 s at about 1.1 GB when 0.79 recorded it, nine steps and cocolog's store
compaction ago), and with `cpp_global_const' STUBBED TO FAIL -- 0.87's behaviour, the predicate
being new here -- 28.6 s: this step's one addition to the hot path costs nothing measurable.
The libc++ gate ran in a window with no sleep in it and is the honest comparison: 945 s against
859 at 0.87, for one header more.

## 0.89 — M6's fifty-sixth step

**M6's fifty-sixth step (0.89): THE LAYOUT RULES A CLASS'S BYTES ARE MADE OF -- the empty
class, the empty base, `alignas' and `[[no_unique_address]]'.** 0.88's not-done list opened
with a PAIR that cannot be taken one at a time, and said so: `sizeof' AN EMPTY CLASS IS ONE
in C++ ([class]/4) -- two objects of it must have two addresses, an array of three is three
bytes, and `new' must hand back something -- while an EMPTY BASE takes NO BYTES (the empty
base optimization), so the first rule written alone would grow every class derived from an
empty one by a byte C++ does not give it, and libc++'s allocators, comparators, tuple leaves
and `__weak_result_type' are empty bases everywhere. It became a TRIO, since two more of that
list are the same question asked of a member: `alignas' was dropped by the reader, so
`std::function''s inline buffer came out aligned 1, and `[[no_unique_address]]' was dropped
with it, so libc++'s marked allocators and paddings each took a byte the ABI does not give
them. THE FOUR RULES: (1) A CLASS WITH NO DATA MEMBERS AT ALL IS ONE BYTE (`ccl_class_size',
in cpp only: in C an empty struct is a GNU extension of no bytes and stays so), and the test
is the MEMBERS and not the layout -- keyed on `lays out to zero', `struct Z { char p[0]; }'
came out 1 where C's answer and clang's is 0, and libc++'s compressed-pair padding, `char
__padding_[sizeof(_ToPad) - __datasizeof_v<_ToPad>]', is exactly such a member. (2) AN EMPTY
BASE HAS NO SUB-OBJECT (`cpp_base_layout_'): no `$base' member is laid down for it, the
base's address IS the object's (`cpp_base_place', `cpp_base_src', `cpp_base_hop', the three
doors that named `$base' on their own), and its typedefs, statics and methods are found
through `cpp_base_scope' as the EXTRA empty bases have been found since 0.71 -- this is that
rule, moved to the first base, where 0.71 could only have it after the first. A MEMBERWISE
COPY MUST NAME THE SOURCE'S BASE AS THE BASE (`cpp_base_src''s reference cast): handed the
object itself, the overload choice looked for a base constructor taking the DERIVED class and
refused `base_constructor'. AND SLICING TO SUCH A BASE IS A CHANGE OF TYPE AND NOTHING ELSE:
`cpp_copies_' sliced a derived object handed to a by-value base parameter only where the base
walk gave HOPS (0.79's rule), and an empty base leaves none -- libc++'s `__priority_tag<N> :
__priority_tag<_N - 1>' is a CHAIN of empty classes, so `__priority_tag<1>()' reached the
`__priority_tag<0>' fallback of `__try_key_extraction_impl' carrying its own type and LLVM
refused the store (`stdmapown' in the C++ gate, the one fixture of 149 that said so). With no
hops every base on the path is empty, so the value carries nothing and only the TYPE moves; the
argument's evaluation is kept beside the base's own empty aggregate, since it may have effects. (3) `alignas' ON A CLASS, A STRUCT OR A UNION ([dcl.align]) is
KEPT by the reader where every other attribute is dropped -- as `align_as(E)' at the END of
the members, the head being where `union_tag' and `enum_base' sit -- folded in the class's
own words by the desugaring as a bitfield's width and an array's bound are (`cpp_align_tag'),
and read by the layout (`ccl_align_as' through `ccl_tag_size': never smaller than the natural
alignment, the size rounded up to it). AND AN EMPTY BASE STILL CONTRIBUTES ITS ALIGNMENT
though it takes no bytes ([class.derived]: the optimization is about storage), which is
written as an `align_as' marker of its own (`cpp_empty_base_align'): libc++ finds the widest
alignment a platform has by deriving `__max_align_impl' from six `alignas'-carrying EMPTY
bases and asking `alignof' of it, and with their alignment dropped it answered 1 --
`alignof(T)' itself has folded since 0.88, so the alignment was there to be read and nothing
carried it. `alignas(T)' is read as that same `alignof_type(T)' (`ccl_align_arg', the type
name tried once and only where a `)' follows it, so `alignas(16)' stays the expression it is).
(4) `[[no_unique_address]]' ([dcl.attr.nouniqueaddr]) is C++20's empty base optimization for a
MEMBER, and the ONE attribute the reader does not drop: an empty member marked with it takes
no bytes and keeps its alignment, a member with bytes of its own lies where it always did.
libc++ marks every container's allocator and comparator with it. The mark is noted as the
attribute goes past (`ccl_skip_attr', since the attributes sit inside `ccl_decl_specs', which
every declaration in both languages shares) and CLEARED ONCE PER MEMBER in `ccl_members' --
not in the declarator, since `ccl_member_decl' has a clause that drops an attribute and
RECURSES, and a reset there wiped the very flag that attribute had just set; it travels in
the member's BIT-WIDTH slot, where a width would sit and no width can (`ccl_plain_width',
`cpp_bit_width'), so nothing else in the passes changes shape, and the layout gives `lay(N,
T, Off, empty)'. AND THE LOWERING'S SHAPE AGREES WITH THE LAYOUT (`ir_struct_shape' through
`ccl_tag_size'): an empty class is one byte in LLVM too, an `alignas' class is padded to the
size its alignment gives it, and a marked empty member is a zero-sized element, `{}', so the
GEP still gives its address.
AND A MEMBER THAT OWNS NO STORAGE MOVES NO BYTES, which the byte of rule (1) made urgent: an
empty class's byte is PADDING as a complete object and NO byte at all as a marked member,
whose address may be one past its holder's own or shared with a neighbour. So such a member is
zero-filled by nothing and copied by nothing (`cpp_zero_fill', at the four value-initialisation
doors and the memberwise copy beside them), and in the lowering a store through its slot writes
nothing while a load answers the type's zero (`ir_store_slot', `ir_load_slot' over the `empty'
mark the shape map now keeps) -- the net under every road that reaches a member slot. Before
it, libc++'s `: __alloc_()' over a marked allocator was a `memset' of sizeof, zero before this
step and ONE after, at an address the member does not own. Two roads fell out of writing it:
`ir_ref_of' handed a SLOT out as a pointer without passing `ir_slot_addr', which leaked a
bitfield's slot into the emitted text long before this step, and `ir_gelems' had no clause for
a member with no bytes and would have fallen into the bitfield packer for a global.
AND THE TEST FOR AN EMPTY CLASS IS ITS MEMBERS, NOT ITS LAYOUT -- written ONCE
(`ccl_no_data_members', asked by `ccl_class_size' and `ccl_empty_layout' alike). Written as
`lays out to zero' the second was wrong in exactly the way the first had already been wrong in
this same step, and I did not carry the lesson three lines down: `ccl_members_layout_' SKIPS a
member whose type it cannot size yet (its last clause takes any term), so a class whose members
are not resolvable at the moment of asking lays out to zero and reads as EMPTY. libc++'s
`_LIBCPP_COMPRESSED_PAIR' marks `__rep_' ITSELF with `[[no_unique_address]]', so basic_string's
24-byte union became a member of no bytes: the emitted struct was `{ {}, padding, {}, {} }'
with no `__rep_' in it at all, `a + ", "' came back EMPTY and `substr' then aborted on
out_of_range, while `a' alone still printed `hello' and `sizeof(std::string)' still read 24.
AND THE RIGHT LAYOUT IS CHEAPER, measured on the same machine within the hour, the spread cold at
reader 71 before and after the one-line rule: `stdvector' 82 -> 14 s and 788 -> 380 MB,
`stdfunctional' 253 -> 60 s and 1412 -> 894 MB -- a struct whose union had vanished sent the
desugaring down roads the program never needed.
FOUND ON THE WAY, each a defect older than this step: A PLAIN STRUCT NAMED AS A BASE IS A
CLASS (`cpp_note_bases', `'$cpp_base_named''), since `struct Tag { }; struct X : Tag { ... }'
is everyday C++ and every empty base there is, while the reader keeps a C++ struct of data
members as C's -- nothing registered Tag and the derived class refused
`base_not_registered'; the names are collected BEFORE anything is registered, as the free
functions have been since 0.56, since a base is named after its own item and the decision
must be made once for the registration and the emission alike. THE LAYOUT MARKERS ARE TAKEN
OUT AT ONE DOOR (`ccl_members_of'): the check's field walks and the lowering's member roads
read that predicate, and an `align_as' where a `member/3' is expected failed a walk without a
word -- `phase(check)', the diagnostic 0.53 put there for exactly this. AND A TAG WHOSE
MEMBER LIST CARRIES A MARKER IS STILL A PLAIN STRUCT (`ccl_class_shape', one predicate where
two places tested the shape by hand): read as a class's, an `alignas' struct answered its raw
class where its desugared struct was meant and `sizeof' had nothing to lay out.
Reader version 71 -- 70 for `alignas', 71 for the mark, and BOTH bumps were owed: the mark
lives in the member terms an AST beside a summary holds, so left at 70 every cached header
kept serving members with `none', `sizeof(std::string)' read 40 against the library's 24 and
its `__data_' sat one byte late, which read as a fresh defect and was a stale cache. The rule
this repository already had (a change to what the AST holds bumps the version, 0.71) covers
the index and covers this.
Lowering version 34.
Gated by `test/cpp/run/emptyclass.cpp' (an empty class, an empty base, two of them, a MEMBER
of empty class type taking its byte, an array of three, and a pointer to an empty base at the
object's own address), `alignas.cpp' (on a struct, over-aligned, `alignas(T)', on a union, as
a member of another class, on an empty base, and the object's address checked at run time) and
`nounique.cpp' at C++20 (a marked empty member costing nothing and the same member unmarked
taking its byte, two marked, an over-aligned one, a marked member WITH bytes lying where it
always did, a trailing one, and libc++'s compressed pair's shape), clang++'s numbers.
Seven gates GREEN at cocolog 1.2.16, warm (the cache had been warmed outside them at all four
levels when the reader moved to 71): the reader's 94 checks, 6 s and 99 MB; the compile gate's 73
at 226 MB; the driver's 23 at 67; the objects' 29; the proof; the C++ one 149 checks -- 146 and
this step's three -- at 1739 MB; the libc++ one's 17 reads, 993 s, 2035 MB.
AND THE C++ GATE'S CLOCK IS A NUMBER THIS TIME, and it is a bad one: 6147 s against 0.87's 1995
for 141 checks, with `pmset -g log' showing NO sleep in the window (the first thing to ask since
0.88). The libc++ gate, which only READS the headers, is 993 s against 945 -- five percent -- so
the reader is untouched and every one of those minutes is in the passes that COMPILE. I NAMED A
CAUSE AND IT WAS WRONG: this step put `ccl_tag_size' inside `ccl_size_align', the hottest
predicate there is, with a `findall' in `ccl_align_as' allocating at every struct sizing, and that
is a good story -- but measured one variable at a time, warm against warm, the same fixture built
against the COMMITTED 0.88 costs the SAME (`stdmap': 37.5 s of user time at 0.89, 38.6 at 0.88,
519 MB against 420). The layout rules cost nothing measurable. The gate's average is 41 s a check
where 0.87's was 14, so the time is in OUTLIERS and not spread evenly -- `stdset3' alone took
twenty minutes of it -- and an outlier is where the next measurement goes. A THIRD number of mine
was no measurement either: the spread's `stdmap' at 105 s and 1182 MB, which I offered as evidence
of a slowdown, was the same code on a MIXED-AGE summary cache; wiped and warmed it is 31 s and
519 MB.
NOT DONE: an empty marked member that is NOT THE FIRST lies one past the members before it where
clang overlaps it with them, and two marked members of ONE empty type share an address where C++
gives them two -- the SIZES agree with clang in both, the addresses do not; `sizeof' a pointer to
member function is still 8 and not the ABI's 16; and A CONVERSION NEVER FIRES FOR A REFERENCE
PARAMETER -- `ccl_resolve_type' passes a `ref' through unchanged and the type-level class test
must not unref (0.51's rule), so `cpp_conv_fits' falls to `RT == RCT' and fails -- which is why
`std::string_view v = s;' takes string_view's COPY constructor over the string's own bytes; that
one is older than this step, found by a probe written for it, and a step of its own (the
by-value road, which is what `__concatenate_strings' uses, works).

## 0.90 — M6's fifty-seventh step

**M6's fifty-seventh step (0.90): `<tuple>`, and the conversion 0.89 left named.** The owner's rule
of 0.78 (a module at once) over `<tuple>`, whose every element libc++ keeps in a BASE of its own
(`__tuple_impl<__index_sequence<_Indx...>, _Tp...> : public __tuple_leaf<_Indx, _Tp>...'), so the
module rests on 0.88's multiple inheritance and 0.89's empty base -- and the first thing it found
was that neither of those laid an object out wrong, but a CAST to one of them did. THE FORMS, each
named: (1) A CAST TO A REFERENCE IS A CONVERSION OF ITS OWN, and the offset is from the OPERAND's
class to the CAST's target ([expr.static.cast]): `ccl_type_of' of a cast answers that target, so
taken whole by `ir_ref_to' the two classes were EQUAL, no base hops were walked and the object's
own address went out -- `L1::sw(static_cast<L1 &>(o))', which is how libc++'s tuple swaps its
leaves, swapped the second leaf of `this' with the FIRST of the argument (`t.swap(u)' on two
tuples gave 5 1 / 2 6 where C++ gives 5 6 / 1 2). The cast's own conversion is made at the one
door and whatever the binding still needs after it follows on the result; a local reference and a
pointer already took their offsets, which is why this survived 0.72. Lowering version 35;
`test/cpp/run/basecast.cpp'. (2) THE TUPLE PROTOCOL ([dcl.struct.bind]/4): where
`std::tuple_size<E>::value' is a constant, THAT many bindings are asked for and each is `get<i>(e)'
-- a tuple has no data member of its own, so the by-position member road found none and refused
`bindings_count'; an E that is no tuple has no such constant and the member road stands. (3) A
BOUND TYPE PARAMETER CALLED takes its ARGUMENTS SUBSTITUTED FIRST and its arity read off the
result, since a PACK EXPANSION is ONE element until it expands: `_TupleDst(std::get<_Indices>(
std::forward<_TupleSrc>(__src))...)' was taken for the one-argument functional cast and its pattern
substituted whole, refusing `pack_unexpanded'. One predicate for the three shapes (`cpp_type_called',
the owner's rule) where three clauses each matched an arity of the RAW list;
`test/cpp/run/packcall.cpp'. (4) AN ARRAY BOUND DEDUCES ([temp.deduct.type]/9: `T (&a)[N]' binds N
from the argument's own bound), which a REFERENCE parameter brings undecayed -- there was no clause
for an array PATTERN at all, only for a pointer pattern against an array argument. (5) A STATIC
MEMBER ARRAY's initializer is RECORDED (the `static' sits in the innermost base's qualifiers, so an
array's is reached through `cpp_static_type' as 0.72 already reached its type; a plain `base(Q, _)'
missed it) and is ITS OWN DEFINITION, `linkonce', as a folding scalar's has been since 0.45
(`cpp_static_aggregate', the items desugared in the class's words); and A STATIC DEFINED IN THE
CLASS IS NOT A SHIPPED SYMBOL -- named by its Itanium symbol (0.73) libc++'s `__matches' had no
type at the call that searches it. (6) A CONSTEXPR CALL AND AN INDEX INTO A CONSTANT ARRAY FOLD
WHEREVER THEY SIT: libc++ writes its search as `__i == _Nx ? __not_found : __find_idx_return(__i,
__find_idx(__i + 1, __matches), __matches[__i])', a conditional whose arms hold the recursive call,
so `ccl_const_eval' failed on the whole expression and nothing reached 0.72's call clause; the
forms that one evaluator cannot take are folded to their literals first and the arithmetic left to
it (the table is written once). (4) to (6) together are `std::get<T>', the by-type get;
`test/cpp/run/arraybound.cpp' has the shape on the program's own classes. (7) A HEADER'S INLINE
VARIABLE WITH NO INITIALIZER, which C++ VALUE-INITIALIZES ([dcl.init]/8; a `constexpr' object must
be initialized and none written is that): `inline constexpr __ignore_type ignore;' is
`std::ignore', and the index took only an inline variable WITH an initializer, so it was never
registered and reached the lowering as an `external global' the link named. Only an EMPTY class is
taken -- a class with a constructor would have to be constructed, and nothing here is evaluated at
compile time. The index is what the AST beside a summary is written by, so reader version 72.
(8) AND AN ASSIGNMENT TEMPLATE COUNTS where a class is asked whether it is ASSIGNABLE, as a
constructor template already counted in `cpp_ctor_arity_fits' (0.46): `__ignore_type''s only
`operator=' is `template <class _Tp> const __ignore_type &operator=(const _Tp &) const', so
`is_assignable<__ignore_type &, int const &>' read FALSE, tuple's CONVERTING assignment
(`operator=(tuple<_Up...> const &)') was rejected with it, and the copy assignment then took a
`tuple<int, int>' for a `tuple<int &, __ignore_type &>' -- an int read as an address, and
`std::tie(a, std::ignore) = f()' died before its first line. It was hidden until (7) made
`std::ignore' link at all.
AND THE CONVERSION 0.89 NAMED AND LEFT: a class value where `const T &' is wanted converts through
its `operator T()' and the reference binds to the PRVALUE the operator makes ([over.ics.user],
[dcl.init.ref]/5), so neither the reference NOR THE `const' ON IT is the conversion's business. THE
SCORER AND THE EMITTER DISAGREED: `cpp_arg_fit_' unrefs the parameter before it asks and so looks
through `const Yards &', and then `cpp_ref_args_' handed `cpp_conv_to' the type AS WRITTEN, where
`cpp_conv_fits' had neither an arithmetic pair nor two pointers nor two REGISTERED classes to
compare -- a plain struct is no registered class -- and fell to `RT == RCT', which the reference,
and then the `const' under it, each defeat on their own. Stripping at the emitter's one door leaves
every SCORE where it was and only makes the emission agree with the choice. 0.89 recorded the
symptom as string_view taking its copy constructor over the string's bytes; measured one variable
at a time against the committed library, `std::string_view v = s;' SEGFAULTS at 0.89 and gives
C++'s answer with this. `test/cpp/run/convref.cpp'.
WHAT RUNS: `test/cpp/run/stdtuple.cpp' -- a tuple built, subscripted by index and BY TYPE, written
through, made by `make_tuple' and `forward_as_tuple' and from a `pair', its `tuple_size' and
`tuple_element', `tie' and `tie' with `std::ignore', the comparisons, structured bindings by value
and by const reference, a `std::string' held and a tuple of them MOVED, a copy, the member `swap'
and `std::swap', and `std::apply' -- clang++ line for line, and `<tuple>' read WHOLE in the libc++
gate. Beside it `basecast.cpp', `packcall.cpp', `arraybound.cpp' and `convref.cpp', each the shape
on the program's own classes.
Seven gates GREEN at cocolog 1.2.16, the cache warmed OUTSIDE them first at all four levels (the
reader moved to 72): the reader's 94 checks, 44 s and 393 MB; the compile gate's 73 at 365 MB; the
driver's 23 at 80; the objects' 29; the proof; the C++ one 154 checks -- 149 and this step's five --
6850 s at 1760 MB, with no sleep in its window (`pmset -g log', the rule since 0.88); the libc++
one's 18 reads, 1096 s, 2310 MB, `<tuple>' 182 items. The C++ gate's 6850 s against 0.89's 6147 for
149 is the five new fixtures and nothing else measurable -- `stdtuple' alone builds in 125 s -- and
0.89's open question, why a check averages 41 s where 0.87's averaged 14, is untouched by this step
and still wants its outlier measured.
AND SEVEN GATES GREEN A SECOND TIME, at cocolog 1.2.18 with the module rebuilt (0.79's precedent for
recording both): the reader's 94 checks, 6 s and 150 MB; the compile gate's 73 at 184 MB; the
driver's 23 at 68; the objects' 29 at 74; the proof; the libc++ one's 18 reads, 1242 s, 1903 MB,
every item count identical to the 1.2.16 run; the C++ one's 154 checks, 6460 s, 1858 MB, no sleep in
its window. NOTHING IS CLAIMED FROM THOSE NUMBERS: the reader's 44 s and 393 MB at 1.2.16 were the
FIRST run after the reader version moved to 72, so they paid the initialization phase over a fresh
store where today's 6 s reads a warm one -- cold against warm, the trap 0.89 recorded -- and the C++
gate's 6850 -> 6460 s and 1760 -> 1858 MB are inside this machine's up-to-a-fifth noise. What the
re-gate says is only what a gate ever says: the engine moved under us (1.2.17's pooled prewarm,
1.2.18's module clauses reaching the knowledge base, both STORE changes, which is why the cheap
store-using gates are the ones that mattered here) and nothing of ours moved with it.
NOT DONE: `std::tuple_cat'. It is the one function of the surface that does not compile, and the
stop is named: `__tuple_cat<tuple<_Types...>, __tuple_indices<_I0...>, __tuple_indices<_J0...> >()
(...)' builds a TEMPORARY of a three-pack class template and calls its `operator()', a member
TEMPLATE with a trailing `_Tuples...', and the recursive overload of that operator is neither
matched by arity nor by its arguments (`member_refused(..., operator(()), argument_mismatch)' then
`arity_mismatch'), so the call stays raw and the lowering meets a call whose callee is a compound
literal. The return-type chain BEHIND it is right -- the trace shows
`__tuple_cat_return_impl.tuple.int_int_double_char' and `tuple_size.tuple.int_int_double_char' ->
`integral_constant.size_t.4' -- and so is `__tuple_cat_select_element_wise', whose pack (3) above
fixed; what is left is the member template on an instance of a class template over three packs, and
it is a step of its own. Also not done, both found on the way and older than this step: a QUALIFIED
DATA MEMBER inside a derived class, `L0::v = a;', is `undeclared('L0.v')' (a qualified METHOD call
has gone through the base hops since 0.73; the data member has no road), and an OUT-OF-CLASS
definition of a static ARRAY member, `const bool Holder::flags[3] = {...};', is
`member_of_class(scoped(['Holder'], flags))' -- the in-class initializer is what (5) defines, and
the out-of-class form is another.

## 0.91 — M6's fifty-eighth step

**M6's fifty-eighth step (0.91): `std::tuple_cat`, `<array>` whole, and `<algorithm>` read whole.** 0.90's one
not-done item of the tuple module, and it took three rules, each reproduced on its own before it was
fixed. (1) AN RVALUE PREFERS `T &&' ([over.ics.ref], [over.ics.rank]/3.2.3) WHERE A TEMPLATE'S
CANDIDATE IS JUDGED: `cpp_params_accept' unrefs BOTH sides (`cpp_unref_all'), so `tuple<_Tp...> &',
`const tuple<_Tp...> &' and `tuple<_Tp...> &&' -- the four overloads libc++ writes `std::get' as --
were ONE candidate to it, all held with no conversions, and the tie fell to the first declared. So
`std::get<0>(std::forward<_Tuple0>(__t0))' answered `int &' where C++ answers `int &&',
`forward_as_tuple' deduced `tuple<int &, int &>', and `__tuple_cat''s recursive `operator()', whose
parameter is the class's own `tuple<int &&, int &&>', rightly refused it -- the `argument_mismatch'
0.90 named. The scoring road has had the rule since 0.44 (`cpp_category_mismatch' in `cpp_arg_fit_');
this is that rule in the template road, as an exclusion (`cpp_ref_binds_not': an rvalue never binds a
non-const `T &') and as a RANK (`cpp_ref_rank': the worse binding costs one conversion, which the
road already orders by, 0.45's fewest-conversions rule). The `const' of `const T &' sits on the
REFERENT's qualifiers and not the reference's own, which is why the first writing of the rank charged
nothing and the tie stood unchanged. (2) A PACK EXPANSION IS A DEPENDENT TYPE WHEREVER IT SITS
(`ccl_dependent_type'): it has no meaning outside a template, so a type carrying one cannot be
deduced at READ time -- libc++ declares `tuple_cat' over `__tuple_cat_return_t<_Tuples...>', an ALIAS
with no `scoped/2' and no free name, which the reader therefore called settled. (3) AND A CALL OF A
FUNCTION TEMPLATE'S NAME IS NOT THE READER'S `auto' TO DEDUCE (`ccl_auto_by_overload' over
`'$ccl_ftmpls''): the symbol table holds ONE entry per name and the reader cannot choose an overload,
which is the desugaring's work -- libc++ declares `inline tuple<> tuple_cat()' beside the variadic
template, so `auto c = std::tuple_cat(a, b)' took the NULLARY one's `tuple<>' whatever its arguments.
THE MEASUREMENT THAT LOCATED IT, and it is the cheapest instrument in this file: the SAME call with
its result type WRITTEN OUT compiled and ran (`std::tuple<int, int, double, char> c = std::tuple_cat(
...)'), which says in one line that the call, the recursion and `__tuple_cat_select_element_wise' are
all right and only the `auto' is wrong -- where the trace of the whole build was 6370 lines, of which
1073 were `deduction_failed' refusals from the specialization ordering that are all CAUGHT and mean
nothing. A trace prints a refusal whether or not it escapes, so a refusal in a log is not a cause.
AND THE MIDDLE OF IT WAS MY OWN, worth more than the fix: rule (1) was first written as
`\+ cpp_lvalue(A)' -- "not an lvalue, therefore an rvalue". `cpp_lvalue' is a PARTIAL list (`id',
`member', `arrow', `deref', `index', a call returning `ref'), and every temporary this compiler
builds is a `stmt_expr' outside it, so genuine lvalues were refused from binding `T &' and
`stdtuple', `stdcout' and `stdmap' all fell -- 0.68's lesson exactly, a change to one overload rule
being worth no more than the gate it passes. The rule is a WHITELIST now (`cpp_xvalue_call': only a
call whose DECLARED result is an rvalue reference, which is what `std::forward' and `std::move' are
and all the shape needs), and those three pass again. Reader version 73, lowering version 36.
Gated by `test/cpp/run/refrank.cpp' (the three reference kinds, in BOTH declaration orders, so the
answer is the rule and not the order) and an extended `test/cpp/run/stdtuple.cpp' (`tuple_cat' over
two tuples and three, and once with the result type written out), clang++'s lines.
NOT DONE: a non-const `T &' still accepts a CONST LVALUE, which C++ forbids -- the other half of
[over.ics.ref], left out on purpose since it was part of what broke the three fixtures and
`tuple_cat' does not need it; `refrank.cpp' covers what holds and this is named rather than hidden.
AND `<array>`, WHOLE, in the same step, which cost two rules that both reach further than the module.
(4) A PLAIN POINTER A LIBRARY CLASS'S MEMBER ANSWERS IS A BORROW OF THE OBJECT (`ck_borrows_from''s
library clause, `ck_borrow_of'): `std::array''s iterators ARE raw pointers, where a vector's are a
`__wrap_iter' class and opaque to the check since 0.79 (`ck_carries_'), so the range-for's own
`auto __e = a.end()' was a LOOSE pointer and the owner's rule refused it at the scope's end --
`plain pointer not consumed'. The library's discipline is its own (0.45), and what its member hands
back points INTO the object, which is what a borrow says: modelled so, the lifetime rules still hold
(it dangles when the object goes) rather than the pointer being merely exempted. (5) BRACE ELISION
([dcl.init.aggr]/15, and C's own rule): a struct member that is an ARRAY, given an item that is no
braced list of its own, takes as many of the items that FOLLOW as it has elements -- libc++ writes
`std::array<_Tp, _Size>' as the aggregate `struct { _Tp __elems_[_Size]; }', ONE member, so every
`std::array<int, 4> a = {1, 2, 3, 4}' is an elision. It is in the LOWERING's initializer walk
(`ir_init_items') and in the desugaring's `cpp_aggregate_inits' alike, and the guard at both is that
MORE ITEMS THAN MEMBERS REMAIN, which is what tells it from 0.84's array member taken from an array
VALUE (`S s = {arr}': one item, one member, and its bytes are meant). It fixes the C side too:
`struct S { int a[4]; } s = {1, 2, 3, 4};'. AND THE ARRAY OF STRINGS WAS NOT A SECOND DEFECT: it
stopped at `no_constructor(basic_string_view..., 1)' before the elision and simply fell out with it
-- one defect seen twice, which is worth saying rather than counting as two. Gated by
`test/cpp/run/stdarray.cpp': `size'/`max_size'/`empty', `[]', `at', `front'/`back', `data', the
range-for and an explicit iterator loop, a copy, all six comparisons, `fill', `swap', the TUPLE
PROTOCOL over an array (`std::get', `tuple_size', a structured binding, through 0.90's own rule),
elements that construct and destroy (`std::array<std::string, 2>', assigned into), and `= {}'.
AND `<algorithm>` READ WHOLE, which was three READER forms and not one of them the desugaring's.
`std::sort' was `undeclared(sort)' -- and nothing pointed at the header, since A PARTIAL READ IS
SILENT (0.44) and the summary simply held no `sort'. The census loop named it in three turns:
(6) `if constexpr' TAKES AN INIT-STATEMENT ([stmt.if]; the init-statement is always evaluated, so it
stays outside the branch that may be discarded): 0.42 gave `if constexpr' its own node and 0.43 gave
`if' its init-statement, the two were never joined, and the clause CUTS on `constexpr' so nothing
else could match -- libc++'s algorithm dispatch is written `if constexpr (using _SpecialAlg =
__specialized_algorithm<...>; _SpecialAlg::__has_algorithm)' and the read died at line 6136 of
14177. (7) A LAMBDA'S INIT-CAPTURE, C++14's `[n = e]' and `[&n = e]' (`cap(init, N, E)'), which the
reader never had: the closure's member is named by the capture and initialized by an expression of
the enclosing scope, naming nothing of that name -- libc++'s radix sort writes
`[__map = std::move(__map)](const auto &__x)'. (8) A LABEL'S BODY MAY BE A DECLARATION, which is a
statement in C++ ([stmt.label]) and in C23 (`ccl_label_body' falls to `ccl_block_item'), for
`case 2: __destruct_n __d(0);'. `<algorithm>` goes 375 -> 522 items and reads WHOLE. Reader version
74. NOT DONE: `<algorithm>`'s desugaring stops at
`no_member_type('_IterOps._ClassicAlgPolicy', '__iter_move')' -- a STATIC MEMBER FUNCTION TEMPLATE of
two SFINAE-guarded overloads, asked for as a TYPE where `_Ops::__iter_move(__first)' means a call --
and that build peaks at 2592 MB against the 2800 cap, the heaviest header met so far and a thin
margin.
WHAT WAS RUN, AND WHAT WAS NOT: the owner asked for no gates in this step, so NOTHING HERE HAS A
GREEN LINE. Sixteen fixtures were run one at a time and pass -- `refrank', `stdtuple', `stdarray',
`stdmap', `stdcout', `stduniqueptr', `stdmemory', `stdoptional', `counter', `bag', `convref',
`basecast', `packcall', `arraybound', `cxx20', `cxx23' -- chosen as the ones this step's rules most
expose: the overload roads, `auto' over a library call (`ccl_auto_by_overload' fires on every one),
and the `if constexpr' and label forms. The seven gates have not been run since 0.90, and the step
is committed on that footing and no other.

## 0.92 — M6's fifty-ninth step

**M6's fifty-ninth step (0.92): `<algorithm>`, and the fifteen rules between its text and its
answers.** 0.91 read `<algorithm>` whole and stopped in the DESUGARING at
`no_member_type('_IterOps._ClassicAlgPolicy', '__iter_move')`. THE FORMS, each named and each cut
to a file of ten to twenty lines that failed in ONE SECOND before it was fixed:
(1) A MEMBER FUNCTION TEMPLATE'S NAME IS A TEMPLATE AND NO TYPE, 0.45's rule for a free one one
scope deeper: libc++ writes `value_type __t(_Ops::__iter_move(__first));' (push_heap, rotate,
sort), which read as a DECLARATION of a function `__t' taking a parameter of type
`_Ops::__iter_move' -- the vexing parse C++ resolves by knowing what the member is. The class-body
scan that notes member templates ahead (`ccl_member_templates_ahead', 0.81) says WHICH KIND each
is now (`ccl_scan_did' answers `N-type' or `N-fn', `ccl_note_mt'), and a function's name joins
`'$ccl_fn_templates'', which `ccl_qname_typish' excludes. AND THE GUARD THE CENSUS EARNED: a
CONSTRUCTOR template's (or a destructor's) declarator-id is the CLASS's own name, so noting it as a
function template made `pair<_T1, _T2>' no type at all and `<vector>' went PARTIAL at pair's
deduction guide -- silent (0.44), and named in one line by `sh test/census.sh'
(`PARTIAL, 210 items; stopped at line 3219').
(2) A CALL'S EXPLICIT TEMPLATE ARGUMENTS ARE TEMPLATE ARGUMENTS, NOT TYPES: libc++'s sort writes
`std::__introsort<_AlgPolicy, _Comp &, _Iter, __use_branchless_sort<_Comp, _Iter> >(...)', whose
last argument is a VARIABLE TEMPLATE's id -- typed as a class it refused `instance_without_body'.
0.63 evaluates an explicit argument where it BINDS (`cpp_bind_explicit'); `cpp_types' was the
pre-pass that mangled it first, and `cpp_call_targs' diverts only the two shapes `cpp_type' gets
wrong (a variable template's id and a concept-id), so nothing that types today types differently.
(3) A FUNCTION TEMPLATE'S INSTANCE THE SHIPPED LIBRARY DEFINES takes its ITANIUM SYMBOL -- 0.61's
and 0.73's named not-done item. libc++ declares `template <class _Comp, class _RandomAccessIterator>
void __sort(_RandomAccessIterator, _RandomAccessIterator, _Comp);' with NO BODY ANYWHERE, compiles
the instances into libc++.dylib and lists them `extern template ... __sort<__less<int>&, int*>' --
which every `std::sort' of an arithmetic type calls. A function TEMPLATE's symbol differs from a
plain function's in three places, all in `cpp_ita_fn_instance': the nested name carries the
TEMPLATE-ID (`_ZN St3__1 6__sort I <args> E E', the template-PREFIX a substitution candidate and
the function's own template-args never one), the bare-function-type that follows a template-id
begins with the RETURN TYPE, and a parameter written as one of the template's own parameters is
`T_' for the first and `T0_' for the second (decimal, where a substitution is base 36), each a
candidate of its own. Measured against the shipped library: `_ZNSt3__16__sortIRNS_6__lessIiiEEPiEEvT0_S5_T_',
character for character.
(4) A PARTIAL SPECIALIZATION'S ARGUMENT LIST IS FILLED FROM THE PRIMARY'S DEFAULTS
([temp.spec.partial]; `cpp_spec_pattern'): libc++ writes `template <class _Tp, class _Up, class = void>
inline const bool __is_trivially_equality_comparable_impl = false;' and specializes it `<_Tp, _Tp>'
-- TWO arguments where the primary takes three -- so the pattern's length matched nothing.
(5) `__is_trivially_equality_comparable' IS ANSWERED (`cpp_trait_of'): `a == b' is `memcmp(&a, &b,
sizeof(T))' for the integral types and pointers, never a float (0.0 == -0.0 with different bits),
an enum (a user may write ==) or a class (padding). With (4) and (5) false, `std::find' took
libc++'s overload guarded by the trait's NEGATION, whose body calls `__find' again: a STACK
OVERFLOW on `std::find(v.begin(), v.end(), 5)'.
(6) AND NO VECTOR EXTENSIONS, the third question of the shape 0.50 asked of exceptions and 0.86 of
RTTI. libc++ vectorizes its algorithms behind `_LIBCPP_HAS_ALGORITHM_VECTOR_UTILS &&
!defined(__OPTIMIZE_SIZE__)', and the first half is on because it asks whether the compiler is
clang-based -- which this one answers yes to, its predefined table being clang's (0.87's hazard).
`__find_vectorized' is built on `__attribute__((__vector_size__(N)))' types, GENERIC LAMBDAS and
the vector builtins. `__OPTIMIZE_SIZE__' is the library's own switch for it and is read in EXACTLY
TWO PLACES in all of libc++, both this one, so predefining it compiles the scalar algorithms the
library ships for -Oz and changes nothing else. (`__builtin_reduce_and' and `__builtin_reduce_or'
live only behind that guard and are still unanswered: reachable again if it ever changes.)
(7) A GENERIC LAMBDA IS A CLOSURE WHOSE `operator()' IS A MEMBER TEMPLATE
([expr.prim.lambda.closure]/3) -- refused by name since 0.42, and what libc++'s `__find_generic' is,
`[&]<class _ValT>(_ValT&& __val) -> bool { return __val == __value; }'. The template's parameters
are the lambda's own (`tparams(Ps)' among the captures) then one INVENTED per `auto' parameter
(`cpp_auto_params', 0.42's rule for an abbreviated function template), and the result type is
deduced at the CALL. The closure's member-template road, its instance's name (`op.call') and the
fallback from `cpp_method' to `cpp_member_template_call' were all there from 0.44, so the rule is
four lines on machinery eleven steps old.
(8) `wchar_t', `char16_t' AND `char32_t' ARE ARITHMETIC TYPES with sizes, ranks, signedness and LLVM
types (`ccl_is_integer', `ccl_basic_size', `ccl_int_rank', `ir_base'; the mangler knew them
already): LP64 makes wchar_t four bytes and signed, char16_t two and unsigned, char32_t four and
unsigned -- and `sizeof(int) == sizeof(wchar_t)' is why libc++'s `__find' of an INT goes through
`__constexpr_wmemchr'.
(9) THE WIDE MEMORY BUILTINS are the C library's functions, DECLARED here when no header did as the
math builtins have been since 0.81: `__builtin_wmemchr', `__builtin_wmemcmp', `__builtin_wcslen'.
(10) `__builtin_assume_dereferenceable' IS AN ASSUMPTION and nothing at run time, beside
`__builtin_assume' and `__builtin_prefetch': libc++'s `__assume_valid_range' calls it on the way
into EVERY range algorithm over a vector's iterators, so it would have failed most of the module's
fixtures one at a time.
(11) A NULL POINTER CONSTANT CONVERTS TO ANY POINTER ([conv.ptr]/1), which only `nullptr_t' knew
(`cpp_null_to_pointer', asked at the three roads that judge an argument: the template acceptance,
the scoring and the arity-only last resort): libc++'s stable_partition writes `pair<value_type *,
ptrdiff_t> __p(0, 0);' and the pair's `(const _T1 &, const _T2 &)' constructor was refused for the
literal 0, leaving no constructor of arity two. AND ACCEPTING IS NOT CONVERTING: bound to the
`const _T1 &' the literal materialized an INT temporary whose ADDRESS went out as the pointer, so
the fixture printed 4 where C++ prints 5 -- a WRONG ANSWER, not a refusal -- and the conversion
goes in at `cpp_ref_args_', the door the class conversions already use.
(12) A CONDITIONAL OVER TWO LVALUES IS AN LVALUE ([expr.cond]/4), so its ADDRESS is the phi of the
arms' where the value form phis the values (`ir_lvalue_form(cond)', `ir_lval(cond)'): `std::min' is
`return __b < __a ? __b : __a;' in a `const _Tp &'-returning function, and as a prvalue
`ir_ref_of' materialized a temporary, stored the STRUCT into it and returned that dead temporary's
address -- `std::min(a, b).c_str()' read its bytes.
(13) A DELETED MEMBER TEMPLATE IS DROPPED as a deleted plain member has been since 0.44
(`cpp_member_body' through the `template' wrapper): libc++ writes `unique_ptr(pointer,
__libcpp_remove_reference_t<deleter_type> &&) = delete' under `is_reference<_Deleter>' to steer
construction to the deleter-by-lvalue overload, and KEPT it won overload resolution and had no
body to emit.
(14) A PARAMETER IS RESOLVED IN ITS CLASS ON THE TEMPLATE ROAD -- 0.66's rule in the one place that
never took it, as 0.70 found it missing from `cpp_args_no_clash': `cpp_params_accept' judged
`const deleter_type &' with the INFERENCE, which knows typedefs and tags and no class scope, so
`deleter_type' (unique_ptr's own typedef of `__destruct_n &') stayed opaque, the reference was
never seen, and the class test -- which must not unref (0.51) -- met one and refused
`argument_mismatch'.
(15) A FREE OPERATOR SERVES A PLAIN STRUCT (`cpp_op_operand'): the road required a registered CLASS
on one side and a struct of plain members is never promoted to one (0.84 promotes only a struct
holding a class), so a program's own `bool operator<(const S &, const S &)' was never found
anywhere -- inside a template or out -- and `x < y' stayed the raw `bin(<, ...)' the lowering
cannot take.
THE THREE THAT HID EACH OTHER, worth more than any of them: the `unique_ptr' failure was (13),
(14) and 0.66's rule stacked, and each was invisible until the one in front of it MOVED -- the
deleted constructor won while it existed, and only once dropped did the refusal name the candidate
whose parameter never resolved. The trace named each in turn (`ctor_candidate', `ctor_no',
`member_refused', 0.79's rule 9); guessing named none of them. AND A REDUCTION OF (14) THAT PUT THE
TYPEDEF AT FILE SCOPE PASSED, because the inference can resolve one there and libc++'s is
class-scope: a probe that passes can mean the PROBE is wrong, and the plain-constructor probe of
the same rule passed for the same reason -- the plain road works and only the template road was
broken.
Reader version 76 (75 for the member-template kind, 76 for `__OPTIMIZE_SIZE__', every summary
rewritten); lowering version 38.
WHAT RUNS: `<algorithm>`'s surface as TEN fixtures --
`test/cpp/run/stdalgorithm.cpp' (the predicates: all_of, any_of, none_of, for_each, count,
count_if), `stdalgorithm2.cpp' (the searches: find, find_if, find_if_not, search, adjacent_find,
find_end, find_first_of), `stdalgorithm3.cpp' (equal, mismatch, lexicographical_compare,
min_element, max_element, minmax_element, min, max, minmax, clamp), `stdalgorithm4.cpp' (copy,
copy_n, copy_if, copy_backward, fill, fill_n, transform unary and binary, generate),
`stdalgorithm5.cpp' (remove, remove_if, replace, replace_if, swap_ranges, reverse, reverse_copy,
rotate, unique), `stdalgorithm6.cpp' (the partitions and the sorts), `stdalgorithm7.cpp' (the
binary searches and the merges), `stdalgorithm9.cpp'
(the heap and the permutations) and `stdalgorithmstr.cpp' (ALL the `std::string' coverage), each
matching clang++ line for line; beside them `nullconst.cpp', `condlvalue.cpp' and `refparam.cpp',
each the shape of (11), (12) and (14) on the program's own classes.
WHY TEN AND NOT ONE, AND THE MODEL THAT WAS WRONG: the surface written as one fixture was still
building at TWENTY-SEVEN MINUTES and was killed. I split it by the NUMBER OF ALGORITHMS, inferring
a superlinear cost from three points (5 algorithms 25-45 s, 12 with strings 263 s, 22 with strings
>1600 s), and the split worked -- 33 s for six algorithms. THE MODEL WAS STILL WRONG, and one
bisect said so: eleven probes identical but for one line, with a BASELINE that calls no algorithm
at all (28 s, which is what including `<algorithm>' and `<vector>' costs), gave
`min_element' 43 s, `max_element' 30, `minmax_element' 28, `min' 29, `max' 28, `minmax' 27,
`clamp' 28 -- SEVEN AT THE BASELINE, free -- against `equal', `mismatch' and
`lexicographical_compare' at over 180 s each. The cost is not the count: it is the TWO-RANGE
family, and `stdalgorithm3' was slow because it happens to hold all three of them.
NOT DONE, AND MEASURED HONESTLY: those three are still ~250 s each against the 28 s baseline, and I
DID NOT FIX THEM. The trace shows what looks like the cause -- an `enable_if' instance keyed by an
UNFOLDED conjunction spelled letter by letter,
`enable_if.binbinbinbinbinbooltruebooltruebooltruenotscopedtmplisvolatilebaseintvalue...', from
libc++'s `__enable_if_t<... && !is_volatile<_Tp>::value && ..., int>', with 1422 candidates and 637
refusals and NO instance asked twice (so breadth, never a loop) -- but a bad thing in a trace is
not a demonstration that it is THE COST. Two fixes failed: folding a static constant inside
`cpp_const_reduce' fired on every `scoped' subterm of every constant evaluation, dragged
`cpp_scope_class' into instantiating the detection idiom's `__test' and broke EVERY probe including
the baseline (a file calling no algorithm cannot be broken by an algorithm fix -- that is the
edit, immediately); and the same fold at `cpp_targ_value', the right place, never fires on
libc++'s expression -- measured against the library with ONLY that clause stubbed off, 255 s
without it and 239 s with, which is this machine's noise. Both were REVERTED. Two reductions of the
shape fold correctly in one second, so the mechanism is not reproduced and that is why it is not
fixed. THE SET OPERATIONS ARE NOT COMMITTED AT ALL: `stdalgorithm8.cpp' (set_union,
set_intersection, set_difference, set_symmetric_difference) has NEVER been seen to pass -- killed
at 16:40 pinned at 499 MB, and flat memory over that long is the shape of something other than
ordinary work in an engine with no heap collector. They are two-range algorithms, so the family
above is the likely reason and they would probably pass given twenty minutes; but the gate globs
`test/cpp/run/*.cpp', so a fixture committed unverified is a fixture that may hang the gate for
the owner, and it waits outside until it is measured.
WHAT WAS RUN, AND WHAT WAS NOT: the owner asked for no gates, so NOTHING HERE HAS A GREEN LINE.
The thirteen fixtures above were run one at a time and pass (`stdalgorithm' 39 s/350 MB,
`stdalgorithm2' 44/427, `stdalgorithm4' 61/320, `stdalgorithm5' 88/329, `stdalgorithm6' 431/1245,
`stdalgorithm7' 119/564, `stdalgorithm9' 40/540, `stdalgorithmstr' 171/676, `nullconst',
`condlvalue' and `refparam' 1-2 s each); `stdalgorithm3' passes at about 1670 s and `stdalgorithm8'
is unmeasured past 16 minutes, which is the open item above. The seven gates have not run since
0.90, and the step is committed on that footing and no other.

## 0.93 — M6's sixtieth step

**M6's sixtieth step (0.93): C17 AND C23 WHOLE, C++20, C++23 AND C++26 TO THEIR ENDS, AND THE
LINUX PORT GREEN.** The owner asked for the levels finished, and this step is the not-done lists of
every earlier one, closed where a form can be closed and named where it cannot. Fifty-odd forms,
each gated; the ones that taught something are told here.
THE C SIDE. (1) `_Generic' IS CHOSEN AT THE READ (C11, missing since M1): the controlling
expression's type is asked of the symbol table the parser keeps -- the macros' door -- decayed,
its top-level qualifiers dropped (C17's lvalue conversion, DR 481), and the association whose
CANONICAL type is the same replaces the form (`ccl_type_canon': typedefs resolved through pointers,
arrays and functions, `unsigned' and `unsigned int' one type, the qualifiers BELOW the top kept, so
`char *' and `const char *' are two); `default' otherwise, and a controlling expression the table
cannot type keeps `generic/2', which the lowering refuses. It is a PRIMARY, not a unary, since
`_Generic(x, ...)(x)' is how <stdbit.h>'s type-generic functions call the one chosen. (2) `_BitInt(N)'
IS LLVM'S `iN' EXACTLY (`ir_base'), sized as the psABI has it (the smallest integer type up to 64
bits, whole eightbytes aligned 8 past that), ranked below the standard type of its width and above
every narrower one (`ccl_bitint_rank', a half-rank), and NEVER PROMOTED (6.3.1.1/2, the guard in
`ccl_promote'); the `wb' and `uwb' suffixes give `wb(N)' and `uwb(N)', a _BitInt of the width the
value needs plus the sign, in BOTH lexers (`ccl_int_kind/4', `x->sfx' 4 and 5). (3) THE OVERFLOW
BUILTINS (`__builtin_add_overflow' and kin, what <stdckdint.h> is) compute EXACTLY in i128 over the
operands widened by their own signedness, store the result truncated, and answer whether widening it
again gives the exact value back -- any integer types on either side, a `_BitInt(128)' included.
(4) `__builtin_unreachable()' is LLVM's terminator; `unreachable()' and `nullptr_t' (`typeof(nullptr)')
come from <stddef.h> AT THE LEVEL ONLY, so THE C STORE IS KEYED BY THE LEVEL where it is not 17
(`ccl_kb_key': `c(V, 23)'), since a header's macros and items are served by that key and a C17 read
must not see them. (5) A VARIABLE LENGTH ARRAY is allocated WHERE IT IS DECLARED, in the body, `alloca
T, i64 n' -- the entry block's allocas are fixed -- and `sizeof' of one is its bound's value times the
element at run time, asked BEFORE the layout, whose answer for an unsized array is honestly ZERO (a
flexible member's); the bound is read where sizeof is, not where the array was declared (named). (6)
`_Thread_local' and `thread_local' are a QUALIFIER, not the storage word: `static _Thread_local' has
both and the storage slot holds one -- and the generic storage clause took the keyword before the new
clause saw it, so the new clause sits AHEAD of it and the words are out of `ccl_storage'; the lowering
spells `thread_local global' for a global and a static local (`ir_tls', the qualifier on the innermost
base). (7) THE PREFIXED LITERALS, both lexers (`ccl_lit_prefix', `ccl_lx_string_k'): `u8"..."' is a
byte string as `"..."' is (char8_t and char are one byte here), `L' `u' `U' give `wstr', `u16str',
`u32str' whose BODY IS THE PLAIN STRING'S, UTF-8 bytes, which the LOWERING DECODES into the wide
elements (`ir_wstring', `ir_utf8_decode') -- so a universal character name in a wide string, which the
DCG had already turned into UTF-8 bytes, comes out as its one code point, and the two lexers stay byte
for byte the same. The check counts them static, as it counts `str' (a wide literal bound to a plain
pointer was refused `unconsumed' until it did). (8) `__VA_OPT__' (C23, C++20: `pp_va_group'), `#embed'
with `limit', `prefix', `suffix' and `if_empty' (the resource's bytes where the directive stood, a
quoted name beside the file and an angled one on the path, a code past 255 spelled back into its
UTF-8 bytes), `__has_embed' (found 1, empty 2, nowhere 0), `__has_c_attribute' answering the standard
attributes' dates and the `__x__' spellings (C only; `__has_cpp_attribute' keeps its 0, the plainest
path through libc++), AND THE FILE'S OWN `#error' IS A DIAGNOSTIC -- it was listed in `'$pp_errors''
and nobody read the list, so a program's #error compiled to `cicilang: ok' -- with `#warning' printed
after the read in clang's shape (`dr_pp_warnings'; a header's stay what they were). (9) `_Alignof',
`alignof' in C23, `_Alignas' read and dropped as C23's alignas is; `typeof_unqual' wraps its operand
`unqual(X)' and the resolution strips the top-level qualifiers; the decimal floating types are read,
sized and refused by name (LLVM has no arithmetic for them). (10) AN UNBOUNDED ARRAY TAKES ITS BOUND
FROM ITS INITIALIZER AT THE READ (`ccl_sized_by_init', a designator `[i] =' moving the position): the
lowering sized the emitted type this way and the table kept `none', so a GLOBAL's `sizeof' was 0 while
a local's was right -- found by the first `#embed' fixture. (11) THE FREESTANDING <limits.h>: glibc
defines none of the limits itself under a GNU-shaped compiler and asks the compiler's header for them
(`_GCC_LIMITS_H_'), so on Linux `INT_MAX' was simply undefined; the values are the predefined macros'
and glibc's own file follows through `#include_next'; <stdckdint.h> and <stdbit.h> beside it, the
latter's suffixed functions over the bit builtins and its generic forms over `_Generic'.
THE C++ SIDE. (12) THE DEFAULTED COMPARISONS ([class.compare.default]): `operator==' and `operator<=>'
written `= default' are SYNTHESIZED memberwise at `cpp_norm_members_' -- the members in order, the
three-way one lexicographic in an int where C++ has std::strong_ordering (0.42's scalar `<=>' is an
int and <compare>'s classes are not modelled: a written result type is taken as int), a defaulted `<=>'
bringing a defaulted `==' where NONE is declared (declared and defaulted, it was synthesized twice:
`invalid redefinition'); a base sub-object and an array member are not compared (named). THE
REWRITTEN CANDIDATES ([over.match.oper]/3.4, `cpp_rewritten_cmp' at `cpp_operator''s last resort):
`a < b' is `(a <=> b) < 0' where the class has `<=>' and no `<', `a != b' is `!(a == b)'. (13) A
CONSTRAINED `auto' IS KEPT as the qualifier `constrained(C, As)' where 0.84 dropped the concept, and
CHECKED where the type is deduced (`cpp_constrained_ok' in `cpp_auto_deduce' and `cpp_auto_bind'):
`Number auto x = e', `const Number auto &r = x', and an abbreviated template's parameter, whose
invented parameter carries it as a `requires' entry -- ONE entry, LAST, conjoined, as the reader
gathers a written head's (`ccl_gather_requires'), and in the READER'S SHAPE, `tmpl(C, [base([],
[typedef(A)])])': written `typedef(A)' bare, `cpp_subst' never bound it and the concept refused
`constraint_unknown' on the free name, which rejected every candidate and left `half(9)' undeclared;
only a concept the PROGRAM declared is carried, a library's being the library's. And
`cpp_constraints_hold' checks EVERY `requires' entry now, where it took the first. (14) `[[assume(e)]];'
is a statement of its own (`assume(L, E)', the check reads the expression, the lowering calls
`llvm.assume'), where every attribute before a statement was dropped. (15) The suffixes `f16', `f32',
`f64', `f128' and `bf16' in both lexers, dropped as `f' is (the native one re-reads the character
after a `b' -- it did not, and read `0.5bf16' as `0.5' then the name `f16': k84 said so in one line).
(16) `static operator()' and `static operator[]' ran as they stood (a static method takes a `this'
and ignores it, 0.36). (17) C++26: PACK INDEXING (`Ts...[0]' a type, `args...[1]' an expression:
`pack_index', substituted once the pack is bound, `cpp_pack_at', the index folded after its own
substitution, out of range and non-constant refused by name), `= delete("why")', THE PLACEHOLDER `_'
(a second `_' in one block is renamed `_$k' at the read and the first keeps the name, as C++ lets a `_'
be named only while there is one), A STRUCTURED BINDING AS A CONDITION (a temporary holds the object,
the names bind into it through 0.79's deferred `bindings' road, and the test is the temporary's --
a class through its operator bool) and as an init-statement (the binding's items spliced into the
block: `ccl_init_items', where a `'$splice'' inside a block built by a rule is spliced by nobody), and
the init-statement clause sits AHEAD of the declaration clause, which read `auto [c2]' as an ARRAY
declarator named nothing; `friend Ts...;' (already `friend(L, [])'); the contract assertions `pre(e)'
and `post(r: e)' read and IGNORED, the standard's own `ignore' evaluation semantic;
`trivially_relocatable_if_eligible' and `replaceable_if_eligible' dropped with `final'; `#embed' in C++.
THE LINUX PORT, GREEN AT LAST (0.87 reached 83 checks). (18) THE PREDEFINED MACROS ARE THE HOST'S:
the table was the reference compiler's on macOS, so `__APPLE__' and `__MACH__' were `any' and Linux
compiled as a Mac over glibc's headers; `ccl_host_os/1' beside `ccl_host_arch/1' in the module
(`@ifdef __APPLE__'), `pp_os/1', the Apple rows under `darwin' (33 of them, `TARGET_OS_*' included)
and `__linux__', `__gnu_linux__', `__unix__', `__ELF__', `__PIE__' under `linux'; `__is_target_os',
`__is_target_vendor' (pc) and `__is_target_environment' (gnu) answer for the host. (19) libc++ is found
under Debian's `/usr/lib/llvm-NN/include/c++/v1' (`ccl_debian_llvm_roots', the newest first) -- without
it `#include <cstdio>' flattened to NOTHING and every C++ fixture was `undeclared(printf)'. (20) The
driver gate's two macOS-shaped checks are the host's (`_main' against `main', `.dylib' against `.so').
THE INSTRUMENTS, three more for the list: a Cicili function is named AFTER it is defined
(`unknown symbol: ccl_lx_string_k' from the transpiler, the wrapper written above the function it
wraps); cocolog's reader refused ONE clause of this step, `append([declaration(...)] , Ifs, B0)', with
the lone message `its clauses would not consult' for the whole library -- bisected by applying each
hunk of the diff alone onto HEAD (a standalone consult of `ccl_ir.pl' fails for its own reasons, so a
per-file consult said `ccl_ir' was broken when it was not: measure against the base); and the reader
gate's `a cached read is the same AST as a fresh one' goes RED when the grammar moves without the
version, which is exactly what it is for. Reader version 77, lowering version 39.
FOUND AND NAMED, NOT DONE: cocolog's integers are 61-bit (the finding in the lexer's own entry), so
`LONG_MAX' and `LONG_MIN' cannot be spelled through this compiler -- `INT_MIN' is in the fixture in
their stead; a VLA's `sizeof' re-reads the bound; a VLA of a VLA; a wide string initializing an ARRAY
(`wchar_t a[] = L"..."'); `_Atomic' objects are plain loads and stores; `_Alignas' on an object is
dropped; `_Complex'; `\\N{...}'; the base sub-object and an array member in a defaulted comparison;
`std::strong_ordering' as a class; coroutines, modules and `consteval' at compile time (the findings
of 0.42 and 0.43 stand); a template's own `auto' parameter constrained by a LIBRARY concept.
THREE MORE, FOUND BY THE GATES AND WORTH THE MOST. (21) A NEW PREDICATE'S NAME IS CHECKED AGAINST THE
DCG'S ARITY TOO: the init-statement's splice helper was named `ccl_init_items/3', and `ccl_init_items//1' -- the
braced initializer's nonterminal -- IS `ccl_init_items/3' once the DCG adds its two arguments; the extra clauses
were reached only on a BACKTRACK out of a braced list, read the token list as an item, and libc++'s variant raised
`Arguments are not sufficiently instantiated' with no line, four minutes into a read that the committed grammar took
whole. It was found in three measurements, none of them a guess: the flattened header read under HEAD's grammar
with the working tree's other files (whole: the grammar's), each hunk of the grammar's diff applied ALONE onto HEAD
and the file read under it, four reads at a time (one hunk raised), and that hunk split in two (the splice lines,
not the new clause); a per-item `catch' in `ccl_externals_' on a scratch copy of the library then named the item.
The helper is `ccl_init_stmt_items' now, and the rule is the one this file already has for C names, applied to
Prolog: a name is looked up before it is given, at its arity AND at the DCG's. (22) 0.92's `cpp_null_to_pointer'
accepted `nullptr' for `void_t<typename U::category> *' by the pointer's SHAPE alone, so the detection idiom's
refusal (no such member type, [temp.deduct]/8) was never raised and the wrong `test' overload held --
`detect2.cpp' had been RED since 0.92, whose gate did not run; the pointee must resolve now
(`cpp_pointee_settles', a refusal there being the candidate's rejection, caught where the candidates are held).
(23) ELEVEN OF 0.92's EXPECTATIONS LACKED THEIR `exit 0' LINE, since they were run one at a time and never
through the gate, which appends the exit status: added. AND THE WATCHDOG BESIDE A GATE MUST FOLLOW THE GATE'S
PROCESS, not the presence of a cocolog process -- the first version here ended at the first second with none,
which is every gap between two fixtures, and a gate ran on unguarded at 5.7 GB beside four bisect reads (0.90's
and 0.91's hole, arrived at from the other side).
AND THE ROAD TO libc++ 18, WHICH THE LINUX GATES OPENED. The C++ gate's first run here failed every fixture over the
standard library, and a snapshot run earlier in the day, which I had read as passing them, had never reached them -- it
stopped at `stdcin' and its FAIL list was a TRUNCATED list, not a pass list (the eighth instrument in the findings: a gate
that ends early reads exactly like a gate that passed the rest, and only the names it printed say which fixtures it ran).
Measured one header at a time with the census on the FLATTENED header under both grammars (`cicilang++ -E', then
`test/census.pl' with `COCOLOG_LIBRARY' set to HEAD's library and cocolog called directly, since `test/census.sh' sources
`config.sh', which puts the working tree's library first whatever the caller had), HEAD's grammar and this tree's stopped at
the same line of `<iostream>' (320 of 793 items) and of `<functional>', and the desugaring under HEAD's library -- with a
HOME of its own, so its summaries at reader 76 never overwrote the tree's, the two grammars keying the same files -- refused
`stdvector' at the same place: every one of these is the environment's, libc++ 18's shapes under this compiler's
configuration, and none is this step's. FIVE OF THEM, CLOSED: (24) AN UNNAMED PARAMETER OF AN UNKNOWN TYPE NAME in a C++
parameter list (`ccl_typedef_name' in the `param' scope, cpp only): a lone name before `,' or `)' can only be a type there,
unless it is a declared object -- the vexing parse `T x(a, b);' reads its arguments, and keeps reading them -- and libc++
18's `shared_ptr.h' writes `atomic_load_explicit(const shared_ptr<_Tp> *, memory_order)' with `memory_order' declared only
under `<__atomic/memory_order.h>', which it includes only where `__has_keyword(_Atomic)' or `__has_feature(cxx_atomic)'
answers 1, and this preprocessor answers both 0 (the plainest path), so the read of `<iostream>' stopped 320 items in,
silently, `cout' never reached; (25) A DESTRUCTOR CALLED WITH ITS CLASS'S TEMPLATE ARGUMENTS SPELLED OUT,
`__f_.~__compressed_pair<_Target, _Alloc>()' (`ccl_dtor_targs', the arguments dropped: the destructor called is the
object's own class's whatever the spelling); with the two, `<iostream>' reads WHOLE (793 items) and `<functional>' with it;
(26) A BASE CLAUSE NAMING A BOUND TYPE PARAMETER takes the class the parameter is bound to (`cpp_subst' on `base(Access,
Name)', told from the type form `base(Qualifiers, Specifiers)' by its first argument): libc++ 18 builds every container on
`__compressed_pair_elem<_Tp, _Idx, true> : private _Tp', and the bare atom was left as written, refusing
`base_not_registered('_Tp', ...)'; a plain struct of data members bound there is still not promoted to a class
(`cpp_note_bases' sees the raw names only), named below; (27) A SCOPE'S NAME IS THE CLASS'S OWN TYPEDEF FIRST
([basic.lookup.unqual]; `cpp_path_class'): `numeric_limits' writes `typedef __libcpp_numeric_limits<...> __base; typedef
typename __base::type type;', and a class named `__base' elsewhere in the header, loaded lazily by that name, won the
scope and refused `no_member_type(__base, type)'; (28) THE C++ RUNTIME IS NAMED AT THE LINK ON LINUX (`ccl_link_libs',
`-lc++'): `c++' is g++ there, whose library is libstdc++, and the one undefined symbol was libc++'s
`std::__1::__libcpp_verbose_abort' -- the driver's link diagnostic keeps ld's first line only, which named the function
and not the symbol, so the object was linked by hand. With them `stdvector' builds and runs through `cicilang++' (398 s
cold, the flatten of `<vector>' at reader 78 in it), and `test/cpp/run/tpbase.cpp' -- the bound base, a member reached
through it, a destructor spelled with its arguments, on the program's own classes -- prints clang++'s numbers. Reader
version 78, lowering version 40.
SEVEN MORE, EACH REPRODUCED IN A DOZEN LINES BEFORE IT WAS FIXED (the traits first, since `__unwrap_iter' -- the door of
every range algorithm over a vector -- is guarded by `is_copy_constructible' of the iterator, and it held for nothing):
(29) A TYPE ARGUMENT IS A TYPE (`cpp_expr' on `type(T)'): the reader gives a builtin trait's type arguments as
`type(T)', and the generic expression walk took the term apart and read `typename add_const<_Tp>::type' inside it as
an EXPRESSION -- the nested type's NAME as an id -- so libc++ 18's `is_copy_constructible', written
`__is_constructible(_Tp, __add_lvalue_reference_t<typename add_const<_Tp>::type>)' where 21 writes the class form,
compared a name with a type and answered 0 for every pointer and every plain struct; (30) `const T' WITH T A POINTER IS
A CONST POINTER ([dcl.type.cv]; `cpp_merge_quals'): the qualifier was DROPPED, so `add_const<int *>::type' was `int *'
-- neither `int *const' nor `const int *' -- and with an array it goes to the elements; (31) A VALUE'S TOP-LEVEL
QUALIFIERS ARE NO BAR to initializing from it ([dcl.init]; `cpp_same_unqualified' in `cpp_convertible'):
`is_constructible<S, const S &>' of a plain struct was 0, since neither side is a registered class and `const S' is not
the spelling `S'; measured against clang++ on every spelling, in and out of a template, all equal now; (32) THE
IMPLICIT COPY IS NOTED WHEN IT IS EMITTED (0.69's rule in its fifth place, `cpp_implicit_copy_ctor'): the fact was
asserted before the emission, so a walk abandoned by a throw -- a candidate rejected -- left the name with no
definition behind it, and `allocator<Rec>::construct' met `undeclared(Rec.Rec.Rec_rr)' for the program's own struct;
(33) A LAMBDA'S WRITTEN RESULT TYPE IS RESOLVED UNDER ITS PARAMETERS ([expr.prim.lambda]; `cpp_lambda_written_ret'):
libc++ 18's basic_string move constructor initializes `__r_' from an immediately invoked `[](basic_string &__s) ->
decltype(__s.__r_) && { ... }(__str)', and with no parameter in scope the decltype was untyped, the result unknown and
the member `not constructed'; (34) A DEFAULT ARGUMENT MAY BE A BRACED LIST (`ccl_param_default' through
`ccl_initializer'): `_Pred __pred = {}' is every ranges algorithm of libc++ at C++20, and the four C++20 headers of
the libc++ gate stopped there, 665 items in; (35) C++20's DESIGNATED INITIALIZER TAKES THE BRACED FORM, `.__width_{
__get_width(__ctx)}' (libc++ 18's <format>, in the C++20 closure of <set>), and A BRACED LIST ON A SCALAR IS ITS ONE
VALUE, or the type's zero when empty ([dcl.init.list]; `ir_init'), where the lowering asked a scalar for its members
(`initializer(0, int)'). With them `stdaggregate' (a vector of a struct holding a string, on the compressed pair of
libc++ 18) and `stdarray' build and run on Ubuntu. THE INSTRUMENT, once more: every one of these was a build of
minutes cut to a file of ten lines that failed in a second, the trait ones printed beside clang++'s answers, and the
one that was not (the implicit move's lost definition) was found by the trace's `implicit_copy(Rec, move)' with no
`lower(function(Rec.Rec.Rec_rr, ...))' after it -- a definition's absence read off a list that names every one made.
(36) AND THE FLATTENED TEXT SPELLS THE PREFIXED LITERALS AND THE BIT-PRECISE SUFFIXES (`ccl_pp_spell_tok', `pp_spell'):
`cicilang++ -E' printed `L"true"' as a code list and `12wb' as `12', which no reader takes -- the census's road only, since
the gate reads the tokens, and exactly the kind of gap a step that adds token kinds leaves in the one instrument that
spells them back; the third census of the C++20 `<set>' stopped on it at `__bool_strings<wchar_t>'.
(37) A BRACED ARGUMENT TO A SCALAR PARAMETER is its one item or the type's zero, at the argument pass and where a
default is filled in (`cpp_scalar_braced'), AND A FUNCTION TEMPLATE'S INSTANCE FILLS ITS DEFAULTS AT THE CALL
(`cpp_fill_defaults' at the two template call sites): `g(1)' of `template <class T> T g(T a, int b = 5)' went out with ONE
argument to a function of two -- garbage where C++ has 6, older than this step and found by the C++20 probe's
`adv(I, S, int p = {})'; the plain road had filled them since 0.63, the template road never had. Gated by
`test/cpp/run/bracedforms.cpp' at C++20 (a braced scalar, `.b{2}', a braced default and argument, a template's default,
the copy-constructibility of a pointer and of a plain struct through the builtin), clang++'s numbers.
AND THE `std::function' ROAD ON libc++ 18, five more, found from a refusal that named the wrong thing:
(38) A MEMBER CLASS TEMPLATE DECLARED AND DEFINED LATER IS REGISTERED AT ITS DECLARATION
(`cpp_register_class_extras', a `template <class _Fp, bool = ...> struct __callable;' among the members), which is how
libc++ 18's `function' declares its `__callable' before the partial specializations that define it.
(39) A BASE'S MEMBER TEMPLATE CALLED BARE WITH EXPLICIT ARGUMENTS is found where C++ finds it ([class.member.lookup]:
the class's own first, then each base's, the signature checked in the class that DECLARES it; `cpp_member_template_of'
in the bare-call clause of `cpp_call'): `__tuple_sfinae_base' declares `__do_test<_Trait>(...)' and every derived
trait calls it bare -- found in the derived class alone, the call fell to the CLASS-template road and refused
`template_without_body(__do_test)', which the static fold caught, leaving the trait's `value' an undefined extern at
the link. `this' goes through the base sub-objects as a qualified call's has since 0.73, null for a static.
(40) A TRAILING RETURN TYPE IS THE RESULT ([dcl.fct]/2; `cpp_trailing_rets' at `cpp_norm_members'): the reader keeps
`-> T' as `trailing(T)' among a member's qualifiers with the result `auto', and NOTHING READ IT -- a member defined
deduced its result from its first return (0.42) and a member DECLARED had none; `static auto __do_test(...) ->
__all<...>;' has no body and its declared result is the whole point, a decltype reads it. AND THE RESULT TYPE IS PART
OF THE SIGNATURE ON THE MEMBER ROAD TOO (`cpp_result_holds' inside `cpp_member_holding''s catch, 0.55's rule for a
free template): `-> __all<__enable_if_t<_Trait<_LArgs, _RArgs>::value, bool>{true}...>' is rejected where a trait is
false, which is the only way the variadic `__do_test(...) -> false_type' beside it is ever chosen. The shape on the
program's own classes in `test/cpp/run/basetmpl.cpp' (a base's member template chosen by its result's SFINAE, `1 0').
A FREE function's trailing type is still dropped by the reader (`ccl_external_rest' keeps only the `const' of the
qualifiers after the parameters), its definition deduced from the first return as before, and a bodyless free
prototype `auto f() -> T;' stays `auto': named, not done.
(41) THE READER (version 80): A TEMPLATE TEMPLATE PARAMETER'S NAME IS A TEMPLATE INSIDE ITS ITEM AND NOWHERE ELSE
(`ccl_note_tt_param', un-noted by `ccl_tparams_leave' through a frame per item, unless the name was a template before),
and A TAG OR A TYPEDEF IS NO CONCEPT (`ccl_concept_name'). With everything above in, `std::function<int(int)>' still
refused `concept_without_body(_Trait)', and the name pointed at `__do_test' -- the ONE place libc++ 18 writes `_Trait'
outside `<variant>'. It was `<variant>': `enum class _Trait' and `template <_Trait _DestructibleTrait, class...
_Types> class __base;', a VALUE parameter of enum type, read as a CONSTRAINED TYPE parameter (0.84's `template
<Concept T>') because `_Trait' had stayed a known template since `__do_test''s head two hundred items earlier; and
the flattened `<functional>' of libc++ 18 pulls `<variant>' in, whose `__variant_detail.__base' then carried a
`requires(tmpl('_Trait', ...))' that every `__base<...>' instantiation met. WHAT FOUND IT: the AST beside the summary
is a file of one clause per item, and `grep "requires(tmpl('_Trait'" <name>-<fold>.ast.pl' named the item in a
second where the breadcrumb (`in(class(__base))') and the header (no `_Trait' but __do_test's) both pointed
elsewhere -- an instrument worth naming: a refusal's NAME is a symptom, and the summary's AST is where a shape can be
looked up by its text. Every summary is rewritten (the version), and the gates ran again after it.
(42) A SCOPED ENUMERATOR AS A TEMPLATE ARGUMENT IS ITS VALUE (`cpp_enum_scope' in `cpp_targ_value', the enum's name the
path's last segment, its enumerators global names): `holder<Trait::two, 5>' was read as a type and keyed by its
spelling, `scopedTraittwo', and the static it fed never folded; libc++'s variant writes `__base<_Trait::
_TriviallyAvailable, _Types...>' so. `test/cpp/run/ttleak.cpp' (the leak's shape, the enumerator argument, clang++'s
numbers).
(43) A MEMBER ALIAS TEMPLATE'S TEMPLATE-ID IS A NON-DEDUCED CONTEXT in a function parameter too (`cpp_match', 0.45's
rule for a file-scope alias): libc++ 18 writes `unique_ptr(pointer, _LValRefType<_Dummy>)' with `_LValRefType' the
class's own alias template over the constructor's defaulted `_Dummy', and read as a class template-id it refused
`deduction_failed' -- no two-argument constructor was left for `__func::__clone''s `unique_ptr<__func, _Dp>
__hold(__a.allocate(1), _Dp(__a, 1))'. AND A FREE NAME UNDER A PACK EXPANSION MAKES A TEMPLATE-ID RAW
(`cpp_free_arg(pack(T))', 0.83's guard one shape wider): `forward_as_tuple' is declared `tuple<_Tp &&...>', and typed
by that raw result the compressed pair's piecewise constructor bound its `_Args1' to `_Tp &&' and `std::forward<_Tp
&&...>' refused `kind_mismatch'. AND A TRACED REFUSAL PRINTS THE BREADCRUMB STACK (`cpp_refuse' over `'$cpp_wstack'',
0.87's eight frames), not the innermost frame: `in(class(__base))' had named the class being LOADED where the
constraint that refused was `<variant>''s, and the stack named the statement, the function, the call and the
signature in one line.
(44) A CALL THROUGH A CAST TO A REFERENCE CALLS THE OPERAND ([expr.static.cast]: the cast names the object, an
lvalue or an xvalue; `cpp_call''s `ccast' clause, never where the cast changes the class): libc++ 18's `__invoke'
writes `static_cast<_Fp &&>(__f)(static_cast<_Args &&>(__args)...)', and the callee reached the lowering as the cast
itself -- every `<algorithm>' fixture over a predicate stopped there, which the C++ gate at reader 80 said first
(`stdalgorithm' through `stdalgorithm3' RED); libc++ 21 writes `std::forward<_Fp>(__f)(...)', a call whose result is a
reference, which 0.55's `cpp_addressable' already took. AND TWO TRAITS libc++ 18 asks by their builtin names,
`__is_volatile' and `__is_abstract' (`cpp_trait_of'; the second is `cpp_not_abstract''s test as a value), measured
against libc++ 18's own headers: of every `__is_*' and `__has_*' builtin they spell, those two were the ones the
desugaring could not answer. AND A TIME CAP THAT KILLS THE SHELL AND NOT THE WORKER IS NO CAP -- 0.46's finding (a
watchdog that kills only the direct child leaves cocolog, its grandchild, running), met again from the probe's side:
`scratchpad/probe.sh' capped its build with a perl `alarm' around `bin/cicilang++', the alarm killed that shell, and
cocolog ran on for ten minutes beside the gate; the cap is coreutils' `timeout -s KILL' now, which signals the whole
group it leads.
(45) THE PACKS AN EXPANSION ZIPS ARE THE ONES NAMED OUTSIDE ITS NESTED EXPANSIONS ([temp.variadic]/5: a pattern
expands over the packs it names UNEXPANDED; a `Ts...' inside it is an expansion of its own, expanded whole in every
element, and `sizeof...(Ts)' names no expansion at all; `cpp_names_outside' behind `cpp_pack_names'): libc++ 18's
`__make_tuple_types_flat' writes `__tuple_types<__apply_cv_t<_Tp, __type_pack_element<_Idx, _Types...>>...>', and
zipped over BOTH packs it refused `pack_lengths_differ' where `_Idx' was empty and `_Types' was not -- the
`__make_tuple_types<tuple, 0>' every tuple constructor over an empty pack asks for; with the lengths equal the answer
had been right by coincidence. (46) AN INSTANCE RESOLVED TO ITS STRUCT SPEC IS THE INSTANCE STILL (`cpp_instance_of''s
first clause): the builtin `__remove_cv_t<__libcpp_remove_reference_t<_Tp>>' hands a tuple's instance back as
`struct('tuple.int_r', Ms)', against which the pattern `_Tuple<_Types...>' matched nothing, so the instance was
incomplete and `__apply_quals' a template without a body. (47) A SCOPED NAME WHOSE LAST SEGMENT IS A TEMPLATE-ID,
`C::template ap<T>', IS A MEMBER ALIAS TEMPLATE AND A TYPE (the `atom(N)' guard on `cpp_targ_value''s scoped clause),
where it was looked up as a static member's value and refused `no_member_type'. `test/cpp/run/packzip.cpp' has the
three on the program's own classes, clang++'s numbers. (48) A CONSTRUCTOR TEMPLATE IS A USER-DECLARED CONSTRUCTOR
([class.default.ctor]/1; `cpp_implicit_ctor_needed', `cpp_trivial_default'): it suppresses the implicit default
constructor as a written one does, unless `C() = default' stands beside it. libc++ 18's `__compressed_pair' has ONLY
templates -- `template <bool _Dummy = true, class = __enable_if_t<...>> explicit __compressed_pair() :
_Base1(__value_init_tag()), _Base2(__value_init_tag()) {}' -- and the implicit constructor made beside it took the
SAME NAME (`C.C.0'), was emitted first and constructed neither base: the tree's end node was garbage, `std::map'
walked it and every container fixture on libc++ 18 built and SEGFAULTED (0.93's first Linux gate). (49) A SECOND BASE
WITH STORAGE IS INITIALIZED THROUGH AN ALIAS as the first base has been since 0.82 (`cpp_extra_inits' through
`cpp_alias_base_init'), and NEVER SILENTLY: libc++ names both bases through `using _Base2 = __compressed_pair_elem<_T2,
1>', and a `findall' that merely failed on the second left it unconstructed -- a base with constructors and no default
one, given no initializer, is refused (base_constructor) as the first base is. (50) A CLASS WHOSE IMPLICIT DEFAULT
CONSTRUCTOR IS MADE IS DEFAULT-CONSTRUCTIBLE (`cpp_constructible' asks `cpp_implicit_ctor_needed'): libc++ 18's
`allocator<T> : private __non_trivial_if<...>' has `allocator() = default' over a base with a constructor, so the
implicit one constructs that base and is no trivial default; answered 0, `is_default_constructible<allocator<...>>'
rejected the compressed pair's only default constructor, which is guarded by it. `test/cpp/run/ctortemplate.cpp' is
the shape on the program's own classes (a template constructor initializing two bases through aliases, alone and as
a member), clang++'s numbers; `stdmap', `stdset', `stdtuple', `stdfunction', `stdfunctional' and `stdbind' are the
library's. (51) THE QUALIFICATION CONVERSION ([conv.qual]; `cpp_quals_added' in `cpp_convertible'): `char *' converts
to `const char *', the pointee gaining qualifiers and losing none. libc++ 18's `__unwrap_range' builds
`std::make_pair(__unwrap_iter(__first), __unwrap_iter(__last))' over a string's characters, and
`is_constructible<const char *, char *const>' answered 0, which rejected every two-argument constructor of the pair
(no_constructor(pair, 2)); `test/cpp/run/qualconv.cpp', clang++'s answers. (52) THE MEMBER-POINTER TRAITS ARE ANSWERED
(`__is_member_pointer', `__is_member_function_pointer', `__is_member_object_pointer' in `cpp_trait_of'; a pointer to
member has been a type of its own since 0.86), AND `decltype' OF A CALL THROUGH A POINTER TO MEMBER FUNCTION is the
member's declared result (`cpp_decltype_of', the desugaring having made `(a.*pm)(args)' a call through the function
pointer the member is here): libc++ 18 writes std::invoke's dispatch as six `__invoke' overloads guarded by
`is_member_function_pointer<__decay_t<_Fp>>::value && is_base_of<...>', and with the trait answered 0 -- a
placeholder from 0.88, when no member pointer was lowered -- every one was refused and the generic `__f(__args...)'
held for a pointer to member function, whose body refused decltype_unknown; `test/cpp/run/memptrtraits.cpp', and
`stdbind' runs. (53) A CALL RETURNING A CLASS BY VALUE IS A PRVALUE, an rvalue as an xvalue is ([basic.lval];
`cpp_prvalue_call' beside 0.91's `cpp_xvalue_call', the second certain shape -- a temporary this compiler builds around
such a call included), so `const T &' binding one costs the conversion that lets `T &&' win, AND A NON-CONST LVALUE
PREFERS THE BINDING WITHOUT THE `const' ([over.ics.rank]/3.2.6; `cpp_ref_rank''s lvalue clause): a forwarding `V &&'
deduced as `S &' beats `const V &' for an lvalue `S'. libc++ 18's `tuple_cat' returns `__tuple_cat<...>()(...)', a
tuple of references BY VALUE, into a tuple of values, and with the prvalue uncharged `tuple(const tuple<_Up...> &)'
tied with `tuple(tuple<_Up...> &&)' and stood first. (54) THE COMMA OPERATOR IS A CONSTANT EXPRESSION (C++11,
[expr.const]; `ccl_const_eval(comma(A, B), V)': the right operand's value, the left a constant or a `(void)' cast of
anything): libc++ writes its conjunction as `_IsSame<__all_dummy<_Preds...>, __all_dummy<((void)_Preds, true)...>>',
and unfolded the second instance was keyed by the term's spelling, so `__all<true, true, true>' was FALSE, every tuple
constructed from another tuple lost its converting constructor template and fell to the impl's bitwise copy, and
`tuple_cat' printed three addresses as an int, a double and a char. `test/cpp/run/commafold.cpp' has (53) and (54) on
the program's own classes, clang++'s numbers; `stdtuple''s `tuple_cat' lines are the library's. (55) NAMED, NOT DONE:
A TYPE'S QUALIFIERS ARE NO PART OF ITS KEY (`cpp_type_key' drops `const' and `volatile'), so `is_const<const int>' and
`is_const<int>', `__tuple_like_ext<const T>' and `__tuple_like_ext<T>' are ONE instance here, and the first made
answers for both -- libc++ 18's `__tuple_like_ext<const _Tp> : __tuple_like_ext<_Tp>' resolved its base to ITSELF
(base_not_registered, the instance in progress) on the road (53) now avoids. Qualified keys were written and measured
on a scratch copy of the library (`const_int', `int_pc' for `int *const'): they uncover the next defect at once
(`__apply_cv' handing `const int &' for a non-const tuple's element), so the road that works by the collision's
coincidence is left as it is and the collision is named here for the step that takes the keys apart. AND THE C++ GATE CAPS EACH FIXTURE'S BUILD (`CPP_FIXTURE_SECS' in `test/cpp.sh', 2400 s unless told
otherwise; `ccl_capped' kills the build's whole process tree past it and records `TIMEOUT after N s' as the fixture's
verdict), since 0.92's finding -- a probe with no time cap is no probe -- held for the gate too: an uncapped
`stdalgorithm7' ran 47 minutes on this box where macOS took 119 s, and the gate behind it waited.
THE `std::function' ROAD ON libc++ 18 IS THROUGH: with (38) to (54) `test/cpp/run/stdfunction.cpp', `stdbind.cpp'
and `stdfunctional.cpp' build and print clang++'s lines on Ubuntu, as do the containers that had built and
segfaulted (`stdmap', `stdset', `stdtuple' with its `tuple_cat', `stdvector', `stdmapstring' and the rest, each named
by the gate below). Every probe of this stretch ran through `scratchpad/probe.sh' (a time cap and a memory cap over
the probe's OWN process group, so a probe may run beside a gate that `watch.sh' -- which sums every cocolog process --
would otherwise kill), a traced build through `scratchpad/trace.sh' (cocolog called directly with `'$cpp_trace'' on,
since `bin/cicilang''s filter drops the trace lines), and a fixture through `scratchpad/fx.sh', which removes the
binary before it builds (the finding on a stale binary, 0.89) and compares as the gate compares. THE INSTRUMENT THAT
PAID: the emitted IR read function by function (`cicilang++ -S -emit-llvm'), which named `tuple_cat''s defect in four
reads where the trace named none -- a trace prints refusals, and the wrong constructor was CHOSEN without one.
NOT DONE, libc++ 18's: the qualifier-less keys (55); `stdalgorithm2', `stdalgorithm3', `stdalgorithm6' and
`stdalgorithm7' build past the gate's cap here (breadth in the two-range family, 0.92's finding, and libc++ 18's
`__introsort' and `__merge' roads with it: `stdalgorithm7' traced 299 instantiations in 900 s and no instance asked
twice); `stdalgorithm8' (the set operations) stays uncommitted, 0.92's rule.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module
rebuilt as 0.93), on this tree at reader 80 and lowering 40, the C++ summaries warmed OUTSIDE the gates first at all
four levels: the reader's 95 checks GREEN in 4 s; the compile gate's 76 in 4 s; the driver's 25 in 5 s; the objects'
29 in 3 s; the proof; THE LIBC++ GATE GREEN, its 18 reads whole under a fresh HOME in 5513 s (`<vector>` 806 items,
`<string>` 754, `<iostream>` 792, `<map>` 767, `<set>` 767, `<unordered_map>` 751, `<unordered_set>` 833, `<optional>`
602, `<memory>` 533, `<functional>` 831, `<tuple>` 441 at C++17; `<set>` 859, `<map>` 859, `<unordered_map>` 843,
`<unordered_set>` 925 at C++20; `<optional>` 397 and `<string>` 522 at C++23; `<optional>` 397 at C++26 -- libc++ 18's
counts, larger than libc++ 21's on macOS for every header, the cold flatten of each on a box whose two spare cores the
C++ gate shared; the watchdog's 4304 MB peak is the SUM of both gates' processes and no number of this gate's own).
THE C++ GATE, whole and capped per fixture (2400 s) on 0.93's library, RED: 152 checks ok and 31 fixtures failed in
21064 s, every failure of the 31 named and classified in 0.94's entry below -- four timeouts in the two-range algorithm
family (`stdalgorithm2', `stdalgorithm6', `stdalgorithm7', `stdalgorithmstr'), one fixture beyond libc++ 18
(`stdoptionalref': its `<optional>' still declares a reference type ill-formed), and twenty-six defects of this compiler's
on libc++ 18's shapes, which 0.94 takes up. The watchdog's 5521 MB peak is the SUM of every cocolog process on the
box, the probes run beside the gate included, and no number of the gate's own.
follows in the commit that carries its numbers, with every fixture that fails on this box named as the environment's
or as this step's.
Before them, run whole on this box without a cap: 105 of the C++ gate's fixtures passed and `stdalgorithm7' had run
47 minutes when it was killed (the exploratory run, superseded).
AND A FINDING THAT KILLED TWO GATES AT ONCE (2026-09-24): `scratchpad/gate.sh' runs its gate under `watch.sh', which
sums the resident size of EVERY cocolog process and kills them ALL past its cap -- ONE GUARDED RUN AT A TIME, the rule
since 0.46 -- and the reader gate started beside the libc++ gate and the C++ gate at a 3000 MB cap summed their 3.1 GB
and killed both, 1430 s into the libc++ one. A gate beside other runs takes the cap of the SUM (7000 MB here) or waits;
`probe.sh' watches its own process group and is the runner for anything beside a gate.


## 0.94 — M6's sixty-first step

**M6's sixty-first step (0.94): THE 64-BIT CONSTANT, and the stream and container fixtures on libc++ 18.** 0.93's C++
gate on Linux, run whole, failed every stream fixture and half the map ones, and the road from those verdicts to their
causes went through seven rules, each reproduced in a file of ten to twenty lines before it was fixed.
(1) A CLASS ARGUMENT FOR A SCALAR PARAMETER CONVERTS ONLY THROUGH A CONVERSION OPERATOR WHOSE RESULT FITS IT
([over.ics.user]; `cpp_type_accepts''s last clause through `cpp_conv_result'): ANY conversion operator counted, so
basic_string's `operator basic_string_view()' let the CHAR inserter, `operator<<(basic_ostream<_CharT, _Traits> &,
_CharT)', take a string -- and on libc++ 18, where the ten char and `char *' inserters are declared before the string
one, it won the tie and the struct was sign-extended to a byte (`invalid cast opcode', stdcin's first line).
(2) THE REFERENCE-BINDING RULES ARE A SECONDARY KEY, NEVER A CONVERSION ([over.ics.rank]/3.2.3 and /3.2.6 rank two
standard conversion sequences that are otherwise INDISTINGUISHABLE): 0.93's rule 53 charged them as a conversion, so
`const basic_string &' bound to a non-const lvalue string cost one and tied with (1)'s user-defined conversion. A
candidate's cost is `Conversions-Demerits' now (`cpp_conversions', `'$cpp_refbind'', `cpp_ref_demerit'), compared in
standard order by `cpp_min_of', and the trace prints `holds(1-0)'.
(3) A NESTED ENUM IS A NESTED NAME in a mangled name (`cpp_ita_type_' on `enum(N, _)', `cpp_class_scope_' through the
holder's `'$cpp_class_types'' entry): `basic_streambuf<char>::seekoff(off_type, ios_base::seekdir, openmode)' is shipped
as `..7seekoffExNS_8ios_base7seekdirEj', and the tag resolved to its enum spec, which no clause took -- the vtable
named the slot by its plain name and the link named it (stdcout, stdendl, every stream fixture).
(4) A C STRUCT IN A MANGLED NAME IS ITS UNSCOPED NAME ([basic.link]: a typedef of an unnamed struct gives it its name for
linkage purposes, the FIRST typedef that names it; `cpp_ita_c_struct', asked BEFORE the resolution, since resolving
`mbstate_t' walks through `__mbstate_t' to the anonymous struct and loses the only name it has):
`basic_streambuf<char>::seekpos(fpos<mbstate_t>, openmode)' is `..7seekposENS_4fposI11__mbstate_tEEj'; a named C struct
reached through its tag is its tag (`struct tm' is `2tm').
(5) A LITERAL PAST 2^60 IS `big(Atom)' IN BOTH LEXERS (reader version 81): cocolog's integers are 61-bit (the finding),
so `9223372036854775807LL' arrived as -1. The atom is the value's decimal digits for a decimal literal and `0x' plus its
lowercase hex digits for a hex, binary or octal one (`ccl_lx_big' in the module, `ccl_int_value' and kin in the DCG,
`pp_norm' through the same door; k84 compares them on `test/c/lexer.c', which carries every form); its type is the first
of long and unsigned long that holds it (`ccl_big_type'); the lowering spells it into the IR as it is, `u0x...' for the
hex form (`ir_big_text', lowering version 41); a `_BitInt' literal past 2^60 folds nowhere. `test/c/run/bigint.c'.
(6) THE CONSTANT EVALUATOR COMPUTES IN 64 BITS, and a CAST TO AN INTEGER TYPE WRAPS ([conv.integral]; `ccl_w_*' over
base-2^30 limbs, `ccl_mag_*'; `ccl_w_cast', `ccl_w_wrap'). The lexer half alone was not enough: libc++ computes every
`numeric_limits<...>::max()' as `type(type(~0) ^ __min)' with `__min = _Tp(_Tp(1) << 63)', and folded in 61 bits with
the casts transparent that is -1 -- on macOS as on Linux. A folded value is a cocolog integer where it fits and
`big(Atom)' beyond; an operation whose result could pass 61 bits takes the limbs; `/' and `%' truncate toward zero,
`>>' of a negative is arithmetic, the bitwise operators are the mathematical two's complement (`~0' is -1) and the
casts make the 64-bit patterns: `(long long) (1ULL << 63)' is -2^63, `(unsigned long) ~0' is 2^64-1. THE ANSWER IT
BOUGHT: libc++ 18's string extractor bounds its loop by `numeric_limits<streamsize>::max()' -- with -1 it never looped,
`cin >> word' read nothing and the stream failed; `test/cpp/run/stdcin.cpp' prints clang++'s lines on Linux.
(7) A CALL THROUGH A CAST TO A BASE'S REFERENCE CALLS THE BASE'S operator() OVER THE BASE SUB-OBJECT (`cpp_call''s
`ccast' clause, `cpp_operand_class', `cpp_base_operator_call'; dispatched when virtual): libc++ 18's
`__map_value_compare' writes `static_cast<const _Compare &>(*this)(x.first, y.first)' over its empty base `less<K>',
and `*this' -- the reader's `deref(this)', the bare atom -- was untyped, so 0.93's rule 44 took the operand's own road
and the comparator called ITSELF until the stack was gone: every map of strings segfaulted before its first line
(stdmapinit, stdmapown, stdmapstring, stdmapstring2). The operand `*this' is the class being walked (the call's
context); a class the cast does not change takes the operand's road, a base of it its own operator.
`test/cpp/run/basecastcall.cpp'.
AND THE GATE NAMES A TIMEOUT: a fixture that ran past `CPP_FIXTURE_SECS' printed its `TIMEOUT' under the six-line
head of a diff, invisible when the expectation had six lines -- four of 0.93's algorithm verdicts were read off the
gate's directory (no binary, so no build finished) rather than the log; the verdict line says it now.
(8) AN EMPTY CLASS VALUE MOVES NO BYTES (`ir_store_slot' and `ir_load_slot' through `ir_empty_class'): its one byte
([class]/4, 0.89) is padding as a complete object and, as an EMPTY BASE reached through a reference, somebody else's.
libc++ 18's compressed pair swaps its second element too, `swap(second(), __x.second())' over `static_cast<_Base2
&>(*this)', which for a `unique_ptr<int>' is the deleter, an empty base at the pair's own address -- and the byte the
assignment stored there was the POINTER's low byte: `p.swap(q)' left one pointer clobbered, and its destructor freed it
(`free(): invalid pointer', stdmemory). `test/cpp/run/emptyassign.cpp' has the shape on the program's own classes,
where the assignment of an empty base through a reference swapped the low bytes of two ints.
(9) A LOCAL SHADOWS AN ENUMERATOR (`ir_expr(id(N))' asks `ir_lookup' first; `ccl_const_eval(id(N))' folds nothing a
frame of `ccl_locals' declares): every enumerator is a global name here, a scoped enum's included (0.71), and libc++'s
`<format>', in the C++20 closure of `<set>', declares `basic_format_arg''s `__arg_t' with an enumerator `__ptr' (14)
-- so `iterator __r(__ptr)' in the tree's `__remove_node_pointer' built its iterator from 14 where `__ptr' was the
parameter, and every erase by iterator in a C++20 program over `<set>' walked a wild node (stdcontains). C and C++
both let a local hide an enumerator; the reproduction on the program's own code is `test/cpp/run/enumshadow.cpp' and
`test/c/run/enumshadow.c'. THE INSTRUMENT: the IR of the reduction, `cicilang++ -emit-llvm', read function by function --
`inttoptr i32 14 to ptr' where the parameter's slot should have been loaded said it in one line, where the backtrace
named only the wild node. AND A QUALIFIED ENUMERATOR IS ITS VALUE WHATEVER A LOCAL IS NAMED (`cpp_expr' on
`scoped(Path, N)' through `cpp_enum_scope', and `cpp_targ_value''s two clauses, all asking `ccl_enum_value' directly):
flattened to `id(ptr)', `Kind::ptr' met the parameter that now shadows the bare name -- the fixture's own first run.
(10) A POINTER TO A CLASS TAKES A POINTER TO THAT CLASS OR A CLASS DERIVED FROM IT ([conv.ptr]; `cpp_pointees_agree'
over `cpp_pointee_kind': a class or a struct tag on each side the same or derived, an arithmetic type on each side,
anything unsettled passing -- in the scoring's `cpp_pointee_fit', and through `cpp_scalar_mismatch' in the template
acceptance and the arity-only last resort, where the detection idiom is decided). Any class pointer took any, so
libc++ 18's `__has_destroy<allocator<__tree_node<string>>, string *>' held, `allocator<__tree_node>::destroy(__tree_node
*)' ran the NODE's destructor on the STRING's address, and the string it destroyed lay eight bytes past the block --
valgrind's `Invalid read ... 8 bytes after a block of size 56', on a set of strings, nondeterministic: stdset3 passed
two runs in six (stdsetstring the same). `test/cpp/run/ptrfit.cpp' has the detection and three overloads by pointee
on the program's own classes, clang++'s numbers.
(11) A BORROW OF A LIBRARY OBJECT MAY BE CONSUMED (`ck_library_root' at the borrow-consumed refusal in `ck_args_'):
0.91 made a plain pointer a library class's member answers a borrow of the object, so an array's `end()' is no loose
pointer at the scope's end -- and `Tag *raw = u.release(); delete raw;', how a unique_ptr hands its object out, was
refused as a borrow freed (stduniqueptr, which passed at 0.86 and had not been through a gate since 0.90). What the
program does with such a pointer is the library's discipline, as its functions' bodies are (0.45): the check neither
follows it nor refuses it.
(12) AN OPERATOR OVER A CLASS OPERAND THAT NO ROAD ANSWERS IS ILL-FORMED (`cpp_operator''s last resort refuses
`no_operator(Op)' where a class stands on either side; with `Plain = none', the rewritten `!=' road's ask, it stays a
failure): kept as the raw form, `int == nullopt_t' read as an `int' inside a `decltype', so libc++ 18's constraint on the
generic `operator==(const optional<_Tp> &, const _Up &)', `is_convertible_v<decltype(declval<const _Tp &>() ==
declval<const _Up &>()), bool>', HELD, that candidate beat the `nullopt_t' one, and its body met the same comparison
(stdoptional2: `type(unknown)' in the lowering). Refused, a constraint's `decltype' is the substitution failure C++ has
there, and anywhere else the defect is named instead of reaching the lowering as an operator over a struct.
(13) THE BIT COUNT FOLDS OVER THE VALUE WRAPPED TO ITS TYPE'S WIDTH, unsigned (`cpp_popcount' through `ccl_w_wrap',
the limbs counted): 0.60's fold took `V >= 0' on the engine's integer, and `(unsigned long) ~(unsigned long) 0' is 2^64-1
now, a `big' -- `type_error(evaluable, ...)' on libcxxforms.cpp, the first thing 0.94's own C++ gate said. AND THE MANGLER'S
CLASS LOOKUPS ARE GUARDED for a process without the desugaring's registries (`cpp_class_known'): test/cpp.pl's c34 spells its
nine symbols with no class registered, and rules (3) and (4) asked `'$cpp_cls'' there -- an existence error, the second
thing that gate said. Both found by the gate and none by the probes, which is what a gate is for.
AND RULE (9)'S GUARD ASKS THE LOCAL'S TYPE (`ccl_shadowed_constant'): a `const' local with a constant initializer IS
the constant (0.63's rule 11), and refused as a shadow it never folded -- libc++'s `__mu' writes `const size_t __indx =
is_placeholder<_Ti>::value - 1;' and indexes a tuple by it, and stdbind, which passed at 0.93, refused
`type_pack_index(id(__indx))' in 0.94's first gate: the third thing that gate said, and again none of the probes.
AND RULE (12) LEAVES `!', `&&' AND `||' ALONE: their class operand converts contextually through its `operator bool'
AFTER the operator road (0.72's rule 19), and refused there `return !__f;', how std::function compares with nullptr,
stopped stdfunction in 0.94's first gate -- the fourth thing that gate said, none of them a probe's.
(14) A CLASS'S OWN STATIC SHADOWS A GLOBAL ENUMERATOR OF ITS NAME IN A STATIC'S INITIALIZER ([basic.lookup.unqual]: class
scope before namespace scope; `cpp_shadowing_static' guards the raw fold in `cpp_fold_static', which then folds in the
class's words): ios_base writes `static const fmtflags floatfield = scientific | fixed;', and libc++ 18's flattened
<iostream> also holds `enum class chars_format { scientific = 1, fixed = 2, ... }', whose enumerators are global names
here (0.71), so the raw fold read 1 | 2 = 3 where the class means 256 | 4 = 260, `setf(fixed, floatfield)' masked the flag
away, and `std::fixed' and `std::scientific' printed defaultfloat -- stdmanip's fifth line, the fifth thing 0.94's first
gate said. The reduction printed the three constants first (`4 256 3' against clang++'s `4 256 260'), which named the fold
before the manipulator road was read at all: print the constants a road turns on before reading the road.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module
rebuilt as 0.94), on this tree at reader 81 and lowering 41, each alone under the 7000 MB cap, the fixtures' summaries
warm: the reader's 95 checks GREEN in 9 s at 107 MB; the compile gate's 78 GREEN in 7 s at 268 MB (`bigint.c' and
`enumshadow.c' among them); the driver's 25 in 6 s; the objects' 29; the proof; THE C++ GATE, whole and capped per fixture (2400 s), RED: 180 checks ok
and 7 failures in 22047 s, against 0.93's 152 and 31 -- twenty-five of 0.93's failures pass (every stream fixture:
stdcin, stdcout, stdendl, stdget, stdgetline, stdistream, stdistream2, stdostream, stdmanip, stdws; the string maps,
stdmapinit, stdmapown, stdnodehandle, stdset2, stdset3, stdsetstring, the four unordered ones, stdmemory,
stduniqueptr, stdoptional2), and the seven left are the five two-range algorithm timeouts (`stdalgorithm2',
`stdalgorithm6', `stdalgorithm7', `stdalgorithm9', `stdalgorithmstr'), `stdcontains' and `stdoptionalref', each
measured below; the gate's own peak is 5881 MB, and the 7129 MB its first watchdog killed at was the SUM with a probe
of mine beside it (below); THE LIBC++ GATE GREEN, its 18 reads whole under a fresh HOME in 5489 s at 3218 MB, alone, every item count
0.93's (`<vector>' 806 ... `<optional>' 397 at C++26). The six gates ran one after another in one chain, each under
its own 7000 MB watchdog, and the C++ gate's summaries were warm.
AND THE FIRST C++ GATE OF THIS STEP, on the tree before rules (13) and (14) were carried in, is the record of what a gate
finds that no probe does: 139 checks ok and 14 failures when the box restarted under it at `stdset3' (its log stops
there; the run before it, killed the same way, is the reason a gate's peak line is written by its watchdog and not by
the gate) -- c34, libcxxforms, stdbind, stdfunction, stdmanip, stdmemory and stdoptional, each fixed above and each
verified one at a time under the edited library before the gate above ran; the four two-range algorithm timeouts;
`stdcontains' (below); `stdoptionalref' (beyond libc++ 18); and `stdaggregate', which crashed ONCE in that gate and
passed twenty-four runs alone, valgrind clean, and is named here rather than explained.
NOT DONE, AND MEASURED: the two-range algorithm family stays past the gate's cap on this box (`stdalgorithm2',
`stdalgorithm6', `stdalgorithm7', `stdalgorithmstr', 0.92's finding under libc++ 18's `__introsort' and `__merge'
roads), and `stdalgorithm9' (the heap and the permutations) joins them here where 0.93's gate passed it -- and it is NO
REGRESSION, measured one variable at a time, each build ALONE on the box: 2222 s at 776 MB under the committed 0.93
library with its own reader-80 cache, 2214 s at 761 MB under this tree, against a 2400 s cap; 0.93's gate passed it
inside the cap by a margin the box's noise covers, and the gate here ran it beside a probe of mine for its last
thirteen minutes. Its memory is FLAT at 755 MB for the whole build under both libraries, the shape 0.92 named for
`stdalgorithm8'. A first comparison beside the gate was KILLED at 171 s by the gate's watchdog, which sums every
cocolog process (the finding below, met once more): a comparison is made alone or not at all.
`stdcontains' (C++20: the four containers with `contains' and `erase_if') PASSES ALONE -- 480 s at 3652 MB over the
scratch cache and 487 s at 3666 MB over the user's own, clang++'s lines, where 0.93's gate made its binary and it
SEGFAULTED (rule 9's enumerator) -- and FAILED IN THE GATE, killed at the 7000 MB sum with that same probe beside it,
the probe's own watchdog reading 742 MB at its peak and the gate's watchdog 7129 MB for every cocolog process at one
instant; what the gate's fixture alone had reached at that instant no instrument recorded, and a build alone never
passes 3.7 GB, so the gate's number is unexplained rather than explained away, and the next C++ gate, run with
nothing beside it, is the measurement. THE INSTRUMENT that closed it: a build ALONE over the SAME cache the gate used,
which is the only comparison that means anything (0.89's finding on a mixed-age cache, and this step's on a probe
beside a gate). `stdoptionalref' is beyond libc++ 18 (its `<optional>' declares a reference type ill-formed; the expectation is
libc++ 21's); `stdalgorithm8' stays uncommitted (0.92's rule); the type keys still carry no qualifiers (0.93's item
55); and `stdaggregate' crashed ONCE in this step's first gate, passed twenty-four builds alone, valgrind clean, and
passed the gate above.

## 0.95 — M6's sixty-second step

**M6's sixty-second step (0.95): THE TWO-RANGE ALGORITHM FAMILY'S COST, which was never breadth -- an
exponential in the most-specialized ordering -- and the not-done list of 0.94, closed.** 0.92 measured
`std::equal' at 250 s against a 28 s baseline on macOS and read its trace as BREADTH (1422 candidates, 637
refusals, no instance asked twice); 0.93 and 0.94 carried five `<algorithm>' fixtures past the gate's 2400 s cap
on Linux under that reading. THE INSTRUMENT that settled it in one run: cocolog's `statistics(cputime, T)'
printed on every trace line beside the memory (`cpp_mem' in a scratch copy of the library), and a script that
sums the gap after each line by the line's functor and ranks the largest gaps -- `t_defined(F) => t_special(F)'
held 121 of stdalgorithm2's first 135 s, which is `cpp_most_special_fn' and nothing else. A stamp at the head of
each pairwise comparison then COUNTED them: 1025 for a two-candidate `search', 1029 for a four-candidate
`__uninitialized_allocator_copy_impl', 257, 65 and 17 elsewhere -- 4^k + 1 for k parameters. THE CAUSE:
`cpp_fn_more_special' leaves choicepoints (`cpp_match''s pointer and array clauses have no cut, and its catch-all
last clause succeeds after any of them), and the ordering was written `\+ ( member(Y, All), Y \== H, more(Y, H),
\+ more(H, Y) )', so every failure of the inner test RETRIED the outer comparison through every alternative
deduction, one choice per parameter. A comparison is a TEST, asked `once' -- at both orderings, the class
specializations' too, and the bare `catch' inside the function one brought under the repository's rule; the
answer is the one it was, since the inner test never depended on which deduction the outer one found. MEASURED
ALONE on this box, each build with the same summaries: stdalgorithm2 59 s (past 2400 before), stdalgorithm6 226 s
(past 2400), stdalgorithm7 78 s (47 minutes, uncapped, at 0.93), stdalgorithm9 57 s (2214 s at 0.94),
stdalgorithmstr 144 s (past 2400), stdalgorithm3 66 s, and `std::equal' alone had been 158 s against a 106 s
baseline on this box before the fix -- the two-range family was never the cost here, the ordering was, and it hit
whichever fixture had four-parameter candidates. 0.92's two failed fixes chased the `enable_if' instance keyed by
a spelled conjunction, which was a real thing in the trace and not the cost: a bad thing in a trace is not a
demonstration that it is THE cost, and a CPU-time stamp per line is the demonstration.
WHAT THE CAP HAD HIDDEN: stdalgorithmstr, inside the cap at last, refused `phi void' -- A CONDITIONAL OVER TWO
VOID ARMS IS VOID ([expr.cond]/2: both arms evaluated for their effects, no value and nothing to phi;
`ir_expr(cond)''s first clause, lowering version 42), which libc++ 18's string algorithms write;
`test/cpp/run/voidcond.cpp'. And `stdalgorithm8.cpp' (includes, set_union, set_intersection, set_difference,
set_symmetric_difference, inplace_merge), written and never seen to pass since 0.92, builds in 84 s and prints
clang++'s lines; it is committed.
THE TYPE KEYS CARRY THE QUALIFIERS (0.93's item 55): `const' and `volatile' are part of an instance's key
(`cpp_type_key': `const_int', `int_pc' for `int *const'; nothing else in a qualifier list keys), so
`is_const<const int>' and `is_const<int>' are two instances where the first made had answered for both; a by-value
parameter's TOP-LEVEL qualifiers stay out of a function's key ([dcl.fct]/5, `cpp_param_fn_type' in
`cpp_params_key'), since `f(int)' declared and `f(const int x)' defined are one function. Eleven of twelve probes
passed under the keys at once and `tuple_cat' refused -- WHICH WAS THE DEFECT 0.93 NAMED, seen whole: the reader
gave every libc++ `get' a `const' on its result, because `constexpr typename tuple_element<...>::type &get(tuple<_Tp...>
&)' went through 0.79's rule (a constexpr OBJECT is a const one) with no declarator in sight, so
`forward_as_tuple(std::get<0>(t))' deduced `const int &' -- and the unqualified keys had made `tuple<const int &>'
and `tuple<int &>' one name, which is why it worked. `constexpr' ON A FUNCTION IS NO CONST ON ITS RESULT
([dcl.constexpr]): the specifier rule reads the word as `const' plus a marker, and the declarator's fold
(`ccl_constexpr_fold' at `ccl_mk_type', the one door every declarator goes through) drops the marker, and the
const with it where the declarator makes a FUNCTION -- an object keeps its const and folds as before. Reader
version 82, since every summary's `get' changes shape. `test/cpp/run/constexprfn2.cpp' (a constexpr function's
reference written through, a template deducing `int &' from it and `const int &' from the const overload, a
constexpr object sizing an array), clang++'s numbers. TWO MORE THE KEYS UNCOVERED, each a rule of its own: A
TEMPLATE ARGUMENT BINDS THE TYPE AS IT IS ([temp.deduct.type]/1; `cpp_match_targs'): the decay of the argument's
top-level qualifiers is [temp.deduct.call]'s, a by-value FUNCTION parameter's, and through `cpp_match' the pattern
`pair<_T1, _T2> &' against a map's `pair<const string, int>' bound `_T1' to `string' -- invisible while the keys carried
no qualifiers, and `argument_mismatch' on every `get' of a structured binding over a map once they did (stdmapstring);
and A FILE-SCOPE `const' OBJECT INITIALIZED BY A CONSTEXPR CALL TAKES ITS VALUE (`cpp_fold_const_inits' at the
declaration item, the program's own desugared functions kept as `'$cpp_ownfn'' where `cpp_const_fold' can find them):
`constexpr int N = twice(21);' had reached the lowering as a call in a global's initializer. AND A MEASUREMENT THAT
WAS NOT ONE, three times in an evening: stdfunction read 3506 MB and stdcontains 5535 MB under this tree where 0.94
had 1489 and 3652 -- and every one of those runs was COLD, the reader's version having moved to 82, with the flatten
of the headers in the same process (the trace showed 2.8 GB of heap BEFORE the first desugaring event, the read's
own); warm and alone, stdfunction is 201 s at 1480 MB and stdcontains 394 s at 3760, 0.94's numbers. A killed run
writes no summary (the finding), so a run killed on its flatten leaves the NEXT run cold too, and a `regression'
that arrives with a reader version bump is a cold cache until a warm run says otherwise (0.89's rule, re-learned).
AND THE OLDER LIST: `stdoptionalref' is beyond libc++ 18 (its `<optional>' declares a reference type ill-formed)
and A FIXTURE BEYOND THE BOX'S LIBRARY IS SKIPPED BY NAME -- `NAME.needs' holds a preprocessor condition over the
library's own macros (`_LIBCPP_VERSION >= 210000'), `ccl_needs_met' in `test/cpp.sh' runs a four-line file
including `<version>' through `cicilang++ -E' and looks for the marker, and the gate prints the fixture as skipped,
neither ok nor a failure (measured: libc++ 18's marker survives and 21's does not). `stdaggregate''s one crash in
0.94's first gate WAS NO CRASH: the log holds the watchdog's kill line right above the verdict, at a 7040 MB sum
with my probes beside the gate -- a misread of 0.94's own finding, recorded here so it is not chased again; its
binary ran 600 times clean.
Reader version 82, lowering version 42; the module rebuilt as 0.95.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1), one after
another under their own 7000 MB watchdog with nothing beside them, the user's summaries warmed OUTSIDE the gates
first at all four levels (one header a process, 32 summaries, since the reader's version moved): the reader's 95
checks GREEN in 9 s at 108 MB; the compile gate's 78 in 7 s at 266 MB; the driver's 25 in 5 s; the objects' 29; the
proof; THE C++ GATE GREEN -- 189 checks ok, `stdoptionalref' skipped by name, NO failure -- in 6775 s at a 3750 MB
peak, against 0.94's 180 ok and 7 failures in 22047 s: every `<algorithm>' fixture inside the cap, `stdalgorithm8',
`voidcond' and `constexprfn2' among the new ones, `stdcontains' 0.94's timeout no more; THE LIBC++ GATE GREEN, its 18 reads whole under a fresh HOME in 5156 s at 3208 MB, every item count 0.94's (`<vector>' 806 ... `<optional>' 397 at C++26): the reader's constexpr fold moved no header's item count, which is what it should have moved -- a type inside an item, not the items.
NOT DONE: `is_const<const int>' and its kin are two instances now, but two `[[no_unique_address]]' members of ONE
empty type still share an address (0.89's); a `constexpr' function is folded only where its body is one `return'
(0.72's rule, unchanged); the C++ gate's reader part still pays a cold flatten of `<sstream>' and its ten headers
after every reader bump (0.67's note), which the warming outside the gates does not cover -- a header the reader's
fixtures include and no run fixture does.


## 0.96 — M6's sixty-third step

**M6's sixty-third step (0.96): THE NOT-DONE LIST OF 0.95, closed -- the empty member's address, the constexpr
function with statements, and the warming as a tool of the repository.** (1) AN EMPTY `[[no_unique_address]]' MEMBER
LIES WHERE THE ITANIUM ABI PUTS IT (2.4 II.3, MEASURED against clang++ 18 on eleven shapes before a line was written):
at offset ZERO whatever lies there, unless an empty subobject of ITS OWN TYPE is there already -- then at the current
data size rounded to its alignment, and on by its alignment while such a subobject is in the way; it takes no bytes
of the data and the class's size still covers its byte. `struct { int x; [[no_unique_address]] E a, b; }' is `a' at
0, `b' at 4, eight bytes; `struct { [[no_unique_address]] E a; char c; }' one byte with `c' at 0; a PLAIN member of an
empty class counts as an empty subobject in the way. The layout walk (`ccl_members_layout_') threads the empty
subobjects placed and the byte past the last of them (`acc(Seen, EmptyEnd)'), the size is the larger of the data's
and that end; and since the offset may lie BEFORE the running position, the lowering emits NO element for such a
member and addresses it by its BYTE OFFSET from the object (`ir_member_slot': `getelementptr i8', the map's
`m(N, empty(Off), T, empty)'), where a zero-sized `{}' element at the running position had given 0.89's address, one
past the members before it. Lowering version 43. `test/cpp/run/nounique2.cpp' at C++20, clang++'s numbers on all
eleven shapes; the older layout fixtures unchanged. (2) A CONSTEXPR FUNCTION WITH STATEMENTS ([dcl.constexpr] since
C++14) FOLDS where a constant is wanted -- 0.72's fold took one `return' and nothing else. The body's statements are
EVALUATED over an environment of Name-Value (`cpp_eval_stmts'): the parameters bound to the arguments' folded values,
locals declared as they are met and a block's own dropped at its end, assignments and the four increments changing
the environment (an increment inside an operand too, `n-- > 1'), `if', `while', `do', `for' with `break' and
`continue', several `return's, every expression folded by `ccl_const_eval' with the names replaced by their values,
under a step budget (200000 statements) so a loop that does not end is a failure and never a hang; what it cannot
take -- an aggregate, a pointer, a call it cannot fold -- FAILS and the call stays a call, as before.
`test/cpp/run/constexprfn3.cpp' (a factorial by a loop, a Fibonacci by `while' over a decremented parameter, a bit
count, a `do'/`while' Collatz, a `for(;;)' with its return inside, `break' and `continue', as a template argument, an
array's bound, a class's static, a global, a `static_assert', and the same functions called at run time), clang++'s
numbers. (3) THE WARMING IS A TOOL OF THE REPOSITORY, `test/warm.sh': every header `test/cpp/*.cpp' and
`test/cpp/run/*.cpp' include, and Cicili's own `test/cpp/*.cpp' that the reader's gate reads whole (`<sstream>',
`<stdexcept>': the ones the scratchpad script never covered), at the level its `.flags' names and at C++17, `<version>' first, one header a process
under a time cap and a memory cap over every cocolog process (2400 s and 7000 MB, the gates' own) -- so a reader
version bump never leaves the C++ gate's reader part cold on `<sstream>' and its ten headers (0.95's not-done). A header
whose warming is KILLED is named as not written. Its first run, at reader 82 with the summaries warm, took 37 headers in
55 s and named none as cold -- and it did not list `<sstream>' at all, since the gate's whole reads are Cicili's files and
not this tree's: the list was widened before the script was believed, which is the measurement a tool owes. AND THE
WIDENING WAS SAVED TWO MINUTES AFTER THE GATE CHAIN HAD RUN THE SCRIPT, so the chain below warmed the 37 and not the
40 -- the script's log says which list it ran (`warm: 40 headers' is its first line now, and a Cicili checkout it
cannot find is named rather than skipped), and the widened list ran ALONE after the gates: 40 headers in 56 s, none
killed, `<sstream>' served warm at 213 MB. Reader version 82 unchanged; lowering version 43.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module rebuilt
as 0.96), one after another in one chain with nothing beside them, each under its own 7000 MB watchdog, the summaries
warm at reader 82: the reader's 95 checks GREEN in 10 s at 107 MB; the compile gate's 78 in 7 s at 264 MB; the
driver's 25 in 6 s at 109 MB; the objects' 29; the proof; THE C++ GATE GREEN -- 191 checks ok (0.95's 189 and this
step's `nounique2' and `constexprfn3'), `stdoptionalref' skipped by name, NO failure -- in 6488 s at a 3771 MB peak
(0.95: 6775 s, 3750 MB: the layout rule and the constexpr evaluator cost nothing the box's noise does not cover);
THE LIBC++ GATE GREEN, its 18 reads whole under a fresh HOME in 5390 s at 3224 MB, every item count 0.95's
(`<vector>' 806 ... `<optional>' 397 at C++26), as a step that moves no reader rule should leave them.
NOT DONE: a constexpr function over an aggregate, a pointer or a call the evaluator cannot fold stays a call (by
design: it fails and never lies); a `[[no_unique_address]]' member of a class with bytes lies where it always did
(the ABI agrees); and 0.89's open question -- why a C++ check averages 34 s on this box where 0.87's averaged 14 on
the Mac -- is still one fixture's outlier away from an answer, `stdtuple' at 235 s the first to measure.


## 0.97 — M6's sixty-fourth step

**M6's sixty-fourth step (0.97): THE CONSTEXPR EVALUATOR OVER AGGREGATES, and the cost of `std::get' -- 0.96's
not-done list, closed.** (1) AGGREGATES IN A CONSTEXPR BODY: a local ARRAY or STRUCT is a VALUE of the evaluator's
environment -- `arr(Elems)' of values, `obj([Name-Value ...])' over the struct's data members in order (`cpp_eval_agg_kind',
`cpp_eval_init') -- built from its braced initializer (an item by position, `.f = e' by name, a nested brace for a nested
aggregate, what is left value-initialized to zero, [dcl.init.aggr]), read and written through a PLACE (`a[i]', `p.x',
`g[1][2]', `ps[i].y': `cpp_eval_place', `cpp_eval_store', the effects and the increments over a place where a name was,
every place inside an expression folded to its value before the one evaluator sees it, `cpp_eval_places'); a FILE-SCOPE
`const' AGGREGATE with a constant initializer is such a value too (`'$cpp_gagg:N'', recorded where its declaration item is
walked, `cpp_global_agg'), so `table[i]' folds inside a body and `table[2]' or `origin.x' wherever a constant is wanted
(`cpp_const_fold' on an index and a member, `cpp_const_reduce' taking a member); a `switch' runs from the matching case
label -- the labels flattened, `case 2: case 3:' two of them -- or from `default', through the fallthrough to a `break'
(`cpp_eval_switch_flat', `cpp_eval_switch_run'); a range-for over an array binds each element in turn; and a NESTED
constexpr call with statements shares ONE step budget with the fold that made it (the nested fold RESET the counter, so
the bound was per level and not per answer) and must answer a SCALAR (`cpp_eval_scalar': an aggregate returned stays a
call). A POINTER stays outside: the call stays a call, named. Gated by `test/cpp/run/constexprfn4.cpp' (a sum over a
constant table, a local array written, a 2-D array, a struct written member by member and a constant struct's member,
digits by a `while' nested in another constexpr call, a `switch' with a block case and a default, a fallthrough, an array of
structs, each as a template argument, an array's bound and at run time), clang++'s numbers. FOUND ON THE WAY, older than
this step and named: an instance keyed by an UNFOLDED value argument, `Box<sum_local(1)>' before the evaluator took it,
was keyed by the call's spelling (`Box.callidsumlocalint1') and its static `v = N' emitted `extern' -- the link named
it, where a refusal by name would have; the key stays as it is, since libc++'s roads key unfoldable expressions
harmlessly (0.92's `enable_if<binbin...>') and are refused later for what they lack.
(2) THE COST OF `std::get', which is where 0.89's open question went. THE INSTRUMENT: 0.95's CPU-time trace on a scratch
copy of the library (`kb(Heap, Store, CPU)' on every line, `tdelta.py' summing the gap after each line by its functor),
over `stdtuple.cpp' alone: 240 s of CPU, 91 s after 25,556 `candidate' events and 78 s after 1,581 `call_types' -- and by
NAME, `get' alone: 188 calls, 96 candidates each, 18,048 checks, 116 s, with 16,083 refusals (7,432 `deduction_failed',
6,816 `kind_mismatch': the by-type `get<T>' templates given an index, the pair's and the array's given a tuple). TWO
CAUSES, each measured alone on the same cache: (a) THE MERGED CANDIDATE SET WAS REBUILT AT EVERY CALL, and
`cpp_fn_merge_defaults' computed each candidate's parameter key against every other's -- 96 x 96 = 9,216 key resolutions
a call, 0.36 s before the first candidate was even tried (the gap after `call_types'); the set is made ONCE per name
and kept (`cpp_fn_candidates', `'$cpp_fncands:F'', remade only where the count of the name's templates has moved, a header
loaded since), and its keys are computed once -- 235 -> 169 s; (b) THE SAME CALL SHAPE WAS CHECKED AGAIN: 188 calls of
`get' in 33 shapes (the name, the explicit arguments, each argument's expression and TYPE -- its value category with it --
the class context, the count of templates), and the holding set with its bindings and conversions is a function of the
shape, so it is REMEMBERED (`cpp_holding_set', `cpp_call_shape', `'$cpp_hs:...''; an argument the inference cannot type is
no key, since the desugaring would type it differently per place, and such a call is checked as before) -- 169 -> 134 s,
clang++'s lines unchanged. TRACED AGAIN under the two: 129 s of CPU, 1,061 of the 1,565 template calls answered from a remembered shape,
the candidate checks 37 s for the shapes met first, the instantiations (`spend') 32 s -- the rest is the work. A THIRD
memo, the CHOICE among the holding set remembered with it, measured 134 -> 132 s, the box's noise, and was TAKEN OUT: a
change is worth what it measures. AND THE MEMO'S FIRST KEY WAS WRONG, which the fixtures said within the hour: keyed by
the explicit arguments' SPELLING, `std::get<__indx>(__uj)' -- libc++'s `__mu', the placeholder's index a `const' local
whose VALUE is another in every instantiation -- answered the first instantiation's holding set to the second, and
`std::bind(add3, _2, _1, 100)(3, 4)' printed 108 for 107 (`stdbind'); the key holds the explicit arguments' VALUES
(`cpp_targ_value', and only where every one is settled), and `stdbind', `stdmap', `stdcout', `stdvectorstring',
`stdoptional2', `refrank', `overloads', `freeoverloads', `classwords' and the constexpr fixtures pass, one at a time,
before the gates.
(3) THE ANSWER TO 0.89'S QUESTION, as far as this box can give it: a C++ check averaged 34 s here against 0.87's 14 on
the Mac, and it is three things, none of them a regression -- the box (`stdmap' 39 s here against 28 s of user time on
the Mac at 0.88, both warm), libc++ 18's larger overload sets and headers (96 definitions of `get'; `<vector>' 806 items
against libc++ 21's 441), and the fixtures added since 0.87 (the `<algorithm>' family, `stdcontains' at 394 s) -- with
the two costs above, which every fixture over a library template paid, taken out: the C++ gate's number below is the
measurement. Reader version 82 unchanged; lowering version 43 unchanged; the module rebuilt as 0.97.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module rebuilt
as 0.97), one after another in one chain with nothing beside them, each under its own 7000 MB watchdog, the summaries
warm at reader 82 (`test/warm.sh' first: 40 headers, 56 s, none cold): the reader's 95 checks GREEN in 9 s at 108 MB;
the compile gate's 78 in 7 s at 265 MB; the driver's 25 in 6 s at 109 MB; the objects' 29; the proof; THE C++ GATE
GREEN -- 192 checks ok (0.96's 191 and `constexprfn4'), `stdoptionalref' skipped by name, NO failure -- in 6108 s at a
3778 MB peak, against 0.96's 6488 s: the 380 s the two memos took out of the whole gate, one fixture more inside it, are
a sixth of `stdtuple''s own gain spread over every fixture that resolves a library template, which is what the trace
said to expect (the candidate set's cost was per call, `get''s set the largest); THE LIBC++ GATE GREEN, its 18 reads whole under a fresh HOME in 5533 s at 3231 MB, every item count 0.96's
(`<vector>' 806 ... `<optional>' 397 at C++26), as a step that moves no reader rule should leave them.
NOT DONE: a constexpr function over a POINTER, or one returning an aggregate, stays a call (by design: it fails and never
lies); a constexpr MEMBER function over `this'; an instance keyed by an unfolded value argument is named above and not
refused; the candidate checks themselves -- 37 s of `stdtuple''s 129 for the shapes met first, 3.5 ms a check -- and the
instantiations are the work that is left, and a check averages 32 s in the C++ gate here where 0.87's averaged 14 on the
Mac, which (3) accounts for.

## 0.98 — M6's sixty-fifth step

**M6's sixty-fifth step (0.98): THE CONSTEXPR EVALUATOR OVER POINTERS, AGGREGATES RETURNED AND `this' -- 0.97's not-done
list, closed.** (1) THE VALUES GREW BY ONE, THE POINTER: `ptr(Base, Off)', its base an `arr(L)' -- a string literal's codes
with their zero (`str(Cs)'), an array named, a pointer's own -- or an `obj(Ps)' (`&q', `this'), a COPY read through and never
written: `s[n]', `*s', `s++', `p - s', `p->x', `++p', two pointers compared, a pointer against null (never null here); a store
THROUGH one has no clause, so the fold fails and the call stays a call. AND THE EXPRESSION IS REDUCED, not substituted:
0.96 replaced every name by its value and handed the term to the one evaluator, which no aggregate could pass through;
`cpp_eval_reduce' walks the expression bottom up over the environment -- a name to its value, a place to what it holds, a
literal string to a pointer, a CALL of a constexpr function to its answer (`cpp_eval_call', which may be an aggregate
now: `return {a, a * 2}', a compound literal, `flip(P p)' taking one), pointer arithmetic to a pointer, a statement
expression to its last value, everything else rebuilt -- into a term whose leaves are `int(V)' and `'$val'(Agg)', and the
scalar arithmetic left is the one evaluator's (`cpp_eval_value' through `cpp_const_value'). A CONST MEMBER FUNCTION over
a constant object is a call over `&q' whose `this' is a pointer to the object's value, and its body's `this->x' reads
through it; the class's methods join the own-function table where the fold finds them (`'$cpp_ownfn'', at the class
item's emission). A FILE-SCOPE CONSTANT AGGREGATE INITIALIZED BY A CONSTEXPR CALL, `constexpr P origin = make(7);', which
reached the lowering as `global_init(call(...))', is folded into its initializer (`cpp_eval_init_term': the value spelled
back as braced items) and is a value to the evaluator as any constant aggregate is. `make(5).y' folds anywhere a constant
is wanted (`cpp_const_fold' on a member or an index of a call's aggregate answer). The evaluator's road is tried first at
the fold and 0.72's one-return road stands as its fallback, the arguments bound as written. Gated by
`test/cpp/run/constexprfn5.cpp' (an aggregate returned as a braced list and as a compound literal, taken by value and by
const reference, a global from a call and its members, a string's length and a count through `s[n]' and `*s++', a sum over
a constant array and over a local one with `a + 1', a word's length by pointer difference, `corner.scaled(3)' -- each as a
template argument too), clang++'s numbers; the older constexpr fixtures unchanged. NOT DONE, named: a store through a
pointer or through `this' (a non-const member function), a pointer to a scalar (`&x'), a constexpr constructor (a global of
a class with one is not folded), `sizeof' over a local array's name.
(2) A VALUE ARGUMENT THAT IS A PLAIN LOCAL'S NAME IS REFUSED BY NAME (`template_argument_not_constant(P, A)' at
`cpp_bind_targs_'): `Box<x>' over a function's parameter keyed the instance by its spelling and the static it fed was an
`extern' the link named. THE FIRST WRITING REFUSED EVERY UNSETTLED VALUE, and `stdtuple' said no within the minute:
libc++'s `get' by type keys `tuple_element' by `__find_exactly_one_t<_T1, _Args...>::value', a static this compiler does
not fold at the binding (`cpp_targ_value' answers the scoped name as written) and folds LATER, inside the instance, where
the road works today -- so an unfolded call or static stays keyed as it is, and only what can never fold, a local's name,
is refused. A type, an int, a bool, a char and a negative literal, an enumerator, `sizeof' and a constexpr call fold as
before (`test/cpp/run/targkeys.cpp'). AND THE FIXTURE THAT SAID NO SAID SOMETHING ELSE TOO: with the refusal narrowed
`stdtuple' still refused, `type_pack_index(...::value)', and a bisect on two scratch copies of the library -- one without
the kind pre-filter below, one without the evaluator's fold -- named the fold in one run each. The evaluator's step counter
was set only at a fold's depth 0, and the evaluator is entered at depth 1 below 0.72's one-return road, which never set
it: `existence_error(variable, '$cpp_eval_steps')', an ERROR and not a failure, which the static's fold caught and read as
a fold that failed, silently. The instrument that named it was a `catch' around the new clause on the scratch copy,
tracing the error it swallowed -- a failure that arrives as an exception leaves no refusal in the trace, and the fold's own
catch made it look like every other unfoldable static. The counter starts at 0 wherever it is first asked.
(3) THE CANDIDATE CHECKS' OWN COST, measured and left: a KIND PRE-FILTER before the full check -- a type parameter given a
plain literal, a value parameter given a plain type, skipped without the refusal machinery (6,816 of `get''s 18,048
refusals were `kind_mismatch' in 0.97's trace) -- built `stdtuple' in 131 s where 132 was the number without it, the box's
noise, and was TAKEN OUT: with the holding set remembered per shape (0.97) the checks that remain are the first of each
shape, and what a check costs is the deduction, not the kind. A check averages 32 s in the C++ gate here, and what is left
in it is the instantiations and the first deductions, the work.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module rebuilt
as 0.98), one after another in one chain with nothing beside them, each under its own 7000 MB watchdog, the summaries
warm at reader 82 (`test/warm.sh' first: 40 headers, 56 s, none cold): the reader's 95 checks GREEN in 3 s at 90 MB; the
compile gate's 78 in 3 s at 220 MB; the driver's 25 in 5 s at 83 MB; the objects' 29; the proof; THE C++ GATE GREEN -- 194
checks ok (0.97's 192, `constexprfn5' and `targkeys'), `stdoptionalref' skipped by name, NO failure -- in 6179 s at a
3766 MB peak (0.97: 6108 s, 3778 MB: two fixtures more, the same clock within the box's noise); THE LIBC++ GATE GREEN, its 18 reads whole under a fresh HOME in 5518 s at 3265 MB, every item count 0.97's
(`<vector>' 806 ... `<optional>' 397 at C++26), as a step that moves no reader rule should leave them.
NOT DONE: a store through a pointer or through `this' in a constexpr body, a pointer to a scalar, a constexpr constructor,
`sizeof' over a local array's name; an unfolded CALL or a class's static as a value argument stays keyed by its spelling
(the reason above); the candidate checks' first deductions and the instantiations are the work a build is made of now.


## 0.99 — M6's sixty-sixth step

**M6's sixty-sixth step (0.99): THE NOT-DONE LISTS, CLOSED WHERE A FORM CAN BE CLOSED -- the constexpr
evaluator's memory, C11's atomics whole, and thirty older items from 0.42 to 0.98.** The owner asked for ALL the
not-done works, so this step is the lists themselves, each item taken with a reproduction and a fixture, and the ones
that stay open named at the end with the reason.
THE CONSTEXPR EVALUATOR'S MEMORY (0.98's list): (1) EVERY LOCAL AND PARAMETER LIVES IN A CELL, a global of its own
(`'$cpp_ec:K'`), the environment mapping the name to it (`N-'$cell'(K)`) beside its declared type (`'$t'(N)-T`), and a
POINTER is `ptr(cell(K), Path)' -- the cell and the path into its value (`[]' the whole, `[2]' an element, `[x]' a
member, `[1, y]' nested) -- so a STORE THROUGH ONE writes the cell the pointer names, whichever function holds it:
`*p = v', `p[i] = v', `q->x = v', a callee's `a[i] = v' through its pointer parameter, `this->x *= k' in a NON-CONST
member function (`p.scale(k)', `q->scale(2)' with q a pointer to a local), `&x' of a scalar (`swap_ints(&x, &y)'), a
REFERENCE parameter or local as an ALIAS of an address (`inc_ref(x)'); an array's name DECAYS to a pointer to its first
element, a string literal is a cell holding its codes, a temporary that is no place gets a cell (`cpp_eval_addr`,
`cpp_eval_load`, `cpp_eval_store_ptr`, `cpp_eval_padd` over the path's last step). 0.98's read-only `ptr(Base, Off)' and
its copy semantics are gone with it. (2) `sizeof(a)' OVER A LOCAL ARRAY, `sizeof(ps[1])', `sizeof(w)' from the declared
types the environment keeps (`cpp_eval_sizeof`, an unbounded array's from its value). (3) A CONSTEXPR CONSTRUCTOR: a
global of a class with one is CONSTRUCTED AT COMPILE TIME (`constexpr V g(3, 4);' -- the constructor runs in the
evaluator over a cell holding the class's zero and the cell's value is the global's initializer, `@g = global %struct.V
{ i32 3, i32 8 }'; `cpp_fold_ctor_init` on every global of a class with constructors, const or not, since this compiler
runs no dynamic initialization: one the evaluator cannot run is REFUSED BY NAME, `dynamic_initialization_of_global(N,
C)', where the lowering had met `global_init(ctor(...))'), a local `V v(1, 2); v.add(5);' and a temporary `V(7, 1).total()'
inside a constexpr body through the same cells, and a void function falling off its end is its zero.
`test/cpp/run/constexprfn6.cpp', clang++'s numbers; the five older constexpr fixtures unchanged.
C11's ATOMICS, WHOLE (0.93's `_Atomic' objects, 0.86's compare-exchange): (4) `library/include/stdatomic.h' is the
compiler's own freestanding header (as clang's, over the `__c11_atomic_*' builtins: the `atomic_*' typedefs through
`_Atomic(T)', the `memory_order' enum over the predefined `__ATOMIC_*', `atomic_flag', every generic function and its
`_explicit' form, `ATOMIC_VAR_INIT', `kill_dependency') -- glibc has none of its own and clang's lives in the resource
directory this inclusion path does not visit, so `#include <stdatomic.h>' had expanded to NOTHING and every `atomic_*'
call went out undeclared; (5) `_Atomic(T)' IS READ (6.7.2.4: the type's specifiers under the qualifier, a pointer or a
qualified type taken whole as `typeof' takes one; `ccl_atomic_spec`); (6) THE `__c11_atomic_*' BUILTINS are the
instructions the `__atomic_*' family already had (`fetch_add/sub/and/or/xor' and `exchange' an atomicrmw, `load',
`store', `init', the two fences), plus `__c11_atomic_compare_exchange_strong/weak' as LLVM's `cmpxchg' (the expected
value loaded, the old value stored back to `*expected', the success bit zero-extended; a failure ordering never a release,
`ir_cmpxchg_fail`) and `__c11_atomic_is_lock_free' answering 1 up to a word; (7) AN `_Atomic' OBJECT IS READ AND WRITTEN
ATOMICALLY (6.7.3, 7.17.7): a load or a store through its slot is the sequentially consistent instruction
(`ir_load_slot`, `ir_store_slot` on `ir_atomic_q`), and `x++', `--x', `x += n', `x -= n', `x |= m', `x &= m', `x ^= m' are
ONE atomicrmw each (`ir_step`, `ir_expr(assign(Op, ...))`), where they had been plain loads and stores. `test/c/run/atomic.c'
(a global and a local `_Atomic', the increments and the compound assignments, `atomic_int', `atomic_fetch_add',
`atomic_exchange', `atomic_compare_exchange_strong' with its `expected' written back, `atomic_load'), clang's numbers.
THE OLDER LISTS, closed: (8) `LONG_MAX', `LONG_MIN', `ULONG_MAX', `LLONG_MAX' print as C prints them
(`test/c/run/longmax.c'): 0.94's `big(Atom)' literal and the 64-bit constant evaluator had closed 0.93's item and nobody
had measured it; (9) A VLA'S BOUNDS ARE EVALUATED ONCE, at the declaration (C 6.7.6.2/5), and kept in the type the
lowering holds for the local (`arr(vla(Reg), E)'), so `int v[n]; n = 10; sizeof(v)' is the size v was made with (it
re-read n), and A VLA OF A VLA is ONE allocation of the flattened element count, `int a[n][m]' n*m ints, whose row
`a[i]' lies i*m*4 bytes in (`ir_lval(index)` over `ir_vla_bytes`) -- `[0 x i32]' had been the row's type and every row
lay at a[0], a SEGFAULT; `test/c/run/vla_nested.c'; (10) `wchar_t a[] = L"hié"' is SIZED BY ITS INITIALIZER, one
element per code point (`ccl_utf8_count`; the body is UTF-8 bytes), and A LOCAL ARRAY INITIALIZED FROM A STRING IS
ZERO-FILLED PAST THE LITERAL (6.7.9/21: `char b[6] = "ab"' left b[5] as the stack had it -- older than the wide form,
found by its fixture), the wide one stored element by element (`ir_init_zero`, `ir_init_chars` with the element's LLVM
type); (11) `_Alignas(16) int x' ON AN OBJECT IS KEPT as the qualifier `aligned(E)' (the reader dropped it with the
attributes; C23's `alignas' and C++'s alike) and read by the alloca (`ir_alloca_typed`), the global (`ir_galign`) and the
layout (`ccl_size_align`: never below the natural alignment, the size rounded to it); `test/c/run/wstr_alignas.c';
(12) TRAILING WHITESPACE AFTER A LINE'S BACKSLASH STILL SPLICES ([lex.phases]/2 as clang reads it, with a warning;
`pp_ends_backslash` asks the last character first, since every line comes through it), and a `//' comment ending in a
backslash swallows the next line as C says; `test/c/run/splice.c'; (13) A COPY OF A NULL POINTER, OR OF A LOCAL WITH NO
OWNERSHIP STATE, IS NULL TO THE CHECK (`ck_plain_copy` in the declaration road and in `ck_kind`): `int *p = 0; int *q =
p;' had made q a FRESH value and refused it `not consumed' at the scope's end, in C and in C++ alike, older than every
step named here; `test/c/run/nullcopy.c'. IN C++: (14) THE DEFAULTED COMPARISONS COMPARE THE BASE SUB-OBJECT FIRST AND AN
ARRAY MEMBER ELEMENT BY ELEMENT ([class.compare.default]/6; `cpp_cmp_pieces`, the bases handed to `cpp_norm_members`
through `'$cpp_norm_bases'`; an empty base has no sub-object and nothing of its own to compare) --
`test/cpp/run/defaultcmp2.cpp' at C++20; (15) A CONST LVALUE NEVER BINDS A NON-CONST `T &' ([dcl.init.ref]/5, 0.91's other
half) in the template acceptance (`cpp_param_accepts`), AND `T &' GIVEN A CONST LVALUE DEDUCES T WITH ITS CONST
([temp.deduct.call]/2: the top-level qualifiers decay only for a by-value parameter; `cpp_deduce_one`) -- the second is
what made the first safe: `std::addressof(_Tp &)' over a `const int &' is `addressof<const int>', where `_Tp := int' had
made a `T &' that no const lvalue binds, and `std::vector::insert' and `basic_string::find_first_of' both refused
`argument_mismatch' on it -- AND THE PARTIAL ORDERING'S REFERENCE TIE-BREAK ([temp.deduct.partial]/9; `cpp_partial_cv_ok`):
where `T &' and `const T &' deduce each other, the less cv-qualified one is not at least as specialized, so `kind(const T &)'
beats `kind(T &)' for a const lvalue -- the gate found this one, since with the deduction both bound the const lvalue and
the tie fell to the first declared, which writes through it; a first writing that refused a `const T' pattern any non-const
type broke `kind(const T *)' over `kind(const T &)' (overloads.cpp): /7 strips the top-level qualifiers before the
comparison, and /9 is the only place they count -- and the gate found a second one: the reference rule's test for a NON-CONST
referent (`cpp_ref_lvalue_only`) read `int (*const &)(int)' as non-const, since it looked only at a base type's qualifiers, and
refused forward_as_tuple's argument inside std::function (stdfunction.cpp, stdfunctional.cpp); a const pointer referent is
const (`cpp_top_const`); `test/cpp/run/constref.cpp'; (16) A PLAIN ONE-MEMBER STRUCT BRACED, `S s = {7}', IS THE
AGGREGATE IT LOOKS LIKE (`cpp_plain_init`, `cpp_braced_scalar_type`: a braced SCALAR is its one item, never a struct,
a union, a class or an array; it had been `sext i32 7 to %struct.S'), and `int arr[9] = {}' VALUE-INITIALIZES the array
(`ir_init`'s scalar clause takes the resolver's FIRST answer: on backtracking `ccl_resolve_type` had answered the
element, and the array took `sext i32 0 to [9 x i32]'); `test/cpp/run/plaininit.cpp', `emptybrace.cpp'; (17) A POINTER TO
A DATA MEMBER IS ITS BYTE OFFSET (the Itanium ABI's representation; `cpp_member_address` over `cpp_offsetof`, `ir_type_`
i64, `ccl_size_align` 8) and `x.*pm', `p->*pm' AS VALUES read the object's bytes at the offset as the member's type
(`cpp_memptr_read`: `*(T *) ((char *) &x + pm)'), where 0.88 had refused both by name; `test/cpp/run/memptrdata.cpp';
(18) `std::invoke(&Pt::x, p)', `std::mem_fn(&Pt::y)(p)' and `std::bind(&Pt::plus, std::ref(p), 10)' run (0.88's list),
which asked one more rule: (19) A FUNCTION PARAMETER PACK IS LESS SPECIALIZED THAN A PARAMETER THAT IS NONE
([temp.deduct.partial]/8; `cpp_fn_more_special`, `cpp_has_pack_param`): `f(F &&, A0 &&)' beats `f(F &&, Args &&...)'
for two arguments, where the pack's overload had won libc++'s `__invoke' for a pointer to data member --
`test/cpp/run/packorder.cpp' (clang++'s `6 102 104 3'), `stdinvoke.cpp' at C++20; (20) `std::unique_ptr''s and
`shared_ptr''s comparisons, `owner_before' (0.86's list) ran as they stood -- `test/cpp/run/stdptrcmp.cpp'; (21) AN
OVERLOAD SET NAMED AS A VALUE IS CHOSEN BY ITS TARGET ([over.over]; `cpp_conv_to`'s clause on `id(F)' with
`cpp_fn_overloaded`, the target's parameter keys against each definition's): `int (*pi)(int) = twice' beside `double
twice(double)', and `apply_i(twice, 3)' (0.74's and 0.78's list); `test/cpp/run/overloadset.cpp'; (22) A CLASS WHOSE
SLOT'S IMPLEMENTATION IS THE PURE DECLARATION ITSELF IS ABSTRACT (`cpp_slot_pure`; 0.72's `cpp_not_abstract' never fired,
since `cpp_slot_impl' answered the pure declaration as an implementation, and `Shape x;' built an object and the link
named its slot) -- and A BASE SUB-OBJECT OF AN ABSTRACT CLASS IS STILL CONSTRUCTED by every derived class
([class.abstract]/6; `cpp_base_ctor` marks the base road, which the first writing did not and `make_shared' refused
`pure_virtual(__shared_weak_count)'); `test/cpp/abstract.cpp' refused by name in the gate's list; (23) A NULL POINTER STAYS
NULL WHEN IT CONVERTS TO A BASE AT AN OFFSET ([conv.ptr]/3; `ir_convert`'s class-pointer clause selects; 0.72's list);
`test/cpp/run/nullbase.cpp'; (24) C++20's `consteval' IS AN IMMEDIATE FUNCTION ([dcl.constexpr]/13): every call is folded
by the evaluator (`cpp_free_call`, `'$cpp_consteval'`) or refused `consteval_call_not_constant(F)', where it had run at
run time like constexpr since 0.42; and AN ARRAY BOUND FOLDS THROUGH THE EVALUATOR TOO (`cpp_array_bound` through
`cpp_const_value`: `int arr[sq(3)]' with sq the program's own constexpr function had been a VLA);
`test/cpp/run/consteval.cpp' at C++20; (25) `[*this]' CAPTURES THE OBJECT BY VALUE ([expr.prim.lambda.capture]/10:
the closure's `'$this'' member is the class itself, initialized `*this', reached through the same member as `[this]''s
reference; the reader's `cap(star_this)'), A PACK CAPTURED, `[xs...]', expands with the enclosing template's bindings
(`cap(pack, N)', `cpp_subst_caps`), a template's `auto' parameter constrained by a LIBRARY concept (`std::integral auto x')
ran as it stood (0.93's list), AND A LAMBDA IS DESUGARED ONCE (`cpp_lambda` remembers the closure by its text, its context
and the captured locals' types, `'$cpp_lambda_memo'`): an `auto' method's result was deduced from its first return
DESUGARED and the body walk desugared the same lambda again, two closure classes, and `return [*this]() { ... }' stored
the second into a slot of the first's type; `test/cpp/run/lambdas2.cpp' at C++20; (26) `std::hash<std::optional<int>>'
(0.84's list): A TRANSPARENT ALIAS TEMPLATE, `template <class _Type, class> using __enable_hash_helper_imp = _Type;', IS
ITS ARGUMENT to the pattern matcher, and an alias THROUGH one too (`cpp_alias_pattern`, `cpp_transparent_alias`): libc++'s
`hash<__enable_hash_helper<optional<_Tp>, ...>>' is `hash<optional<_Tp>>' as C++ has it, where the specialization matched
nothing and the primary's `__enum_hash' base was taken; `test/cpp/run/stdhashopt.cpp'; (27) A PACK NAMED INSIDE THE LAST
SEGMENT'S TEMPLATE ARGUMENTS of a scoped name is seen by the expansion (`cpp_names_outside`, `cpp_names_in`: `std::get<
_Idx>(__bound_args_)...'); (28) A MEMBER TEMPLATE DEFINED OUT OF CLASS MAY NAME ITS OWN PARAMETERS DIFFERENTLY from the
declaration ([temp.mem]; `cpp_align_tparams` renames the definition's to the declaration's, position for position):
libc++ 18 declares `template <class _Iterator> void __construct_at_end_with_size(_Iterator, size_type)' and defines it over
`_ForwardIterator', so the keys never met, the instance stayed a declaration and the link named it; (29) `std::erase_if' on
an `unordered_map' at C++20 runs (`test/cpp/run/stderaseif.cpp'; the map and the set had been ONE probe, killed at a 4 GB
cap after 836 s -- 0.79's rule on a fixture near a gigabyte a half, met again). (30) A COMPARISON THAT FAILS UNDER `\+' EXHAUSTS EVERY ALTERNATIVE OF WHAT CAME
BEFORE IT -- 0.95's exponential in the most-specialized ordering, from the other side: `cpp_fn_more_special`'s prefix
(the opaque bindings, the substitution, the parameter types) left choicepoints, the ordering asks `\+ more(H, Y)', and
`std::sort' over a vector's iterators -- a road the committed library could not take at all, `cannot_deduce(
_RandomAccessIterator)' -- spent 484 of its 570 s choosing among the FOUR holding candidates of libc++'s
`__uninitialized_allocator_copy_impl': 127,476 deductions for one choice (the CPU-time trace, `ms_deduce_begin' counted).
The prefix is `once', and the same build is 28 s with 929 deductions; five variants that switched off the other new
rules one at a time had each measured the same 570 s, which is how the guesses were retired before the instrument spoke.
THE LIBC++ GATE reads `<vector>',
`<string>' and `<iostream>' WHOLE AT C++20 too (0.84's list; `test/libcxx.pl'), beside the associative containers there --
and `<iostream>' at C++20 was the one RED of the first full chain, whose read pulls libc++'s `<format>' in, and it asked
for four rules, none of them `<format>''s own: (31) THE STANDARD MACROS ARE THE PROGRAM'S, NEVER A LIBRARY HEADER'S
(`ccl_lib_unit/1' around the flattened read in `ccl_read_unit', read by `ccl_unit' before it registers `format', `print',
`println' and `clone'; restored on success, failure and a throw): libc++'s `formatter<char, wchar_t>' writes `return
format(static_cast<wchar_t>(...), __ctx);', a call of ITS OWN two-argument `format', and the global macro fired on it and
refused `macro_failed(format, ...)' -- which the gate reported as `could not be read' and the census, reading the flattened
text as a USER file, reproduced in one line; the census reads a flattened header as the library's now, and takes the level
(`CCL_CENSUS_STD=20'). (32) A CLASS-SCOPE ALIAS IS A TYPE THROUGHOUT ITS CLASS'S BODY ([class.mem]/6, the rule 0.81 gave the
member templates and 0.86 the member class templates): the body's ahead scan notes `using N =', a member ALIAS template's
name after its `template <...>', and `typedef ... N;' (the name right before the `;', so a function pointer's, which ends
in `)', is left alone) -- libc++'s `basic_format_string' writes `_Context{__types_.data(), ...}' in its constructor and
`using _Context = ...;' under `private:' after it, and read in order the braced temporary of an unknown name stopped the
read 878 items in. `test/cpp/run/aliasahead.cpp' (an alias template, an alias and a typedef each used before they are
declared), clang++'s number, a syntax error without the rule. (33) THE FLATTENED TEXT SPELLS A LITERAL PAST 2^60 as its
digits (`pp_int_codes' at both spelling doors): `cicilang++ -E' wrote `big(0xff00000000000000)ul', which no reader takes --
the census's road only (0.93's item 36 once more), and what stopped the first census 103 items in. (34) A HEADER'S MACRO
TABLE IS PER LEVEL, in the process's memo (`ccl_hm_key': the path and the level, as `ccl_unit_key' keys the unit cache) and
in the store (`ccl_kb_remember_macros' replaces THIS LEVEL's rows and meta, where it retracted the whole predicate): found
by the reader gate's fresh store at 84 and the compile gate after it -- `atomic.c' at C17 memoized `<stdio.h>''s table as
`store(K17)', `c23.c' at C23 read the header again (a store miss at that level), stored the C23 rows and RETRACTED the
C17 ones, the memo kept naming K17, and `macros.c' at C17 met `undeclared(EOF)' -- a fixture that built alone in two
seconds, since the order is the gate's, and a fixture that then FAILED ALONE too, since the read with the unexpanded `EOF'
had been STORED as the file's AST (the AST cache does not see the macro table's state; a bad table poisons a cached read
until the store restarts). Both the reproduction in one process (`c23.c' then `macros.c') and the store's own rows said
so, where the gate's log and a standalone build each said something else.
Reader version 84 (83: `_Alignas' kept, the wide string sizing, `[*this]', `[xs...]', `_Atomic(T)'; 84: no global macro
inside a library header, a class-scope alias ahead); lowering version 44 (the VLA
bounds in the type, the atomics, the member offset, the null base, the wide array). A NAME IS LOOKED UP BEFORE IT IS GIVEN, at its
arity (0.93's rule, met again): the first spelling of the braced-scalar test was `cpp_scalar_type/1', which EXISTS -- and
answers yes to an array -- so `int arr[9] = {}' kept failing under a fix that read right; the audit of every new name's
definitions across the library is what found it.
NOT DONE, NAMED, each measured on this box: `std::vector::insert', `erase' and `resize' (0.62's list) build past (28)
and stop at `no_member(__construct_at_end, __split_buffer<int, allocator<int> &>)': libc++ 18's two `__construct_at_end'
member templates are both refused, the forward-iterator one because `__has_forward_iterator_category<move_iterator<int
*>>::value' comes out FALSE here (a trait chain through `move_iterator''s `_If<...>' iterator_category), the other
`cannot_deduce($anon2)' -- the road to it is named; `std::bind_front' and `std::not_fn' (0.88's list) stop where
`is_invocable_v<_Op, _BoundArgs &..., _Args...>' in `__perfect_forward_impl''s `operator()' default template argument does
not fold (`variable_template_not_constant': the static behind it, `integral_constant<bool, __invokable_r<...>::value>::
value', is keyed by an unfolded static, 0.98's named collision) -- `std::identity' ran; `basic_string::find_first_of'
(0.84's list) stops at `cannot_deduce(_BinaryPredicate)': libc++ hands the STATIC MEMBER FUNCTION `_Traits::eq' as a
predicate, and a static method here takes a null `this' (0.36), so its address is no plain `bool (*)(char, char)' --
a static method without `this' is a change to every static call site and a step of its own; `std::erase_if' on an
`unordered_set' at C++20 stops at `call(id(iter_move))', C++20's `ranges::iter_move' customization point;
`std::enable_shared_from_this': `shared_from_this()' builds now (it refused `pure_virtual' before (22)'s base rule) and ABORTS
at run time -- the object's `__weak_this_' is never set, so libc++'s `__enable_weak_this' detection (a conversion to
`enable_shared_from_this<_Yp> *' in a SFINAE default) is what does not fire here; `std::atomic<T>'
IN C++: libc++ 18 configures its `<atomic>' by `__has_extension(c_atomic)', which this preprocessor answers 0 (the plainest
path), so the header defines neither implementation (`template_without_body(__cxx_atomic_base_impl)'); answering 1 for
that one extension would put libc++ on the `_Atomic(T)' and `__c11_atomic_*' road this step built for C, and is the next
step, measured against every stream and container fixture first; `_Complex', `\N{...}', `std::strong_ordering' as a class,
coroutines, modules, `sizeof' a pointer to member function 8 against the ABI's 16, an unqualified use of a colliding name
from inside the deeper namespace (0.88), the closure escaping its scope (0.59), `std::format' and the ranges.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module rebuilt
as 0.99), one after another in one chain with nothing beside them, each under its own 7000 MB watchdog, the summaries
warmed OUTSIDE them first at all four levels (`test/warm.sh': 43 headers cold at reader 84, 8732 s, none killed; the
chain's first run was cut short by a container restart during that warm and the chain ran again whole): the reader's 95
checks GREEN in 7 s at 107 MB; the compile gate's 84 (0.98's 78 and this step's six C fixtures) in 6 s at 248 MB; the
driver's 25 in 9 s at 148 MB; the objects' 29; the proof; THE C++ GATE GREEN -- 211 checks ok (0.98's 194 and this
step's seventeen), `stdoptionalref' skipped by name, NO failure -- in 4499 s at a 3779 MB peak (0.98: 6179 s for 194,
and the 1680 s fewer are 0.99's rule 30, the `once' on the most-specialized ordering's prefix, on every fixture that
sorts or copies through libc++'s uninitialized-memory algorithms); THE LIBC++ GATE GREEN, its 21 reads whole under a
fresh HOME in 8422 s at 3835 MB: the eleven C++17 headers and the three C++23/26 reads at 0.98's item counts (`<vector>'
806 ... `<optional>' 397 at C++26), and at C++20 `<vector>' 898, `<string>' 846, `<iostream>' 884 (the three new reads,
which are the 2900 s more than 0.98's 5518), `<set>' 859, `<map>' 859, `<unordered_map>' 843, `<unordered_set>' 925.

## 0.100 — M6's sixty-seventh step

**M6's sixty-seventh step (0.100): THE REPOSITORY IS `cicilang`.** The owner renamed the repository
from `cicili-lang' to `cicilang', and this step carries the name through every file. WHAT IS RENAMED, the
compiler's own names: the repository and the language's C name in prose, `cicilang'; the commands,
`bin/cicilang' and `bin/cicilang++' (no `cicili' command remains); the module, `module/cicilang.cicili'
built to `library/cicilang.so', loaded as `library(cicilang)'; the four surface predicates,
`cicilang_ast/2,3', `cicilang_ir/2', `cicilang_compile/3', `cicilang_link/3'; the command's variables,
`CICILANG_KB', `CICILANG_INCLUDE', `CICILANG_LANG', `CICILANG_ME'; the freestanding headers' guards,
`_CICILANG_*_H'; the user's cache, `~/.cicilang' (`KB' and `cpp' under it; an existing `~/.cicili' is
moved, not rebuilt: a summary is keyed by the header's path and the reader's version, never by the
cache's own directory, so every summary and the store stay valid); the run's answer lines, `cicilang: ok'
and `cicilang: N error(s)', which `bin/cicilang' filters and the gates read; the benchmark's B-tree,
`bench/btree/btree_cicilang.c'; the fixtures' strings and the proof's message (`proof/forty2.ll': three
bytes shorter, so its array is `[19 x i8]' -- the proof gate said so first, the one RED of the rename).
WHAT KEEPS ITS NAME, the neighbour's: Cicili the language and the philosophy, `$CICILI' its checkout,
`cicili.lisp' its transpiler, `sdk.cicili' cocolog's SDK, the `.cicili' extension of the native pieces --
and the `ccl_' prefix of every predicate the library defines, which is the library's own convention and
collides with nothing; the naming rule reads `only the four cicilang_ doors keep the compiler's name'.
A string literal a fixture prints or hashes (`fmt.c', `stdfunctional.cpp') is data and stays.
THE README IS REWRITTEN: what cicilang is, its features, the commands, the four predicates, the
additions, the safe part, the macros, the C++ levels and the library, the layout and the rules; the
version log that had grown to 1800 lines is out of it (this file is the record). `DESIGN.md''s status
line, stuck at M2 since 0.11, says where the milestones stand.
AND THE NOT-DONE LISTS, TAKEN UP AGAIN in the same step (the owner asked for them all, and for no gate
until the work was done): `std::atomic<T>' in C++, `enable_shared_from_this', `find_first_of' and kin,
`std::erase_if' over an unordered container, `bind_front' and `not_fn', the escaping closure, two namespaces
of one name, the ABI's pointer to member function, and C's complex types. Each was cut to a reduction of
ten to twenty lines on the program's own classes that failed in a second before it was fixed, and each has
a fixture; the rules, named:
(1) `__has_extension(c_atomic)' IS 1, the one extension answered, so libc++ 18 configures its `<atomic>' on
the `_Atomic(T)' and `__c11_atomic_*' road 0.99 built for C (`_LIBCPP_HAS_C_ATOMIC_IMP'); with it, three
older defects: AN ENUMERATOR IS AN INT to the inference (the parser declares one in scope, the bulk noter
keeps only its value, and after the passes' rebuild `o == release ? relaxed : o' typed its arm unknown --
libc++'s `__to_failure_order'); a class with a WRITTEN constructor takes `{12}' as that constructor's
arguments and never as an aggregate's items (`cpp_aggregate_class' guards the braced-aggregate clause of
`cpp_decl_pieces'); and a constructor initializer naming a TEMPLATE PARAMETER, `_Base(__value)', is
substituted like a base clause (`cpp_subst' on `init(P, As)'), where it was dropped silently -- a member
initializer that names nothing the class has REFUSES now (`cpp_inits_known', `unknown_initializer'). And a
STATIC MEMBER FUNCTION NAMED AS A VALUE is a plain function: a static method takes a null `this' here (0.36),
so its address is no `bool (*)(char, char)'; a THUNK (`<Name>.fn', `cpp_static_thunk') without the `this'
parameter is emitted where the name is taken, which is how libc++'s `find_first_of' hands `_Traits::eq' to
its search. `test/cpp/run/stdatomic.cpp', `staticfn.cpp', `stdstringfind.cpp'.
(2) `shared_from_this': A POINTER TO A DERIVED CLASS CONVERTS TO A POINTER TO ITS BASE in the convertibility
the traits ask ([conv.ptr]/3; `cpp_pointer_to_base' in `cpp_convertible': `is_convertible<Node *, const
enable_shared_from_this<Node> *>' answered 0, so `__enable_weak_this''s SFINAE never chose the template and
the `(...)' fallback won, `bad_weak_ptr' at run time), and THE PROGRAM'S OWN `f(...)' KEEPS ITS ELLIPSIS in its
origin (`own(V)'), where `own' alone let no call fall to it after the templates rightly refused.
`test/cpp/run/stdsharedfromthis.cpp'.
(3) THE ESCAPING CLOSURE (0.59's hole): the desugaring makes a lambda a compound literal of its captures, so
A CLOSURE BORROWS WHAT ITS CAPTURES BORROW (`ck_borrows_from' on `compound_lit'), and the two places that make
a value a borrow -- a declaration's initializer and a return -- ask a closure-aware test beside
`ck_carries_type' (`ck_borrowing_type': a `ref' member is bound once and read through, and counting it as
carrying refused every closure's construction as a borrow stored); `return f' of a closure holding `&x' of a
local is `borrow_escapes' where a dangling reference compiled and ran; a `[this]' closure is a borrow of the
parameter and may go; a by-value capture borrows nothing. FOUND WITH IT, three older ones: A LAMBDA'S RETURN
IS THE LAMBDA'S (`cpp_first_return' walked into the lambda's body and took its `return x + k' for the
enclosing function's first return, `k' undeclared there: `lambda_result_type'); A FUNCTION WITH AN `auto'
RESULT IS DECLARED UNDER THE DEDUCED TYPE once its item is walked ([dcl.spec.auto]: defined before its type
is used), where the table kept the raw `auto' and `auto f = make(3)' asked the initializer's type again
WITHOUT END (1.5 GB in 15 s); and 0.99's null-copy rule is for POINTER locals only (`int x = n' had made x an
owner in the null state). `test/cpp/run/closurescope.cpp'; `test/cpp/escape.cpp' refused, in the gate's
list of refusals as a check's (`test/cpp.sh').
(4) TWO NAMESPACES OF ONE NAME, in the program's own units (0.88's rule was a header's): the outermost keeps
the bare name, a deeper namespace's item is renamed `<innermost named namespace>.<name>' before anything is
registered (`cpp_ns_resolve', the units rewritten and the table built again from them), its bare uses inside
that namespace go to the key (`cpp_qualify_body', `cpp_rename_names' -- unless the item declares a parameter,
a local, a member, a METHOD or a capture of the name, which shadows it: vector's own `begin()' beside
`std::begin'), a qualified use resolves to it wherever a name is read (`cpp_ns_key' through `'$cpp_ns_own''),
a defined function and a namespace-scope object are renamed as a class is (a declared-only function keeps its
name, the shipped library's symbol). THE SAME BODY REWRITE REACHES A HEADER'S DEEPER NAMESPACE (0.88's
not-done). AN INLINE NAMESPACE IS MARKED by the reader (`namespace(L, inline(N), Items)'): its name stays in
the mangler's path (`std::__1' is `St3__1', `cpp_hdr_ns' unwraps) and is skipped where the innermost NAMED
namespace keys a name (`cpp_ns_named'), and TWO PATHS ARE ONE NAMESPACE BY THEIR NAMED SEGMENTS
(`cpp_ns_named_path': libc++ declares `begin' in `namespace std' and in `namespace std { inline namespace
__1', which is one namespace and was two). AND A NAMESPACE-SCOPE OBJECT CALLED goes to its class's
`operator()' (`cpp_callable_global', `cpp_object_call'), qualified or bare: libc++'s customization point
objects, `ranges::iter_move(x)' with `inline constexpr auto iter_move = __iter_move::__fn{}' in
`std::ranges::inline __cpo', beside the hidden friends of the same bare name. `test/cpp/run/nscollide.cpp';
`stderaseifuset.cpp' at C++20 (see below).
(5) `bind_front': A METHOD'S QUALIFIERS ARE SUBSTITUTED TOO (`cpp_subst_quals'): a trailing return type,
`-> decltype(Op()(std::get<Idx>(bound_)..., std::forward<Args>(args)...))', sits among them, and passed
through unchanged it kept the class's pack `Idx' unsubstituted (`type_pack_index(id(_Idx))'); A TRAILING RETURN
TYPE NAMES THE PARAMETERS AND `this' ([dcl.fct]/2), which are declared, substituted, while it is resolved --
in the candidate check (`cpp_result_holds' with the parameters; a `decltype' result is part of the SFINAE, as
a template-id result has been since 0.79) and where the member is emitted (`cpp_method_ret'). `bindfront.cpp'
at C++20 (see below).
(6) A POINTER TO MEMBER FUNCTION IS THE ITANIUM ABI'S `{ ptr, adj }', sixteen bytes (0.88's and 0.89's
not-done): the function's address, or `1 + the slot's byte offset' in the table for a VIRTUAL member, and the
this adjustment, 0 here (a base's address is made by the conversion at the call). The type is `{ ptr, i64 }'
in the lowering, its two fields `pm.ptr' and `pm.adj' (`ccl_members_of', `ir_member_slot'), two INTEGER
eightbytes across a call, a cast into it builds the aggregate (`ir_expr(cast)', `ir_gconst'), and the call
`(obj.*pm)(args)' (`cpp_memptr_call') tests the bit: an odd `ptr' indexes the OBJECT'S OWN table, read
through the object's address AS THE MEMBER'S CLASS (a derived object's table pointer sits in that base
sub-object), so `&Shape::area' on a base pointer to a `Square' dispatches; an even one is the function. A
pointer to member and a pointer to a FUNCTION are code, never memory the check follows (`ck_carries_',
`ck_is_pointer_type': `int (*f)(int) = c ? a : b' was a loose pointer). `test/cpp/run/memfnptr.cpp' (sizeof
16, the two forms, a virtual member through a base pointer, passed and returned by value), clang++'s numbers.
(7) C'S COMPLEX TYPES (C11 6.2.5, Annex G; the last not-lowered type of M2's list): `_Complex double' and
`_Complex float' are two components (`{ double, double }', `{ float, float }'; sized and aligned as the
component, two SSE eightbytes across a call, so glibc's `creal', `cabs' and `conj' take and return them as
clang's calls do), the usual arithmetic conversions make a complex of the common real type where either
operand is complex (`ccl_complex_usual'), `+ - * /' are Annex G's formulas without the special cases
(`ir_complex_op'; the division is the textbook one, not `__divdc3''s), `== !=' compare both components, the
negation both, a real converts to a complex with a zero imaginary part and a complex to a real by its real
part (`ir_complex_convert'), GNU's `__real__ z' and `__imag__ z' are read (`real_part', `imag_part') and
C11's `CMPLX' and `I' come from THE COMPILER'S OWN `<complex.h>' (`library/include/complex.h': the C
library's declarations first, then the two over `__builtin_complex', since glibc spells them with the
imaginary literal `1.0iF', a GNU extension this compiler does not read -- and defines `CMPLX' for GCC only,
so the fixture defines its own for clang). AND THE MATH LIBRARY IS NAMED AT THE LINK ON LINUX (`-lm',
`ccl_link_libs'): glibc keeps `sqrt', `creal' and `cabs' apart from libc. `test/c/run/complex.c', clang's
numbers.
AND WHAT THE FIXTURES FOUND WHEN THEY RAN AGAIN, seven more, each cut to a file that failed in a second:
(8) A DELEGATING CONSTRUCTOR'S NAME ARRIVES AS THE INSTANCE'S: rule (1) substitutes a constructor initializer's
name where it is a bound parameter, and the INJECTED CLASS NAME is bound to the instance (0.44's `Self'), so
libc++'s `__value_func(_Fp &&__f) : __value_func(std::forward<_Fp>(__f), allocator<_Fp>())' arrived as
`init('__value_func.fn_int_int', ...)' -- `cpp_own_name' knew the template's name only, the initializer fell
to `a class named as a base' (cpp_init_known) and was DROPPED: every `std::function' was constructed EMPTY
and `bad_function_call' aborted the run (stdbind, and every std::function fixture). The instance's own name
is its own name. (9) INHERITING CONSTRUCTORS THROUGH AN ALIAS TEMPLATE'S NAME: `using __perfect_forward<
__bind_front_op, _Fn, _Args...>::__perfect_forward;' names the base by the ALIAS it was written as, not the
class `__perfect_forward_impl' it is (`cpp_tmpl_head' of the base clause), and unrecognized the
`__bind_front_t' had no constructors and its three arguments fell to an aggregate initializer of one member.
(10) A FUNCTION BOUND TO A REFERENCE TO A POINTER CONVERTS FIRST ([conv.func]) and the reference binds the
TEMPORARY pointer ([dcl.init.ref]/5; `ir_ref_to'): the function's address IS the value a reference to a
function carries, and handed on as the pointer's address libc++'s `__tuple_leaf(_Tp &&)' over `int (*const
&)(int, int, int)' loaded the CODE of `add3' as the pointer -- `std::bind_front' jumped into its callee's
bytes (0xF8247489FC247C89, add3's prologue read as an address). Lowering version 46. `test/cpp/run/fnrefptr.cpp'.
(11) A SCOPED NAME THAT IS A TYPE OF ITS CLASS IS A TYPE ARGUMENT in an EXPRESSION too (`cpp_targ_value' on
`scoped(Path, N)'): `is_same<iterator_traits<int *>::iterator_category, random_access_iterator_tag>::value'
is read as a value (the reader cannot know the member is a type), walked as an expression it became the
static member's name `id('iterator_traits.int_p.iterator_category')', and keyed so `is_same' compared two
spellings and answered 0 -- which is how libc++ 18's `move_iterator::iterator_category', an `_If' over that
trait, came out wrong for `vector::insert'. `test/cpp/run/scopedtarg.cpp' (the same probe printed
`1 0 1 1 1 0' against clang++'s `1 1 1 1 1 1' before, one number per link of the chain). (12) A MEMBER TEMPLATE'S
DEFINITION IS PAIRED WITH THE DECLARATION WHOSE TEMPLATE PARAMETERS AGREE ([temp.mem]; `cpp_mdef_match' in
two passes, `agree' then `any'): two member templates of one name and one parameter list, told apart by a
SFINAE default alone -- libc++ 18's `__split_buffer::__construct_at_end' twice and `vector::insert(
const_iterator, _It, _It)' twice -- KEY alike, and the first definition found served BOTH declarations: the
second's kinds matched no default and refused `cannot_deduce($anon2)', so `vector::insert' had no
`__construct_at_end' at all. The kinds are compared IN THE CLASS'S WORDS (`cpp_tparams_alike' over the member
list's own typedefs, `cpp_mdef_types', since the merge runs before the instance is registered): libc++ writes
the declaration's guard over `value_type' and the definition's over `_Tp', one type under two spellings. AND THE
DEFAULTS COME FROM THE DECLARATION wherever the two lists are of one SHAPE, kind for kind
(`cpp_keep_tdefaults'), which is C++'s rule ([temp.param]/12: a default on the declaration alone) -- lent
only on structural equality, `value_type' against `_Tp' lent nothing. `test/cpp/run/sfinaedefs.cpp' (the two
shapes, a bare call inside a method too), `stdvectorinsert.cpp' (0.62's not-done: the range insert through
`__construct_at_end', the initializer-list insert, `erase' of one and of a range, `resize' up and down, a fill
insert -- `4 4 2 3 | 4', clang++'s). (13) THE SUMMARY IS WRITTEN LAST, AND WHOLE (`ccl_read_unit',
`ccl_write_whole': through a temporary name and a rename): a run the watchdog killed while it wrote the AST
beside the summary -- the slow one, written second -- left a valid `.sum' beside no `.ast.pl', and every
program over `<set>' then refused `template_without_body(set)' until the cache was wiped by hand
(stdfunctional, 641 s cold). The summary is the validity key, so it is the last file a run writes, and a
truncated one never reads as valid. (14) AND A REFUSAL A TRACE NEVER SHOWED: `cpp_bind_targs_' fell to the RAW
argument silently where `cpp_targ_value' failed; it says `targ_raw(P, A)' under the trace now.
Reader version 86 (85: `__has_extension(c_atomic)'; 86: the inline namespace's mark, the deeper namespace's
bare uses rewritten in the AST beside the summary), lowering version 46 (the member pointer, the complex
types, the function-to-pointer bind); the module rebuilt as 0.100.
NOT DONE, NAMED: `std::strong_ordering' as `<compare>''s class (a scalar `<=>' and a defaulted one are an
`int'); the imaginary literal `1.0i' (C11's `I' and `CMPLX' come from the compiler's own `<complex.h>'), the
complex division as the textbook formula (Annex G's special cases, `__divdc3', are not modelled) and `__real__'
as an lvalue; `_Complex long double'; a pointer to member function's `adj' is always 0 (a base at an offset is
adjusted at the call by the conversion, never in the pointer), and a pointer to a VIRTUAL member of a class
with several polymorphic bases would need the adjustment; the closure the safe part follows is the one made
where it is declared -- a closure held in a `std::function' is the library's discipline (0.45); `[*this]'
copies the object by the implicit copy, a class with a destructor refused as ever; an unqualified use of a
colliding name from inside the deeper namespace resolves by the rewrite of the item's BODY, so a use inside a
default argument or a base clause is not rewritten; `stderaseifuset.cpp' (C++20, the customization point
objects through `ranges::iter_move') builds in about 750 s at 3.8 GB and stays one fixture; `\N{...}',
coroutines, modules, `consteval' at compile time, `std::format' and the ranges as before.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module rebuilt
as 0.100), one after another in one chain with nothing beside them, each under its own 7000 MB watchdog, the summaries
warmed OUTSIDE them first at all four levels (`test/warm.sh': 44 headers cold at reader 86, 9282 s, none killed): the
reader's 95 checks GREEN in 13 s at 107 MB; the compile gate's 85 (0.99's 84 and `complex.c') in 14 s at 332 MB; the
driver's 25 in 9 s at 137 MB; the objects' 29; the proof; THE C++ GATE GREEN -- 225 checks ok (0.99's 211 and this
step's fourteen: stdatomic, staticfn, stdstringfind, stdsharedfromthis, closurescope, nscollide, stdbindfront,
stderaseifuset, memfnptr, fnrefptr, scopedtarg, sfinaedefs, stdvectorinsert, and `escape.cpp' refused by name),
`stdoptionalref' skipped by name, NO failure -- in 5284 s at a 3791 MB peak (0.99: 4499 s for 211: the two C++20
fixtures over `<functional>' and the unordered containers are most of the difference, `stderaseifuset' alone about
750 s); THE LIBC++ GATE GREEN, its 21 reads whole under a fresh HOME in 8524 s at 3810 MB, every item count 0.99's
(`<vector>' 806 ... `<optional>' 397 at C++26, `<vector>' 898 at C++20): the reader's version moved for the index
and the marks, not for what an item is.

## 0.101 — M6's sixty-eighth step

**M6's sixty-eighth step (0.101): THE NOT-DONE LIST OF 0.100, closed where a form can be closed.** The
owner asked for the not-done works, and this step is 0.100's list taken item by item, each cut to a
reproduction of a dozen lines before it was fixed and each gated.
(1) `<compare>''S ORDERING CLASSES ARE libc++'S OWN ([cmp.categories]; 0.42's scalar `<=>' was an int and a
defaulted one an int). A scalar `<=>' answers `std::strong_ordering' for integers and pointers and
`std::partial_ordering' for floating operands (`cpp_scalar_ordering': the class's one `signed char' holding
-1, 0, 1 and -127 for unordered, built as the aggregate its private constructor would build, `cpp_ordering_value'),
a defaulted `<=>' the class written or the common category of its members (`cpp_defaulted_ordering'; its
pieces compared as `>' minus `<', so a member of a class with its own `<=>' answers the class and the
rewritten candidates take it), and the six comparisons with the literal 0 -- `o < 0', `o == 0', `std::is_lt(o)'
-- go to the HIDDEN FRIENDS the header writes over `_CmpUnspecifiedParam'. Four things they asked: A POINTER TO
MEMBER TAKES A NULL POINTER CONSTANT ([conv.mem]/1; `cpp_pointerish' knows `memptr', so the literal 0 fits
`_CmpUnspecifiedParam(int _CmpUnspecifiedParam::*)' and converts through it); A DEFAULTED FRIEND `operator=='
COMPARES THE DATA MEMBERS ([class.compare.default]; `cpp_friend_item' over the class's members, where
`friend constexpr bool operator==(strong_ordering, strong_ordering) noexcept = default;' would have been emitted
as the word `default'); A REWRITTEN COMPARISON WHOSE `<=>' ANSWERS A CLASS goes through the class's operator
(`cpp_rewritten_cmp': `(a <=> b) < 0' is the friend over the literal); and A STATIC DATA MEMBER DEFINED OUT OF ITS
CLASS IN A HEADER is the class's own definition (`inline constexpr strong_ordering strong_ordering::less(
_OrdResult::__less);': indexed under the class, `cpp_index_name'; noted with its initializer at the class's
registration; emitted `linkonce' with the value its constexpr constructor gives at compile time,
`cpp_static_constructed' over 0.99's `cpp_fold_ctor_init'; skipped as an item at the lazy load), where it had
been named by an Itanium symbol nothing ships. A program that writes `<=>' without `<compare>' keeps the int (C++
calls it ill-formed; the older fixtures print that int). Reader version 87 (the index changed). Gated by
`test/cpp/run/stdcompare.cpp' at C++20 (`strong_ordering', `partial_ordering' with an unordered NaN, a defaulted
`<=>' over ints, over a double and over a member with its own, `std::is_lt' and kin, the static constants, two
pointers) and `<compare>' read WHOLE at C++20 in the libc++ gate (348 items). Not done: `std::strong_ordering'
as the result of a defaulted `<=>' whose members include a NaN double (the lexicographic int has no unordered;
`partial_ordering::unordered' comes only from a scalar `<=>'), `std::compare_three_way', `std::common_comparison_category'.
(2) THE IMAGINARY LITERAL, GNU's (clang's and gcc's), in BOTH LEXERS: `2.0i', `1.5if', `3i', `1.0fi', `1.0li',
`0x10i', `j' for `i' -- `tok(imag, F, L)' a `_Complex double' constant, `tok(imagf, F, L)' a `_Complex float' one
(`ccl_float_suffix//1', `ccl_int_tok//4', `ccl_imag_mark//0' in the DCG; `ccl_lx_imag_c', `x->imag' in the
module), the value the float imaginary part (an integer's, `3i', is 3.0 here where clang has a `_Complex int',
which nothing here lowers); the parser's `imag(F)' and `imagf(F)', typed, checked, lowered as the constant
{ 0, F } and folded into a global's initializer (`1.0 + 2.0i', `1.0 - 2.0i'); k84 compares the two lexers on
the new line of `test/c/lexer.c'; the flattened text spells them back (`ccl_pp_spell_tok', `pp_spell').
(3) ANNEX G's MULTIPLICATION AND DIVISION ARE THE C RUNTIME'S OWN: `__muldc3' and `__divdc3' (`__mulsc3',
`__divsc3' for a complex float), which recover the infinities the textbook formulas turn into NaNs and which
clang calls at every `*' and `/' of two complex values -- libgcc's and compiler-rt's alike, linked by cc
(`ir_complex_rt': a complex double comes back as two SSE eightbytes, `{ double, double }', a complex float as
one, `<2 x float>'); `(1 + 1i) / 0' is two infinities and `(inf + 1i) * 2' keeps its infinity, as C has them.
(4) `__real__ z' AND `__imag__ z' ARE PLACES (`ir_lval', the component's own address inside the complex's slot:
`__real__ z = 5.0', `__imag__ z += 1.0'), and the two words are GNU words to the reader's typedef heuristic --
`__real__ z = 5.0;' at a block's start had read as a declaration of `z' with the type `__real__'.
(5) `_Complex long double' IS A COMPLEX DOUBLE here, as `long double' is a double: its arithmetic and its
components run; glibc's `creall' and `cimagl' take the x87 pair and cannot be called on it, named.
(6) THE FLOATING CONSTANTS' AND CLASSIFICATION BUILTINS, which glibc's `<math.h>' writes its macros on under a
clang-shaped compiler (0.87's hazard once more, `__has_builtin' answering 1): `INFINITY' is `__builtin_inff()',
`NAN' `__builtin_nanf("")', `HUGE_VAL' `__builtin_huge_val()' -- the constants (`ir_float_builtin') -- and
`isnan', `isinf', `isfinite', `isnormal', `signbit' are `__builtin_isnan' and kin, `fcmp' over the value
(`ir_fp_class'; `isinf_sign' the signed answer); every one was `undeclared' before, so a C program that tests a
NaN did not compile. Lowering version 47. Gated by `test/c/run/complex2.c', clang's numbers.
(7) A CLOSURE'S CAPTURE OF CLASS TYPE IS CONSTRUCTED BY COPY AND DESTROYED WITH THE CLOSURE
([expr.prim.lambda.capture]/10, 0.36's not-done, a lambda's destructor): a by-value capture whose class has
constructors -- a `std::string', a class with a destructor, the object itself under `[*this]' -- is copied
through its copy constructor, so the closure is built MEMBER BY MEMBER as an aggregate whose member constructs
is (`cpp_closure_value' over `cpp_aggregate_inits', 0.83's temporary road: the temporary registered with the
statement, or ELIDED into the local it initializes, `cpp_temp_elide' on the plain road too), a reference
capture BOUND to its object (`cpp_member_from''s `ref' clause, 0.61's rule for an aggregate's member); the
closure's implicit destructor destroys the member (0.41's rule, which the closure class already had) -- bitwise,
`[t]' of a class with a destructor held a copy no constructor made and destroyed it once more than it was made
(`1 2' for clang's `2 2'). And a GENERATED body's `this->$this' is the closure's own member, never the enclosing
object's (`cpp_expr''s first clause: the implicit destructor of a `[*this]' closure walked `arrow(this, '$this')'
into `(&this->$this)->$this'). FOUND ON THE WAY, older: a declaration of SEVERAL declarators defining a class's
members out of class, `int Tag::made = 0, Tag::gone = 0;', is one item per declarator (`cpp_item'; the raw item
had reached the lowering, `member_of_class'). Gated by `test/cpp/run/closurecopy.cpp' (a string captured, a
class with a destructor counted, `[*this]' of a class with a destructor inside a const method), clang++'s
numbers, valgrind clean.
(8) A COLLIDING NAME IN A BASE CLAUSE OF THE DEEPER NAMESPACE IS REWRITTEN (`cpp_rename_names' on
`base(Access, Name)' and `virtual(Name)'): `struct D : Base' inside the inner namespace took the outer `Base';
a default argument was rewritten already, and `test/cpp/run/nscollide2.cpp' has both.
AND A LESSON, cheap: `cpp_lambda_''s HEAD still spelled the closure as `compound_lit(T, init(Items))', so the
member-by-member value its body now built was unified away and the trace showed a temporary registered beside a
bitwise closure -- a clause's head is part of its answer, and a body that computes a new result must reach it.
NOT DONE, NAMED: a pointer to member function's `adj' is always 0 (a base at an offset is adjusted at the call by
the conversion, never in the pointer); the closure the safe part follows is the one made where it is declared --
a closure held in a `std::function' is the library's discipline (0.45); `stderaseifuset.cpp' (C++20) builds in
about 750 s at 3.8 GB and stays one fixture; `_Complex int'; `\N{...}', coroutines, modules, `std::format' and
the ranges as before.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module rebuilt
as 0.101), one after another in one chain with nothing beside them, each under its own 7000 MB watchdog, the summaries
warmed OUTSIDE them first at all four levels (`test/warm.sh': 44 headers cold at reader 87, 10155 s, none killed): the
reader's 95 checks GREEN in 15 s at 109 MB; the compile gate's 86 (0.100's 85 and `complex2.c') in 21 s at 366 MB; the
driver's 25 in 10 s at 85 MB; the objects' 29; the proof; THE C++ GATE GREEN -- 228 checks ok (0.100's 225 and this
step's three: stdcompare at C++20, closurecopy, nscollide2), `stdoptionalref' skipped by name, NO failure -- in 5935 s at
a 3804 MB peak (0.100: 5284 s for 225). THE LIBC++ GATE GREEN, its 22 reads whole under a fresh HOME
(0.100's 21 and `<compare>' at C++20, 348 items) in 8957 s at a 3879 MB peak, every other item count 0.100's (`<vector>'
806 ... `<optional>' 397 at C++26, `<vector>' 898 at C++20; 0.100: 21 reads in 8524 s, the one read more being the
difference) -- run ALONE and a second time: the container restarted 1212 s into its first run, which wrote nothing (the
gate writes its log at its end), and 0.101 was committed with the gate still running, its numbers carried by 0.102, as
0.93's were.

## 0.103 — M6's sixty-ninth step

**M6's sixty-ninth step (0.103): THE NOT-DONE LIST OF 0.101, closed where a form can be closed -- `_Complex int',
a NaN member under a defaulted `<=>', `\N{NAME}', and two probes named.**
(1) `_Complex int', GNU's INTEGER COMPLEX, which clang and gcc both take. THE INTEGER IMAGINARY LITERAL `3i' is its own
token in BOTH lexers, `tok(imagi, N, L)' (`ccl_int_tok', `ccl_lx_emit_int'; k84 compares them on `test/c/lexer.c''s
line), the parser's `imagi(N)', a `_Complex int' constant `{ 0, N }' -- 0.101 had made it the float 3.0 and a complex
double; its `u' and `l' suffixes are DROPPED, so `2ui' and `3li' are `_Complex int' here where clang has `_Complex
unsigned' and `_Complex long' (named). THE REAL TYPE OF A COMPLEX IS WHATEVER STANDS BESIDE `_Complex'
(`ccl_complex_real' through `ccl_specs_without'; `_Complex' alone a complex double), and the usual arithmetic
conversions over two complex integers are the integers' own (`ccl_complex_usual' through `ccl_usual': `3i + 2' a
`_Complex int', `7u + 3i' a `_Complex unsigned', `5l + 6li' a `_Complex long'); a complex integer is NO integer to
`ccl_is_integer', as a complex double has been no float since 0.100. THE LOWERING: `{ i32, i32 }' by the real's LLVM
type (`ir_base', `ir_complex_elem' over i8 to i64 beside float and double), `+' and `-' by `add' and `sub', `*' and `/'
by the TEXTBOOK FORMULAS as clang lowers them for an integer complex -- no runtime helper, no infinities to recover:
(ac - bd) + (ad + bc)i, and the quotient's (ac + bd) / (cc + dd) and (bc - ad) / (cc + dd), each an integer division of
the real's signedness (`ir_complex_op' takes the real type, `sdiv' or `udiv') -- `==' by `icmp eq', the negation by
subtraction, the ABI's leaves two INTEGER leaves of the real's size (`ir_leaves' recursing on the real, where the
floating ones were spelled out), a global's constant's components spelled as integers (`ir_complex_text'; a floating
constant truncates as the conversion does), the conversions through `ir_complex_convert' as before -- which decides BY
THE C TYPES now (`ccl_is_complex(From)', `ccl_is_complex(To)'): the LLVM-shape test would have taken an ABI piece
`{ i64, i64 }' (`ir_pieces_type') for a complex once the integer shapes joined the table. `test/c/run/complex3.c',
clang's numbers.
(2) A NaN MEMBER UNDER A DEFAULTED `<=>' IS UNORDERED ([class.spaceship]/2: the member's own `<=>', a partial_ordering
for a floating type; 0.101's not-done): a floating piece's sign is `a == a && b == b ? sign : -127' where the result is
partial_ordering (`cpp_cmp_sign', the scalar `<=>''s own test since 0.101), and the pieces carry the member's TYPE now
(`pc(A, B, T)' from `cpp_cmp_pieces', read alike by the defaulted `==', the friend `==' of <compare> and the category
choice, `cpp_defaulted_ordering' over the pieces -- so an ARRAY of doubles makes the category partial too, where the
member's own type was asked and an array is no float). `test/cpp/run/stdcompare.cpp' extended (a NaN member under
`auto', and under a written `std::partial_ordering'), clang++'s lines. AND A LESSON, cheap once seen and an afternoon
before: the first writing named the piece's type `PT' inside the findall -- THE VARIABLE THE CLAUSE'S HEAD ALREADY USED
for the parameter's type -- so every piece was required to unify with `const P &', the if-chain came out EMPTY, every
defaulted `<=>' answered equal, and five lines of stdcompare went RED. A name is looked up before it is given -- 0.93's
rule for a predicate, 0.99's for its arity -- and in a clause of thirty lines, for a VARIABLE too. The instrument that
found it was the `cicilang: '-prefixed write into the desugaring (the finding) under `-S -emit-llvm', since
`-fsyntax-only' skips the desugaring in C++ mode: 0.87's trap, met again on the first try, an empty log read as `never
reached'. A clause's helper predicates were also first written BETWEEN two clauses of the predicate they serve, which
cocolog takes as it takes any discontiguous clauses; they sit after it now.
(3) `\N{NAME}' ([lex.charset], C23 6.4.3; the not-done of every step since 0.43): the code point whose Unicode name
that is, in a string (as UTF-8, `ccl_utf8'), a char and a wide char, in BOTH lexers. THE TABLE IS WRITTEN ONCE:
`library/ccl_uninames.pl' holds one fact per assigned character, `ccl_uname(Name, Code)', the Name property of Unicode
14.0.0 as python3's unicodedata gives it (43,819 facts, 2.0 MB, the Hangul syllables among them), and one
`ccl_uname_range(Prefix, Lo, Hi)' per run of the five families named by their code point's hex digits (CJK UNIFIED
IDEOGRAPH-4E00 and kin, 13 runs), which both lexers COMPUTE; `module/build.sh' spells the facts into
`module/ccl_uninames.h' (the names sorted in strcmp's order under LC_ALL=C for the native lexer's binary search, the
runs after them; never committed) and the module's `ccl_uname_code' is raw C over it -- Cicili names no C array, the
numpy module's way -- called from `ccl_lx_ucn' beside `\u' and `\U'; the DCG's `ccl_ucn' takes `N{' and
`ccl_uname_value' asks the ranges, then the table, LOADED ON THE FIRST `\N{' A PROCESS MEETS (`ccl_uninames_ready',
`ensure_loaded' of the file found on `$COCOLOG_LIBRARY'; a global remembers it, never a clause, the finding on what
persists). An EXACT match, as the standards have it; a name that is nobody's is a LEXICAL ERROR in both lexers
(`ccl_escape' refuses `N{' so the escape never falls to the letter N, and `ccl_lx_escape' the same), as clang refuses
it. `test/c/run/uniname.c' (a string of five names, one of the computed family, a Hangul syllable, a char, a wide
char), clang's bytes; the build 2 s at 70 MB, the table's load inside it. Reader version 88. NOT READ: the name ALIASES
(`NameAliases.txt': the egress proxy of this box refuses unicode.org, so the file could not be fetched; python's
`unicodedata' takes an alias in `lookup' and enumerates none) -- a small file and a named road.
(4) FOUND ON THE WAY, older than every step here: `sizeof("abc")' WAS 8. A string literal is typed as the pointer it
decays to (`ccl_type_of(str(_))', 0.1's) and `sizeof' asked the type; a literal's size is its ARRAY's bytes now
(`ccl_literal_bytes' at the two doors, the lowering's `ir_expr(sizeof)' and the evaluator's `ccl_const_eval(sizeof)':
the narrow one its codes and the NUL, a wide one a code point per element, `wchar_t' and `char32_t' four bytes each,
`char16_t' two), which the uniname fixture's own last line found, printing 2 for clang's 3 over
`sizeof(L"...x") / sizeof(wchar_t)'. Lowering version 49 -- 48 for the complex integer, 49 after an IR made at 48 had
reached a probe's store: the second fix's probe was SERVED the old emission in 0 s (`EXIT 0 0 s peak 0 MB', and a
binary whose time was six minutes old), which is the store's rule (`dr_ir/3') working as written and the reason the
lowering version moves with every change to what is emitted, however small.
(5) PROBED AND NAMED, not fixed, each a road of its own: `std::compare_three_way' -- its `operator()' is a member
template constrained by `three_way_comparable_with<_T1, _T2>', and `cmp(3, 5)' STAYS RAW (`not lowered yet:
call(id(cmp))'): the member road finds no candidate, leaves the form and traces no refusal (the shape on the program's
own class, a member template `operator()' with a trailing `decltype(t <=> u)', runs under `auto' and under a written
result); `std::common_comparison_category_t' -- stops in `__get_comp_type' at `undeclared(bool(false))': its `bool
_False = false' value parameter, substituted into the `static_assert(_False, ...)' of the branch that `if constexpr'
should have discarded, arrives as an `id' holding its value.
NOT DONE, NAMED: the integer imaginary literal's suffixes (`2ui', `3li'); `_Complex int' past 2^60 (`imagi(big(A))',
refused by name); `\N{...}''s aliases; a pointer to member function's `adj' is always 0; a closure held in a
`std::function' is the library's discipline (0.45); `stderaseifuset.cpp' (C++20) builds in about 750 s at 3.8 GB and
stays one fixture; `std::compare_three_way' and `std::common_comparison_category' as above; coroutines, modules,
`consteval' at compile time, `std::format' and the ranges as before.
THE GATES: the reader's 95 checks GREEN on this tree at reader 88 (15 s at 266 MB, k84 comparing the two lexers on
the new lines) and the compile gate's 87 (0.101's 86 and `uniname.c', `complex3.c' beside it) GREEN in 9 s, each under
the watchdog; the chain of all seven -- the warming of 44 headers at reader 88 first, then the gates one after another
with nothing beside them -- was RUNNING when this was committed, and its numbers are carried by the next commit, as
0.102 carried 0.101's.

## 0.104 — M6's seventieth step

**M6's seventieth step (0.104): THE NOT-DONE LIST OF 0.103, closed -- the integer imaginary literal's suffixes,
`\N{NAME}''s aliases at Unicode 15.0.0, `std::common_comparison_category' and `std::compare_three_way'.** The owner
asked for the remaining not-done works before the C++ and libc++ gates, so 0.103's chain was stopped after the C
gates and these four were taken first, each cut to a reduction of a dozen lines before it was fixed and each gated.
(1) THE INTEGER IMAGINARY LITERAL'S SUFFIXES (0.103 dropped them: `2ui' was a `_Complex int'): BOTH lexers give
four token kinds, `imagi', `imagui', `imagli', `imaguli' (`ccl_imag_kind' over the integer's kind in the DCG;
`x->sfx' in the module, 1 and 5 for `u', 2 for `l', 3 for `ul', k84 comparing them on `test/c/lexer.c''s new line),
and the parser's node CARRIES THE REAL TYPE, `imagi(Specs, N)': `2ui' a `_Complex unsigned', `3li' a `_Complex long',
`4uli' a `_Complex unsigned long', an unsuffixed one `int' where it fits and `long' past INT_MAX (as C types a decimal
literal), a `big(A)' past 2^60 typed by `ccl_big_type' and SPELLED WHOLE through `ir_big_text' (`ccl_imag_specs';
0.103 refused `imagi(big(A))' by name); the flattened text spells the suffix back (`pp_imag_suffix'); the inference,
the check and the lowering read the node (`ir_expr(imagi)': `{ 0, N }' of the real's LLVM type, `ir_imag_const',
`ir_complex_text(big(A))'). `test/c/run/complex3.c' extended (`2ui', `3li', `4uli + 1', `9000000000000000000i',
`3000000000i' as a long), clang's numbers. Lowering version 50.
(2) `\N{NAME}''S ALIASES ([lex.charset], C23 6.4.3: a name OR an alias of the kinds clang takes -- control,
correction, alternate, figment -- never an abbreviation: `\N{NUL}' is refused as clang refuses it). THE TABLE IS
GENERATED by `module/gen-uninames.pl' (committed) from Perl's `Unicode::UCD': `prop_invmap("Name")' gives the names
and the families' runs (a run per `<code point>' range, `TANGUT IDEOGRAPH SUPPLEMENT-' among the 16), the Hangul
syllables' names are COMPUTED from the Jamo tables (`charprop' per syllable was 0.5 s each: killed after 600 s), and
`prop_invmap("Name_Alias")' gives the aliases with their kinds -- at Unicode 15.0.0, where python's `unicodedata' is
14.0.0 and enumerates no alias and the box's proxy refuses unicode.org's `NameAliases.txt': 44,115 names and 119
aliases; `module/build.sh' keeps an alias's kind comment out of the header (`sub(/\).*$/, "", v)'), and the module's
binary search takes the aliases as names. `test/c/run/uniname.c' extended (`\N{NULL}', `\N{LATIN CAPITAL LETTER GHA}'
a correction, `\N{BYTE ORDER MARK}' an alternate, `\N{ALERT}'), clang's numbers. Reader version 89.
(3) `std::common_comparison_category_t', FOUR RULES, and 0.103's diagnosis corrected: the stop at
`undeclared(bool(false))' was the `static_assert(_False, ...)' of the branch `if constexpr' should have discarded,
and the branch was REACHED because `__cat' never folded; once it folds, the branch is discarded before the assertion
is walked, and `_False' is nobody's business. (a) AN ARRAY INITIALIZER WITH A PACK EXPANSION SIZES NOTHING AT THE
READ (`ccl_sized_by_init', reader version 90): `constexpr _CCC __type_kinds[] = {_StrongOrd, __type_to_enum<_Ts>()...}'
was sized TWO, one per item written, and the third kind was stored past the array; the desugaring sizes it once the
pack expands (`cpp_size_by_init' at `cpp_decl_pieces'). (b) A `const' LOCAL AGGREGATE WITH A CONSTANT INITIALIZER IS A
VALUE TO THE EVALUATOR (`cpp_note_const''s second clause, `'$cpp_gagg:N'' marked `local' -- `cpp_global_agg' tells a
local's from a global's by `cpp_local' -- 0.97's rule for a file-scope one), AND A `const' SCALAR LOCAL INITIALIZED BY
A CONSTEXPR CALL FOLDS THROUGH THE EVALUATOR (`cpp_const_value' in `cpp_note_const''s first clause; 0.63's rule took a
literal constant only): `constexpr _CCC __cat = __comp_detail::__compute_comp_type(__type_kinds)' -- a reference-to-
array parameter over the local array, its bound deduced (0.90) -- folds to the category and the `if constexpr' chain
decides; a fold that fails is TRACED (`const_not_folded', `const_agg_not_folded' with each item's value, `agg_item'),
which is how (a) was found. (c) A RETURN IN A DISCARDED `if constexpr' BRANCH DOES NOT DEDUCE ([stmt.if]/2):
libc++'s `__get_comp_type' opens with `if constexpr (__cat == _None) return void();', and the first return taken
textually made EVERY category type `void' (the emitted instance returned void with the right branch's value loaded
and dropped); the first-return walk decides the condition with the declarations before it in scope and enters the
kept branch only (`cpp_first_return_in', ONE walk where `cpp_first_return' then `cpp_declare_before' were two --
the owner's rule -- at the method's door and the lambda's; a condition that does not fold leaves both branches, as the
statement walk does). (d) A DEDUCED `auto' RESULT IS DECAYED at the free function's door as the method's already was
(`cpp_decayed' in `cpp_lambda_ret'; [dcl.spec.auto]: `auto' deduces as a by-value parameter): `return
partial_ordering::equivalent', a `static const' member, deduced `const partial_ordering', and `is_same_v' told it
from the plain one -- the last `0' of the probe. AND A NAMESPACE-QUALIFIED VARIABLE TEMPLATE IN AN EXPRESSION,
`std::is_same_v<A, B>', is its value (`cpp_expr' on `scoped(Path, tmpl(N, Args))' where the path names no class):
flattened it had become `scoped([std], bool(false))'. The variable template's instantiation traces its arguments and
its value (`vartmpl(N, Args, V)'), which is what named (d).
(4) `std::compare_three_way' asked for NOTHING OF ITS OWN: its `operator()' is a member template constrained by
`three_way_comparable_with<_T1, _T2>', whose `__compares_as' is `same_as<common_comparison_category_t<_Tp, _Cat>,
_Cat>' -- false for everything while (3) answered void -- and with (3) the constraint holds and the member template is
chosen as any is; 0.103 read the raw call as `the member road finds no candidate and traces no refusal', where the
trace had `constraint_not_satisfied(operator(()))' and the refusal was the constraint's. THE REDUCTION that told the
rules apart is `test/cpp/run/stdcompare2.cpp''s own `pick<Ts...>()' (an `if constexpr' chain whose first return is
`void()', through a class's `decltype' and an alias template): it passed at every step while libc++'s shape still
failed, and only the trace's `vartmpl' line with a `const' in it said why -- a reduction that passes says the probe is
wrong, not the library (0.92's lesson, from the other side). Gated by `test/cpp/run/stdcompare2.cpp' at C++20
(`compare_three_way' over ints, doubles, a class with a defaulted `<=>', `is_eq' of its answer;
`common_comparison_category_t' of every pair of categories, of none, and of an `int', which is void; the reduction),
clang++'s numbers.
Reader version 90, lowering version 50; the module rebuilt as 0.104.
NOT DONE, NAMED: a `\N{...}' abbreviation alias (clang refuses it too); a pointer to member function's `adj' is always
0; a closure held in a `std::function' is the library's discipline (0.45); `stderaseifuset.cpp' (C++20) builds in
about 750 s at 3.8 GB and stays one fixture; coroutines, modules, `consteval' at compile time, `std::format' and the
ranges as before.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module rebuilt
as 0.104), on this tree at reader 90 and lowering 50: the reader's 95 checks GREEN in 13 s at 284 MB (k84 comparing the
two lexers on the new lines of `test/c/lexer.c'); the compile gate's 88 GREEN in 20 s at 666 MB. The fixtures the
rules touch were built ONE AT A TIME under the probe's caps before anything else: stdcompare2 (12 s, 294 MB),
stdcompare, defaultcmp2, lambdas2, closurescope, stdoptional3 (239 s, 1764 MB) PASS, the rest of the loop running.
The chain of all seven that was to follow this commit was STOPPED ten minutes in, on the owner's word ("7 hours is
ridiculous"), and replaced by 0.105's parallel gates; 0.103's and 0.104's C++ and libc++ numbers are 0.105's chain's.
Before it stopped, sixteen fixtures the rules touch were built one at a time and PASSED (stdbindfront 840 s,
stdtuple 631 s and stdmap 638 s among them; stdfunction killed once at the probe's 4000 MB cap during a cold flatten,
then 226 s and 1518 MB warm).

## 0.105 — M6's seventy-first step

**M6's seventy-first step (0.105): THE GATES IN PARALLEL -- seven hours was a serial chain doing one piece of
work twice.** The owner: "Refactor test cases and gates, 7 hours is ridiculous." MEASURED FIRST, from 0.101's
chain on this box (four cores, 16 GB): the warm read 44 library headers cold, one a process, in 10155 s; the libc++
gate read 22 of the SAME headers cold AGAIN, under a fresh HOME, in 8957 s; the C++ gate built its fixtures one at a
time in 5935 s; the four small gates and the proof took under a minute. Two defects of design and no defect of the
compiler: THE SAME COLD READ TWICE, and ONE CORE OF FOUR in use throughout. (1) THE POOL (`test/parlib.sh'):
`ccl_pool NMAX LAUNCH_MB HARD_MB' runs job lines from its input, up to NMAX at once, and launches the next one only
while the summed resident size of every cocolog is under LAUNCH_MB (9000), killing the whole pool past HARD_MB
(14000) -- a build peaks in the gigabytes and cocolog has no collector (the finding), so a lane count alone would
exhaust the box; the memory gate lets the light builds pack onto the cores while a heavy one holds the next launch
back. POSIX: the running children are tracked by PID and `kill -0', since dash has no `jobs -r' -- the first
writing used it, dash printed `Illegal option' once a second and the pool ran ONE job at a time, which looked like
a slow pool rather than a broken one until the log was read. And a pool's wall clock is its LAST job's end, so the
jobs go LONGEST FIRST (`ccl_lpt_order', the classic LPT rule): each job's seconds are appended to a timings file
(`~/.cicilang/fixture-times', `header-times'; the last line per key wins, the unknown first), and the next run
orders by them. Measured on twelve fixtures over a warm cache: 245 s in four lanes where their warm serial sum is
420 s, every one PASS-identical, 3 GB summed at the peak. (2) THE LIBRARY READ IS THE WARM (`test/libcxx.sh',
`test/readhdr.pl'): a summary is keyed by the reader's version and every dep's time (`ccl_sum_valid'), so after a
version bump every summary is cold whatever HOME holds it, and the libc++ gate's fresh HOME bought nothing but a
second cold read of what the warm had just read. The phase now WIPES the user's C++ cache, reads the UNION -- the
22 library headers at their levels, each asserted to read whole to its minimum, and the 21 other headers the
fixtures and Cicili's C++ files include, warmed by a syntax-only build -- ONE HEADER A PROCESS through the pool, each
read capped by coreutils' `timeout -s KILL' (which kills the process group it leads, the cocolog grandchild
included; the old warm's cap had been lost in the first writing and was put back before this commit), and leaves
the summaries written: the C++ gate after it is fully warm, and `test/warm.sh' is a shim that runs it. Measured
into a throwaway HOME: GREEN in 3277 s where the two serial phases took 19112 s -- every one of the 22 counts equal
to 0.101's (<vector> 806 and 898 at C++20, <iostream> 792 and 884, <unordered_set> 833 and 925, <string> 754, 846
and 522 at C++23, <optional> 602, 397 and 397 ...), the 21 others warmed and none failed -- and that run had the
heavy headers in its first lanes by accident and <functional> at C++20 starting last, which the longest-first order
now prevents. (3) THE C++ GATE BUILDS ITS FIXTURES IN PARALLEL (`test/cpp.sh'): each fixture is one self-contained
job (`ccl_fixture': built under its own time cap, run with its .stdin, compared with its .expect) whose verdict goes
to a file of its own, so four lanes never interleave on the output; the verdicts are collected in alphabetical
order after the pool, so the report reads as it did; the reader's checks (`test/cpp.pl', one process), the
refused-by-name builds and the summary-cache check stay serial, being seconds. `CPP_JOBS=1' is the old gate. (4)
ONE CHAIN (`test/gates.sh'): reader, compile, driver, objects and the proof one after another, then the library
read, then the C++ gate, each line `== NAME: GREEN in N s', a RED stopping it; `GATES_JOBS' sets the lanes of both
parallel phases. THE TEST CASES THEMSELVES are unchanged: 176 fixtures, and no fixture was merged or dropped --
each names what it proves, and a merged one would say less when it fails. A LESSON worth the line: a shell script
is READ AS IT RUNS, so a gate script edited while that gate is running continues from its old byte offset into the
new text; the longest-first libcxx.sh waited in a scratch file until the validating run had exited.
WHAT IS MEASURED AND WHAT IS NOT: the pool on twelve fixtures and the library read whole, above; the full chain
`sh test/gates.sh' over the user's cache follows this commit, and its numbers -- and 0.103's and 0.104's C++ and
libc++ ones, whose serial chains were stopped -- are carried by the next commit.

## 0.106 — M6's seventy-second step

**M6's seventy-second step (0.106): WHAT THE PARALLEL GATES FOUND ON THEIR FIRST RUN -- a summary with no AST behind
it, and a pool whose jobs could eat its queue.** 0.105's chain ran whole on this box for the first time: the five
small gates GREEN in 49 s together, the library read GREEN in 3168 s with every count equal to 0.101's, and the C++
gate RED in 3718 s with nine failures -- 6935 s for the chain where the serial one took about 25,000. The nine were
TWO defects, and neither was the compiler's work on a program. (1) THE LOST AST, older than the refactor and exposed
by it: 0.100 moved the summary's write AFTER the AST's (the summary is the validity key, so it must be the last file
a run writes), but only the summary's write ran `mkdir -p' on the cache directory -- so in a cache whose directory
did not exist, the FIRST header a process read met no directory, its AST write FAILED, and the summary written after
it CREATED the directory and stood valid with no template bodies behind it. Every program instantiating that header's
templates then refused `template_without_body' until the cache was wiped by hand. The old warm ran over an existing
directory and never met it; the library read WIPES the directory on every run, so the headers that finished first
lost their ASTs -- here <string> at C++17, and all eight C++17 fixtures over `std::string' failed on it. And the
catch around the AST's write made it WORSE: its recovery traced the error and SUCCEEDED, so an exception read as a
written AST. THREE RULES (`library/ccl_include.pl'): the directory is made before the AST is written
(`ccl_sum_dir_ready', which the summary's write shares); a summary is written only when its AST was (the recovery
fails now); and a summary is VALID only with its AST beside it (`ccl_sum_valid'), so a hollow summary already in
someone's cache is read again and repaired rather than refusing programs for ever. Proven on <cstdio>: into an absent
directory it had lost its AST, and has it now; with the AST removed by hand, the next read writes it again. (2) A
JOB READ THE POOL'S INPUT: `ccl_pool' takes its jobs from standard input and `eval'ed each one with that input
inherited, and cocolog's query loop reads its standard input -- so a build could swallow the job lines queued behind
it. One did: `stdoptionalref' was never run, and the collector, which names every fixture that left no verdict, said
so (`no verdict'); every job now runs with `/dev/null' as its input. AND a failed build's time is no measure of its
cost -- the eight string fixtures failed in seconds and would have been ordered LAST next time, though they are heavy
-- so only a passing build's seconds (and a good read's) are recorded for the longest-first order. HOW THE FIRST WAS
FOUND, worth its line in the list of instruments that answer without measuring: the first probe into the write put
its markers on `user_error', which cocolog does not have, so the FIRST marker failed and took the write down with it
-- an instrument that broke the thing it measured, reading exactly like the defect; on standard output they named
the failing step at once (the file write), and a ten-second test on a small header with the directory absent and
then present named the cause. Library change only in what the summary cache writes and accepts; reader version 90,
lowering version 50 unchanged; the module rebuilt as 0.106.
THE GATES: the fixes are proven on the reductions above, and at this commit the whole chain `sh test/gates.sh' is
running on them (reader 8 s, compile 7 s and driver 8 s GREEN so far); its numbers are carried by the next commit.

## 0.107 — M6's seventy-third step

**M6's seventy-third step (0.107): THE PARALLEL CHAIN, measured whole -- and the last shell defect it had.** 0.106's
chain was cut by a container restart after the small gates, and ran again whole on this box (Ubuntu 24.04, x86_64,
four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1): the reader's 95 checks GREEN in 10 s, the compile gate's 88
in 11 s, the driver's 25 in 11 s, the objects' 29 in 3 s, the proof in 1 s; THE LIBRARY READ GREEN in 2705 s over four
lanes, the 22 asserted headers at 0.101's counts to the item (<vector> 806 and 898 at C++20, <string> 754, 846 and 522
at C++23, <iostream> 792 and 884, <map> 767 and 859, <set> 767 and 859, <unordered_map> 751 and 843, <unordered_set> 833
and 925, <optional> 602, 397 and 397, <memory> 533, <functional> 831, <tuple> 441, <compare> 348 at C++20) and the 21
other headers warmed, none failed -- 3168 s at 0.105's first run, the difference the longest-first order, which now had
the last run's times to order by -- and every one of the 43 summaries written has its AST beside it (0.106's rule,
proven on the whole cache: the directory was wiped at the phase's start and the headers that finished first are the
ones that had lost theirs); THE C++ GATE in 1440 s over four lanes, 229 checks ok and ONE failure, `stdoptionalref':
`no verdict'. THE CAUSE, and it is the shell's and not the compiler's: sh has no local variables, and the helper that
decides whether a fixture is beyond the box's library (`ccl_needs_met', 0.95) kept its status in `r' -- the very name
`ccl_fixture' keeps its RESULT FILE in. So the skip verdict was written to a file named `1' in the gate's scratch
directory, which the gate's trap then removed, and the collector found nothing under the fixture's name. The serial
gate before 0.105 printed its verdicts and had no path variable to lose, which is why the defect arrived with the pool.
The helper's names are its own now (`_nd_cond', `_nd_f', `_nd_r'), and its preprocessor run reads `/dev/null' as its
input as every pool job does (0.106). Proven on the fixture's job alone (`skip stdoptionalref.cpp: needs
_LIBCPP_VERSION >= 210000'), then by the C++ gate run again alone: GREEN in 1395 s, 229 checks ok, `stdoptionalref' skipped by name, no failure. THE CHAIN: 4181 s where the serial one took
about 25,000 (10155 s of warm, 8957 of libc++ read, 5935 of C++ builds at 0.101) -- the owner's seven hours are one
hour and ten minutes. AND A RULE FOR THE GATE SCRIPTS: a
shell function that sets a variable sets it for its CALLER, so every helper a pool job calls uses names that no job
uses; the tell was a verdict that is missing where a wrong one would have been visible. Reader version 90, lowering
version 50 unchanged; the module rebuilt as 0.107.

## 0.108 — M6's seventy-fourth step

**M6's seventy-fourth step (0.108): THE MISSING PARTS OF C, AND THE MAIN GAPS OF C++ -- RTTI, exceptions, coroutines,
modules, contracts, the array cookie, multiple polymorphic bases.** The owner asked for every C part and every main
C++ gap named in the not-done lists, then the gates. Each form was cut to a probe of ten to forty lines, built by
clang and by cicilang, run, and compared line for line (`one.sh'); each has a fixture.
THE C SIDE, found by probing clang's behaviour over the whole language, twenty-odd forms: (1) TRIGRAPHS in the ISO
modes before C23 (`-std=c17', `-std=c11', `-std=c99', `-trigraphs'; the GNU modes and C23 do not read them, clang's
rule): replaced in the preprocessor's source lines before anything else, the store keyed by the mode (`ccl_kb_key'
gives `c(V, CS, trigraphs)'), a fixture's `NAME.std' naming its level turns them on in the compile gate. (2) `long
double' IS x86_fp80 on x86-64 (its own LLVM type, `0xK' constants, 16 bytes aligned 16, the `L' suffix its own token
kind `floatl' in both lexers, `%Lf' through printf, libm's `l' functions, the `__builtin_*l' constants); arm64 keeps
the double. (3) A VARIADIC DEFINITION: the compiler's own `<stdarg.h>' over `__builtin_va_start', `va_arg' LLVM's
instruction, `va_end' and `va_copy' the intrinsics, `__builtin_va_list' the ABI's type (x86-64's array of one
struct). (4) HEX FLOATS and a float with a leading dot in both lexers; `f' a `floatf' kind, so `1.5f' is a float.
(5) DESIGNATED INITIALIZERS in arrays and nested (`[3] = x', `.a.b = y', a designator moving the position), a global's
normalized to positional order. (6) A COMPOUND LITERAL of an unsized array sized by its items. (7) `offsetof', folded
from the layout, through nested members, array elements and anonymous members. (8) `_Bool' a byte with the
conversion rules. (9) K&R DEFINITIONS (`int f(a, b) int a; char *b; { ... }'), their parameters adjusted.
(10) `[static N]', `[const N]' and `[*]' in a parameter. (11) C11's ANONYMOUS STRUCT AND UNION MEMBERS, their members
the holder's own (a hidden `$anonK' member and a route through it). (12) `__func__', `__FUNCTION__',
`__PRETTY_FUNCTION__'. (13) An enum or a tag declared in a block. (14) An array argument decayed to a pointer where
a prototype is missing. (15) TENTATIVE DEFINITIONS (`int x; int x = 3;' one object). (16) `#line N "f"' and the GNU
line markers, which `__LINE__', `__FILE__' and `assert' read.
THE C++ SIDE. (17) `new T[n]' OF A CLASS, THE ABI's ARRAY COOKIE (0.86's `new_array_of_objects', refused by name
since): the count written in the max(8, alignof(T)) bytes before the first element, each element constructed in
place, `delete[]' reading the count back and destroying in reverse, the block freed from the cookie's address.
(18) `if consteval' IN THE CONSTANT EVALUATOR: the compile-time branch where the evaluator folds, the run-time branch
in the object (0.43 kept the run-time one everywhere). (19) C++26's CONTRACTS ENFORCED: `pre(e)' and `post(r: e)' on a
function or a method and `contract_assert(e);' are checked at run time, a violation printing `contract violation:
precondition of F (line L)' on stderr and aborting -- the standard's `enforce' semantic, where 0.93 read them and
ignored them; a postcondition over every return, the returned value named. (20) RTTI OF THE PROGRAM'S OWN CLASSES:
`typeid' of a type and of a polymorphic object (read from the vtable), `dynamic_cast' to a pointer and to a reference,
over libc++abi's `__dynamic_cast' and `type_info' objects the lowering emits (`_ZTI', `_ZTS', with the
`__class_type_info', `__si_class_type_info' and `__vmi_class_type_info' layouts), and THE VTABLE HAS THE ITANIUM
PREFIX, offset-to-top and the type_info pointer before the slots, the vptr pointing at the slots; a library class's
type_info is the shipped symbol. libc++ keeps its own no-RTTI configuration (0.86): only the program's `typeid' and
`dynamic_cast' use it. (21) EXCEPTIONS OF THE PROGRAM'S OWN: `throw' over `__cxa_allocate_exception' and
`__cxa_throw', `try'/`catch' by type and `catch (...)' through a landing pad, `__gxx_personality_v0',
`llvm.eh.typeid.for', a rethrow, and every call inside a `try' an `invoke', so the defers of the frames it leaves run
on the way out; libc++ keeps its no-exceptions configuration (0.50). (22) MULTIPLE POLYMORPHIC BASES: a second
polymorphic base gets a SECONDARY VTABLE in the object, its slots THUNKS that adjust `this' by the base's offset and
call the override; `delete' through the second base finds the whole object by offset-to-top; a pointer to member
function carries the `adj' a conversion from a base adds. (23) C++20's MODULES: `export module M;',
`module;' with its global fragment, `import M;', `export' before an item and `export { ... }', partitions
(`M:P'), `import <header>;' and `import "header";' as includes, `import std;' as a fixed list of headers; an imported
module is read from `M.cppm' (`.ccm', `.cxxm', `.ixx', `.mpp') beside the importer or on the inclusion path, its
functions and initialized globals emitted `linkonce' into the importer. (24) C++20's COROUTINES, LLVM's switch-resumed
lowering: the desugaring makes a body holding `co_await', `co_yield' or `co_return' a SKELETON -- the promise of
`R::promise_type' declared, `coro_begin' (llvm.coro.id over the promise, the frame from operator new,
llvm.coro.begin), `coro_ret' (get_return_object(), converted as a return is), the initial suspend's await,
`coro_body' (the body, a fall-off `return_void()'), the final suspend's await and `coro_done' (every defer run, the
frame freed through llvm.coro.free, llvm.coro.end, the ramp's return). A co_await is a statement expression over the
awaiter -- `await_ready()', else `coro_suspend' (llvm.coro.save, `await_suspend(coroutine_handle<P>::from_address(
frame))' whose void, bool or handle result decides, llvm.coro.suspend and the switch whose destroy edge runs every
defer), then `await_resume()' -- through the promise's `await_transform' where it has one; co_yield is `yield_value';
co_return the promise's `return_value' or `return_void' and a jump to the final await with its scopes' defers run.
libc++'s coroutine_handle calls `__builtin_coro_resume', `destroy', `done', `promise', `noop' and the desugaring
`__builtin_coro_frame': LLVM's intrinsics. THE EMBEDDED LLVM RUNS `default<O0>' AT -O0 TOO (`module/ccl_llvm.cicili',
`level >= 0'): it ran no passes at all there, and CoroSplit is a pass -- `Cannot select: intrinsic %llvm.coro.begin'.
FIVE MORE RULES THE COROUTINE PROBES FOUND, each older than coroutines: (25) A NESTED CLASS'S OWN SHORT NAME inside its
body takes the nested type with no guard, the class made ready after (`std::coroutine_handle<promise_type>' inside
`Gen::promise_type' met 0.86's per-(class, name) guard, still set while the name's resolution made the class ready,
and keyed the instance by the free name); (26) `C() = default' beside other constructors makes a DEFAULT CONSTRUCTOR
EXIST for a holder (`cpp_default_ctor_exists'): a promise holding a `std::coroutine_handle<>' was left uninitialized,
`__handle_ = nullptr' never run, and a local `Outer::In y;' of a nested class with default initializers too --
valgrind named it; (27) `T cur{};' and `int n{3};' as DEFAULT MEMBER INITIALIZERS value-initialize as `m()' does;
(28) `Gen{h}' inside the class template Gen (a functional cast to the reader) is LIST-INITIALIZATION of the aggregate,
also while the instance is still being registered; (29) a RETURN converts through the value's CONVERSION OPERATOR
([class.conv.fct]), as it did through the result's converting constructor: `return h;' of a coroutine_handle<P>
where coroutine_handle<> is the result.
AND THE DEDUCTION RULES THE RANGES PROBE FOUND: (30) `std::pair{a, b}' -- a NAMESPACE-QUALIFIED CTAD, where only the
bare name deduced; (31) THE WRITTEN DEDUCTION GUIDES first ([over.match.class.deduct]): a guide is indexed under
`$guide.<class>' (reader version 94) and tried before the constructors, since libc++'s pair has template constructors
only; (32) A PARAMETER WHOSE TEMPLATE PARAMETERS ALL STAND IN NON-DEDUCED CONTEXTS takes no part in deduction
([temp.deduct.call]/1): `format(format_string<_Args...>, _Args &&...)' is `basic_format_string<char,
type_identity_t<_Args>...>' against a string literal, which refused `deduction_failed'; (33) A POINTEE KEEPS ITS
QUALIFIERS in deduction ([temp.deduct.call]/4): `T *' against `const int *' is T = const int, where the clause that
decays a by-value argument took the pointee too and made it `int' -- libc++'s `__to_address(_Tp *)' answered
`int *' for a `const int *'. Gated by `test/cpp/run/deduceguide.cpp'.
Reader version 94, lowering version 52; the module and `library/ccl_llvm.so' rebuilt.
Gated by `test/c/run/trigraphs.c', `varargs.c', `hexfloat.c', `ldouble.c', `designated.c', `cforms.c', and
`test/cpp/run/arraycookie.cpp', `ifconsteval.cpp' (C++23), `contracts.cpp' (C++26, exit 134 after the violation),
`rtti.cpp', `exceptions.cpp', `exceptions2.cpp', `multibase2.cpp', `multibase3.cpp', `memfnadj.cpp', `ldouble.cpp',
`modules.cpp' (C++20, importing `mathm.cppm' which imports `basem.cppm'), `cogenerator.cpp', `cotask.cpp' (symmetric
transfer, a bool await_suspend, a local with a destructor across a suspension, an infinite generator destroyed
early), `coeager.cpp' (suspend_never at both ends), `coawait.cpp' (await_transform, an lvalue awaiter, a coroutine
lambda), `cotemplate.cpp' (a class template generator), `nesteddefault.cpp' and `deduceguide.cpp', each clang's
output; the coroutine probes valgrind clean.
NOT DONE, NAMED: THE RANGES and `std::format'. `std::ranges::sort' over a vector stops in libc++ 18's
`__unwrap_range', where `pair<const int *, const int *>' built from two calls of `__unwrap_iter' refuses both
two-argument constructors (`__enable_implicit' false for the pair's own `const _T1 &' road, the forwarding one
arity_mismatch), past rules (30) to (33); `std::format' passes its deduction by (32) and its build did not finish
inside 1800 s cold. A coroutine: `std::coroutine_traits' specializations (the promise is always `R::promise_type'),
`unhandled_exception' (no try around the body), `operator co_await' on an awaitable, the ramp's return object read
from the frame when the frame is freed inside the ramp (the value is kept in an alloca spilled to the frame; the
eager probe passes under valgrind, so LLVM keeps it out of the frame, but no rule here guarantees it). A module: the
exported names are not enforced (a non-exported function is visible), a header unit's macros are not exported, module
linkage is `linkonce'. RTTI: a class with virtual bases gets no `__vmi' layout for them. Exceptions: `noexcept' is not
enforced, a class caught by value is bound, not copied. A thunk calls the primary chain's override.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module and
`ccl_llvm.so' rebuilt as 0.108), `sh test/gates.sh' on a fresh store: the reader GREEN in 12 s; the compile gate
GREEN in 19 s (51 C fixtures); the driver GREEN in 8 s; the objects' and the proof GREEN; THE LIBRARY READ GREEN in
2828 s over four lanes, cold after the reader bump, every count 0.107's and the 26 other headers warmed; THE C++ GATE
RED in 1437 s on two REFUSAL checks only -- `control.cpp' (a `try') now builds and gives clang's exit 39, and
`coro.cpp' is refused as clang refuses it, for a promise with no `get_return_object' -- every run fixture ok; the
list updated, the C++ gate alone GREEN in 1482 s, 246 checks, `stdoptionalref' skipped by name. TWO THINGS ON THE
WAY, worth their lines: the driver gate's first run was RED on the ABI check, `specs([double])', and the cause was mine
-- `ir_type(T1, x86_fp80)' as a TEST in the ABI's leaves, whose cached answer for a double is no unification but the
last `ir_base' clause's throw; a type is asked, then compared (`LLx == x86_fp80'). And a compile gate was KILLED by
the kernel's OOM killer at 14 GB while probes of mine ran beside the chain, in the middle of a write to the store:
the next reader gate said `commit failed: the store refused it: hexmap ends inside the chunk'. A killed writer can
leave the store damaged; it is a cache, and a fresh one (`rm -rf ~/.cicilang/KB ~/.cicilang/KB.version') is the
repair -- and one guarded run at a time is the rule that would have kept it whole (0.46's, broken by me again).

## 0.109 — M6's seventy-fifth step

**M6's seventy-fifth step (0.109): C++20's CONSTRAINED ALGORITHMS on libc++ 18, `<ranges>' read whole, the tie spelled
`tie', and a candidate's check inside `\+ \+'.** The owner asked for the ranges and `std::format'; the first run,
the second is named with its stop. THE ALGORITHMS: `ranges::sort', `ranges::find' and `ranges::count_if' over a vector
run and print clang++'s lines (`test/cpp/run/stdranges.cpp' at C++20). The road there, each rung its own rule and most
of them reproduced in a dozen lines before they were fixed: (1) A PARAMETER'S TYPE MAY NAME AN EARLIER PARAMETER
([dcl.fct]/9: `decltype(std::__unwrap_iter(__orig_iter)) __iter'), so the parameters are declared in order while
their types are resolved and keyed (`cpp_plain_params_seq', `cpp_params_keys_seq'). (2) `noexcept(e)' is a bool
constant (true unless the operand throws: the reader drops a function's `noexcept', so a call's own is not known --
named). (3) A COMPOUND REQUIREMENT TAKES `decltype((e))' ([expr.prim.req.compound]: an lvalue is `T &';
`cpp_decltype_paren'), and a failing concept or requirement says which (`concept_unsatisfied', `requirement_unmet').
(4) CONSTRAINED PARTIAL SPECIALIZATIONS: a candidate whose constraints fail is none, and among those that hold the
more constrained wins, counted by conjuncts (`cpp_by_constraints': `indirectly_readable_traits'). (5) `decltype' OF A
CONDITIONAL over two glvalues of one type is the reference with both arms' qualifiers, and of a call through a
function reference its declared result (`cpp_cond_glvalue', `cpp_fn_result': `common_reference'). (6) Two class types
are the same by their keys where the spellings differ (`cpp_same_type'). (7) A MEMBER ALIAS TEMPLATE AS A TEMPLATE
TEMPLATE ARGUMENT, `_Tester::template _Apply', keeps its class (`tname(mt(C, N))'), is substituted as a scoped
template-id and found through the bases (`cpp_member_alias_of'): libc++'s `_ITER_CONCEPT'. (8) AN `auto' OBJECT
TAKES ITS INITIALIZER'S TYPE -- a namespace-scope one (`cpp_vars', declared again at file scope) and a STATIC MEMBER
(`cpp_static_auto', `cpp_declare_statics'); a CALL OF A STATIC OBJECT of class type goes to its `operator()', qualified
or bare in its class; and a static of an EMPTY class initialized in the class is its zero bytes, `linkonce': libc++'s
`_IterOps<_RangeAlgPolicy>' is `static constexpr auto __iter_move = ranges::iter_move;' and every ranges algorithm calls
through it (`test/cpp/run/autoobject.cpp'). (9) AT `-O0' THE PIPELINE RUNS `globaldce' after `default<O0>'
(`module/ccl_llvm.cicili'): the instances made for a `decltype' or a requires-clause -- `iter_move' over libc++'s
`__projected_impl', whose `operator*' the library declares for unevaluated use and never defines -- are `linkonce_odr'
and called by nothing, and kept they named a symbol the link could not find; every higher level drops them already.
(10) A CANDIDATE'S CHECK RUNS INSIDE `\+ \+' where the call's arguments are ground (`cpp_candidate_check', on the free,
member and constructor roads): what it makes that lasts (instances, facts, globals) survives, the deductions and
substitutions of every candidate tried are reclaimed, and only the bindings come out through a global. THE MEASUREMENT
that found it: the trace's heap stamps summed by the event before each growth put 9.7 GB after `candidates_remembered';
the ranges probe went 7.9 GB -> 2.6 GB (958 s -> 858 s, warm). THE READER (versions 95 to 97): (11) C++17's NESTED
NAMESPACE DEFINITION, `namespace ranges::views { ... }', and C++20's `A::inline B' (`ccl_ns_segs', `ccl_ns_nest') --
the read of `<ranges>' stopped there, line 11,496 of 61,507, and no view was ever read; (12) a NAMESPACE ALIAS,
`namespace views = ranges::views;', an item that does nothing, as `using' is (namespaces flatten); (13) THE FIRST NAME OF
A CLASS HEAD IS THE CLASS'S OWN ONLY WHERE NO `::' FOLLOWS IT (`ccl_struct_body'): `template <class> friend struct
std::__segmented_iterator_traits;' inside `join_view' made `std' a type name for the rest of the header, and the read
stopped, silently, at `take''s functor 1,150 lines later -- found by a census bisect of the flattened header (four cuts
read in parallel, then four inside the item, then four in the context: the failing text was identical to `drop''s,
which read, and only the context told them apart), and the class body's look-ahead scan takes no qualified name for a
member template either (`ccl_scan_did'). `<ranges>' reads WHOLE at C++20, 956 items, and joins the libc++ gate.
(14) A NAMESPACE'S KEY BEFORE A CLASS OF THE SAME NAME in a qualified call (`cpp_call'): libc++ has both the namespace
`ranges::views::__all' and a class template `__all', and `__all::__fn{}' was built as the class's member.
THE TIE IS THE WORD `tie' (the owner's rule): `x tie y' where `x <*> y' stood, in both lexers (`<*>' is no punctuator
any more), the grammar, the fixtures, the docs; a CONTEXTUAL word, read only after a declarator or a `:=' form and only
before a name, so `std::tie' and a C name `tie' are what they were. AND THE README's `format' example declares the
variables its holes name. NAMED, NOT DONE: THE VIEWS -- `views::filter(v, pred)' now reaches `filter_view''s deduction
guide and `views::all' (a `ref_view' for an lvalue), and stops in `ref_view''s `empty()' under `requires { ranges::empty(
*__range_); }', a member's trailing requires-clause over a DATA MEMBER checked with no class scope; the pipe
`v | views::filter(...)' needs the adaptor closure's hidden friend `operator|' behind it. `std::FORMAT' -- `std::format("{}
and {}", 2, 3)' reads, and its desugaring runs past 12 GB in three minutes inside `basic_format_string''s compile-time
checks (`__determine_arg_t<_Context, ...>' with `_Context' the class's own alias unresolved), right after choosing
`std::__declval<__arg_t *&>'; the same `declval' over the real `__arg_t' outside that context builds in 4 s, and a guard
on the mangler tried there fixed nothing and was taken out. `noexcept(f())' of a function not declared noexcept answers
true. Reader version 97, lowering version 52; the module rebuilt as 0.109.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1), `sh test/gates.sh'
in one chain with nothing beside it: the reader GREEN in 13 s (k84 comparing the two lexers on the `tie' line of
`test/c/lexer.c'); the compile gate GREEN in 19 s (the tie fixtures and the eight refused ties); the driver GREEN in
9 s; the objects in 4 s; the proof; THE LIBRARY READ GREEN in 3387 s, its 23 asserted headers whole -- 0.107's 22 and
`<ranges>' at C++20, 956 items -- and the other headers the fixtures include warmed; THE C++ GATE GREEN in 1815 s, 251
checks ok, `stdoptionalref' skipped by name, no failure, the five new fixtures among them (`stdranges', `autoobject',
`concepttraits', `memberaliasttp', `nsforms'). Measured alone before the chain: `stdranges' 1169 s at 3.1 GB warm (858 s
before `<ranges>' read whole, 958 s and 7.9 GB before the candidate checks were scoped).

## 0.110 — M6's seventy-sixth step

**M6's seventy-sixth step (0.110): THE NOT-DONE LISTS OF 0.108 AND 0.109 -- noexcept, trailing return types, the
coroutine traits, catch by value, the virtual base through the table and the DIAMOND, modules' exports and header units, and
the next stops of the views and of std::format.** The owner asked for every not-done item; each form was cut to a probe of ten
to forty lines, built by clang and by cicilang and compared line for line, and each has a fixture. (1) `noexcept' IS KEPT on a
function (reader version 98; `ccl_suffix_quals', `'$ccl_nothrow''): the operator `noexcept(f())' asks the callee
(`cpp_nx_throws'), and an exception that leaves a noexcept function calls `std::terminate' without the destructors on the way,
as clang does (`cpp_nx_wrap': a try whose handler is of the kind `terminate', which the landing pad catches and runs no cleanup
for; only where the program throws at all). `test/cpp/run/noexcept.cpp'. (2) A FREE FUNCTION'S TRAILING RETURN TYPE, a
prototype's and a definition's (`ccl_trailing_ret', `ccl_fn_quals'): `auto add(int, int) -> long;' was an `auto' the reader
could not settle. `trailing.cpp'. (3) COROUTINES: `operator co_await', a member and a free one (`cpp_coro_awaiter'); the promise
through a `std::coroutine_traits' specialization, constructed from the coroutine's parameters where it has such a constructor
(`cpp_promise_type', `cpp_promise_init'); `unhandled_exception' around the body (`cpp_coro_guard'); a qualified specialization's
head, `struct std::coroutine_traits<...>', registered. `coawaitop.cpp', `cotraits.cpp'. (4) A CLASS CAUGHT BY VALUE IS A COPY,
and `throw E(args)' builds the exception in its own memory (`cpp_catches', `cpp_new_at'). `catchvalue.cpp'. (5) THE VIRTUAL
BASE IS REACHED THROUGH THE TABLE (the Itanium ABI's vbase offset at `vptr[-3]'; `ir_member_slot' on a struct marked
`virtual_base', `ccl_vbase_kind'): a class whose first base is virtual and that has a table of its own reaches that base
through the offset its table holds (`cpp_vbase_offset' puts it in every table of such a class, primary and secondary), so a
base sub-object finds the shared base wherever the complete object lays it; a polymorphic virtual base has this class's
secondary table in it, typeid and dynamic_cast go through it, and the type_info flags the base VIRTUAL with the offset's place
(-24). The complete object's constructor and destructor build and destroy the base AT ITS PLACE (`$base!'). The stream fixtures
over libc++'s `basic_ostream : virtual basic_ios' read the shipped tables' offsets the same way. `vbasertti.cpp'. (6) THE
DIAMOND ([class.mi]/6), clang's record layout byte for byte: `struct D : B, C' over `virtual A' embeds each path as its
BASE-SUBOBJECT form `B.nv' (the class without the shared base, its DATA size as bytes, so what follows uses its tail padding:
`int d' at 28 inside C's 16 bytes, `sizeof(D)' 48), holds the shared base once at its end (`$vb', `'$cpp_vb_holder''), builds
it first and stores its own tables before the paths' BASE-VARIANT constructors run (the ABI's C2 and D2, `C.C.k.nv',
`C.dtor.0.nv', `cpp_nv_twin': the body without the virtual base and without the table's store), destroys it last, and takes
each method's FINAL OVERRIDER from whichever path overrides it (`cpp_final_impl', `cpp_primary_entry', a thunk that hands the
complete object to the call's own conversion); a method of a base the class does not name dispatches on that base's table
(`cpp_hops_class'). Where a path holds the base only further in, it stays whole and the later paths are `.nv'; a diamond over
a virtual base with no table is refused by name (`virtual_base_by_two_paths', `test/cpp/diamond.cpp'). `diamond.cpp',
`diamond2.cpp', `thunkdeep.cpp'. (7) MODULES: a name the module does not export is not visible to the importer (`ccl_exported',
`ccl_module_hide': renamed `N$Module', refused as undeclared, `test/cpp/modhidden.cpp'); a HEADER UNIT's macros reach the
importer (`pp_import_line'); and an inline function the program's own header defines is EMITTED with the program, by
`#include' and by import alike (`cpp_include_fns', `cpp_header_fns': a `"..."' header outside the system's directories), where
it was declared and never defined and the link named it. `headerunit.cpp', `hdrinline.cpp'. (8) A MEMBER WHOSE TRAILING
REQUIRES-CLAUSE IS UNMET is no candidate and is not instantiated ([temp.inst]/11; `cpp_method_viable'), the clause walked in
its class (`'$cpp_req_ctx'') and substituted with the class's arguments (`cpp_subst_quals'); a MEMBER template's and a
constructor template's own constraints are walked in their class too (`cpp_with_req_ctx': ref_view's `__fun'), a concept's
body never. `memberreq.cpp', `ctorreq.cpp', `refview.cpp'. (9) A DATA MEMBER OF CLASS TYPE CALLED THROUGH AN OBJECT, `c.f(x)',
goes to its class's `operator()', and a hidden friend `operator|' template serves the pipe. `pipefriend.cpp'. (10) AN INSTANCE
STILL BEING REGISTERED IS A CLASS (`__is_class', the CRTP: `ref_view<R> : view_interface<ref_view<R>>'), and an instance over
such a class is LAZY, its members made where they are used ([temp.inst]/4; `cpp_incomplete_arg'). `crtpconcept.cpp'. (11) A
REQUIRES-EXPRESSION IS A bool VALUE ([expr.prim.req]/1): `enable_view = derived_from<...> || requires { ... }'. `reqvalue.cpp'.
(12) A LIBRARY CLASS'S CONSTEVAL CONSTRUCTOR keeps its member initializers and not its compile-time check (basic_format_string's
parse of the format string, which nothing here evaluates; named). (13) A GLOBAL ENUM OF THE PROGRAM IS A GLOBAL NAME in a
mangled symbol (`1K'): taken to its name it resolved to the enum again without end -- 6 GB in 84 s behind a `std::array' of an
enum, which is where std::format's run had been going; and a GLOBAL's braced list is elided into an array member as a local's
was (`ir_gelide'). `enumarray.cpp'. Reader version 98, lowering version 54; the module rebuilt as 0.110.
NOT DONE, NAMED: `views::filter(v, pred)' now reaches `filter_view''s constructor and stops at
`member_not_constructed(__base_, ref_view<vector<int>>, 1)': `__base_(std::move(__base))' finds neither the constructor template
(rightly: it refuses its own class) nor the implicit copy, beside the default member initializer `_View()' that ref_view cannot
take; the pipe over libc++'s adaptor closures is untried behind it. `std::format' passes its compile-time constructor and the
enum mangling and was not run to its next stop in this step (each run of it is minutes, and the container restarted four times
under the long probes). A diamond: construction vtables are not made (a virtual call inside a path's constructor reaches the most
derived override), the implicit copy of a diamond class is not made memberwise, a library class's base-variant constructor is
never called (a program class deriving from two library classes that share a virtual base is refused by name). Module linkage
stays `linkonce'.
THE GATES, ON LINUX (Ubuntu 24.04, x86_64, four cores, 16 GB; clang 18, libc++ 18, cocolog 1.8.1, the module rebuilt as 0.110),
`sh test/gates.sh' in one chain with nothing beside it: the reader GREEN in 15 s (k84 comparing the two lexers); the compile gate
GREEN in 25 s; the driver GREEN in 9 s; the objects in 5 s; the proof; THE LIBRARY READ GREEN in 3240 s over four lanes, cold
(the reader's version moved to 98), its 23 headers whole -- several one item more than 0.109's, the noexcept and trailing
forms the reader keeps now (`<vector>' 807, `<iostream>' 793, `<functional>' 832; `<ranges>' 956 at C++20 as before) -- and
29 other headers warmed; THE C++ GATE GREEN in 2010 s, 271 checks (0.109's 251 and this step's 20), `stdoptionalref' skipped
by name, no failure. The 0.110 commit was made while the two parallel phases ran (the container restarted four times under
long runs in this step); these are their numbers, carried by 0.111.

## 0.112 — M6's seventy-seventh step

**M6's seventy-seventh step (0.112): C++20's range views on libc++ 18, `std::format`'s road, the suspected defects
of the validation, and `CLAUDE.md` rewritten by topic.** The owner asked for the two items 0.110 named as not done,
then for every entry of `CLAUDE.md` validated and the file refactored by current topics.

THE VIEWS. `views::filter(v, pred)` called, through the pipe and chained, its iterators walked
(`test/cpp/run/stdviews.cpp` at C++20). Seven rules, each cut to a reduction of a dozen lines first:
(1) A DEFAULTED DEFAULT CONSTRUCTOR WITH A REQUIRES-CLAUSE IS ONE ONLY WHERE ITS CONSTRAINTS HOLD ([temp.inst]/11):
`filter_view() requires default_initializable<_View> && default_initializable<_Pred> = default` was noted as the
implicit default constructor of a holder of `ref_view`, which has none (`member_not_constructed`); a constructor's
qualifiers are substituted with the instance's arguments, and a constructor whose trailing requires-clause is unmet
is no candidate and is not instantiated (`cpp_ctor`'s three candidate sets, `cpp_member_fns`). `defaultreq.cpp`.
(2) THE COPY PASS RUNS ON A LOCAL'S CONSTRUCTOR CALL (`cpp_decl_pieces`), as on a temporary's since 0.83: `H h(v,
pred)` handed the vector itself to a `ref_view` parameter. `localconv.cpp`. (3) A CAPTURELESS LAMBDA CONVERTS TO A
POINTER TO FUNCTION ([expr.prim.lambda.closure]/8; `cpp_closure_invoker`): a conversion operator to `R (*)(Ps)`
answers a static invoker `lambda.K.fn`; a pointer to function converts only to its own function type
(`cpp_conv_fits`); a class value assigned to a scalar converts through its conversion operator. `lambdafp.cpp`.
(4) `std::rel_ops` IS NOT INDEXED (`ccl_flat_items_`): only a using-directive finds its names, which is not modelled,
and flattened its `operator!=` took filter_view's iterator before C++20's rewritten `==`. Reader version 99.
(5) A LIBRARY CLASS'S HIDDEN FRIEND IS WRITTEN IN THE CLASS'S WORDS (`cpp_register_lazy_friends`,
`'$cpp_friend_in'`): `operator==(const __iterator &, const __iterator &)` matched nothing (`no_operator(==)`).
(6) A CLASS DERIVES FROM EVERY BASE IT NAMES (`cpp_derives`): `__range_adaptor_closure_t<F> : F,
__range_adaptor_closure<...>` has its CRTP base second, and `is_base_of` was false -- no `operator|`. (7) A
QUALIFIED PATH OF TWO OR MORE SEGMENTS IS WALKED FIRST (`cpp_scope_class_`): `_ITER_CONCEPT`'s
`__iter_concept_cache<_Iter>::type::template _Apply<_Iter>` took the asking class's own `type`. `scopewalk.cpp`.

`std::FORMAT`'S ROAD. The build of `std::format("{} and {}", 2, 3)` went from 1353 s and 6.3 GB to about 118 s and
1.5 GB warm, through eight stops, each its own rule and fixture at C++20: (1) ONE SPELLING PER INTEGER TYPE
([basic.fundamental]; `cpp_int_spelling/2` in `cpp_canon_specs` and `cpp_type_key`): `signed int` is `int`,
`long int` is `long`, `unsigned` is `unsigned int`; `__libcpp_is_signed_integer<signed int>` never matched `int`.
`intspell.cpp`. (2) A NESTED-NAME-SPECIFIER NAMING A PARAMETER IS A NON-DEDUCED CONTEXT in a pattern
([temp.deduct.type]/5.1; `cpp_non_deduced`). `ndpath.cpp`. (3) A CONVERSION THROUGH A CONSTRUCTOR TEMPLATE whose
parameter is a template-id ([over.ics.user]; `cpp_class_converts`' second clause). `ctortconv.cpp`. (4) A NESTED
TEMPLATE-ID PATTERN FILLED FROM THE PRIMARY'S DEFAULTS ([temp.arg]/2; `cpp_fill_pattern/4` in `cpp_match_tmpl`).
`tmpldefaults.cpp`. (5) AN ITEM DECLARED BY A NAMESPACE-QUALIFIED NAME BELONGS TO THAT NAMESPACE ([namespace.memdef]/2;
`ccl_flat_quals`, and `cpp_spec_name`'s scoped variable-template clause): `__format::__enable_insertable<
basic_string<_CharT>>` defined in `std` belonged to nothing, and `std::format` wrote into a `__writer_container<void>`.
Reader version 100. `qualspec.cpp`. (6) A PRVALUE OF NON-CLASS TYPE HAS NO TOP-LEVEL CV ([expr.type]/2;
`cpp_prvalue_type/2`), and a qualified type-constraint names its concept by its last segment (`cpp_concept_of`).
`prvaluecv.cpp`. (7) AN `auto` PARAMETER BESIDE A WRITTEN TEMPLATE HEAD invents its parameter after the written ones
([dcl.fct]/22; `cpp_register_`). `autohead.cpp`. (8) A MEMBER FUNCTION WITH AN `auto` PARAMETER IS A MEMBER TEMPLATE
(`cpp_auto_members/2`). `automember.cpp`. (9) AN INSTANCE STILL BEING REGISTERED IS A SCOPE (`cpp_path_class`; its
typedefs are noted before its members): `basic_format_context` holds `basic_format_args<basic_format_context>`, whose
`__basic_format_arg_value` reads `typename _Context::char_type`, and flattened as a namespace it was the bare
`char_type` -- an argument typed by it reached `invoke_result<F, unknown>` and `declval<unknown>`
(`kind_mismatch(_Tp)`). `inprogscope.cpp`. (10) AND NO 128-BIT INTEGER, the fourth configuration question after the
exceptions, RTTI and vector extensions: `__SIZEOF_INT128__` is not predefined any more, the one macro libc++ 18 reads
to decide `_LIBCPP_HAS_NO_INT128`, since nothing here lowers an `__int128`: the same visitor met the `__int128_t
__i128_` member of `__basic_format_arg_value`, a type with no meaning here. Reader version 101, every summary rewritten.
(11) `formatter<bool>` estimates a width through libc++'s grapheme-cluster table, `ranges::upper_bound(__entries, ...)`
over a constant C array, and four rules stood in its road, each cut to a file that failed in seconds
(`arrayref.cpp`, `rangesarray.cpp`): `T &` deduces an array AS AN ARRAY ([temp.deduct.call]/2; `cpp_deduce_one`), so
ranges::begin's `is_array_v<_Tp>` holds; an array's element keeps its qualifiers as a pointee does (`cpp_match` on
`arr`, `cpp_match_pointee`); `common_reference` of `const unsigned &` and `uint32_t &` is that reference -- the
conditional's two glvalues are ONE type under two spellings (`cpp_cv_union`), each qualifier counted once, and two
references are the same type when their referents are (`cpp_same_compound`); and a member template's requires-clause
among its qualifiers is checked under the deduced bindings (`cpp_member_tmpl_req`) and the instance is made with its
qualifiers SUBSTITUTED (`cpp_try_member`), where the raw clause skipped the member and its name was noted made; and
`ranges::less` compares the table's `unsigned` with a `char32_t`, whose common reference is the prvalue `unsigned int`:
C++'s `char32_t` promotes to its underlying type ([conv.prom]/8; `ccl_promote`, `wchar_t` to `int` alike), and the
usual arithmetic conversions answer an UNQUALIFIED value (`ccl_usual`), where an operand's const stayed on it
(`charpromote.cpp`). And past the desugaring, the lowering met `this->__size_ = {0}`: libc++'s basic_format_args writes
`size_t __size_{0};', and the scalar test of a braced default member initializer took only a spelled base type, not
`typedef(size_t)' -- it resolves the type first now (`cpp_scalar_member_type`; `scalarbrace.cpp`); and the format-spec parser's
`__code_point<_CharT> __fill_{}' over `struct __code_point<char> { char __data[4] = {' '}; }' refused
`member_not_constructed': a braced default member initializer of a CLASS member list-initializes it
([dcl.init.list]/3; `cpp_member_inits' through `cpp_member_from'), and an aggregate's member with no item takes its
own default member initializer before it is value-initialized ([dcl.init.aggr]/5.1; `cpp_agg_inits/6' over the
class's defaults; `aggdefaults.cpp'); and `formatter<const _CharT *, _CharT>::format' reads `_Base::__parser_', a
QUALIFIED DATA MEMBER through the base's alias, which 0.90 had named as having no road: `C::m' in a member function
with C the class or a base of it is that member of `this' ([class.mfct.non.static]/2; `cpp_qualified_data_member/4':
the hops down to C's sub-object, then C's own), a later base with storage through its slot, and through the closure
in a lambda that captured `this' (`qualmember.cpp'); and the lowering of `__parser<char>''s implicit constructor
ran away over its bitfields: an enum whose underlying type is a typedef, `enum class __alignment : uint8_t', had no
size and fell out of the layout (`ccl_size_align' resolves it first now), an enumeration is a scalar type whose braced
default member initializer is its one item ([basic.types.general]/9; `cpp_scalar_type'), and a bitfield is read with
its type's sign, written once (`ir_signed_/1': `bool', `char8_t', `char16_t', `char32_t' unsigned, an enum by its
underlying type) -- a `bool f : 1' holding true had read as -1 (`enumbits.cpp'); and the global `__fields_integral', a
designated list over bitfields, met `case(init([]))': the hole between two designators (`ccl_init_norm') is the
member's zero and a braced scalar its one item in the bitfield packer (`ir_gbit_value/2'), which C needed too --
`struct F g = {.a = 1, .c = 1}' over bitfields did not compile (`test/c/run/bitdesig.c'); a global of an AGGREGATE
class takes the aggregate road, its list completed by the class's default member initializers ([dcl.init.aggr]/5.1;
`cpp_agg_constant/3', a header's inline variable too), where the program's own was refused
`dynamic_initialization_of_global' and the library's lost a `{true}' default; and every aggregate door makes a
designated list POSITIONAL (`cpp_agg_values/3', a skipped member the hole `'$no_item''), where the values had been
taken in order with their designators dropped -- `F l{.b_ = true}' set the first member (`aggconst.cpp'); and
`__consume_result::__error' named nothing: an enum that TYPES A DATA MEMBER, `enum : char32_t { __ok, __error } __status
: 1 {__ok};', declares its enumerators in the class as one declared alone does (`cpp_member_enum/2';
`memberenum.cpp'); and `__format::__parse_number_result __r = __format::__parse_arg_id(...)' reached the lowering
as the bare template: class template argument deduction takes the COPY DEDUCTION CANDIDATE first
([over.match.class.deduct]/1.3: one initializer of an instance's type gives its arguments) and a namespace-qualified
name in a declaration (`cpp_ctad_name/2'; `ctadcopy.cpp'); and a `case' label is a constant expression desugared and
folded as any, where it had been kept raw: `case __format_spec::__type::__default:', a static constant, a constexpr
call (`caselabel.cpp'); and `basic_format_string<char, int, int>::__types_' came out with FOUR items for two
arguments and none of them a constant: `cpp_init_expr' collected every answer of a nondeterministic walk in its
`findall' (one walk per item now) and a static's items are folded through the evaluator (`cpp_fold_items/2';
`staticpack.cpp'), and one whose items do not fold, `__handles_' and its immediately invoked lambdas, is declared and
not defined, unused since the consteval check is dropped (`staticunused.cpp'); and `__output_buffer::__flush()'
calls `__flush_(__ptr_, __size_, __obj_)', a data member of pointer-to-function type named bare, which is a call
through it as C calls one (`fnptrmember.cpp'); and `if constexpr' over a constexpr CALL is decided through the
evaluator (`cpp_const_bool/2'), where libc++ 18's `__format_arg_store' kept both branches and the discarded one named
`__args_', which the packed store does not have (`ifconstexprcall.cpp'); and `std::basic_format_context(...)' reached the
lowering as the bare template: in a constructor taken as a guide, the INJECTED CLASS NAME is the class over its own
parameters ([temp.local]/1; `cpp_ctad_self/4'), so `basic_format_args<basic_format_context>' deduces `_CharT'
(`ctadself.cpp'); and `std::move(__writer_).__out_it()' passed `addr(move(...))' as the object: a member function called
on `std::move(x)' takes x itself, the xvalue having chosen the `&&' overload (`cpp_object_arg/3'; `moveobj.cpp'). And in the LOWERING,
a reference handed to a by-value aggregate parameter is read through (`ir_args_', `ir_ref_value_type/2'): the value of
a cast to a reference is the referent's address, and `std::invoke' of the visitor's generic lambda over `monostate'
stored it as the struct, which LLVM refused (`refbyvalue.cpp'). And a DESIGNATED temporary, `T{.a = 1}', keeps its designators: the reader
had dropped them (`ccl_postfix_p' over `ccl_item_values'), so libc++'s `__parsed_specifications<_CharT>{.__std_ =
__std{...}, ...}' stored its first item into the ANONYMOUS UNION whole; the reader keeps a designated list as a
compound literal of T (`ccl_braced_temp', reader version 102), an aggregate class's is built member by member
(`cpp_agg_temp/5'), a designator may name a member of an anonymous union (`cpp_agg_slots', `'$anon_item'(F, V)'),
and `return {.a = 1}' designates the result too (`desiganon.cpp'). With it, in C as in C++, a BITFIELD IN A UNION is
read and written through its bits (`ir_union_slot/4'), where every union member was read at the union's address
whole and a 3-bit field read the byte another member had written (`test/c/run/unionbits.c').
THREE MORE BETWEEN THE LOWERING AND THE LINK. A LAZY library class's static data member is DEFINED WHERE IT IS NAMED, as
its member functions are ([temp.inst]/3; `cpp_static_use/3', `cpp_use_static/2'): checking `std::format''s second
candidate instantiates `basic_format_string<wchar_t, int, int>', and the class's emission folded its statics'
initializers (`__types_', `__handles_'), which pulled the whole `wchar_t' format road and `numpunct<wchar_t>' into a
`char' program, and LLVM refused a slot's declaration over the never-laid-out `basic_string<wchar_t>'. clang's
`__datasizeof(T)' is folded to the Itanium dsize (`cpp_trait', `cpp_pod_layout', `cpp_lays_end') and
`__has_extension(datasizeof)' answers 1 as clang's does (reader version 103): libc++ 18's other road, a member template's
explicit specialization, did not fold, and `__libcpp_datasizeof<T>::value' was an undefined symbol wherever
`__constexpr_memmove' copied a range -- at the committed 0.111 too, measured with its library (`datasizeof.cpp'). And a
header's ENUM keeps its namespace path, in the index and the AST beside the summary (`cpp_enum_ns_name/2', reader
version 104), so `to_chars(char *, char *, double, chars_format)' is called by its shipped symbol,
`..._dNS_12chars_formatE', where the mangler had spelled a global `12chars_format' (`tocharsfmt.cpp').
THEN THE PROGRAM LINKED AND CRASHED, in `basic_format_args::get': an ANONYMOUS STRUCT INSIDE AN ANONYMOUS UNION was
flattened into the union, so `__types_' lay over `__values_'; it is one member of the union now, its fields in
sequence (`cpp_norm_union_members/3', `cpp_anon_path/3'; `anonstructunion.cpp').
COCOLOG 1.8.38, pulled and reviewed with Cicili's and ZiguratIP's documentation commits: the heap is COLLECTED since 1.8.36
(`coco_heap_gc', between two steps of the outermost engine, never inside `findall/3' or `forall/2'), the SDK gained
three entries with its ABI unchanged, and COMPAT.md lists where cocolog differs from SWI-Prolog. The module, the
embedded LLVM and cocolog's `os' and `process' modules were rebuilt; the five small gates are GREEN on it, and the
`std::format' build, warm, peaked at 591 MB where 1.8.1 took 2882 MB.
(12) A
CALL'S FIRST REFUSAL IS ITS OWN (`cpp_instantiate_function__`): the global is restored for the enclosing call, since a
candidate check makes calls of its own -- `std::invoke`'s refusal had named a nested `__sfinae_test_impl`'s reason.
AND THE COST, measured with the CPU-time trace: a concept's satisfaction
and a variable template's value are remembered per ground arguments (`'$cpp_ccm'`, `'$cpp_vtm'`), the concepts are
facts by name (`'$cpp_concept'`), and a miss of the tag, typedef, tag-struct and file-scope caches is remembered too
(`ccl_caches_misses`, `'$ccl_miss'`), the file scope's writer marking a declared name for a new look
(`ccl_gdeclare_recheck`): `cpp_path_class(std, _)` copied the whole tags table at every `std::` call.
`std::format` RUNS: `test/cpp/run/stdformat.cpp` at C++20 -- an int in every base, widths, fill and alignment,
precision, a char, a bool, a string, positional arguments and `format_to` -- prints clang++'s lines, warm in about
two minutes. The last stops were the class forms the owner's next request closed (below): a static member of class
type with a constructor, a pointer into a string literal as a global's constant (`ir_gconst`), and an
`initializer_list` constructor chosen only where the items fit it.

THEN EVERY NOT-DONE ITEM, the owner's next request, each cut to a reduction first, each with its fixture.
THE CLASS FORMS: (1) A GLOBAL OF CLASS TYPE WITH A CONSTRUCTOR THAT IS NO CONSTANT is DYNAMICALLY INITIALIZED
([basic.start.dynamic]): its construction goes into `$cpp_ginit', which `@llvm.global_ctors' runs before `main', and
its destructor is registered with `atexit' ([basic.start.term]; `cpp_dynamic_init/4'); a constant one is still folded
(`cpp_fold_quietly'). `globalinit.cpp'. (2) A STATIC LOCAL OF CLASS TYPE is constructed once under
`__cxa_guard_acquire' and `__cxa_guard_release' and destroyed through `__cxa_atexit' ([stmt.dcl]/3). `localstatic.cpp'.
(3) A LOCAL ARRAY OF OBJECTS is built element by element -- a prvalue item elided into its element -- and destroyed in
reverse in one defer. `localarray.cpp'. (4) A TEMPORARY BOUND TO A REFERENCE LIVES AS LONG AS THE REFERENCE
([class.temporary]/6; a hidden local `$ext_K'). `lifeext.cpp'. (5) A TEMPORARY IN A LOOP'S CONDITION OR STEP is made
and destroyed at every turn ([class.temporary]/4; `cpp_cond_once/4'). `looptemp.cpp'. (6) A PRVALUE INITIALIZING A
LOCAL IS THE LOCAL ([dcl.init]/17.6.1), walked once: walked twice, a temporary's constructor ran on the wrong
object (`drop 32767'). `prvalueinit.cpp'. (7) An `initializer_list' constructor is viable only where the items fit its
element ([over.match.list]/1.1; `cpp_il_ctor_for/3'), and a list that fits it is the better conversion
([over.ics.rank]/3.1): `std::string tag{"t"}' had come out empty. (8) A consteval CONSTRUCTOR or MEMBER of the
program folds where it is called, or is refused by name (`cpp_note_consteval', `cpp_consteval_fold';
[dcl.constexpr]/13). `constevalm.cpp'. (9) A lambda's requires-clause is its operator template's constraint
(`cpp_lambda_constraint'; reader version 105). `lambdareq.cpp'. (10) `dynamic_cast<void *>' is the complete object
through the table's offset-to-top ([expr.dynamic.cast]/7). `dynvoid.cpp'. (11) An enumerator's type is its enum
([dcl.enum]/5), so an operator over enum operands is the program's (`cpp_enum_args/3'). `enumop.cpp'. (12) An
overloaded member's address is chosen by its target ([over.over]; `'$memaddr'(C, N)'). `classforms.cpp'.
THE SUSPECTED DEFECTS the validation had found by reading, closed: (13) A BASE WITH CONSTRUCTORS, NONE A DEFAULT ONE,
NAMED BY NO INITIALIZER IS REFUSED, `base_constructor(B)' ([class.base.init]/9; `cpp_no_default_ctor/1'), where it was
left unconstructed; such a base deletes the implicit default constructor. `basedefault.cpp',
`test/cpp/basenodefault.cpp'. (14) PLACEMENT NEW stores what [expr.new]/24 says (`cpp_placed_value'): a plain struct
value-initialized to every byte zero, where it took a scalar zero; and its result borrows the address it was given
(the check's `$at' clause), where a local buffer's was a loose pointer. `placeplain.cpp'. (15) `is_convertible' takes
no `explicit' constructor (`cpp_converting/1'). `explicitconv.cpp'. (16) A SUMMARY TERM PAST 8000 CHARACTERS goes to
the `.big.pl' beside it as `'$ccl_sum_big'(F, I, T)', consulted back: cocolog's `term_to_atom/2' reads through an
8 KB buffer, and twelve `tag(...)' lines of `<vector>''s summary -- `basic_string' 56 KB -- were dropped silently.
(17) `decltype' of a call through a member function pointer keeps the member's reference result, and the lowering
binds a reference result through the statement expression the call is (`cpp_called_fn/3', `ir_ref_result/2'):
`std::invoke(pm, s) += 2' wrote into a dead copy. `memptrdecl.cpp'. (18) The dead predicates `cpp_plain_lib_class/1',
`cpp_no_copies/1' and the unread `'$cpp_free_ops'' are gone.
WHAT THE PROBES FOUND ON THE WAY: (19) A MEMBER NAMED THROUGH AN OBJECT BY ITS QUALIFIED NAME, `b.A::v',
`p->A::f()', `this->Base<T>::f()' ([expr.ref]/7): the reader takes it (`ccl_member_qseg'; reader version 106) and
the desugaring reaches the base sub-object and calls without dispatch (`cpp_qual_object', `cpp_qual_call').
`qualobject.cpp'. (20) AN ALIGNMENT SPECIFIER CHANGES THE ALIGNMENT, NEVER THE SIZE (`ccl_size_align'): `sizeof x'
of `_Alignas(16) int x' was 16 and `alignas(S) unsigned char buf[sizeof(S)]' 192 bytes for 24, and a loop over it
wrote past its stack slot. `test/c/run/alignsize.c'. (21) A COMPOUND ASSIGNMENT AND AN INCREMENT TAKE THEIR PLACE
ONCE ([expr.ass]/6, C 6.5.16.2/3): 0.99's atomic road decided by taking the place in a clause of its own, and the
lowering emits as it goes, so `slot() += 5' called slot twice. `test/c/run/oncetarget.c', `oncetarget.cpp'. Lowering
version 59. (22) A DESTRUCTOR STORES ITS OWN CLASS'S TABLES FIRST ([class.cdtor]/4): a virtual call in `~A()' under a
T reached T's override, whose members were destroyed. `dtorvt.cpp'. (23) A CAPTURELESS GENERIC LAMBDA CONVERTS TO A
FUNCTION POINTER ([expr.prim.lambda.closure]/9): an invoker per target calls the closure's member template
(`cpp_generic_invoker/5'). `genericfp.cpp'. (24) A NESTED CLASS, AND A LAMBDA MADE IN ONE, SEE THE ENCLOSING CLASS'S
STATICS ([class.nest]/4; `cpp_static_member/3' through `'$cpp_enclosing''). `nestedlambda.cpp'. (25) THE PRIMARY BASE
IS LAID OUT FIRST (the Itanium ABI): a polymorphic base after plain ones is moved to offset 0 and the bases are still
built in the order written (`cpp_primary_first/3', `cpp_bases_in_order/4'), where it was refused by name since 0.108.
`primarybase.cpp', `primarybase2.cpp'. And `recself.cpp' shows the recursive `this auto self' lambda deducing its
result from a first return that does not recurse, which C++ requires. THE COMMAND LINE: `-D' and `-U' define and
undefine macros as clang's do (`ccl_pp_cmdline/1'; a summary is keyed by them), `test/driver.sh'. THE C SIDE:
`1.0li' is a `_Complex long double' constant in both lexers and `CMPLXL' comes from the compiler's `<complex.h>'
(`test/c/run/complex4.c'), and a `u"..."' literal spells a code point past U+FFFF as a surrogate pair
(`test/c/run/u16pairs.c').
AND THE LIBRARY MODULES' REMAINDERS (0.62's to 0.84's lists), each probe against clang++ with libc++ 18 and each defect
cut to a reduction first: (26) COPY-INITIALIZATION FROM A MOVE CHOOSES THE MOVE CONSTRUCTOR ([dcl.init]/17.6.2): `M b =
std::move(a)' took the copy constructor, and `= static_cast<T &&>(x)' was elided bitwise into a double free; the move is
kept among the constructor's arguments (`cpp_ctor_args', `cpp_xvalue_move/2'). `moveinit.cpp'. (27) `decltype(std::move(x))'
IS `T &&' ([dcl.type.decltype]; `cpp_std_move_call/2'), where the desugaring makes the move of a scalar the value.
`decltypemove.cpp'. (28) AN INSTANCE MADE WHILE A CALL'S ARGUMENTS ARE TYPED IS NO PART OF THAT CALL: `cpp_isolated' sets
the caller aside too. `stdvectorvector.cpp' (a vector of vectors, copied and moved). (29) A VIRTUAL CALL, AND A METHOD
CALLED BARE INSIDE ITS CLASS, TAKE THEIR ARGUMENTS THROUGH THE PASSES A DIRECT CALL DOES (`cpp_dispatch/6',
`cpp_dispatch_copied/6'): libc++'s `basic_stringbuf::seekpos' hands an fpos to an `off_type' through `this->seekoff(__sp,
...)', and LLVM refused the `sext' of a struct; a class taken by value went bitwise to a callee that destroys it.
`dispatchargs.cpp'. (30) A CONVERTING CONSTRUCTOR'S TEMPORARY FOR A BY-VALUE PARAMETER IS THE PARAMETER
([class.copy.elision]/1): `g(9)' over `g(T t)' destroyed it twice, older than this step. `convbyval.cpp'. (31) OF TWO
MEMBERS THAT TIE, THE ONE WHOSE REQUIRES-CLAUSE HOLDS WINS ([over.match.best]/2.6; `cpp_best_q' over
`cpp_constraint_count'), and such a member carries `.rq<fold>' in its name (`cpp_req_key/2'): libc++'s iota_view has two
`end() const', and the first declared answered a sentinel; `views::iota' runs. `moreconstrained.cpp'. (32) A DERIVED
OBJECT FITS A BASE'S PARAMETER, a Conversion ([over.ics.ref]/1; `cpp_arg_fit_' through `cpp_derives/2', now one
predicate where dynamic_cast had a second definition of the name): `__save_flags<_CharT, _Traits> __sf(__is)' took the
private copy constructor, declared and never defined. `explicitvbase.cpp'. (33) `__visibility__("hidden")' IS KEPT on a
member defined out of its class (`hidden(Sto)'; reader version 107), and an extern template's instance compiles such a
member from the header: libc++ 18 writes `_LIBCPP_HIDE_FROM_ABI void basic_stringbuf<...>::__init_buf_ptrs()' without
the `inline' 0.75's rule read. (34) A COLLIDED NAMESPACE NAME IS KEYED BY THE SHORTEST UNIQUE SUFFIX OF ITS PATH
(`cpp_ns_unique_suffix/3'), and a relative qualifier is made absolute where the item's namespace is known
(`cpp_qualify_paths/4', `cpp_abs_ns_path/5'; `cpp_ns_key/3' tries suffixes longest first): `ranges::__transform::__fn'
and `ranges::views::__transform::__fn' were one key, and `views::transform' and `views::reverse' met the algorithms'
classes. `nscollide3.cpp'. (35) A NAMESPACE-QUALIFIED TEMPLATE-ID CALLED TAKES THE KEY: `__elements::__fn<0>{}',
views::keys. (36) INSIDE A MEMBER CLASS TEMPLATE'S INSTANCE ITS SHORT NAME IS THE INSTANCE: the hidden friend
`operator==' of take_while_view's `__sentinel' reached the lowering as `typedef('__sentinel')'. `sentinelpair.cpp'. And
the fixtures the lists asked for: `stdvectorcopy.cpp' (a class that copies and does not move, 0.62),
`stdvectorstring2.cpp' (`insert', `erase', `resize', `assign' over strings, 0.70), `stdoptional4.cpp' (C++23's
`transform' to a string and `and_then' over a conditional, 0.84).
NAMED, NOT DONE: the tail padding of a non-POD base is not reused (`struct D : B { int y; }' over a polymorphic B is
24 bytes here and 16 under clang; self-consistent), and the diamond has no construction vtables.

THE SUSPECTED DEFECTS the validation found by reading the code, four of them fixed and gated: a hex literal past 2^60
folded as decimal digits (`ccl_limbs_of_hex`, `test/c/run/bighex.c`); `__is_abstract` never true
(`cpp_abstract_class/1`, `abstracttrait.cpp`); an enum taken for an arithmetic type by the traits and
`__is_trivially_equality_comparable`, so `std::find` over an enum used `memcmp` past the program's `operator==`
(`cpp_enum_type/1`, `cpp_arith/1`), with an enumeration operand's free operator chosen ([over.match.oper]/1;
`cpp_enum_operator_call/4`; `enumeq.cpp`); and an init-capture that made no member, `[&n = e]` losing its `&`
(`cpp_init_capture/4`, `cap(init_ref, N, E)`, `initcapture.cpp`). The others are named in `CLAUDE.md`'s Not done.

CLAUDE.MD BY TOPIC. Thirteen agents validated the 589 KB file slice by slice against the code -- every predicate,
global, fixture and file it names, and every rule against the later steps that changed it -- and ten more merged
their extracts into topic sections: the owner's rules, the layout, the gates, the driver, the lexers, the
preprocessor, the C and C++ readers, the includes and the store, classes, templates, concepts, overload resolution,
lambdas, constant evaluation, the object layout and the ABI, exceptions to contracts, libc++, the safe part, the
lowering, time and memory, the findings, what runs and what is not done. One bullet is one rule as it holds now, with
the version that made it. The validation found about 250 statements no longer true -- a rule a later step narrowed
or replaced, a "refused by name" since implemented, a not-done since closed, a predicate renamed -- and the new file
states each as the code has it now. Of the 1476 names the new file cites, every one is in the code (`cpp_ita_' is the mangler's prefix, a family). This file, `HISTORY.md`,
keeps the old step log verbatim.

Reader version 107, lowering version 59; the module rebuilt as 0.112, over cocolog 1.8.38. NO GATE HAS RUN ON THIS COMMIT. It is a save point of the work in progress: every fixture it adds matched clang++'s
output in a probe, one at a time, and the rules above were each proven on a reduction, but the seven gates -- which
read every header cold at reader 107 -- have not run over it, and the views (`transform', `reverse', `keys', `values',
`take_while', the chain) and `std::quoted' are not yet run through after the fixes they asked for. The next commit
carries the gates' numbers.

## 0.113 — M6's seventy-eighth step

**M6's seventy-eighth step (0.113): the views of `<ranges>` run one by one, `std::quoted` linked, and the seven gates
over the 0.112 save point.** 0.112 was committed as a save point with no gate run over it, and named what was still to
run through: the views `transform`, `reverse`, `keys`, `values`, `take_while`, the chain, and `std::quoted`. This step
runs each of them alone against clang++ with libc++ 18 at C++20, fixes what they ask for, and runs the gates.

THE RULES, each cut to a reduction first: (1) THE HIDDEN MARK OF AN ATTRIBUTE THAT BEGINS AN ITEM is kept
(`'$ccl_hidden_lead'`; reader version 108): 0.112 kept `__visibility__("hidden")' on a member defined out of its class,
but where the attribute stands right after a template head, the rule that drops a leading attribute and reads the item
again cleared the mark first -- libc++ 18 writes `template <...> _LIBCPP_HIDE_FROM_ABI void
basic_stringbuf<...>::__init_buf_ptrs()', the extern template's instance called it by a symbol the library does not
export, and the link named it. `stdquoted.cpp' (`std::quoted' on output and input). (2) AN UNNAMED TEMPLATE PARAMETER
OF A DECLARATION TAKES THE DEFINITION'S NAME, never the reverse (`cpp_tparam_renames', `cpp_rename_tparams'): libc++
declares `template <bool> class __iterator;' in transform_view and defines it `template <bool _Const> class
transform_view<...>::__iterator', and `__iterator<!_Const>' was renamed to nobody's `anon'. `viewiter.cpp'.
(3) A VARIABLE TEMPLATE WHOSE VALUE IS AN OBJECT OF CLASS TYPE answers that value, a compound literal of the class
(`cpp_object_value/1'), and its instance called is the object's `operator()' (a `cpp_call' clause on `tmpl(N, As)',
never for a function template's prototype, which is a declaration item too -- the first writing caught `__declval' and
refused every `declval'): libc++ 18 writes `template <size_t _Np> inline constexpr auto elements =
__elements::__fn<_Np>{};' and `keys = elements<0>', and an object that is no constant was refused. `vtobject.cpp'.
(4) BOTH IMPLICIT MEMBERS OF A CLASS ARE MADE IN THE CLASS (`cpp_in_class' around `cpp_implicit_ctor' and
`cpp_implicit_dtor' in `cpp_item'): transform_view's `__sentinel' default-initializes `sentinel_t<_Base> __end_ =
sentinel_t<_Base>()', and made outside the class `_Base' did not resolve (`instance_not_emitted'). `sentbase.cpp'.
(5) A HIDDEN FRIEND WITH AN UNMET REQUIRES-CLAUSE IS NOT REGISTERED ([temp.inst]/11; `cpp_friend_req/3',
`cpp_friends_viable/3'): transform_view's iterator writes `friend auto operator<=>(...) requires random_access_range<
_Base> && three_way_comparable<iterator_t<_Base>>', and deducing its `auto' over a `__wrap_iter', which has no `<=>',
refused and left the view's `begin()' undeclared. With it: `a <=> b' takes a free `operator<=>' (a hidden friend among
them), a plain struct with none refuses instead of taking the scalar rule, and an `auto' operator deduces its result
as a plain function does. `friendreq.cpp'. (6) A MEMBER CLASS TEMPLATE OF A LIBRARY CLASS IS THE LIBRARY'S
(`cpp_lib_origin/2'): transform_view's `__iterator<_Const>' was checked as the program's code, and the safe part
refused `__parent_(std::addressof(__parent))'. (7) A MEMBER WHOSE CLAUSE IS UNMET IS NOT DECLARED where its declaration
cannot be made -- an `auto' result that does not deduce, or a constrained constructor whose parameter types do not
resolve (`cpp_unmet_member/4' in `cpp_declare_members', asked only after the failure): ref_view<map>'s `data() const
requires contiguous_range<_Range>' refused `views::keys', and transform_view's iterator `__iterator(__iterator<!_Const>)
requires _Const' instantiated an `__iterator<true>' over a const filter_view. The first writing caught the throw and
left the failed deduction's scope frame open, so every later declaration of the registration went into that frame and
vanished with it (`op.eq.2' of the transform iterator undeclared): the scope is restored now. `memberunmet.cpp'.
(8) A NON-CONST MEMBER IS NO CANDIDATE ON A CONST OBJECT ([over.match.funcs]/5; `cpp_const_viable/1'), a static
member, an explicit object parameter and a closure's `operator()' excepted (const unless `mutable', which is not
marked; the first writing left the closure out, and `invocable<const lambda &, int &>' failed for take_while's
predicate): it was only scored lower, so `range<const transform_view<filter_view<...>>>' held through the non-const
`begin()', and take_view's `end() const' was walked. `constmember.cpp'.

THE VIEWS, each alone against clang++: `transform', `reverse', `iota', `take', `drop', `take_while', `keys',
`values', and the chain `filter | transform | take' give clang++'s output. All eight in one program
(`views2.cpp' of the session) still stop: `auto_result' of the chained `take_view<transform_view<filter_view<...>>>'
after the earlier statements; each piece alone passes, so a memo of an earlier statement is the suspect. Not yet
found.

Reader version 108, lowering version 59; the module rebuilt as 0.113, over cocolog 1.8.38. NO GATE HAS RUN ON THIS
COMMIT either. It is a second save point: each fixture it adds (`stdquoted', `viewiter', `vtobject', `sentbase',
`friendreq', `memberunmet', `constmember') matched clang++'s output in a probe, one at a time, but the seven gates --
which read every header cold at reader 108 -- have not run over 0.112 or 0.113. The rule of (8) changes the member road
for every const object, so the gates are the proof it still owes. The next commit carries their numbers.

## 0.114 — M6's seventy-ninth step

**M6's seventy-ninth step (0.114): the seven gates over 0.113, two defects they found, and cocolog 1.8.41.** 0.112 and
0.113 were save points, committed with no gate run over them. This step runs the seven gates, fixes what they find,
pulls cocolog and runs them again on its new version.

THE GATES ON 0.113, over cocolog 1.8.38: reader GREEN in 8 s, compile 12 s, driver 7 s, objects 2 s, the proof 0 s,
the library read (`test/libcxx.sh`, every header cold at reader 108) 1293 s. The C++ gate was RED, with two failures:

(1) `member.cpp` WAS NO VALID C++. `bag.h`'s `Bag<T>` had only a non-const `operator[]`, and `member.cpp` calls it on a
`const Bag<T> &`. clang++ refuses that program; 0.113's rule (a non-const member is no candidate on a const object,
`cpp_const_viable/1`) refused it too, as it must. The fixture is now valid: `bag.h` adds `const T &operator[](int i)
const`. The output is unchanged.

(2) A MEMBER TEMPLATE'S INSTANCE WAS NAMED FROM ITS UNSUBSTITUTED QUALIFIERS. `cpp_try_member` mangled the instance's
name from the qualifiers as written (`Qs`), and made the instance from the substituted ones (`Qs1`). A member that
carries a requires-clause has the fold of its clause in its name (`.rq<fold>`, 0.112), and the two folds differ, so the
call named a function that was never defined, and the link refused it. `rangesarray.cpp` (ranges::begin over an
array) and `stdformat.cpp` failed so. A worktree at 0.112 failed in the same way, so the defect is 0.112's, which no
gate had run. The name now comes from `Qs1`. The emitted IR changes only where it was wrong; the lowering version
stays 59.

With both: the C++ gate GREEN in 1289 s, 356 checks ok, 300 of 301 fixtures (the one skip is `stdoptionalref`, which
needs libc++ 21), peak 5376 MB.

COCOLOG 1.8.38 TO 1.8.41, reviewed: 1.8.39 (`cff7a70`) makes a load directive that loads nothing print SWI's `ERROR`
and `Warning` lines, then go on; the carried libraries keep `library(error)`, `dcg/basics` and `dcg/high_order`.
1.8.40 and 1.8.41 add the translation library (`library/reasoning/`) and its reports, which cicilang does not use, and
the Docker images and install scripts. The SDK's ABI is unchanged; cocolog and its `os` and `process` modules and both
of cicilang's modules were rebuilt. Every load directive of cicilang names a library that exists, so no new line is
printed. The refused allocation still gives a wrong answer at 1.8.41 (no `oom` check in the step loop).

THE GATES ON 0.114, over cocolog 1.8.41: reader GREEN in 5 s (peak 122 MB), driver 6 s (116 MB), objects 2 s, the proof
0 s. The compile gate's first run was killed by the watchdog at 6000 MB after 775 s, where 1.8.38 took 12 s. It did not
occur again: GREEN in 13 s over the user's store (peak 164 MB), and in 13 s over a new store (peak 175 MB). The cause is
not known; a module rebuilt while the run started is the suspect. The library read GREEN in 1241 s (23 asserted reads,
36 other headers warmed, 0 failed), then the C++ gate GREEN in about 1300 s: 356 checks ok, 300 of 301 fixtures, the one
skip `stdoptionalref`; the two together 2539 s, peak 5415 MB. All seven gates are GREEN on 0.114 over cocolog 1.8.41.

Reader version 108, lowering version 59; the module rebuilt as 0.114, over cocolog 1.8.41.

## 0.115 — M6's eightieth step

**M6's eightieth step (0.115): all the views in one program, and the parts of std::format and the streams that were
not tried.** The owner asked for the work recommended after 0.114: first the views together and their fixtures, then
`std::vformat`, a formatter the program writes, `std::print`, the wide format, the wide streams, `seekg` and `seekp`,
and `cin >> long double`. Each stop was cut to a reduction, compared with clang++ (libc++ where libstdc++ has no such
header), fixed and given a fixture.

THE VIEWS. The single views of 0.113 got their fixtures (`viewiota`, `viewreverse`, `viewtransform`, `viewtakewhile`,
`viewdrop`, `viewtake`, `viewkeys`, `viewchain`). All of them in one program (`viewsall.cpp`, 1627 s) stopped first at
`auto_result` of the chained `take_view`, then at `!=` of `views::keys`. The defects:

(1) A FUNCTION'S RESULT ROLE LEAKED. `cpp_method_body_` set `'$cpp_ret'` and did not restore it on failure or throw, so
a later `return 0;` in `main` went through `vector(size_type)`. It is restored on every exit now.

(2) `this` WAS NOT IN SCOPE in the implicit default constructor while its member initializers were built
(`member_not_constructed('__output_buffer.char', 3)`). `cpp_implicit_ctor_` declares the parameters first now.
`implicitthis.cpp`.

(3) A PARAMETER WHOSE TEMPLATE PARAMETERS ARE ALL GIVEN EXPLICITLY was still deduced (`deduction_failed(
basic_format_args)`). `cpp_explicit_skip` leaves it out of the deduction ([temp.deduct.call]/1 as 0.108 has it for a
non-deduced parameter). `explicitarg.cpp`.

(4) A TYPE REQUIREMENT ATE ITS OWN `typename` (`requires { typename T::key_type; }`), and the read of `<print>` stopped
at `format_kind`. The rule peeks the word now. Reader version 109. `typereq.cpp`.

(5) A REFERENCE PARAMETER OF A CLASS NEVER CLASHED in the arity-only resort: `iota`'s friend `operator-` took a
`filter_view`'s iterator, and `filter_view` became a sized range. `cpp_args_no_clash` looks through the reference.
`friendclash.cpp`.

(6) A PROGRAM'S HIDDEN FRIEND kept the class's own names unresolved (`typedef('It')`): `cpp_friends_resolved` resolves
its result and parameters in the class. A FRIEND TEMPLATE of a member class template is in the class's words
(`cpp_friend_tmpl_words`: the short name of the member class template, the class's typedefs, the class's own short
name), and its body is walked in the class (`'$in_class'`). `cpp_match` names a member class template by its registered
name. A BARE CALL OF A STATIC MEMBER TEMPLATE passes no object (`cpp_static_bare`): the friend called `cur(i)` with a
`this` that is not declared. `friendtmpl.cpp`, and `viewkeys.cpp` again.

THE FORMAT AND THE STREAMS. The defects:

(7) A CONVERTING CONSTRUCTOR TEMPLATE over a template-id matched any instance of the template: `cpp_match` lets an
element that is no parameter pass, so `basic_format_args<wformat_context>` took `__format_arg_store<format_context,
...>`, and `std::vformat` chose the wide overload. The substituted parameter must be the argument's class now.
`ctorctx.cpp`.

(8) RAW STRING LITERALS were read by neither lexer. libc++ 18's escaped-string writer writes `R"(\')"`, and the read of
`<format>` stopped there at C++23 (`std::print`). Both lexers read `R"d(...)d"` and its prefixes `u8`, `L`, `u`, `U`
in C++ (`ccl_raw_prefix//1`, `ccl_raw_body//4`; `ccl_lx_raw_start`, `ccl_lx_raw`); `test/c/lexer.c` has them, and
reader check `k84` compares both lexers on them. A raw string that spans lines is read by the lexers; the
preprocessor's line splitting does not know it. Reader version 110; the module rebuilt.

(9) THE REVERSED `==` CANDIDATE (C++20, [over.match.oper]/3.4.4): `sentinel_for<__nul_terminator, const char *>` asks
`__nul_terminator == p`, and libc++ writes only `operator==(const _CharT *, __nul_terminator)`. `cpp_rewritten_cmp`
tries `operator==(y, x)` from C++20, once per pair; `!=` takes a class on either side. `reversedeq.cpp`.

(10) `Loop()(1, 2);` WAS A DECLARATION OF NOTHING: an unnamed declarator with an initializer. The call was dropped, and
libc++'s `ranges::copy` copied nothing. An init-declarator must name what it declares now ([dcl.decl]/1). Reader
version 110. `tempcallstmt.cpp`.

(11) THE CALLER'S OBJECT LEAKED INTO AN EMISSION. A member template emitted while a const object's call was chosen was
walked with `'$cpp_obj_const'` still `const`, so `*__result = *__first` in `__copy_loop::operator() const` found no
`back_insert_iterator::operator=` and stored a `char` into the iterator. `cpp_isolated` sets the object's constness
and value category aside. `isolatedobj.cpp` (it fails on the library without the fix).

(12) A C STRUCT REGISTERED AS A CLASS lost its linkage name in the mangler: glibc's `_IO_FILE` is a library class once
a header load registers it, and `__is_posix_terminal(FILE *)` kept its plain name, an undefined symbol at the link of
every `std::print`. A tag indexed under `c` (an `extern "C"` scope) is a C struct to the mangler (`cpp_ita_c_tag`).
`stdprint.cpp`.

(13) THE WIDE FORMAT took the narrow overload by three loose tests: a constructor template converted any argument
(`cpp_converting/2` now deduces its parameter and checks its constraints, `cpp_ctor_tmpl_takes`); `is_convertible`
asked `cpp_converting/1`, which ignores the source type (it asks `cpp_converting/2` with the source now); and a
pointer to one arithmetic type converted to a pointer to another (`cpp_arith_pointee_differs`). `wideformat.cpp`.

(14) A WIDE LITERAL IN A CONSTANT: the evaluator reads `L"..."`, `u"..."` and `U"..."` as their code units and
`wcslen` over them, and a pointer into such a cell spells back as the literal; the lowering spells it in a global's
constant (`ir_wide_lit`). `__bool_strings<wchar_t>::__true` was an undefined symbol. Lowering version 60. `widesv.cpp`.

(15) A STATIC DATA MEMBER OF A LIBRARY CLASS TYPE in the program's class was declared under its written type, a struct
with no class registered, and `Words::yes.size()` stayed a raw member call. `cpp_declare_statics` resolves the type
through the template road for the program's classes (for every class it took std::format past 3.5 GB).
`staticsv.cpp`.

What runs now, with its fixture: `std::vformat`, `std::make_format_args`, `std::formatted_size` and
`std::format_to_n` (`stdvformat`); a `std::formatter` the program specializes (`stdformatter`); `std::print` and
`std::println` at C++23 (`stdprint`); `std::format(L"...")` (`stdwformat`); `std::wcout`, `std::wostringstream` and
`std::wistringstream` (`stdwstream`); `seekg`, `tellg`, `seekp` and `tellp` on `istringstream` and `ostringstream`
(`stdseek`); `cin >> long double` and the fail state after it (`stdcinld`). `std::stringstream` does not build:
`basic_iostream` is libc++'s own diamond, and the base-variant constructors and destructors (C2, D2) of library
classes are not made.

THE GATES ON 0.115, over cocolog 1.8.41 (`test/gates.sh`, four lanes): reader GREEN in 11 s, compile 23 s, driver 11 s,
objects 3 s, the proof 0 s. The library read GREEN in 2211 s, every header cold at reader 110 (23 asserted reads, 39 other
headers warmed, `<print>` among them, 0 failed). The C++ gate GREEN in 3283 s: 384 checks ok, 328 of 329 fixtures (the
one skip is `stdoptionalref`, which needs libc++ 21). The slowest fixture is `viewsall` (1759 s in the pool); the new
format and stream fixtures take 199 s to 421 s. All seven gates are GREEN on 0.115.

Reader version 110, lowering version 60; the module rebuilt as 0.115, over cocolog 1.8.41.

## 0.116 — the rename

**The rename (0.116): cocolang is cicilang.** The owner renamed the repository from `cocolang` to `cicilang` and asked
for every `cocolang` in the tree to follow. Both names have eight letters, so no string length moved (`proof/forty2.ll`
keeps its `[19 x i8]`).

What changed: the files `bin/cicilang`, `bin/cicilang++`, `module/cicilang.cicili` and `bench/btree/btree_cicilang.c`
(`git mv`); the library `library(cicilang)` and `library/cicilang.so` (the module's `coco-deflibrary` name and its
`(source "cicilang.c")`); the four doors `cicilang_ast/2,3`, `cicilang_ir/2`, `cicilang_compile/3` and
`cicilang_link/3`; the variables `CICILANG_KB`, `_INCLUDE`, `_LANG` and `_ME`; the user's cache `~/.cicilang`; the answer
lines `cicilang: ok` and `cicilang: N error(s)` and the filter in `bin/cicilang` that keeps them; the header guards
`_CICILANG_<NAME>_H`; the temporary names of the gates; the push URL; and the words in the documents, this record
included. What stays: `cocolog` and the SDK's `coco_*` names (the neighbour's), the `ccl_` prefix, and `.cicili`,
`sdk.cicili` and `$CICILI`.

The cache was moved by hand (`mv ~/.cocolang ~/.cicilang`); the reader and lowering versions did not move, so the
summaries and the store stay valid. A user who keeps the old directory gets a cold cache.

GATES, all seven GREEN on 0.116, over cocolog 1.8.41: the reader 95 ok (2 skips: Cicili's two example files are not
here); the compile gate 101 ok (58 run, 43 refused), 13 s; the driver gate 26 ok, 7 s; the objects gate 29 ok, 3 s; the
proof exit 42; the library read GREEN in 1558 s (peak 1703 MB), cold, because the edited `library/include` headers
changed their times; the C++ gate GREEN in 2542 s (peak 4593 MB), 384 checks ok, one skip (`stdoptionalref`, which needs
libc++ 21). The commit b527c80 was made before they finished.

THE FIRST COMPILE-GATE RUN WAS RED, and it was the store. The gate ran over the user's store at `~/.cicilang/KB`, which
the earlier runs had written, and it grew to the 7000 MB cap and then to 9000 MB without an answer; three runs. Each of
the 101 fixtures built alone through `bin/cicilang` in under 5 s; the commit before the rename (a worktree at 3332f98,
built) went GREEN in 16 s over a fresh store, and so did this tree (17 s, 174 MB). The store was removed
(`rm -rf ~/.cicilang/KB ~/.cicilang/KB.version`, the repair CLAUDE.md names) and the gate went GREEN in 13 s. The cause
of the damage is not found: the store had been copied by `mv` from `~/.cocolang`, and a watchdog and a `pkill` had
killed cocolog runs over it before. Named, not fixed. After a rename that moves the store, remove it too.

Reader version 110, lowering version 60; the module rebuilt as 0.116.

## 0.117 — M6's eighty-first step

**M6's eighty-first step (0.117): the "not done" list, worked.** The owner asked to pull the neighbours and finish the
"not done" works. ZiguratIP was rebuilt and cocolog moved from 1.8.41 to 1.9.1 (a header of the SDK moved; both
modules were rebuilt). The baseline came first: the seven gates of 0.116 over cocolog 1.9.1, in a worktree and a HOME of
their own, were all GREEN (reader 95 ok, compile 101 ok, driver 26 ok, objects 29 ok, the proof, the library read 542 s
over 23 asserted reads, the C++ gate 2588 s, 384 checks ok and one skip, peak 5676 MB). Then each entry of CLAUDE.md's
"Not done" section was cut down to a reduction of 10 to 40 lines, built with clang or clang++ (`-stdlib=libc++`, to
match the libc++ 18 that cicilang reads) and with cicilang, compared line by line, fixed and given a fixture. What was
a limit of the language, or by design, stays and is said so.

This commit is a SAVE POINT, as 0.112 and 0.113 were: the baseline above is the only gate run of the step, and NO GATE HAS RUN ON THE CODE
BELOW. Each fixture it adds matched clang++ in a probe, alone, over a cache of its own; the seven gates -- which read every header cold at
reader 114 -- run in the next commit and carry their numbers.

BATCH A: C, the ABI and the mangler.

(1) THE ITANIUM MANGLER spells a function type (`F<ret><params>E`), an array (`A<n>_<elem>`) and a pointer to member
(`M<class><type>`) as a parameter (`cpp_ita_type_`, `cpp_ita_fparams/6`: an array or function parameter is a pointer,
the top-level `const` goes; `cpp_ita_whole/5`: the whole type is a substitution candidate). `c37`
checks `PFvizE`, `RA4_i` and `PFvvE` with `S1_`, the symbols `std::set_terminate(void (*)())` is shipped under.

(2) PLACEMENT NEW OF AN ARRAY: `new (p) T[n]`, `T[n](...)` and `T[n]{...}` are a loop of placement news over the address,
with no cookie, and the result borrows the placement address (`cpp_new_at_array`; the `$at` gensym prefix is what
`ck_borrows_from` reads). `placearray.cpp`.

(3) A LOCAL ARRAY OF ARRAYS OF OBJECTS is constructed and destroyed element by element (`cpp_elem_class` peels the
array layers), and so is a `static` local array of objects: the Itanium guard (`__cxa_guard_acquire`/`release`), the
construction once, and a wrapper `$cpp_sdtor.N` registered with `__cxa_atexit` (appended through `'$cpp_ginit_fns'`,
`cpp_ginit_items`). Nested braced items that are prvalues of the element class are the elements. `localarray2.cpp`.

(4) A VLA INITIALIZED BY `= {}` (C23 6.7.10) zeroes with `llvm.memset` in `ir_locals`; any other VLA initializer is still
refused, `vla_initialized(N)`. `test/c/run/vlaempty.c` (`-std=c23`).

(5) `va_arg` OF A STRUCT, A UNION, A COMPLEX AND AN `__int128` on x86-64 (SysV 3.5.7): `ir_va_arg_aggregate` reads the
register save area by the class of each eightbyte, else the overflow area, 16-aligned where the type is. AAPCS64 stays
refused, `va_arg_of_aggregate`. `test/c/run/vaaggregate.c`.

(6) THE SysV REGISTER BUDGET (3.2.3). A struct that classifies `direct` goes in registers only if all its eightbytes
find a free register of their class; else the whole struct goes in memory (`byval`), though a later argument may still
take the registers. `ir_regs_start/ir_regs_take` are threaded through the declare (`ir_params_lls`), the define
(`ir_params`) and the call (`ir_args_`, the variadic tail too); an sret result takes one INTEGER register, a scalar one
of its class, an `__int128` two. The link fixture grew two lines (`budget_*` built by clang, `bud_*` by cicilang;
`test/c/link/abi.h`, `abi_helper.c`, `abi_main.c`) and the driver gate's expected line count moved from 5 to 7. The old
library fails the new lines (checked).

(7) `__int128` AND `unsigned __int128` are types: the reader (`ccl_gnu_word('__int128')`, `ccl_basic_type`), the typedef
names `__int128_t` and `__uint128_t` (`ccl_builtin_typedef/2`), a rank above `long long`, size and alignment 16, LLVM's
`i128` (`ir_base`), the mangler's `n` and `o`. A constant of the type that folds is spelled in a global
(`ir_gconst`, `big(A)` through `ir_big_text`). `__SIZEOF_INT128__` is predefined for C only: C++ keeps libc++'s
no-int128 configuration by design. Reader check `k92`; `test/c/run/int128.c`, `test/cpp/run/int128.cpp`.

(8) A BUG FOUND BY (7): `_Static_assert(sizeof(T) == 16)` over a struct failed in C since 0.57. `ccl_assert_holds` did
`ccl_const_eval(E, V), V =:= 0`, backtracked into the evaluator, and `sizeof` had four answers (16, 0, 0, 0). The
assertion asks `once/1` now and `sizeof`, `sizeof_type` and `alignof_type` fold to one answer. `test/c/run/sizeofassert.c`.
Also found, not chased: `ir_type` asked of an UNRESOLVED typedef of an anonymous struct, before the resolved form,
broke a later member lookup (`no_member(b, struct(anon...))`); `ir_regs_take_` resolves first.

BATCH B: the language.

(9) DEDUCING `this` ON A CLASS'S METHODS (C++23): `this auto &&self`, `template <class Self> ... this Self &&self`, `this
const Node &self`, `this Node &self`, `this Node self`. The object of the call is the FIRST ARGUMENT of the candidate
(`'$cpp_obj_expr'`, set by `cpp_method_on` and `cpp_method_on_ptr`, set aside by `cpp_isolated`; `cpp_member_holding`
makes it the first argument of a candidate with `explicit_this(N, T)`), so `Self` is deduced from the object like any
argument: an lvalue gives `D &`, a prvalue `D`, a derived object the DERIVED class, which is the CRTP's replacement.
`cpp_this_auto` invents `$A1` first among the member template's parameters; `cpp_subst_quals` substitutes
`explicit_this`; an `auto` result is the first return with the object parameter in scope (`cpp_method_ret`).
`operator()`, `[]`, `==` and `+=` work. `deducethis.cpp` (C++23). `test/cpp/deduced_this.cpp`, the refusal that stood
since 0.43, is removed with its entry in `test/cpp.sh`.

(10) NOT A LIMIT: a captureless lambda with an explicit object parameter has no conversion to a function pointer
([expr.prim.lambda.closure]/8). clang++ 18 refuses it too. The entry is gone from "Not done".

(11) `mutable` LAMBDAS. The reader keeps `mutable` among the captures (`ccl_lambda_specs/1`; reader check `c38`).
`cpp_lambda_const_check/3` refuses `assign_to_capture(N)` for an assignment, an increment or a decrement whose left side
is a by-value capture, or a member of one, in a lambda that is not mutable. A name declared inside (a nested lambda's
parameter, a local) hides the capture (`cpp_declared_names/2`), and a write through a copied pointer is the pointee's.
The closure's `operator()` is still never `const`. `lambdamutable.cpp`; `test/cpp/lambda_const.cpp` is refused.

(12) ACCESS CONTROL for the program's own classes. A `class` starts private, a `struct` and a `union` public;
`public:` and kin move it on; `using Base::m;` puts `m` under the access it stands at; an overload set is as open as
its most open member. `cpp_register_class/5` takes the class kind and notes `'$cpp_acc'(Class, Name, Access)`
(`cpp_note_access`), with `'$ctor'` and `'$dtor'` for the special members and `'$cpp_afriend'(Class, class(F) | fn(F) |
any)` for the friends. `cpp_check_access/3` asks where the walk NAMES a member: `x.m`, `p->m`, a bare member in a member
function or a derived class, a method call (`.`, `->`, bare, `C::f()`), the constructor chosen for a local and for a
`new`. The code may name a private member from its own class and the classes it is nested in (`cpp_access_scopes/2`
through `'$cpp_enclosing'`, a closure's through the class it was made in), a protected one from a derived class, and a
friend's: a class by name or instance, a function by `'$cpp_cur_fn'` (set by `cpp_with_fn/2`; a friend function
template's instance is `F.<keys>`, `cpp_fn_is/2`). The refusal is `access(Kind, Owner, Member)` with the statement's
line (`'$cpp_line'`). The reader keeps `friend class X;` as `friend(L, [friend_class(Q)])`, and that clause stands
BEFORE the one that reads a friend declaration as a member; behind it `friend class X;` was `nested(class(X, none))` and
no friend was noted (the first run of `c38` found it, and the permissive `any` that had hidden it). Not asked: an
inheritance's own access, a pointer to member, a nested type, a destructor, an operator used as an operator, and
[class.protected]'s rule on the object's type. `accessctl.cpp`, `accessctl2.cpp` (the allowed forms); `test/cpp/access_data.cpp`,
`access_method.cpp`, `access_protected.cpp`, `access_ctor.cpp` and `access_base.cpp` are refused.

(13) LIBRARY CALLS THE SAFE PART REFUSED. A library static function's pointer result is a borrow of the object it takes
by reference (`allocator_traits<A>::allocate(a, n)`: `ck_borrows_from` with the leading null `this`), and a library
function's pointer result borrows what its pointer arguments borrow (`std::construct_at(p + 2, 42)`). `stdallocator.cpp`,
`stduninit.cpp` (C++20: `construct_at`, `destroy_at`, `destroy`, `destroy_n`, `uninitialized_copy`, `_fill`, `_move`,
`_default_construct`, `_value_construct` and their `_n` forms).

(14) SCALAR DYNAMIC INITIALIZATION (C++): `int g = f() * 2;`, `static int h = g + 4;`, `const int k = f();`, `double d =
f() / 2.0;`, `Color c = pick();`, `int br{f(3)};`, `int *p = &arr[2];`, and a static member defined out of its class
(`int A::v = A::compute() * 2;`, in the class's words through `'$in_class'`). The global stays zero and the RAW
initializer is assigned in `$cpp_ginit`, in declaration order, in the list that holds the class-typed globals
(`cpp_dynamic_scalars/7` after `cpp_fold_const_inits` and in the scoped-static clause; `cpp_runtime_init/1` decides: a
call that did not fold, a read of a variable, a dereference, a member, an index, an assignment, `new`, the address of
anything but a name). Constants stay what they were. Never `thread_local`, `extern`, a class, an array or a reference.
`globalscalar.cpp`. A file-scope `int *p = new int(7);` is still refused, `no owner behind`: the safe part's rule.

(15) A NESTED CLASS CALLS A STATIC MEMBER FUNCTION OF ITS ENCLOSING CLASS BY NAME (`compute()` inside `A::N::get`): a
`cpp_call` clause over `cpp_encl_chain` and `cpp_static_bare`. It was `undeclared(compute)`; the data statics had it
since 0.112. `accessctl2.cpp`.

(16) NESTED LAMBDAS. `cpp_capturable/3` accepts a local or a capture of the enclosing closure, in the explicit and the
default captures: `[a]{ return [a]{ ... }(); }` sees the outer closure's members. `[this]` inside a lambda that
captured `this` captures THE OBJECT (`cpp_captures_this` returns the object's class, `cpp_this_item/3` its address
`addr(arrow(this, '$this'))`). `lambdanest.cpp`.

BATCH C: the streams.

(17) `std::stringstream`, `std::wstringstream`, `std::ofstream`, `std::ifstream` and `std::fstream` build and run, and a
program class derived from `std::ostream` and from `std::iostream` over its own streambuf. The defects, each cut to a
reduction:

- `cpp_nv_twin` no longer refuses a library class: libc++'s `basic_iostream`, a diamond over `basic_ios`, gets its
  path bases' base-variant constructors (`C.C.k.nv`) compiled; `basic_istream(sb)` and `basic_ostream(sb)` are inline in
  the class.
- A derived class fits a LATER base (`cpp_class_fits/2` through `'$cpp_base_slot'`; `cpp_class_base_instance/4` for the
  deduction of `basic_ostream<_CharT, _Traits> &` from a stringstream, whose `basic_ostream` is the SECOND base of
  `basic_iostream`).
- A member `operator<<(long long)` over an `fpos`'s `operator streamoff()` is as good as an exact match
  (`cpp_arg_conv_exact`): `cout << os.tellp()` printed the byte 6.
- A constructor or destructor defined out of its class keeps `inline` and the hidden mark (reader 112: `ctor_def` and
  `dtor_def` carry their prefix qualifiers, `ccl_prefix_quals/2`; `cpp_mdef_inline` reads them): `inline
  basic_ofstream<...>::basic_ofstream(const char *, ...)` is compiled, not called by a symbol no library exports.
- A member of an instance whose class is NOT laid out as the ABI lays it is compiled, never called by its shipped
  symbol (`cpp_nonabi_bases`, `'$cpp_nonabi'`): the program keeps `__sb_` of an `ofstream` at offset 160 (the virtual base
  last, as the Itanium ABI has the complete object), libc++'s exported `basic_ofstream<char>::open` wrote it at 8. A
  diamond's holder (`basic_iostream`) keeps its layout and its shipped members (`\+ cpp_shared_vbase`); a first version
  of the rule broke `<iostream>` (`undeclared('..D1Ev.nv')`).
- CONVERSION COUNTS SURVIVE NESTED CANDIDATE CHECKS (`cpp_conv_enter/1`, `cpp_conv_leave/1` on the free, member and
  constructor roads): a candidate whose signature asks a trait ran nested holding sets that reset the counter, and
  `out << "x"` on an `ofstream` chose the filesystem path's friend inserter (1 conversion) over `const char *` (3).
- A derived-class pointer to a base-class pointer outranks the conversion to `void *` (`cpp_void_for_class`):
  `cout << is.rdbuf()` printed the address.
- A path base's shipped destructor with an EMPTY header definition is left out of the diamond (`cpp_nv_dtor`):
  `std::wstringstream` (libc++ ships `basic_iostream<char>` only).
- C FUNCTIONS THAT SHARE A NAME WITH A LIBRARY TEMPLATE: `cpp_mangled_name` never mangles a name the C library declares
  (`cpp_header_c_name`), and `cpp_c_decl_current/2` emits the C prototype as an item when the table's entry for the name
  is another overload's. `std::remove(path)` after `<fstream>` had met the algorithm's `_ForwardIterator`.
- READER: a local variable hides a typedef name (`ccl_local_variable/1`, reader 112). `const char *path` beside the
  filesystem's `path` made `std::ofstream out(path);` a function declaration.

`stdstringstream.cpp`, `stdfstream.cpp`, `streamderived.cpp`. Not done: `std::filesystem` itself (a `path` method meets
`_PathCVT::__append_range`, which refuses `typedef(tmpl(basic_string, ...))`), and the wide file streams.

(18) A RANGE-FOR OVER A BRACED LIST (reader 112): `for (int v : {4, 9, 1, 7})` was a syntax error (found by a
`std::deque` probe). The list is the backing array of the `initializer_list` it would make: a local array of the first
item's type (decayed and unqualified as `:=` has it) in a block of its own, iterated as any array is
(`ccl_range_expr//1`, `ccl_range_stmt/5`). An untypable first item keeps the braced range, which the desugaring refuses
by name. `rangeforbraced.cpp` (C++20), reader check `c39`.

(19) A MEMBER OF A NESTED CLASS BUILT FROM A PRVALUE OF ITS OWN CLASS: `class udist { class param_type {...}; param_type
p_; udist(int a, int b) : p_(param_type(a, b)) {} };` was `member_not_constructed(p_, 'udist.param_type', 1)`.
`cpp_init_arg_class/2` desugared the argument with no context, where the nested class's short name `param_type` is no
name; it uses the class being built now (`cpp_class_ctx`). Found by `<random>`'s `uniform_int_distribution`. `nestedinit.cpp`.

BATCH D: the library pieces nobody had tried (`<complex>`, `<random>`, `<bitset>`, `<chrono>`, `<string>` literals, `<valarray>`,
`<span>`, `<charconv>`, `<thread>`, the views, `std::format` of ranges). Thirteen probes of 10 to 30 lines were compared
with clang++/libc++ one by one; each stop was cut to a reduction, and the ones below were fixed. The cause was in the
reader or the desugaring, not in the library, every time (reader version 113).

(20) A KEYWORD AS A LITERAL OPERATOR'S SUFFIX: libc++'s `<complex>` defines `operator"" if` (for `1.5if`), and the item
loop stopped there with the whole `namespace std { ... }` unread (`template_without_body(complex)`). The suffix of
`operator""` is an identifier or a keyword now (`ccl_op_name`).

(21) A CONVERSION FUNCTION DEFINED OUT OF ITS CLASS was a syntax error for a class template and a function returning the
class for a class (`S::operator int() const { ... }` read with `S` as its result, named `::operator int`). The name's type
is `ccl_conv_type` (specifiers and pointers; `int ()` was a function type), and an explicit rule reads the definition
(`X<E>::operator valarray<R>() const`) as a function whose result is the conversion type. `<valarray>` stopped at it.
`convout.cpp`, reader check `c41`.

(22) A VALUE TEMPLATE PARAMETER HIDES A TYPEDEF OR A TEMPLATE OF ITS NAME. The class-scope names of every class read before
stay in the env (an out-of-class member's body needs them), and a `typedef ... _Size;` in one of libc++'s classes made
`bitset<_Size>` of `template <size_t _Size>` a TYPE argument: none of std::bitset's members defined out of the class
matched `bitset<16>`, and they were undefined at the link. `template <size_t __count, __enable_if_t<__count < _Dt, int> =
0>` of `<random>` read `__count <` as the algorithm `std::__count`'s template-id. `'$ccl_vparams'` frames and `'$ccl_vhead'`.
`valueparam.cpp`.

(23) A DECLARATION-SPECIFIER BEFORE `friend`: `constexpr friend difference_type operator-(...)` (libc++ at C++20) was no
friend, and `std::bitset::count()` met `no_operator(-)`. `friendprefix.cpp`.

(24) USER-DEFINED LITERALS, which no one had written down as missing: `5_km` was a syntax error, and `1500ms` of `<chrono>`
read as `0`. The reader makes a literal followed by an identifier `udl(Suffix, Literal)`; the preprocessor kept the
pp-number `5_km` as one token the lexer cuts in two and `pp_norm` turned into zero (`pp_norm_toks`); the desugaring calls the
free operator `op.literal_<suffix>.<arity>` over the literal as the standard hands it over; a header's literal operators
are indexed, noted and emitted lazily (`cpp_index_name`, `cpp_note_hdr_fns`, `cpp_register_lazy`). `"hello"s` and `"world"sv`
run against libc++. `userliteral.cpp`, `stdliterals.cpp`, reader check `c40`.

(25) THE CONSTANT FOLDING OF A LEFT SHIFT did not wrap: `intmax_t(1) << 63` was +2^63 where clang folds -2^63, so libc++'s
`-((intmax_t(1) << (sizeof(intmax_t) * CHAR_BIT - 1)) + 1)` (`INTMAX_MAX`, `duration::__no_overflow`) was -2^63 - 1 and every
`__no_overflow<...>::value` false: no duration converted to a coarser or finer one, `seconds` to `milliseconds` included. The
shift wraps in the promoted type of its left operand (`ccl_shl_wrap`). `shiftwrap.cpp`.

(26) A FOLDED STATIC CONST LOST ITS TYPE: `static const long long v = -3;` named `A::v` was the int literal -3, and
`printf("%lld", A::v)` printed 4294967293 (libc++'s `ratio<-1, 2>::num`). It keeps the member's arithmetic type as a cast
(`cpp_static_value`). `staticconsttype.cpp`.

(27) THE CONVERSION FUNCTION WHOSE RESULT IS THE TARGET comes first, and a conversion function's NAME is substituted with the
class's arguments (`operator T()` of `S<long>` is `operator long()`; it stayed `operator T()`, and `long t = s;` took the first
arithmetic conversion function declared); a definition out of the class is found by kind and compared once substituted.
`convin.cpp`.

(28) A CLASS VALUE RETURNED WHERE A SCALAR IS WANTED converts through its conversion function: libc++'s `bitset::test` returns
its `__bit_const_reference` as a `bool` and was compared with zero as a struct (an LLVM error). `returnconv.cpp`.

(29) A HIDDEN FRIEND OF A LIBRARY CLASS SEES THE CLASS'S STATICS: `__bit_iterator::__bits_per_word` in the friend `operator-`
was `undeclared`.

(30) AN ARRAY MEMBER'S BRACED INITIALIZER: `: __first_{0}` (the reader's one-item `init`) and `: n_{5, 6}` (several items) were
`lvalue(int(0))` or ignored; libc++'s `__bitset` left its words uninitialized. `arraybrace.cpp`.

(31) THE MEMBERS OF A PARTIAL SPECIALIZATION DEFINED OUT OF ITS CLASS (a SILENT WRONG ANSWER, found by the bitset probe printing
`count()` 8 for an empty set). An out-of-class constructor or destructor lost its class's template-id, so `__bitset<1, _Size>::
__bitset()` and the primary's `__bitset<_N_words, _Size>::__bitset()` and the explicit `__bitset<0, 0>::__bitset() {}` were all
`ctor_def(L, __bitset, ...)`, every definition applied to every instance, and the first registered won: `bitset<16>` ran the
constructor of `__bitset<0, 0>`, an empty body, and the primary's loops over a one-word class. The reader keeps the pattern as the
qualifier `pattern(Args)`, and a specialization's definitions are tried before the primary's (`cpp_special_pattern`).
`specmember.cpp`.

(32) BRACED TEMPORARIES AND THE initializer_list CONSTRUCTOR ([over.match.list]/1; found by a `std::vector<std::string>{"a",
"b"}` argument): `T{a, b}` was the call `T(a, b)`, so a class with an `initializer_list` constructor took the items as
constructor arguments -- the iterator-range constructor for two `const char *` (`instance_refused(...)`), the (count, value)
one for `std::vector<int>{5, 1}`, five elements for `std::vector<int>{5}`. The reader marks a non-empty braced temporary
`braced_temp(call(T, Values))` (the empty list stays the call, value-initialization), the inference types it as the call, and
`cpp_expr` asks `cpp_braced_class/3` (the type hook, never a name over an unbound parameter) and `cpp_il_braced/3`: a
non-empty list that is not one item of the class itself or a class derived from it ([dcl.init.list]/3.2: `std::vector<int>{v}`
copies) whose items a class element type takes (`cpp_il_class_items_fit/2`) goes through `cpp_init_list/4` and the list
constructor; any other form is the call it was. The same rule serves `return {"a", "b"}`, a braced argument to a class
parameter and a nested braced item (`std::vector<std::vector<int>> v = {{1, 2}, {3}}`). `cpp_init_list` takes the caller's
context: a local `std::vector<int> v{n_, m_}` in a method named its members with no `this`. `tempinitlist.cpp`.

(33) A BRACED LIST CONVERTS TO AN `initializer_list<T>` PARAMETER when each item fits T or T's converting constructor takes it:
`std::vector<std::string>({"x", "y", "zz"})` scored 0 for the list constructor (a `const char *` is no `std::string` to the
fit), so the arity alone chose `explicit vector(const allocator_type &)` and handed the allocator three strings
(`no_constructor(allocator<string>, 3)`). `cpp_il_elem_fits/2`.

(34) A RANGE-FOR OVER A PRVALUE OF A CLASS WITH A DESTRUCTOR DESTROYED IT TWICE (a double free, since the range-for of 0.41):
`for (auto x : std::vector<int>(3, 7))`. The range's temporary was registered with the loop statement, and the `auto &&`
declaration the loop makes is a statement of its own whose elision looked in its own register and found nothing; the loop's
statement takes the temporary out first (`cpp_temp_elide` before the declaration). A call returning the vector by value was
never registered and always worked. `tempinitlist.cpp`.

(35) MORE THAN ONE `auto` DECLARATOR (reader 113; found by `<complex>`'s `auto q = a / b, s = a - b;`): the declaration read
its first initializer as an EXPRESSION, so the comma took `s = a - b` for a comma expression and the declaration named `q`
alone (`not lowered yet: auto(q)`) -- in a block and at file scope, and so for the idiom `auto it = v.begin(), e = v.end();`
outside a `for`. Each declarator is read with an ASSIGNMENT-expression and deduced alone (`ccl_auto_more//3`,
`ccl_auto_next//3`, a `'$splice'/1`). `autodecl.cpp`.

(36) `std::span` (found by the bitset probe, which also used one): `span<int>` instantiated the PRIMARY with the extent
2^64 - 1 and its members' `_Extent * sizeof(element_type)` ran past 4 GB. `span<_Tp, dynamic_extent>` is a partial
specialization on a NAME (`inline constexpr size_t dynamic_extent = numeric_limits<size_t>::max()`) whose value is past
what cocolog's integers hold: three defects stood between the pattern and the argument. The pattern's value was evaluated
by `ccl_const_eval` alone, which knows no name that a constexpr call defines (`cpp_value_of` asks the template argument's
own road); two values past 2^60 are `big(Atom)`, a decimal atom when computed and a hex one when written, and were compared
with `=:=` (`ccl_w_cmp`); and a file-scope `constexpr` initialized by a call was folded once, the first attempt only
emitting the library instances the call runs through (twice now). `span<int>` passed where a `span<const int>` is wanted is
item (42). `stdspan.cpp` (C++20).

(37) THE MATH BUILTINS WITH AN int OR A POINTER AMONG THEIR PARAMETERS: `<complex>`'s division calls `std::scalbn` and
`std::logb`, `__builtin_scalbn` was `undeclared`. `scalbn` and `ldexp` take (T, int), `frexp` (T, int *), `modf` (T, T *),
`ilogb` answers an int (`cpp_math_odd/4`).

(38) A FAILED STATEMENT IN THE LOWERING RE-EMITS THE ONES BEFORE IT (found by `std::bitset<70>`'s `w2 = w << 2;`; a latent
defect of the lowering since the start): nothing undoes an emitted line, and `ir_stmts` leaves the choice points of every
statement, so a failure in a late statement backtracked into the resolver of an earlier one and the body was lowered AGAIN
-- the first copy's allocas stayed, LLVM refused `multiple definition of local value named 'w.101'`. The failure itself was
`ir_leaves` of an array member whose element type is the unresolved `typedef(size_t)` (`__bitset<2, 70>`'s `unsigned long
__first_[2]`): no size, no ABI. The element is resolved first. Named, not fixed: a statement that fails and succeeds the
second time would run twice when the statements before it have no declaration to give them away. `bs71`, `stdbitset.cpp`.

(39) THE MANGLER LOOPED ON `std::byte` (found by `std::vector<std::byte>`, 4 GB in ten seconds; a defect since 0.94, hidden because
no library function had a `byte` among its template arguments): a nested enum is a type of its holder (`Enclosing.Name` in
`'$cpp_class_types'`), and `cpp_class_scope_` took ANY class typedef whose target was the enum for its holder -- `typedef _Tp
value_type` of `__split_buffer<std::byte, ...>` made `std::byte` a member of that buffer, and the chain of names it built named
itself. The typedef must carry the enum's own last name. `stdbyte.cpp`.

(40) A BUILT-IN OPERATOR OVER A CLASS WITH A CONVERSION FUNCTION (found by `std::vector<bool>`'s `count += v[i]`, `no_operator(+=)`):
C++ applies a non-explicit conversion function to an operand of a built-in operator ([over.match.oper]/3.3), and this refused the
form. After the class's own operators, the free ones, the enumeration ones and the rewritten comparisons have answered nothing, the
operator is the built-in one on what the function gives (`cpp_builtin_via_conv/4`); `m * 2` over `operator double`, `-c`, `~c`.
`convarith.cpp`.

(41) THE INTEGER ABSOLUTE VALUES AND A KEYED QUALIFIED CALL: `std::abs(-4L)` met `undeclared('__builtin_labs')` (libc++'s
`<stdlib.h>`), now `__builtin_abs`, `labs`, `llabs`. With `<complex>` included `std::abs` is the KEY `std.abs` (complex's template: two
namespaces declare the name, and the deeper one is keyed), so `std::abs(x)` of a double was `deduction_failed(complex)` and
`std::norm(z)`, which calls it, too: the plain overloads in the outer namespace, which `using ::abs` brings into std, are tried when the
key's refuse (`cpp_bare_fn/1`). `stdcomplex.cpp`.


(42) THE QUALIFICATION CONVERSION THROUGH AN ARRAY (found by `stdspan.cpp`: `sum(sp)` of a `span<int>` over `void sum(std::span<const
int>)`): the argument was stored into the parameter's struct BITWISE, and LLVM refused the module (`'%t8' defined with type
'%struct.span.int...' but expected '%struct.span.const_int...'`). libc++ 18's converting constructor `span(const span<_OtherElementType,
_OtherExtent> &)` requires `__span_array_convertible<int, const int>`, that is `is_convertible_v<int (*)[], const int (*)[]>`, and
`cpp_quals_added` had no clause for an array: an array's element carries the array's qualifiers ([basic.type.qualifier]/3), so
`int (*)[]` converts to `const int (*)[]`. Named, not fixed: a class passed to a parameter of ANOTHER class that no constructor takes
reaches the lowering as a bitwise store of two different structs, an LLVM error where a refusal by name would say more.

(43) THE CHOSEN FUNCTION DECIDES THE OBJECT OF A BARE CALL, NEVER THE NAME (found by `std::vector<bool>`: its first `reserve` was a
segmentation fault; a defect since 0.47): the class declares `void swap(vector &)` and `static void swap(reference, reference)`, and
`swap(__v)` in `reserve` went out with a null `this` because `cpp_static_bare/2` asks whether the NAME has a static overload.
`cpp_static_bare/3` asks with the mangled name the member road chose (`cpp_method_on_ptr`); a static function still takes its unused
`this`, so a wrong answer costs nothing. gdb named the frame (`swap.c3.size_t_p` called from `vector<bool>::swap` with a null
object) and the IR showed `call void @...swap...(ptr null, ptr %__v.16)`. `vectorbool.cpp` (`push_back`, `reserve`, `resize`, `flip`, `assign`,
`insert`, `erase`, the proxy, the static `swap` of two proxies, a copy, a comparison).

(44) A BASE NAMED BY A TYPE PARAMETER OR BY AN ALIAS (the "Not done" entry of 0.93, cut to a reduction): `template <class B> struct D : B
{ int y; }` over `struct P { int x; }` refused `base_not_registered(P, D.P)`. The structs named as bases are collected before anything
registers (`cpp_note_bases`), and the base clause of the template names the parameter `B`; the instance now promotes a plain struct
that its bases name before it registers (`cpp_promote_plain_bases/1` in `cpp_instance_body`). The reduction showed a second, older
defect on the way: a base named through an ALIAS of a class (`using ZA = Z; struct Y : ZA`, `typedef Z ZT; struct X : ZT`) was refused
`base_not_registered('ZA', 'Y')` with no template in sight, since `cpp_type` leaves an alias as it is; `cpp_alias_class/2` resolves it in
`cpp_base_name` and in `cpp_note_bases_`. Named, found on the way: the program's own class templates are instantiated EAGERLY, members
included, so `D<Q>::sum()` that names a member `Q` lacks is refused though nothing calls it -- C++ instantiates a member where it is used
([temp.inst]/3). The reason is the safe part (the program's instances are checked), and it is in "Not done" now. `baseparam.cpp`.

BATCH E: the library sweep (what a program asks of libc++ once the language is whole).

The sweep took the headers a program reaches for first and had not been tried -- `<list>`, `<deque>`, `<queue>`, `<stack>`, `<numeric>`,
`<cstdlib>`, `<iterator>`, `<thread>`, `<mutex>`, `<charconv>`, `<atomic>` at C++20 -- wrote a program of 20 to 50 lines for each, built it with
clang++ (`-stdlib=libc++`) and with cicilang++, and followed each difference to its cause. Every defect below was found that way; each has a
reduction of its own where the library's shape could be cut out of the library.

(45) PARENTHESIZED FUNCTIONAL CASTS (reader 114; found by `<thread>`: `thread() : __t_((__libcpp_thread_t())) {}`, and by the idiom
`std::vector<int> r((std::istream_iterator<int>(in)), std::istream_iterator<int>())`): `(T())` was read as a cast to the function type `T ()`
and `(std::vector<int>(n))` as a type-id with the named declarator `(n)`; both then looked for an operand after the `)` and the read stopped.
`ccl_cast_expr` refuses a `fn(_, _, _)` type, and a type-id's declarator is abstract (`ccl_type_name//2` demands `N == anon`). The reader and
compile gates were run again over a fresh HOME at once (reader 96 ok and two skips, compile 105 ok). `parencast.cpp`.

(46) A BRACED DEFAULT INITIALIZER OF A PLAIN STRUCT OR UNION MEMBER reached the lowering as a bare braced expression (found by `std::mutex`:
`__libcpp_mutex_t __m_ = _LIBCPP_MUTEX_INITIALIZER;`, glibc's `{ { 0, 0, 0, 0, 0, 0, 0, { 0, 0 } } }` over a union). `cpp_member_from/6` assigns
a compound literal of the member's type (`cpp_plain_aggregate/1`), and the plain-member clause of `cpp_member_inits` asks it for the default.
`aggmemberinit.cpp`.

(47) A MEMBER TEMPLATE OF A PLAIN CLASS DEFINED OUT OF IT was never emitted (found by `std::mutex` and `std::thread`, whose constructors are
`template <class _Fp, ...> thread::thread(_Fp &&, _Args &&...)`): the definition went to `'$cpp_mdef'` with no pattern, where only an instance
of a class template looks, so the call named a symbol nothing defined and the link failed. `cpp_register_` keeps it (`cpp_mdef_put/4`) and
`cpp_refresh_mts/1` gives the bodyless declaration, registered with the class as a member template, the body of its definition through the merge an
instance makes (`cpp_member_def/5`). The first version missed the constructors: the row's key is `ctor` and the shape key `$ctor`; the rows are
found by `cpp_member_shape(M, _, _, none)`. `membertmpl.cpp`.

(48) AN INSTANCE WHOSE BASE IS STILL BEING REGISTERED (found by `std::list`: `base_not_registered(...)`): libc++'s `__list_imp` names
`__list_node_base<int, void *>` and, through its pointer traits, `__list_node<int, void *>` as the pointee of a typedef, which instantiates the node
-- whose base is the class whose registration asked for the typedef. C++ asks no definition of a pointee. The registration of the derived instance
is deferred (`'$cpp_deferred'`, `cpp_instance_body/4`, trace `deferred`) and runs when the class is first looked up (`cpp_class/2`,
`cpp_run_deferred/1`), by which time the base is a class. The first version tested atoms only and missed a base named by a template-id;
`cpp_base_in_progress/1` resolves the template-id to the instance in progress (`'$cpp_iname'`). `stdlist.cpp`.

(49) TWO CLASS TEMPLATES OF ONE FLATTENED NAME (found by `std::vector<int> v = {1, 2, 3}` after `#include <iterator>`, which pulls in `<variant>`):
`std::copy` of trivially copyable ints found the wrong `__overload` -- `<variant>` defines `template <class _Tp, size_t _Idx> struct __overload`
in `std::__variant_detail`, the algorithms `template <class _F1, class _F2> struct __overload : _F1, _F2` in `std`; the flattening lost the namespaces
that told them apart (`arity_mismatch`). Where the name has class templates of DIFFERENT parameter kinds the first whose parameters take the
arguments is the one (`cpp_class_template/4`, `cpp_tparam_kinds/2`, `cpp_kinds_fit/2`). The first attempt compared no kinds and chose the one with a
value parameter for a type argument; the kinds are compared now. A name with one kind is untouched.

(50) A CONDITIONAL WITH THE LITERAL ZERO AND A POINTER (found by `std::deque`: a crash at the first `push_back`; a defect from the start, in the inference
and in the lowering): `__map_.empty() ? 0 : *__mp + ...` was typed `int`, so the overload taking a pointer lost to the one taking a
`long` (`no_constructor`), and the lowering's phi was `i32`: the pointer went through `ptrtoint ... to i32` and lost its high half. [expr.cond]/7:
the null pointer constant converts to the pointer's type. `ccl_type_of(cond)` and `ir_expr(cond)` give the pointer when one arm is a null
constant (`ccl_null_constant/1`) and the other a pointer, in both orders and both languages. The lowering's half is a C defect too, so the C program is a
fixture (`test/c/run/condnull.c`; the safe part refuses a plain pointer stored in a struct, so the program keeps its pointers in locals).
`condzero.cpp`, `stddeque.cpp`.

(51) A STATIC DATA MEMBER OF A CLASS TEMPLATE DEFINED OUT OF ITS CLASS (reader 114; found by `std::deque`: `begin()` read the undefined symbol of
`__deque_iterator::__block_size`): `template <...> const _DiffType __deque_iterator<...>::__block_size = ...;` was kept by nothing. The class's
`'$cpp_mdef'` rows now hold it as `static_def(N, Init)` (`cpp_mdef_item/4`; the header's index keys it under the class), and the instance takes
the initializer as the member's own default (`cpp_static_defs/5`), so it folds as one written in the class does. `tmplstatic.cpp`.

(52) `__underlying_type` AND AN ENUM WHOSE UNDERLYING TYPE IS A DEPENDENT TYPEDEF (found by `-std=c++20` programs that stored into a `std::atomic`:
`typedef(scoped([tmpl(underlying_type, ...)], type))` reached `main`): libc++ 18 writes `enum class memory_order : __memory_order_underlying_t`
over `typedef underlying_type<__legacy_memory_order>::type __memory_order_underlying_t`. `__underlying_type(E)` is answered
(`cpp_underlying_of/2`: the written base, else `int` when an enumerator is negative, else `unsigned`; `underlyingtype.cpp`). The enum's base is
SETTLED where the enum is first named (`cpp_enum_unsettled/4` in a `cpp_type` clause) and the typedef is OUTPUT as an item
(`cpp_settle_typedef/2`), since the passes build the table again from the output's items and a note made during the desugaring is gone by
then. THE LESSON IS CLAUDE.md's OLD ONE: three attempts failed the same way before the cause was seen -- the clause had been edited with a comment
in the middle of a line, `% the tag asked with its members UNBOUND ... ccl_typedef_of(A, D), D = ...`, and the comment ended the line, so the
goals after it were never part of the clause and it failed on every call. A probe around `cpp_type` showed the typedef resolving to `unsigned`,
which made the cause look elsewhere. `enumsettle.cpp`, `stdatomic20.cpp`.

(53) A FUNCTION TEMPLATE-ID NAMED AS A VALUE (found by `std::thread`: `pthread_create(&__t_, 0, &__thread_proxy<_Gp>, __p.get())`,
`lvalue(tmpl('__thread_proxy', ...))` at the lowering): `f<int>` and `&f<int>` need no target when the explicit arguments settle every
template parameter. `cpp_explicit_instance/3` takes the first candidate of the name whose explicit arguments bind (`cpp_bind_explicit`), whose
defaults fill the rest, whose parameters are all bound and whose constraints hold, names and emits the instance as any instance is, and
`cpp_expr` makes the id its name, the address under `&`. The same rule serves `std::from_chars` of a SIGNED type, which hands
`__from_chars_atoi<__t>` to `__sign_combinator` as its by-value `_Fn` (it was `cannot_deduce('_Fn')`).

(54) A FREE OPERATOR FUNCTION THAT A HEADER DEFINES (reader 114; found by `std::thread::id() == std::thread::id()`: `no_operator(==)`): the header
index, the noting of a header's functions and their lazy registration had one clause each for a LITERAL operator and none for any other operator
function, because the templates (`cpp_template_name`) were the only free operators libc++ had written until `<thread>` and `<system_error>`
defined `inline bool operator==(__thread_id, __thread_id)` for a class. `cpp_index_name/2`, `cpp_note_hdr_fns/1` and `cpp_register_lazy/1` take any
free operator the header DEFINES (a declaration alone is not indexed) under its free operator name `op.<word>.<arity>`.

(55) A SHIPPED FUNCTION'S PROTOTYPE DECLARED IN THE FRAME OF THE FIRST CALLER (found by a program with two kinds of thread: the first `std::thread` made
`__thread_proxy<A>`, the second `__thread_proxy<B>`, and `__thread_local_data().set_pointer(...)` in the second was `no_member(set_pointer, ...)`):
`cpp_use_mangled/3` noted the Itanium-named function done and declared its type with `ccl_declare/2`, which writes into the INNERMOST OPEN FRAME --
the first instance's body scope, popped when it ended -- so the second function that called it met a call of no type (`unknown`), and a member call on
an unknown type refuses. `ccl_gdeclare/1` declares it at file scope. A defect since 0.61 that nothing had called twice with a member call on the
result. `stdthread.cpp`.

(56) `volatile` IN THE MANGLER (found by `-std=c++20` `notify_one`, `notify_all` and `wait` of a `std::atomic`, which linked to nothing): the
parameters of libc++'s `__cxx_atomic_notify_one(void const volatile *)` and its siblings were spelled `PKv`; the ABI says `PVKv`. `cpp_ita_cv/2`
spells `V` before `K`, the group is ONE substitution candidate with its type (`cpp_ita_wrap_cv/6`; `VKv` is `S0_`, `PVKv` `S1_`), and a by-value
parameter loses both qualifiers. The first version took `cpp_ita_wrap/5`'s first letter for the group and wrote `PVv`. The three symbols of clang++
are in `c37`. `stdatomic20.cpp`.

(57) `using typename Base<T>::name;` IN A CLASS (reader 114; found by `std::from_chars`: `type(unknown)` at the lowering): libc++ 18's `<charconv>`
`__traits` writes `using typename __traits_base<_Tp>::type;` and its members take `type &`, and the member was skipped as an unknown using
declaration. It is the class-scope typedef `name` of `typename Base<T>::name` now.

(58) AN ENUM VALUE-INITIALIZED BY `E()` AND `E{}` was `undeclared(E)` (found by `std::errc()` in `r.ec == std::errc()` of `<charconv>`):
the tag-called clause took an enum only with one argument. With none it is the enum's zero ([dcl.init]/8). `enumvalue.cpp`.

(59) A CALL THAT RETURNS A REFERENCE TO AN ARRAY was loaded whole (`%t = load [10 x i32]`), and the pointer arithmetic on it died as `type(unknown)`
(found by `std::from_chars`: libc++'s `static auto &__pow() { return __table<>::__pow10_32; }` is added to): the array is the address, which decays.
And `auto &gr() { return g; }`, a plain function with a deduced REFERENCE result, was `not lowered yet: auto` at its first call, though the
method road had it since 0.113: `cpp_auto_result/1` and `cpp_fn_auto_ret/4` deduce the type under the reference, undecayed
(`cpp_lambda_ret_mode/5`). `autoref.cpp`.

(60) A NON-CONST REFERENCE BOUND AN ARITHMETIC LVALUE OF ANOTHER TYPE (a SILENT WRONG ANSWER, found by `std::from_chars`, which stored 0 for "12345" and
garbage for "-77"): libc++'s `__mul_overflowed(unsigned char, _Tp, unsigned char &)` was chosen for `(uint32_t, uint32_t, uint32_t &)`, and its
`__r = ...` wrote ONE BYTE of the caller's variable. [dcl.init.ref]/5.1: `unsigned char &` binds only an lvalue of a reference-related type. The
acceptance of a template candidate refuses an arithmetic lvalue of another arithmetic type for a non-const lvalue reference (`cpp_param_accepts/2`, the
types compared by `cpp_type_key` without their qualifiers). What showed it was the IR of the caller: the call passed `i8 %t71` where the
variable lay. `stdcharconv.cpp` (`from_chars` of int, long and unsigned in two bases, an invalid string, a value out of range; `to_chars`).

(61) SMALLER FINDS OF THE SWEEP, each with a fixture or inside one: `std::span<int>` converts to `std::span<const int>` (the qualification
conversion through an array, `cpp_quals_added`; `stdspan.cpp`); `vector<bool>::reserve` ran with a null `this` because the NAME `swap` has a static
overload (`cpp_static_bare/3`; `vectorbool.cpp`, a defect since 0.47); a plain struct bound to a base-clause type parameter and a base named through an
alias (`baseparam.cpp`); `<numeric>` (`stdnumeric.cpp`), the C library through `<cstdlib>`, `<cstring>`, `<cctype>` (`stdcstdlib.cpp`), the
rvalue-stream `getline` and `sync_with_stdio` (`stdstreammisc.cpp`), `std::queue`, `std::stack` and `std::priority_queue` (`stdqueue.cpp`),
`std::bitset`, `std::complex`, `std::byte` (above).

(62) AN ARITHMETIC VALUE BOUND TO A REFERENCE TO ANOTHER ARITHMETIC TYPE (found by `std::deque`: a segmentation fault at the 3000th `push_back`; gdb on the
binary showed `__split_buffer`'s constructor receiving the capacity 8589934593 = 0x200000001 from `std::max<size_type>(2 * __map_.capacity(), 1)`):
the temporary a `const size_t &` binds to the int `1` was made as wide as the int -- four bytes, read as eight, the upper four whatever the stack
held. Reductions of ten lines: `const size_t &r = 3;`, `id(3)` over `size_t id(const size_t &)`, `pick<size_t>(3, 2)`, `std::max<size_t>(0, 1)`.
`ir_ref_to/3` takes the arithmetic case first (`ir_ref_converts/3`: the referent's LLVM type differs from the expression's, or a `bool` is bound to a
non-`bool`) and binds a temporary of the REFERENT's type, converted from the value (`ir_ref_convert/3`); a reference member bound in a constructor
goes through the same door (`ir_bind_into/3`). Two types of one LLVM type still share the lvalue's address -- an `int` and a `const unsigned &` --
which differs from the standard only where the variable is written while the reference lives. The defect is as old as the lowering of references.
`refwiden.cpp` (an int literal, an int lvalue copied and not aliased, an int to a double, a double to an int, a float widened, `-1` to `unsigned long
long`, an `unsigned char` to an `int`, a `bool` from 5 and from 0.0, an rvalue reference to a converted copy), `stddeque.cpp`.

(63) A CONVERSION FUNCTION THAT YIELDS A REFERENCE (found by `std::thread`, below): libc++'s `reference_wrapper<T>::operator T &()` was no
candidate where a `T &` or a `T` is wanted, because the result's reference was kept and neither `cpp_bare_type/2` nor `cpp_conv_fits/2` looks through
one. `bump(r, 3)` with `r` a `std::reference_wrapper<Counter>` and `void bump(Counter &, int)` passed the WRAPPER's address as the Counter, in 0.116
too (the baseline worktree prints `0 0 1 4` for the reduction where clang++ prints `6 16 6 20`). `cpp_conv_result_type/2` strips the reference in
`cpp_conv_member_/6` ([over.match.ref]/1.1). `fnptrargs.cpp`.

(64) CALLS THROUGH A POINTER OR A REFERENCE TO FUNCTION took none of the passes a call by name gives (found by `stdthread.cpp`, whose binary hung: gdb
showed four threads, each in `lock_guard`'s `mutex::lock()` on a DIFFERENT mutex, at addresses 0x1e0 apart inside the thread blocks -- the callee
had run on the `std::ref` wrapper's address as its `Counter`): libc++'s `__invoke` writes `static_cast<_Fp &&>(__f)(static_cast<_Args &&>(__args)...)`
with `_Fp` a function REFERENCE, and `cpp_call/4` met an `id` that is no declared function, so `cpp_ref_args/3` and `cpp_copies/2` (which look up
`fn(_, Ps, _)` of the NAME) did nothing. `cpp_callee_params/2` reads the parameters off the callee's FUNCTION TYPE -- a pointer to function, a
reference to one, a member or an element of such a type -- and the three places that take the passes use it: `cpp_ref_args/3` on a name,
`cpp_call/4`'s last clause on any callee expression, `cpp_copies/2` on any `call(F, Args)`. A class taken by value through a function pointer is now
copied for the callee, which destroys its own (it was the caller's object, destroyed twice). `fnptrargs.cpp` (a reference_wrapper to `Counter &` and
to `int &`, directly, through `std::invoke`, a function pointer and a reference to function; a `Tag` with a printing copy constructor and destructor
through `void (*)(Tag)`; an int to a `const long &` through a pointer), `stdthread.cpp`.

(65) A TYPEDEF THAT NAMES A SCALAR HAS NO MEMBER TYPES (found by `std::list::assign(3, 4)`, which ran past 28 minutes and 2.6 GB and never finished -- the
sweep's one PERFORMANCE finding; a trace of four minutes was 420,029 lines of `flatten([size_t], iterator_category, in(sig(__test)))` and
`free_name_instance(iterator_traits, _InputIterator, ...)`): `typename U::iterator_category` with `U = size_t` is a SFINAE failure, and was not. The
argument `size_t` is a typedef NAME, and `cpp_subst_path/3` made a path segment `nonclass(A)` only for a scalar written as a builtin type; the typedef
kept its name, flattened as a namespace, and found `iterator_category` in some other class, so libc++'s `__has_iterator_typedefs<size_t>` held, and
`iterator_traits<size_t>` was walked as an iterator. A ten-line reduction prints 1 for `has_ic<size_t>` where clang++ prints 0 and `has_ic<unsigned
long>` was right. `cpp_typedef_scalar/1` resolves the typedef first. `sfinaetypedef.cpp`.

(66) THE TYPES OF THE PARAMETERS A CALL LEAVES OUT (the other half of 65, which the first fix exposed: `no_member_type('enable_if.0.void', type)` at
the call, uncaught): libc++ 18 writes the SFINAE of `list::insert` and `list::assign` as a trailing PARAMETER, `__enable_if_t<__has_input_iterator_category
<_InpIter>::value> * = 0`, which no call supplies. `cpp_params_accept/3` stopped when the arguments ran out, so the template with `_InpIter = size_t`
held whatever the trait said and the walk of 65 ran before the ranking dropped it; with 65 fixed the trait said false and the type was never
resolved, so the candidate was chosen and its emission refused. [temp.deduct]/7: the type of every function parameter, supplied or defaulted, is
substituted. `cpp_params_resolve/2` does it for the rest of the list. `std::list<int>::assign(3, 4)` builds in 8 seconds and matches clang++
(`stdlist.cpp` has it back). `sfinaetypedef.cpp` has a `pick(T, enable_if<...>::type * = nullptr)` pair that only this rule can tell apart.

(67) A VARIABLE THE SWEEP'S OWN EARLIER STEP SHADOWED, found by the first POOL of fixtures run before the chain (40 fixtures through `runfx.sh` over a warm
cache, three at a time, ten minutes -- a net for a step that changes rules every fixture uses): `refbyvalue.cpp` was refused by LLVM, `store
%struct.Two %t1, ptr %t2` with `%t1` a `ptr`. The SysV register budget of batch A gave `ir_args_/5` a register state named `R0`, and the older clause
for a reference handed to a by-value aggregate parameter used `R0` for the resolved reference type in `ir_ref_value_type(T0, R0)`, which could
never unify with `regs(I, S)`: the clause failed, silently, for every such argument. Renamed `RV`. (CLAUDE.md's old lesson, "look a variable up
before giving it", a second time.)

(68) `__builtin_bit_cast(T, e)` (the items the sweep had left, tried again after 65 and 66): `std::bit_cast` was `trait_unknown('__builtin_bit_cast')`.
`cpp_trait/3` answers it with a statement expression: a local of T, a local copy of e (its type unref'd and unqualified), a `memcpy` of `sizeof(T)`
bytes from the one to the other, the local of T last ([bit.cast]; libc++ 18 writes `return __builtin_bit_cast(_ToType, __from);`). `stdbitcast.cpp`
(C++20: a float and an integer both ways, a double, a struct, a `std::array` of bytes, and the rest of `<bit>`: `popcount`, `countl_zero`,
`countr_zero`, `has_single_bit`, `bit_ceil`, `bit_floor`, `rotl`, `rotr`, `bit_width`).

WHAT THE SWEEP DID NOT FINISH, named in "Not done": `<random>` (a `std::mt19937` with `uniform_int_distribution`: killed at the 1500 s cap and
again at ten minutes after 65 and 66, refusing nothing. A trace of two minutes is 74 `spend`s and no flood: the desugaring descends
`__log2_imp<unsigned long long, 4294967296, N>` from N = 63, one instance in two seconds, 5.6 MB of the store written for each. libc++'s recursion
with its two partial specializations, written out in a program of its own, builds in one second altogether, and in three with `<random>`
included: the instances are slow only when they are made from inside the instantiation of the engines, and one `__log2` is 32 of them; the cause
is not found, and the next step to take is the CPU attribution by stubs, as CLAUDE.md's "Finding a cost" has it); `std::valarray`
(`instantiation_depth(121, '__slice_expr')`); `std::filesystem::path` (`_PathCVT::__append_range` meets `typedef(tmpl(basic_string, ...))`);
`std::variant` with `std::visit` (`no_member('__base', '__visit_alt', 2)`: `__make_fmatrix` fills a `constexpr` array with function-template
instances named as values, and the call goes through an element of it); `<chrono>`, whose durations and clocks run but build in 8 to 14 minutes.


Reader version 114, lowering version 62; the module rebuilt as 0.117, over cocolog 1.9.1. NO GATE HAS RUN ON THIS COMMIT. It is a save point of
the work in progress, as 0.112 and 0.113 were: every fixture it adds (the list is the diff of `test/cpp/run/` and `test/c/run/`) matched
clang++'s output in a probe, one at a time, over a cache of its own, but the seven gates have not run over it, and the rules of this step change
the reader (reader version 114: the parenthesized cast, the block declarators, `using typename`, the static_def index, the header's free operators),
the free-function road, the overload acceptance (the arithmetic reference), the argument passes of every call through a pointer or a reference to
function, the SFINAE of every function template (a scalar typedef has no member types; the types of the parameters a call leaves out), the
reference binding of the lowering and the mangler (`volatile`) for every program. Two pools of existing fixtures (41 and 50, three and two at a time)
were run as a net over the late rules; the first found the defect of (67), and the second's verdicts are in the next commit's entry. The next commit
carries the gates' numbers.

## 0.118 — M6's eighty-second step

**M6's eighty-second step (0.118): the seven gates over 0.117, and the two defects they found.** 0.117 was a save point,
committed with no gate run over it (as 0.112 and 0.113 were). This step ran the gates over a snapshot of it, in a HOME
of its own with every cache cold, alone on the box. The reader, compile, driver and objects gates, the proof and the
library read were GREEN at once. THE C++ GATE WAS NOT: it found two defects of 0.117, both in rules that the step's
own pools of fixtures had not met, and one of them was a build that held 8.7 GB, which the owner's rule on memory
forbids by itself.

THE POOLS, before the chain. A change to the rules every program reaches -- the call passes, the overload acceptance, the
reference binding -- was tried first on pools of existing fixtures, built over a warm cache and compared with their `.expect`
(`runfx.sh`, three lanes then two): 41 fixtures in 1730 s and 50 in 1792 s. The first found the defect of (67), `refbyvalue.cpp`,
fixed before the commit; its only other line was `stdranges`, which was killed by hand at 4.2 GB after 21 minutes of CPU, and the
chain builds it. That line was the second defect below, seen and not believed: "slow, the chain will say". The second pool was
green throughout: the SFINAE and trait fixtures (`detect`, `detect2`, `detect3`, `sfinaedefs`, `ndpath`, `tmpldefaults`, `targkeys`,
`autohead`, `automember`, `ctorreq`, `memberreq`, `concepttraits`, `stdtraits`), the algorithms, the containers and the streams, and
every fixture of this step's library sweep. Their builds took 0 to 440 s; the longest were the cold flattens of `<sstream>` and
`<fstream>` (440 s and 346 s), `<span>` (290 s), and `stdatomic20.cpp` (432 s, which builds the `<chrono>` instances of the atomic
wait).

THE FIRST C++ GATE RUN was stopped at 328 of 389 verdicts. It had two failures and one build still running:

(1) `sentinelpair.cpp` was refused by the safe part of 0.117, the access check: `access(private, 'V.int.S.0', end_)` at
`S(S<!C> s) requires C : end_(s.end_)`. The class `S` is a member class template of `V`, defined out of it, and it says
`friend class S<!C>;`. The friend was noted under the bare name `S`, the check compared that name with the template of the
asking instance, which is `V.S` (a member class template is named `Class.Name`, as a nested class is), and they never matched.
`cpp_friend_is/2` now takes a friend named by the SHORT name of a member class template (`'$cpp_nested_tmpl'`) for an instance of
that template. The fixture had passed at 0.112 and 0.113 and was not in a pool: access control was written after it.

(2) `rangesarray.cpp` and `stdranges.cpp` RAN AWAY. `rangesarray.cpp` is `ranges::upper_bound` over a constant array of six lines;
its recorded builds were 12, 20 and 14 s and 173 MB at 0.116. At 0.117 it held 7.8 GB after 11 minutes and grew 12 MB a second, and
the sum of the gate's cocolog processes was 100 seconds from the watchdog's 12,000 MB, which would have killed all four lanes. The
build was killed by hand at 8.7 GB (and `stdranges.cpp`, the same defect, at 2.3 GB after 7 minutes, when its record is 87 to 112 s)
so that the gate could go on. A trace of 60 seconds of the build showed 134,232 `flatten(...)` lines, against 6 at 0.116, and
`free_name_instance(iterator_traits, _InputIterator, ...)`: an instance made on a FREE name, which grows to the cap. Three of
0.117's rules were reverted one at a time on a runnable copy of the tree (the types of the unsupplied parameters, the scalar
typedefs, and the alias clause of `cpp_type`); only the last one ended it, in 10 seconds with the right output. The clause
had been given a second case in 0.117 -- an alias whose definition is a MEMBER type of an instance, `typedef
underlying_type<__legacy_memory_order>::type __memory_order_underlying_t`, for `std::atomic` at C++20. But the table of typedefs holds
the block-local and class-scope typedefs of the headers too, and libc++ writes `typedef typename
iterator_traits<_ForwardIterator>::value_type value_type;` in function templates: a scope that did not resolve (the 0.116 trace has
the same two flattens, harmlessly) left the bare name `value_type`, the table gave that typedef, and the rule followed it with
`_ForwardIterator` free -- 48,279 times in 25 seconds, each an instance of `iterator_traits` on the free name whose own class
resolved `value_type` again. A definition that names a template parameter is now never followed (`\+ cpp_raw_type(...)`);
`stdatomic20.cpp`, the reason for the rule, is still the same as clang++'s output. The two builds killed by hand are the
only lines of the first run that are not a verdict: it was stopped, its processes with it, and the gate run again from the
start over the corrected tree.

The lesson is the one of 0.112: a rule that the pools did not meet is not tested, and a pool line that is "slow" is a result.
`stdranges` at 4.2 GB after 21 minutes was the defect, hours before it had a name.

GATES over the 0.117 snapshot, cocolog 1.9.1, a HOME of its own, alone on the box: the reader gate GREEN, 96 ok and 2 skips
(Cicili's two example files are not here), 5 s; the compile gate GREEN, 106 ok (63 run, 43 refused), 8 s; the driver gate
GREEN, 26 ok, 7 s; the objects gate GREEN, 29 ok, 3 s; the proof exit 42; the library read GREEN in 958 s over four lanes, cold
(the 23 asserted reads and 60 other headers warmed, none failed to flatten; peak 1179 MB). The C++ gate over the 0.117 snapshot
was stopped as told above. THIS COMMIT IS A SAVE POINT, as 0.117 was: the C++ gate over the CORRECTED tree -- a snapshot
of this commit's tree, the summaries of the library read warm -- was running when it was made, and NOTHING about it is claimed.
The six gates above run no C++ desugaring (the reader, the C driver, the objects layer, the proof and the header reads), so 0.118's
change to `library/ccl_cpp.pl` and the module's version string leave their verdicts as they are. Each fix was seen to pass alone:
`sentinelpair.cpp` and `rangesarray.cpp` (10 s, 166 MB) match clang++, and so does `stdatomic20.cpp` (274 s). The next commit
carries the C++ gate's numbers.

Reader version 114, lowering version 62; the module rebuilt as 0.118, over cocolog 1.9.1.

## 0.119 — M6's eighty-third step

**M6's eighty-third step (0.119): the C++ gate over 0.118's tree.** 0.118 was committed while its C++ gate ran. The gate ran to its end,
alone on the box (the other work on it was one-second reductions under a cap of their own), over a snapshot of 0.118's tree and the
HOME of the library read, its 84 summaries warm: 388 fixtures built, ran and printed what clang++ prints, the one skip is
`stdoptionalref` (it needs libc++ 21), none failed, in 2989 s over four lanes, the pool's peak 9034 MB (the sum of its cocolog
processes). The slowest were `viewsall` 1357 s (1759 s at 0.115), `viewchain` 438 s, `tempinitlist` 429 s, `stdwformat` 375 s, `stdviews`
371 s and `stdcontains` 368 s. The three fixtures behind 0.118's fixes -- `sentinelpair`, `rangesarray` and `stdranges` -- passed in the pool.

THE GATE WAS RED BY ONE CHECK, not by a fixture: `c20` of `test/cpp.pl`. `throw Err{t}` has read `throw(braced_temp(call(id('Err'),
[id(t)])))` since 0.117 -- a class with an `initializer_list` constructor takes the list first, and the reader keeps the braced
temporary as its own node -- and the check still expected the plain call. The rule was right and its check was not edited with it: the
checks of `test/cpp.pl` read the AST by its shape, only this gate runs them, and 0.117 was a save point. The check says what the
reader gives now. `test/cpp.pl` alone, over 0.118's library, is GREEN: 48 ok (the 42 checks and Cicili's six C++ files), 15 s,
237 MB. The pool and the command's checks around the red one were green. The chain was not run again over this tree, which differs
from 0.118's by that check, the module's version string and the documents.

So all seven gates have run on cocolog 1.9.1 over the tree of 0.117/0.118: the six that run no C++ desugaring over a snapshot of
0.117 (0.118 changed none of what they run), the C++ one over 0.118's own.

TWO LESSONS OF THE INSTRUMENTS. (1) The watch of this run reported eight FAIL verdicts in its first minutes (`refbyvalue`,
`stdformat`, `stdformatter`, `stdprint`, `stdvformat`, `stdwformat`, `stdwstream`, `streamderived`). They were not this run's: a
gate that is killed leaves its `mktemp -d` directory (the `trap` does not run on SIGKILL), and the watcher took the last of
`ls -d /tmp/cicilang-cpp-*/res`, which was the stopped first run's, with the verdicts of the 0.117 tree. The gate's own log had one FAIL
line, the check. An instrument that answers about a thing other than the one asked answers confidently and wrongly: the watcher
reads the newest directory now, and the dead one is removed. (2) A reader change that moves a node is not finished until the one gate
that reads nodes by shape has seen it.

Reader version 114, lowering version 62; the module rebuilt as 0.119, over cocolog 1.9.1.

## 0.120 — M6's eighty-fourth step

**M6's eighty-fourth step (0.120): the desugaring four times faster.** The gates of 0.118 took 958 s for the library read and
2989 s for the C++ gate, and the builds that the owner's memory rule forbids -- `rangesarray.cpp` at 8.7 GB, `viewsall.cpp` at 3.5
GB -- were the symptom of one cause: cocolog's `nb_getval/2` COPIES what it answers, and a build asked the same few large
terms thousands of times. A flat profile found where. No predicate of the desugaring was slow in itself.

THE INSTRUMENT. cocolog has no profiler, so a scratch copy of the library was made by a script (not in the repository, as the other
session tools are not): every clause of `ccl_cpp.pl` and `ccl_infer.pl` begins with a goal that stamps `statistics(cputime, T)` and
adds the time since the last stamp to the clause entered before it. That is a flat profile in which a clause is charged for what runs
after it is entered and before the next clause is -- its own goals, the builtins it calls, and the callees that are not instrumented --
and the stamp is taken again when the goal ends, so the instrument's own cost is not charged. Its overhead is a factor of three, its
ranking is the work's. On `stdvector.cpp` (9.6 s of CPU on the loaded box, 7.3 s alone): `cpp_class/2` 19% and `cpp_class_typedef/4` 12%, the
rest flat. In-situ timers around the suspected reads then measured the copies themselves, not the smear: the retrieval of the class
record, 68,075 times, 2.61 s; the copy of the list of class typedefs, 38,777 times, 1.23 s (and the `memberchk` on it 0.25 s); the copy of
the enclosing classes, 29,700 times, 0.06 s; the cache index, 61,193 times, 0.14 s; `ccl_tables_changed/0`, 202 times, 0.002 s. A count of
`cpp_class/2` per call site: `cpp_base_scope/2` alone asked 44,764 times, for the BASE.

THE CHANGES, each by what it copied.

(1) THE LIGHT CLASS RECORD. A class's record, `cls(Base, Data, Members, Statics, Defaults, Slots)`, is 97% its members -- every
method with its body -- and a lookup that wanted only the base, the data or the slots copied the class. `cpp_class_put/2` now writes
`'$cpp_clsl'(C, cls(Base, Data, Statics, Defaults, Slots))` beside it, a hundredth of the size, `cpp_class_l/2` answers it (a class not
registered yet is asked of `cpp_class/2`, which loads it, and the light fact is there after), and 95 calls whose members field was `_` ask
it (45 others want the members and are left alone). The script that rewrote the calls checked each by its pattern.

(2) SEVEN REGISTRIES THAT WERE LISTS IN A GLOBAL ARE FACTS: the class typedefs `'$cpp_ctype'(Class, Name, Type)`, the enclosing classes
`'$cpp_encl'`, the static initializers `'$cpp_sinit'`, the lazy library classes `'$cpp_lazy_c'`, the destructors defined out of their class
`'$cpp_dtor_def'`, the names that keep C linkage `'$cpp_cname'` and the default arguments `'$cpp_dflt'`. A fact is found by its first
argument and copies only what it answers. They are written newest first (`asserta`) and a lookup takes the first match, as `memberchk/2`
did; `test/cpp.pl`'s mangler check, which set one by `nb_setval/2`, asserts it. 48 replacements, each counted by a script that refuses to
run if the text it finds is not the text it expects.

(3) THE FILE SCOPE, THE TYPEDEFS AND THE TAGS ARE BUCKETED. 800 file-scope declarations into a table of 3,000 names and 6,000 lookups were 6 of
the 15 CPU seconds of a `std::vector` build; one write was 40 ms at 20,000 names, because `nb_setval/2` copies what it takes and every
lookup the answer caches missed read the whole table. A table is now 128 globals (`P_0` .. `P_127`), an entry lives in the bucket its key's
characters hash to, and a write or a lookup copies one bucket (`ccl_tab_*` in `library/ccl_syntax.pl`): 15 microseconds a lookup, 25 a write,
48 ms for a bulk of 20,000. Inside a bucket the order is the old list's, so the first entry that unifies is the one the single list gave.
`ck_declare_at/4`, which built every frame to find the one that holds a name, asks the open frames and then the file scope. The only
reader of a whole table in order is the drain functions' loop (`ir_drain_functions/1`), which now takes the buckets in turn: the same
functions in another order, which is why the lowering version is 63.

A fourth idea was measured and left out: the cache index, 61,193 lookups, 0.14 s -- the answer caches are not the cost.


MEASUREMENTS. One build each on a quiet box, CPU seconds, the same HOME (its summaries valid for both trees), output compared with the
fixture's `.expect`, 0.118 then 0.120: `stdvector.cpp` 17.2 -> 4.0, `stdmapstring.cpp` 58.0 -> 10.1, `stdalgorithm3.cpp` 21.6 -> 5.1; all three SAME.
The gate's recorded build times (`~/.cicilang/fixture-times`), 388 fixtures in both runs: the sum 11,775 s -> 2,936 s (4.0 times);
`viewsall` 1357 -> 211 s, `viewchain` 438 -> 57, `tempinitlist` 429 -> 41, `stdwformat` 375 -> 78, `stdviews` 371 -> 69, `stdcontains` 368 -> 42,
`stdformat` 328 -> 103, `stdvformat` 322 -> 73, `viewkeys` 318 -> 28, `stdstringstream` 291 -> 91. The one that gained nothing is
`stdatomic20` (279 -> 277 s), which is the reader's cold flatten of the headers of `<atomic>`'s wait, not the desugaring.

GATES over a snapshot of this commit's tree (the repository was left alone while they ran), cocolog 1.9.1, a HOME of its own, every cache
cold: the reader gate GREEN (96 ok, 2 skips, 5 s), the compile gate GREEN (106 ok, 9 s), the driver gate GREEN (26 ok, 7 s), the objects gate
GREEN (29 ok, 2 s), the proof exit 42; the library read GREEN in 1001 s (958 s at 0.118: the reads are the reader's, not the
desugaring's, and other work shared the box), peak 1173 MB; THE C++ GATE GREEN IN 908 s (2989 s at 0.118), `test/cpp.pl` 48 ok, 388
of 389 fixtures ok and the skip `stdoptionalref`, the pool's peak 1675 MB (9034 MB at 0.118). Before the chain: the four small gates
and the proof over the working tree, the same numbers.

Two things the step did not do: reader version 114 stays (a summary's content is the same), and `<random>` -- a `std::mt19937` with
`uniform_int_distribution`, killed at its 1500 s cap since 0.117 -- was tried over these tables (the build was killed at 900 s, no
binary): the cost of its instances is not the tables'.

The method, for the next cost: a flat profile (`CLAUDE.md`, "Finding a cost"), then timers in situ around the suspected reads, then a
count per call site. The profile ranked `cpp_class/2` 19% and `cpp_class_typedef/4` 12% and nothing else above 3%; the timers said
which reads. A profile of a build that does not end needs only a CPU limit.

Reader version 114, lowering version 63; the module rebuilt as 0.120, over cocolog 1.9.1.

## 0.121 — M6's eighty-fifth step

**M6's eighty-fifth step (0.121): `std::variant` and `std::visit`, and what they needed.** The "not done" list held one sentence
about `<variant>`: `std::visit` was refused, `no_member('__base', '__visit_alt', 2)`. Behind that sentence stood about twenty
defects, and each was met in turn, only when the one before it was cured: a union template, three classes of one name in three
namespaces, a base clause that is a pack, a using-declaration over a pack, a class defined in a function body, a member template
called through a pointer, a table of function pointers made of static member template-ids. Each was cut down to a reduction of ten
to forty lines, built with clang++ and with cicilang, and compared line by line before it became a rule. `std::variant<int,
double> v = 7;` builds now, and so does every form of the twelve new fixtures. The rules are in `CLAUDE.md`'s topics, each with its
fixture; this entry keeps the order in which the program met them.

THE DEFECTS, in the order met.

(1) UNION TEMPLATES. libc++ 18 keeps the alternatives of a variant in `union __union<_Trait::_TriviallyAvailable, _Index, _Tp,
_Types...>`, a template and its specializations of a union. Only `class` and `struct` items were class templates, so no instance
existed. `cpp_template_defined`, `cpp_template_class_def`, `cpp_instance_class` and `cpp_spec_name` take a union item, and the
instance is a union class (`'$cpp_union'`, asserted in `cpp_instance_body_`).

(2) THE UNION'S DESTRUCTOR. A union class's destructor destroyed every member, and the members share their storage: a variant
holding a long string freed it twice at its end. [class.dtor]/16: the union's destructor destroys no member (`cpp_dtor_body`).

(3) CLASSES OF ONE NAME IN SEVERAL NAMESPACES. `__base` is declared by `__variant_detail`, by `__variant_detail::__access` and by
`__variant_detail::__visitation`, and `__variant` by the last two; the flattened index keeps them apart by the suffix of their
namespaces (0.112). A qualified
name's first segment is looked up in the item's own scope (`cpp_rename_qualifier`), a class segment that follows namespace
segments is its key (`cpp_path_keys`), and a block's `using __variant_detail::__visitation::__variant;` makes the short name that
class for the statements after it (`cpp_stmts`, `cpp_body_typedefs_`).

(4) THE OVERLOAD SET OF A PACK OF BASES. `__all_overloads : _Bases... { using _Bases::operator()...; }` and C++17's `overloaded` idiom.
The reader skipped the `using` to its semicolon (reader version 115 reads `using(L, pack(Q))`); the base clause that is a bare pack
was an atom the expansion did not take; and the call road took the first base that had a method that fits, where C++ ranks the
union of their overloads. `cpp_inherit_methods/5` gives the class a forwarder for each method of the named base, so that the
overload rules see one set (`using Base::f;` too, with the hiding rule of [namespace.udecl]/15); a later empty base has no hop
(`cpp_base_hops`); an operator is a name after a qualifier (`cpp_qual_name`, `cpp_using_last`).

(5) AN AGGREGATE WITH BASES. `overloaded o{ [](int) {...}, [](double) {...} }` is an aggregate of C++17 ([dcl.init.aggr]/4.2): the
items go to the bases first. A closure that captures nothing is an empty base and keeps nothing, so its item is dropped
(`cpp_agg_skip_bases/3`); `cpp_class_takes/2` counts them.

(6) THE CONVERSION THAT NARROWS. The converting constructor of a variant chooses its alternative by `__overload<T, I>::operator()
(T, U &&) -> __check_for_narrowing<T, U>`, i.e. by whether `T (&&)[1]` accepts `{declval<U>()}`. A braced list for an array
parameter now holds only without narrowing ([dcl.init.list]/7; `cpp_narrows/2` and kin), so `variant<std::string, bool> v =
"text";` holds the string. And of two templates that tie on the class conversions, the one that takes an arithmetic argument as it
is beats the one that converts it (`cpp_scalar_rank/2`, [over.ics.rank]/3): `variant<long, int> v = 5;` holds the int.

(7) LOCAL CLASSES. `__assign_alt` assigns through `struct { void operator()(true_type) const ...; ... } __impl{this, ...};`, a class
with no name defined in a function. A local class is a class of the unit under a name of its own (`cpp_local_class/6`), registered
where the walk meets it, memoized by its text, named by the statements after it, and met by the first-return walk of an `auto`
result.

(8) MEMBER TEMPLATES. `__this->__emplace<_Ip>(...)` had no clause (the arrow took the template-id for a method name), and
`__impl_.__emplace<_Ip>(...)` found only the class's own templates, not a base's (`cpp_member_tmpl_via/7`). A nested class calls
a static member template of its holder bare (`__std_visit_exhaustive_visitor_check<...>();`). A static member template-id named
as a value is the thunk of its instance (`cpp_member_explicit_instance/4`, `cpp_instance_thunk/3`): `std::visit` stores
`dispatcher<Is...>::template dispatch<F, Vs...>` in an array of function pointers.

(9) A COMPILE THAT DID NOT END. `const bool v = as(b).vl();` over a derived class's object and a template that returns its argument's
reference: the constant evaluator reduced the member to the same term and `cpp_const_value` asked again, for ever -- twenty
minutes in the prologue of `std::visit`. A reduction that changed nothing is no value (`cpp_const_fold`).

(10) THE REST OF THE SURFACE. A variable template whose value is a braced object of the declared class (`in_place_index<I>`,
`cpp_braced_object/4`); an `inline` function template's instance is `linkonce` (`__invoke` over the overload set was a plain
definition, called but never defined: a link error); a reference member of an aggregate binds its item
(`__value_visitor<_Visitor>{std::forward<_Visitor>(__visitor)}`; `ir_init_sub/4`), a closure's own reference captures excepted.

(11) THE CATEGORIES, which made the copy of a variant move the string of its source. Four defects, one symptom (`stdvariant`:
the source string of a COPY was empty): `decltype(x)` of an unparenthesized name is its declared type, the reference kept; a
member initializer's `std::forward<A>(a)` was judged on its raw form and took the move constructor for every argument
(`cpp_arg_lvalue/1`); a member of an xvalue is an xvalue, and `std::move(x).m` is `std::move(x.m)` (`cpp_xvalue_member/2`); a
member of a const object is const, for an argument and for a deduced result. And `auto &&` as a result is `T &` for an lvalue
return and `T &&` for the rest.

(12) `hash<variant>`: the parameters of a function are declared before its block typedefs are resolved (`using alt_type =
remove_cvref_t<decltype(__alt)>;`), a class bound as its tag names its class in a path, and the call of a temporary object
takes the copy pass (`std::hash<std::string>{}("hello")` handed the literal's address to a `const string &`).

(13) THE EXTRA MOVE, AND THE DEFECT BEHIND IT. `Wrap<S>{S(9)}` moved the temporary into the member; C++17 constructs it in place. The first
cure copied the temporary into the member bitwise, and the fixtures that hold a class with its own address broke:
`Wrap<std::list<int>>{std::list<int>{7, 8}}` and a `std::function` member crashed at their first use (`free(): invalid pointer`),
the sentinel pointing into the dead temporary. The cure is C++17's own: the temporary is constructed IN the member
(`cpp_prvalue_in_place/3` retargets the statement expression to the member's address). Reduced (`reloc1`, `reloc2`), the same
defect stood in 0.120 for three more forms that the old code copied bitwise: a local initialized from a prvalue
(`std::function<int(int)> f = std::function<int(int)>(g);`), a `return` of a prvalue (`return std::list<int>{1, 2, 3};`,
`std::map<int, int> mk() { return std::map<int, int>{{1, 2}}; }`) and a local from a call that returns through the hidden pointer
(`std::map<int, int> m = build();`, which iterated for ever after `m[5] = 6`). The lowering builds each in the object
(`ir_prvalue_block`, `ir_in_place`, `ir_sret_call` and `'$ir_sret_into'`, the Lowering topic). The last form needed one more
step, found by the reduction `r4a`: `return m;` of a LOCAL map moves it into a `$ret` temporary and the temporary was copied into
the result -- the same block, named `$ret` instead of `$tmp`. `prvalueinplace.cpp` holds all of them.

(14) THE LAST ONE, found by the fixture that tests (2): a union at NAMESPACE scope with a constructor, a destructor or a method was
refused at its first use (`class('U')`), at 0.120 as well. It is a union class like the nested one (`cpp_union_class_members/1`,
`cpp_register_`, `cpp_item`), and `ccl_data_members/2` leaves the tag's `union_tag` out of the members so that `U u = {5}` names the
first one.

A REGRESSION OF THIS STEP, found by the closure fixtures before the chain: (10)'s first form bound every reference member of an
aggregate through the item's value, and a closure's reference capture, whose item is the address already, was bound through a
second indirection (garbage, `-1292736359`). The rule is by type now: an item whose type is a pointer to the referent is the
address (`ir_address_item/2`).

(15) THE COMPARISONS OF C++20. `variant <=> variant` was refused because `std::three_way_comparable<std::string>` was false. The
cause was not the concept: a rewritten comparison ([over.match.oper]/3.4) looked only at a member `operator<=>`, and libc++ 18
declares `operator<=>(const basic_string &, const _CharT *)` free. A free `operator<=>` and its reverse (`b <=> a`, the
comparison mirrored, `cpp_cmp_mirror/2`) are candidates now; `cpp_convertible` knows a class-to-class conversion (a derived
class, the target's converting constructor, the source's conversion function). `stringcmp20.cpp`, `stdvariantcmp.cpp`.

(16) THE FIRST CHAIN, RED. Five `std::format` fixtures failed (`stdformat`, `stdvformat`, `stdwformat`, `stdformatter`, `stdprint`):
the const member of (11) typed a `const char *const` argument, and the deduction of a by-value `T` kept the pointer's own
`const`, so no `__determine_arg_t` specialization matched. `cpp_decayed` drops it ([temp.deduct.call]/2). The bisect over the
hunks of the step (a group "leave-out" bisect, `bisminus.sh`; a prefix bisect failed because the hunks depend on each other) found
the two hunks; all five fixtures pass.

FOUND AND NOT DONE (in `CLAUDE.md`'s "Not done"): a member initializer `m_(S(5))` still moves the temporary into the member (the
aggregate form elides); an overload set on `const S &` and `S &&` over a plain struct chooses the first declared (`f(S{2})`,
`f(std::move(s))`: `copy copy copy` where clang++ prints `move move copy`). Also found: `own` is a keyword of the language, and a
fixture's member named `own` did not read.

GATES, over the final snapshot of 0.121 (committed before the last two finished; numbers carried by 0.122): reader 6 s, compile 10 s, driver 7 s, objects 3 s, proof 0 s, library read 836 s (peak 1019 MB), C++ gate 938 s (peak 1578 MB, 404 fixtures, no FAIL, the one skip `stdoptionalref`); all seven GREEN. The first chain of this step, over an earlier snapshot, was RED on five `std::format` fixtures (16).

Reader version 115, lowering version 64; the module rebuilt as 0.121, over cocolog 1.9.1.

## 0.122 — the numbers of 0.121

A save point: the gate numbers of 0.121 (above) and the last-run note in `CLAUDE.md`. No code changed; the module version moved to 0.122.

## 0.123 — the leftovers of 0.121, and libc++ 21 begun

**0.123: a member built from a prvalue in place, the move of a plain struct, libc++ 21 and 22 side by side.** Committed while the
gates run (a chain over libc++ 18 on a snapshot of this tree; nothing is claimed GREEN yet; the next commit carries the numbers).

(1) `H() : m_(S(5)) {}` is `m_(5)` (`cpp_member_inits`): the S is constructed once, in the member; the 0.121 probe `mv2` printed `ctor`, `move`,
and clang++ `ctor`. Fixture `memberinplace.cpp` (a struct that counts, a `std::function`, a list, a map, a string member).
(2) `f(const S &)` beside `f(S &&)` over a PLAIN struct (probe `mv1`): `std::move(s)` of a plain struct is `static_cast<S &&>(s)`
(`cpp_plain_xvalue`), the exact-match road takes an rvalue reference for an rvalue argument and no rvalue reference for an lvalue
(`cpp_fn_exact`, `cpp_prefer_rvalue`, `cpp_category_mismatch`), and a return reads a reference value through (`ir_stmt(return)`). Found on the
way, and a defect since 0.45: `std::vector<S>::push_back(const S &)` of a plain struct stored a struct into an int (`cpp_same_record`
took a `const S` for another type than `S` and the argument, a call, had none). Fixture `moveplain.cpp`.
(3) libc++ 21: the box has 18 (`/usr/lib/llvm-18`), 21 (`libc++-21-dev` from apt.llvm.org) and 22 (unpacked) side by side, chosen by
`$LLVM`; the link names the chosen tree's library (`-L<root>/lib -Wl,-rpath`, `ccl_link_libs`). Reader 116: a variable template names
itself in its own initializer (`__static_gcd`), and a value-initialized plain struct or union is zero (`__rep_ = __rep();`). `<string>`
reads whole and `stdstring.cpp` runs at 21. libc++ 21.1.8 has NO `optional<T &>`: it came with libc++ 22 (`__cpp_lib_optional >= 202506L`),
and `stdoptionalref.cpp` passes at 22; its `.needs` is that macro now.

## 0.124 — libc++ 21, the first failures

Committed while the chain over libc++ 21 runs (nothing claimed GREEN). Its library read had four failures: `<optional>` and `<string>` at C++23
and `<optional>` at C++26 read whole to fewer items than libc++ 18's floors (libc++ 21 includes less at C++23: `<optional>` 397 -> 222 items,
`<string>` 522 -> 410), so the floors in `test/libcxx.sh` are under both now (200, 380, 200); and `<iostream>` at C++20 stopped at libc++ 21's
`__allocating_buffer`, which uses a class-scope alias declared after its use with an attribute before the `=`
(`using _Alloc [[__gnu__::__nodebug__]] = allocator<_CharT>;`): the scan that notes such aliases ahead takes the attribute (reader 117).

## 0.125 — libc++ 21: the partial ordering

Committed while the batch over libc++ 21's failing fixtures runs (nothing claimed GREEN). The first failure met: `std::mismatch(a, a + 3, b, b + 3)` of four
pointers took the overload `mismatch(I1, I1, I2, BinaryPredicate)` and called a pointer (`call(id('__pred'))`), at libc++ 18 under C++20 as well; libc++ 21's
`lexicographical_compare` of pointers calls it, so `stdalgorithm3`, `stdarray` and others failed. The cause: the comparison of two function templates deduced each
way, since a parameter that stands twice (`I2, I2`) bound at its first occurrence and the second went unseen. Fixtures `partialorder2.cpp`, `mismatch4.cpp`.



## 0.126 — libc++ 21: the failures that were left

**0.126: libc++ 21 on Linux, the failures that were left.** Gated on one tree: the seven gates GREEN over libc++ 18, and the library read and the C++ gate GREEN over libc++ 21 (the numbers are at the end). The box has libc++ 18, 21 and 22 side by side (`LLVM=/usr/lib/llvm-NN` chooses the tree
that is read and linked); 0.123 to 0.125 ran the fixtures over 21 and left a list. Each failure was cut down to a reduction of ten to forty lines, built with
clang++ and with cicilang and compared line by line, then given its rule in `CLAUDE.md` and a fixture; a negative control, the rule reverted in a scratch copy of
the library, showed that each fixture earns its line. In the order the program met them:

(1) `__has_builtin(__builtin_common_type)` answers 0 (`pp_no_builtin/1`, reader 118): libc++ 21 then flattens `common_type` on its own specializations, as libc++ 18
does, and not on clang's builtin class template (`stdnumeric`, `stdptrcmp`, `stdatomic20`). Fixture `commontype.cpp`.
(2) `std::addressof(f)` of a FUNCTION: `T &` and `const T &` given a function deduce the function type ([temp.deduct.call]/2), not a pointer to it; libc++ 21's
`std::thread` hands `std::addressof(__thread_proxy<_Gp>)` to `__libcpp_thread_create`, and every thread program failed at the link. `addressfn.cpp`.
(3) The constant evaluator folds `__builtin_clz*`, `ctz*` and `popcount*` over an argument it holds (libc++ 21's `__countl_zero` is `__builtin_clzg(__t, digits)` of a
parameter, so `stable_sort`'s radix size stayed an unfolded static and an undefined symbol), and keeps a pointer through a named cast
(`reinterpret_cast<const char *>(__str)` in `__constexpr_strlen`: `std::string_view s{"true"}` of a constant did not fold, `constsv`, `staticsv`). `bitcount.cpp`,
`strlencast.cpp`.
(4) An enum's underlying type named through an ALIAS TEMPLATE-id (`using __memory_order_underlying_t = __underlying_type_t<__legacy_memory_order>;`) is settled as a
dependent typedef is (`stdatomic20`).
(5) A free OPERATOR template's declaration is registered and indexed as its definition is, and lends its default (`template <class _Tp, __enable_if_t<...> = 0>
complex<_Tp> operator*(...);` declared, defined later without the `= 0`): `a * b` of two `complex<double>` had no operator (reader 119). `enabledecl.cpp`. And a
template parameter that two function parameters deduce deduces ONE type: the second occurrence had been unseen, and a converting constructor then rescued
`operator*(const _Tp &, const complex<_Tp> &)` over two complexes with `_Tp = complex<double>`. `deduceagree.cpp`.
(6) A pointer to a data member of a PLAIN struct (`&Pt::x`), and `__builtin_invoke` of one on an object, a `const` object, an rvalue and a pointer
(`std::invoke(&Pt::x, p)`, `is_invocable`, `invoke_result`). `invokedata.cpp`.
(7) The poison pills: libc++ 21 writes `void iter_move() = delete;` where libc++ 18 wrote `void iter_move();`, and a deleted nullary function was not indexed, so the
unqualified call in `__unqualified_iter_move` went to the object `ranges::iter_move`, whose `operator()` asks the same concept: an endless recursion at the first
`std::reverse_iterator` of C++20 and in every `std::print` (reader 120). `reverseiter.cpp`.
(8) A requires-expression's own parameter pack expands with the bindings as a function's does (`cpp_subst` on `requires_expr`). Its parameters had become `__args$1`,
`__args$2` while the requirement kept `__args`, found nowhere, so the variable of that name in `__try_constant_folding(..., basic_format_args __args)` was found, and
`invocable<equal_to &, char &, char &>` was unmet in every `std::format` and `std::print`. `reqpack.cpp`.
(9) A static member function named BARE as a value is its thunk (`fn = prep;`, `Buf{16, prep}`); several static functions of the name wait for the target that
chooses ([over.over]), and a non-static member of the name is no candidate: libc++ 21's `__allocating_buffer` has a member `__prepare_write(size_t)` beside the
static `__prepare_write(__output_buffer &, size_t)`. `staticfnval.cpp`.
(10) A qualified enumerator is the value ITS OWN ENUM gives it. The enumerators' table is keyed by the bare name, so `B::X` beside `A::X` printed A::X's value, and
a `case state::Consonant:` naming an enum nested in the class being walked reached the lowering raw -- libc++ 21's grapheme-cluster rules, `std::print` and
`std::format` of a string. A silent wrong answer in the program's own code since the first enum class; found by the library. `enumscope.cpp`.
(11) A plain struct or union member initialized by parentheses from a value of another type is aggregate initialization (C++20): libc++ 21's `basic_string() :
__rep_(__short())` was assigned as `sext %struct.__short to %struct.__rep` and LLVM refused it in every `std::string` of a `-std=c++20` program. `unionparen.cpp`.

(12) libc++ 18's `__invoke` for a data member, found by `invokedata.cpp` (itself written for (6)): a plain struct is its own base to `__is_base_of`
(`std::invoke(&Pt::x, p)` took the pointer overload), `*e` of an arithmetic value is refused by name (`deref_of_arithmetic`: the detection of `__invoke`'s
dereference overloads read `*int` as an lvalue), `x.*pm` carries the object's const and its xvalue (`cpp_memptr_qualify`, so `invoke_result_t<int Pt::*, const Pt &>` is
`const int &` and the one over `Pt &&` an `int &&`), and a pointer operand that is a reference to a pointer is read through in the lowering (`*static_cast<A0 &&>(a0)`:
`ir_ptr_operand`).
(13) The views of libc++ 21 (`viewdrop`, `viewkeys`, `viewreverse`, `viewtake`, `viewtakewhile`, `viewtransform`, `viewchain`, `stdviews`, `viewsall` -- nine
fixtures that had failed since the first run over 21): `__pipeable<_Fn> : _Fn, __range_adaptor_closure<__pipeable<_Fn>>` is asked for `ranges::
__derived_from_range_adaptor_closure(__range_adaptor_closure<_Tp> *)`, and a LATER EMPTY base is a base to the template-id deduction and to `cpp_class_fits`
(`'$cpp_extra'`: no sub-object, no slot, [temp.deduct.call]/4.3); and `struct __fn : __range_adaptor_closure<__fn>` of a header asks `requires is_class_v<_Tp>` of its
CRTP base while `__fn` is registering, so a header's plain class being loaded is a class to `__is_class` (`cpp_class_in_progress`). Fixture `crtpclass.cpp` (the
first; the second is the views' own).
(14) `stdvformat` (`formatted_size`, `format_to_n`): two rules, found one under the other. (a) `std::addressof(__max_output_size_)` in the base initializer of
libc++ 21's `__formatted_size_buffer` was typed `_Tp *` by the summary's signature and `_Tp` is a KNOWN name -- libc++'s `__format_char` opens with `using _Tp =
decltype(__value);` and a typedef in a block joins the unit's one table -- so the argument came out `int *` and fitted no constructor: the type of a call of a function
template that names the template's own parameter is raw (`cpp_callee_param_type/2`; `rawparam.cpp`, a program with a block typedef `_Tp` and `std::addressof` in a base's
initializer). (b) With `<string>` read before `<format>`, `back_inserter` stood TWICE under its name (each header's summary holds the file): the first candidate's check
refused and left `back_insert_iterator<void>` half made -- its name recorded, no struct made -- and the second was answered the name, held, and emitted a constructor of
a class that was never made (`typedef(back_insert_iterator.void)` at the lowering). One function template declared by two summaries is one candidate
(`cpp_dedupe_candidates/2`: alike in head, storage, result, parameters and body once the line of each statement is set aside). Two ways of mending (b) at its root
were tried first and are not in the tree: a registration that refuses FORGETS its name (a second ask refuses again), which broke `viewchain` and `viewsall` -- the
views at libc++ 21 lean on the name being answered after a refusal, a refusal of the not-yet-mended trailing-`decltype` SFINAE of `std::size` -- and a library member
whose `auto` result does not deduce left undeclared. `formatton.cpp` (C++20, libc++ 21 only), `stdvformat.cpp`; negative controls for both rules: the rule reverted in a
scratch copy of the library, two different refusals.
(15) `stringcmp20` (`std::three_way_comparable<std::vector<int>>` was false): libc++ 21's vector `<=>` is `__synth_three_way_result<_Tp>` over the lambda
`[]<class _Tp, class _Up>(const _Tp &, const _Up &)`, and the tables carry `_Up` as a block typedef of another function (`using _Up =
__libcpp_remove_reference_t<_Tp>;`), which `cpp_type` resolved in the lambda's second parameter: `const _Tp &`, `_Up` undeducible. A generic lambda's parameters that
name its own template parameters stay as written where the tables know the name (`cpp_lambda_params/3`). `lambdatparam.cpp` (C++20), a program of its own.

Found and not fixed (they are in "Not done"): a comparison, `!`, `&&` and `||` are an `int` in C++ (`decltype(x < y)`, `sizeof(auto b = x < y)`, `boolalpha`, the
overload on `bool`); the block-typedef leak behind (14a) and (15) is worked round where it bit, not scoped.

Fixtures added: `addressfn`, `bitcount`, `commontype`, `deduceagree`, `enabledecl`, `enumscope`, `invokedata`, `memptrqual` (C++20), `reqpack` (C++20), `reverseiter`
(C++20), `staticfnval`, `strlencast`, `unionparen` (C++20), `crtpclass` (C++20), `formatton` (C++20), `lambdatparam` (C++20), `rawparam`: 17 in all, 425 in the
directory. The 0.123 fixture `stdoptionalref` is skipped below libc++ 22 (`__cpp_lib_optional >= 202506L`).

**The numbers.** One tree (`snapY`: its `library/`, `test/`, `module/`, `bin/` and `proof/` are the commit's, byte for byte), cocolog 1.9.1, fresh HOMEs. Over
libc++ 18 (`LLVM=/usr/lib/llvm-18`): the reader gate GREEN in 5 s, compile in 9 s, driver in 7 s, objects in 2 s, the proof; the library read GREEN in 771 s (62 other
headers warmed, none failed to flatten; peak 1045 MB); the C++ gate GREEN in 836 s (peak 1516 MB): 424 of 425 fixtures ok, the 14 refusals, 1 skipped
(`stdoptionalref`, `__cpp_lib_optional >= 202506L`, which libc++ 21.1.8 does not meet). Over libc++ 21 (`LLVM=/usr/lib/llvm-21`, the C gates do not read libc++): the library
read GREEN in 750 s (peak 1039 MB), the C++ gate GREEN in 667 s (peak 1540 MB), 424 of 425, the same skip. Before the chains, a net of the fixtures that reach the rules
everything walks -- overloads, deduction, containers, streams, lambdas, the library's detections: 77 over libc++ 18, 95 over libc++ 21 with the views, the format
family and the new fixtures -- ran SAME. It is the net that showed the first mending of (14b) wrong: 93 of 95 over libc++ 21, `viewchain` and `viewsall` RED, until the
mending was taken out and the candidates de-duplicated instead (77 of 77 and 95 of 95, then the chains above).

Reader version 120, lowering version 67; the module rebuilt as 0.126, over cocolog 1.9.1.


## 0.127 — the "Not done" list of 0.126 taken up

**0.127: the C++ language items of "Not done".** The owner's word: finish the works that "Not done" lists. This step takes the
C++ language items whose fix the box can prove; the ABI layout, the decimal floating types, the untried libc++ modules, the
safe part's flow and the debug info are later steps. Each item was cut down to a reduction, built with clang++ and with
cicilang and compared line by line, given its rule in `CLAUDE.md` and a fixture; a negative control, the fixtures built on a
worktree of 0.126, shows each fixture of a defect failing there (`boolresult`, `promotion`, `plainclash`, `nsenum`, `aggbase`
DIFFERENT; `enumtype`, `trailret`, `lazymember`, `valueinit` refused) while `accessctl3`, `lambdaconst` and `byteops`, which guard
what stays allowed, pass there too. In the order they were taken:

(1) A comparison, `!`, `&&` and `||` are `bool` in C++ (`ccl_truth_type/1`; the lowering's `ir_truth/4` makes an `i8`): `decltype(x
< y)` was `int`, `auto b = x < y` four bytes, `boolalpha` printed `1`, `f(x < y)` took `f(int)`. With it, three neighbours that the
same programs met: an enumerator is of its ENUM's type (`'$t'(Name)-Tag` and `'$s'(Tag)-1` beside the values, reader 121;
`h(Red)` called `h(int)`, `v.push_back(Green)` was `undeclared`), an enum promotes as its underlying type, and a PROMOTION is a
better conversion than any other (2.5 against 2, an enum to its fixed underlying type 2.75; `p(short)` beside `p(long)` and
`p(int)` took the first declared). A member operator and a free one are weighed together (`cpp_prefer_free/3`): `cout << c` of an
enum is the member `operator<<(int)`. A conditional over two arms of one arithmetic type keeps it (`(c ? 'Y' : 'N')` printed 89).
Fixtures `boolresult`, `enumtype`, `promotion`.
(2) A free function DEFINITION keeps a trailing `decltype` as its result (reader 121, `cpp_decltype_ret/3`), so `auto first(V &v)
-> decltype(v[0])` returns a reference and the SFINAE of `-> decltype(t.foo())` drops the candidate; the result type is substituted
under the packs' bindings; a member named through a scalar refuses `no_member(M, T)`. Fixture `trailret`.
(3) A block's typedef is the block's in C++ (`cpp_scoped_typedefs/2`, `ccl_tab_del/2`; the bulk noter keeps out of the unit's table
all but the tags and enumerators of its type). Fixture `blocktypedef` (HEAD prints a wrong value).
(4) The program's own class template instances are lazy, their members made where used and still checked (`'$cpp_lazy_p'`).
Fixture `lazymember`.
(5) Access control: the access of an inheritance, [class.protected]'s rule on the object, a pointer to member, a nested type's name,
a destructor and an operator used as one. Six refusals, `access_inherit` ... `access_operator`, and `accessctl3` for the allowed forms.
(6) A closure's `operator()` is const unless `mutable` (or an explicit object parameter): `non_const_member_on_const(M, C)` and
`binds_const(N)` refuse what clang++ refuses (`lambda_method`, `bind_const`); `lambdaconst` for what stays allowed.
(7) The small defects: a plain struct handed to a scalar parameter clashes in the arity-only resort and in a call through a
function pointer (`plainclash`, C++20); two namespaces' enums and enumerators of one name are keyed as functions and classes are
(`nsenum`); value-initialization zeroes a class whose default constructor is not user-provided -- `R()`, `R r = R();`, `T t{}`, a
member's `r()`, `new R()`, `new (p) R()`, `new int()` -- while `new T` and `new (p) T` with no initializer default-initialize (reader
122's `new_default(T)`; `valueinit`); an aggregate's base with storage takes its item (`aggbase`: `D d{}` never ran the base's
constructor); a class's table pointer is no pointer the check follows (`V v = V();` was `untied`).

Found on the way and fixed: a SHIPPED static member function was called with the desugaring's null `this` first, so
`ios_base::sync_with_stdio(true)` passed a null where the bool goes and `locale::global(loc)` a null for its locale (`shipstatic`; the
lowering drops the null, `'$cpp_static_abi'`). A regression of (1) that the net caught: with the enum promoted, `~b` of a `std::byte`
was the built-in on an int, -16; a scoped enum's operators are now the header's, loaded by name, templates among them
(`byteops`) -- and the first form of that rule resolved every header operator template's parameter types, which instantiated
`duration<_Rep1, _Period1>` over its free names and recursed in `<ratio>`'s `__static_gcd` until the cap (a program with `<locale>`).
A bare-named parameter alone is asked now.

The first chain over libc++ 18 was RED on one fixture, `enumtype`, which had gone into the directory unseen -- against the rule that a
fixture goes in only once seen to pass; the net that was to show it had stopped at the `'$cpp_bacc'` defect. Two defects stood behind it:
`Shape::Circle`, an enumerator of an unscoped enum nested in a class, was folded by the class road as an `int` static
(`cpp_enum_class_tag/3` gives it its enum's type), and `std::cout << Hi` of an `enum : unsigned char` printed 72: the template road
ranked a promotion as a conversion, one demerit each, so the free `char` inserter tied with the `unsigned char` one, came first, and lost
to the member `operator<<(int)`; a promotion costs one demerit now and a conversion two. The C++ gate over 18 and the chain over 21 then
ran on the mended tree.

Moved out of "Not done" as rules: `\N{NUL}` refused, a VLA initializer other than `= {}` refused and `__imag__` of a real as a place
refused, each as clang refuses it; a recursive lambda through `this auto self`; a file-scope `new int` without an owner; module
linkage.

Fixtures added: `boolresult`, `enumtype`, `promotion`, `byteops`, `trailret`, `blocktypedef`, `lazymember`, `accessctl3`,
`lambdaconst`, `plainclash` (C++20), `nsenum`, `valueinit`, `aggbase`, `shipstatic`: 14, 439 in the directory; refusals added:
`access_inherit`, `access_protobj`, `access_memptr`, `access_nested`, `access_dtor`, `access_operator`, `lambda_method`,
`bind_const`: 21 in `test/cpp.sh`.

**The numbers.** cocolog 1.9.1, fresh HOMEs, two snapshots that differ in `library/ccl_cpp.pl` alone (the two `enumtype` rules),
which no C gate and no library read walks. Over libc++ 18 (`LLVM=/usr/lib/llvm-18`): the reader gate GREEN in 5 s, compile in
10 s, driver in 7 s, objects in 3 s, the proof; the library read GREEN in 1055 s (64 other headers warmed, none failed to
flatten; peak 1464 MB; the reader bump made every summary cold); the C++ gate on the committed tree GREEN in 820 s (peak
1669 MB): 438 of 439 fixtures ok, 1 skipped (`stdoptionalref`), the 21 refusals and the safe part's. Over libc++ 21
(`LLVM=/usr/lib/llvm-21`): the library read GREEN in 1031 s (peak 1286 MB), the C++ gate GREEN in 740 s (peak 1531 MB), 438 of
439, the same skip.

Reader version 122, lowering version 68; the module rebuilt as 0.127, over cocolog 1.9.1.

## 0.128 — line tables, the store's vacuum, unsigned constants

**0.128: `-g`, the vacuum and the unsigned constants.** Two items of "Not done" (Tools and performance) and four defects of the
constant evaluator that the probes of 64-bit and 128-bit global constants found, before the `__int128` step they were written for.

(1) `-g` gives LINE TABLES, DWARF 5 (`ir_dbg_*` in `library/ccl_ir.pl`): a function the program defines gets a `DISubprogram`, every
instruction of its body the `DILocation` of the statement's line, and the module the compile unit, the file and the two flags LLVM
asks. `bin/cicilang` maps every `-g` form but `-g0` and `-ggdb0` to the option `debug`; the driver hands the lowering the file's
absolute path; the IR cache's signature folds the option. A library function gets none. Checked by hand with gdb over
`dbg1.c` (`break twice` stops at `dbg1.c:3`, `bt` shows `main () at dbg1.c:9`, `next` steps to lines 4 and 5, `finish` returns
to line 9) and over a C++ program with a class, a template, a lambda and libc++ containers (`dbg2.cpp`: `break dbg2.cpp:15`
stops in the instance of `sum`, and `bt` names `main () at dbg2.cpp:24`); the driver gate's new check reads the line table back
with `llvm-dwarfdump` (the lines 3 4 5 8 9 10 11 and the file's name). No variable, type or scope is described: `print x` has
nothing to read; and a C++ function is known to the debugger by this compiler's own name (`break 'Counter.bump.int'` stops,
`break Counter::bump` finds nothing). Both stay in "Not done".
(2) The C store is vacuumed: `bin/cicilang` counts its runs in `KB.runs` and runs `cocolog --embed KB vacuum` every 64th one,
and each gate vacuums the store it starts from (`ccl_kb_prepare`). A vacuum of a 25 MB store takes 0.4 s.
(3) An unsigned constant operation is done in its type (`ccl_cv_binary/7`, `ccl_cv_unary/3`): the evaluator's values are
untyped mathematical integers, so `~0u` was -1, `~0u / 3` folded to 0 (clang: 0x55555555), `0u - 1` was -1 and `-1 < 0u` held;
`_Static_assert(~0UL / 3 == 0x5555555555555555UL)` failed and `unsigned g = ~0u / 3;` was 0. Where both operands and the result
are small and not negative the answer is the same in every type and comes at once; else the operands' common type decides.
(4) `#if` computes in `uintmax_t` (C 6.10.1/4; `'$ccl_cv_pp'`): `#if ~0u == 0xFFFFFFFFFFFFFFFF` was false.
(5) The bulk noter had an evaluator of its own for an enumerator's value (`ccl_const_eval_in/3`), which read `(unsigned char) 300`
as 300 and `-1 < 0u` as 1; it asks `ccl_const_eval/2` now, the enumerators before put in as their values. Reader 123: a
summary's `enum/2` values come from it.

Moved out of "Not done": `-g` (line tables; the variables stay), the store's dead rows, and `std::atomic<shared_ptr>`, which
neither libc++ 18 nor libc++ 21 has (clang++ refuses it over both trees).

Fixture added: `test/c/run/unsignedconst.c` (globals, enum values, an array bound and ten `_Static_assert`s, against clang).

**The numbers.** cocolog 1.9.1, fresh HOMEs, one snapshot of the tree. Over libc++ 18 (`LLVM=/usr/lib/llvm-18`): the reader
gate GREEN in 5 s, compile in 10 s, driver in 7 s (27 checks, the line table's among them), objects in 4 s, the proof; the
library read GREEN in 1123 s (64 other headers warmed, none failed to flatten; peak 1824 MB; the reader bump made every summary
cold); the C++ gate GREEN in 929 s (peak 1665 MB): 438 of 439 fixtures ok, 1 skipped (`stdoptionalref`), the 21 refusals and
the safe part's. Over libc++ 21 (`LLVM=/usr/lib/llvm-21`): the library read GREEN in 940 s (peak 1130 MB), the C++ gate GREEN in
644 s (peak 1660 MB), 438 of 439, the same skip. Probes of the next step ran beside the two long gates, so their times are no
measure.

Reader version 123, lowering version 69; the module rebuilt as 0.128, over cocolog 1.9.1.


## 0.129 — `__int128` in C++, the decimal floating types, and what they found

**0.129: two items of "Not done" (C), and the defects they found.** Each defect was cut down to a reduction, built with clang
(gcc for the decimal types, which clang does not have) and with cicilang, compared line by line, given its rule and a
fixture; a negative control built each fixture on 0.128.

(1) `__SIZEOF_INT128__` is predefined in C++ as in C, so libc++ builds its int128 configuration: `numeric_limits<__int128>`,
`to_chars` and `from_chars` in 128 bits, `std::hash<__int128>` and `std::format` of one run (`int128lib.cpp`, `int128fmt.cpp`).
That configuration met three defects in turn:
(a) the bit builtins had no type to the inference, so a conditional over two calls of `__builtin_clzll` had none and the
lowering refused it, `type(unknown)` -- in C as well (`bitcond.c`); libc++'s `__libcpp_clz(__uint128_t)` is written so;
(b) a folded constant past 64 bits was typed `unsigned long` and lowered as an `i64`, cut to its low half:
`numeric_limits<__int128>::max()` printed 2^64 - 1;
(c) EVERY EXPLICIT SPECIALIZATION OF A FUNCTION TEMPLATE WAS IGNORED: `template <> int f(unsigned long, int)` was one more
candidate with no template parameter, tied with the primary, and lost to it, the first declared; `template <> int f<char>(...)`
went to the class specializations, which nothing reads for a function. A silent wrong answer in the program's own code since the
first function template; libc++'s `__to_chars_itoa(char *, char *, __uint128_t, false_type)` printed `42` as twenty digits. A
specialization is no candidate now: the chosen template's instance takes its body (`fnspec.cpp`; on 0.128 every line of it differs).
(2) The `global_init` refusal that "Not done" named: a floating constant under a cast to an integer type folds (`(__int128) 1e30`,
`(int) 2.5`), a double past 2^59 converts to a wide integer exactly and a wide integer to a double rounded to nearest, a floating
global's fold reads a cast to an integer type, and an integer global from a floating initializer converts -- `int g = 2.5;` was
spelled as a double's hex, which LLVM refuses (`floatglobal.c`).
(3) C23's decimal floating types, `_Decimal32`, `_Decimal64`, `_Decimal128`, run as gcc builds them: the literal's text kept by
both lexers and encoded exactly (BID, rounded half to even), the value carried as a float, a double or an fp128 so that the ABI
passes it where gcc does, every operation a call of libgcc's decimal runtime (`decimal.c`, against gcc's output). The type words
were read as typedef names. A decimal member of a struct is an SSE leaf, a `_Decimal128` one fp128 piece: until that rule, a
struct of decimals went in integer registers, and the call from gcc-built code read garbage while the call into it only looked
right (the values were still in the xmm registers); the driver gate now passes values, structs and a variadic call both ways
against gcc-built code.

Moved out of "Not done": the decimal floating types and `__int128` in C++. Left there: a decimal from or to a 128-bit integer
(gcc calls `__bid_floattidd` and `__bid_fixddti`, which this libgcc does not have) and an operation in a decimal global's
initializer.

(4) Found by the gate over libc++ 21: the bit builtins knew the widths 8, 16, 32 and 64 only, and the lowering failed with no
word, `item(function('__countl_zero.unsigned___int128', ...))`. Once `__int128` was C++'s, libc++ 21's `__countl_zero` calls
`__builtin_clzg` on an `unsigned __int128` (libc++ 18 splits it into two 64-bit calls), and every program that formats an
integer reaches it: `std::format`, `std::print`, `std::formatter`, `format_to_n` and the two `__int128` fixtures, eight RED. Every
integer width is one now, an `_BitInt(N)`'s too (`bitwide.c`, `bit128.cpp`).

Fixtures added: `test/c/run/decimal.c`, `floatglobal.c`, `bitcond.c`, `bitwide.c`; `test/cpp/run/fnspec.cpp`, `int128lib.cpp`,
`int128fmt.cpp` (C++20), `bit128.cpp` (C++20); the link files `test/c/link/dec_main.c`, `dec_helper.c`.

**The numbers.** cocolog 1.9.1, fresh HOMEs, one snapshot of the tree. Over libc++ 18 (`LLVM=/usr/lib/llvm-18`): the reader
gate GREEN in 5 s, compile in 10 s, driver in 7 s (28 checks, the decimal ABI's among them), objects in 3 s, the proof; the
library read GREEN in 1327 s (peak 2890 MB: the reader bump made every summary cold, and probes ran beside it); the C++ gate
GREEN in 954 s. Over libc++ 21 (`LLVM=/usr/lib/llvm-21`): the library read GREEN in 1141 s (peak 1313 MB), the C++ gate RED in
701 s, eight fixtures, (4) above. After the fix, on the same snapshot with its two fixtures: the three C gates over a fresh
store (reader 5 s, compile 10 s with 111 run fixtures ok, driver 7 s), the C++ gate over libc++ 18 GREEN in 1128 s and over 21
GREEN in 794 s, 442 of 443 fixtures each, 1 skipped (`stdoptionalref`), the 21 refusals and the safe part's. Probes of the next
steps ran beside the long gates, so their times are no measure.

A defect found while the fix was gated: the compile gate run a second time over the store its first run had filled RAN AWAY,
7.3 GB in eight minutes. A read the store serves holds its floats as cocolog writes them, with 15 digits (`%.15g`): every
literal that needs more came back another double, a silent wrong answer, and `0x1.fffffffffffffp1023` of `hexfloat.c` came
back past the largest double, an infinity, on which the lowering's normalization recursed without end. A defect of the store
since M4 that no gate met, because each version bump starts a fresh store; "Not done" names it until its fix.

Reader version 124, lowering version 70; the module rebuilt as 0.129, over cocolog 1.9.1.

## 0.130 — `-g`: the variables, their types, the blocks and C++'s names

A SAVE POINT: the four C gates and the proof ran on this commit, GREEN (reader 5 s, compile 11 s, driver 11 s with 30
checks, objects 5 s), beside the net chain of the series 0.130 to 0.132, so their times are no measure; the library read and
the C++ gate ran on the whole series, and their numbers are 0.132's. Nothing else is claimed GREEN.

**0.130: the rest of `-g`, an item of "Not done" (Tools).** 0.128 gave line tables alone: a debugger stopped at a line, and
`print x` had nothing to read, and a C++ function was known by this compiler's own name. Each piece was read back with gdb
over a C program (`v1.c`: parameters, locals, an array, a struct with a bitfield and a pointer to itself, an enum, globals),
a C++ program without the library (`c2.cpp`: a namespace, a base with a virtual function, a class template's instance, a
nested class, a static data member, an `enum class`) and one over libc++ (`dbg2.cpp`: `std::vector<int>`, `std::string`, a
lambda), and against clang's own output for the same programs.

(1) THE VARIABLES. Every named local and parameter of a function the program defines is a `DILocalVariable`, declared by
`llvm.dbg.declare` over its slot where `ir_local/3` makes it; a parameter has its number and `this` the object pointer's
flags; every global the program defines is a `DIGlobalVariableExpression` that the compile unit lists, and a static local
one in its function's scope.
(2) THE TYPES, described once per module and keyed so that one struct named three ways is one type: base types by their
encoding, pointers, references, cv, typedefs, arrays, structs, unions and classes with their members at their bit offsets
(a bitfield flagged, a base sub-object an inheritance), enums with their enumerators (a scoped one flagged). gdb prints a
`std::vector<int>` and a `std::string` member by member.
(3) THE BLOCKS: a block of statements is a `DILexicalBlock`, so two variables of one name in two blocks are two.
(4) EACH FUNCTION'S TYPE: `ptype twice` is `int (int, const char *)`, and `finish` prints the value returned.
(5) C++'S NAMES AND SCOPES: a method is its member's name in its class's description (so `ptype` lists the methods), a free
function its name in its namespace's `DINamespace`, a function template's instance its name and arguments (`twice<int>`), a
class its own name (`Buf<int, 4>`) in its namespace or its holder, a static data member `Class::name` in its class's
namespace. `break geo::Counter::bump` stops in both overloads, `bt` names `geo::Counter::bump`, `print shapes::Outer::made`
reads the static, `print k` is `shapes::Kind::square`. The symbols stay this compiler's own.
(6) THE PROLOGUE: the parameters' stores have no location, as clang's have none. With the function's line on them, LLVM
put the prologue's end before them, and gdb's breakpoint on a function read the parameters before they were stored
(`n=32767`). The line table is clang's row for row.
(7) THE KINDS: `-g1`, `-ggdb1`, `-gline-tables-only` and `-gline-directives-only` give the line tables alone (`debug(lines)`,
`emissionKind: LineTablesOnly`, no variable and no type); the other forms the full information; the last form on the line
wins, as clang. The compile unit says `nameTableKind: None`, as clang's does on Linux: gdb had warned that it ignores LLVM's
`.debug_names`.

What is left in "Not done": a destructor at a scope's end has its object's declaration's line, no location has a column,
`-g3`'s macros are not described, and a static data member is a global with a qualified name, not a member declared in its
class.

Checks: the driver gate's two new checks read the variables and the types back with `llvm-dwarfdump`, and the line table
with no variable under `-gline-tables-only` (30 checks). By hand: every `test/c/run/*.c` built with `-g` and run against its
expect (67 of 67), and 35 C++ fixtures built with `-g` and run against theirs.
