# cocolang

**A Safe Modern C and C++ compiler to LLVM, written on cocolog.**

cocolang reads C and C++, checks it, and lowers it straight to **LLVM IR**.
It is not a transpiler: no C is ever emitted. Every pass -- the preprocessor,
the reader, the type inference, the ownership check, the C++ desugaring and
the lowering -- is [cocolog](https://github.com/saman-pasha/cocolog) clauses,
and the embedded LLVM turns the IR into a native binary. The philosophy is
[Cicili](https://github.com/saman-pasha/cicili)'s Safe Modern C: memory
safe, ownership checked at compile time, zero runtime overhead, no garbage
collector. cocolang is a new implementation of that philosophy, and its
native pieces are written in Cicili.

It uses Cicili, cocolog and [ZiguratIP](https://github.com/saman-pasha/ziguratip)
and **modifies none of them**. `DESIGN.md` is the architecture; `CLAUDE.md`
is how the repository is worked on, its rules by topic; `HISTORY.md` is the
record of every step.

## Features

* **C17 and C23, whole.** Every form of C17, and C23's: `_BitInt(N)`,
  `_Generic`, `typeof` and `typeof_unqual`, `nullptr`, `constexpr` objects,
  `static_assert`, `[[attributes]]`, `#embed`, `__VA_OPT__`, `#elifdef`, the
  digit separator, binary literals, `wb` suffixes, the checked arithmetic of
  `<stdckdint.h>` and the bit utilities of `<stdbit.h>`, C11's atomics
  through the compiler's own `<stdatomic.h>`, variable length arrays, thread
  locals, wide and UTF-8 literals, variadic functions over the compiler's
  own `<stdarg.h>`, `long double` as x87's 80-bit type on x86-64, hex
  floats, designated initializers, anonymous members, K&R definitions,
  `#line`, and trigraphs in the ISO modes. `-std=c17` is the default,
  `-std=c23` the level.
* **C++17, C++20, C++23 and C++26.** Classes, virtual dispatch, multiple
  and virtual inheritance, templates with partial specialization, SFINAE,
  concepts and `requires`, lambdas (generic, capturing `this` and `*this`),
  structured bindings, `if constexpr`, `consteval` at compile time, the
  three-way comparison and the defaulted comparisons, pack indexing, the
  `_` placeholder, class template argument deduction, pointers to members,
  `constexpr` functions evaluated at compile time over locals, aggregates,
  pointers and `this`, RTTI (`typeid`, `dynamic_cast`), exceptions
  (`throw`, `try`, `catch`), `new T[n]` of a class with the ABI's array
  cookie, multiple polymorphic bases with their secondary vtables,
  virtual bases reached through the vtable, the diamond with one shared
  base, `noexcept` enforced, trailing return types,
  coroutines (`co_await`, `co_yield`, `co_return`, `operator co_await`,
  `std::coroutine_traits`, over LLVM's coroutine intrinsics), modules
  (`export module`, `import`, header units, exports enforced), contracts enforced at
  run time, and the Itanium ABI's layout, name mangling and calling
  convention, so cocolang's objects link with clang's.
* **libc++ compiled from its own headers.** Nothing of the standard
  library is written here: `std::vector`, `std::string`, `std::map`,
  `std::set`, the unordered containers, `std::optional`, `std::tuple`,
  `std::array`, `std::unique_ptr` and `std::shared_ptr`, `std::function`,
  `std::bind`, `<algorithm>`, `std::cout`, `std::cin`, `std::getline` and
  the manipulators all compile from libc++'s own bodies and run, on macOS
  (libc++ 21) and on Linux (libc++ 18).
* **The safe part.** `own` pointers are linear and `move` hands them on. A
  borrow dangles when its owner is consumed and may not escape. A struct's
  own fields are owners that go with it. A plain pointer parameter is a
  borrow of the caller's. `x tie y` ties a lifetime. Every pointer has an
  ownership path, or the program is refused, at compile time, with the
  statement's line.
* **Macros in the compiler's own language.** A `.pl` file included, or a
  `#cocolog ... #end` block, is a set of macros that run at parse time over
  the syntax tree, with the symbol table open to them. `format`, `print`,
  `println` and `clone` are such macros.
* **The small additions.** `name := expr;` declares by inference, its left
  side a pattern; `name { members }` declares a struct type; `defer(a, b)
  { body }` is a scope-bound cleanup with no runtime.
* **clang's arguments.** `cocolang` and `cocolang++` take what `clang` and
  `clang++` take: `-c -S -E -emit-llvm -fsyntax-only -o -O0..-Oz -I -l -L
  -shared -std= --version`. Diagnostics are `file:line: error: what`.
* **Fast, once warm.** The C headers a program includes are read once into
  the user's knowledge base, `~/.cocolang/KB`, and served from it in every
  later run; a C++ library header is flattened once and summarized to
  `~/.cocolang/cpp`. A built file's IR is cached beside its unit. The
  B-tree benchmark matches clang `-O3` and beats Rust's `BTreeSet` on
  insert and search.

## Install and build

cocolang needs the three neighbours checked out beside it (the paths are
the `CICILI`, `COCOLOG` and `ZIGURATIP` variables, defaulting to
`~/Projects/GitHub/<name>`), an LLVM with its C API (Homebrew's `llvm` on
macOS, `llvm-18-dev` or newer on Debian and Ubuntu), a `cc` and a `c++`
for the link, and libc++ for the C++ side.

```sh
CICILI=~/Projects/GitHub/cicili COCOLOG=~/Projects/GitHub/cocolog sh module/build.sh   # -> library/cocolang.so
LLVM=/usr/local/opt/llvm sh module/build-llvm.sh                                     # -> library/ccl_llvm.so
sh test/reader.sh; sh test/compile.sh; sh test/driver.sh; sh proof/run.sh            # the C gates
sh test/libcxx.sh; sh test/cpp.sh                                                    # the C++ gates: the library read warms the cache first
sh test/gates.sh                                                                     # all seven in one chain, the C++ ones in parallel
```

`module/build.sh` transpiles `module/cocolang.cicili` with Cicili and
compiles it against cocolog's module SDK. `library/*.pl` needs no build.

## The commands

```sh
cocolang prog.c -o prog              # read, check, lower, compile, link
cocolang -c prog.c                   # prog.o        cocolang -S prog.c   # prog.s
cocolang -emit-llvm -c prog.c        # prog.ll       cocolang -fsyntax-only prog.c
cocolang -E prog.c -o flat.c         # the preprocessed text, from cocolog's preprocessor
cocolang -O2 a.c b.c util.o -lm -o app
cocolang -std=c23 prog.c -o prog     # C23's forms
cocolang++ -std=c++20 prog.cpp -o prog
cocolang -I include prog.c           cocolang -ast-dump prog.c           cocolang --version
```

`cocolang++` is `cocolang` for C++: the same arguments, every input read as
C++, C++17 the default level and `-std=c++20`, `-std=c++23`, `-std=c++26`
the others, the link through `c++`. The exit status is 1 when there is a
diagnostic. `cocolang -v` says each step, and `served main.c from the
store` when a file's IR came from the cache.

The knowledge base is the user's, `~/.cocolang/KB` (or `$COCOLANG_KB`;
`--no-kb` keeps everything in memory). The first call is the initialization
phase, reading the C standard library's headers once. It is stamped with
the reader's and the lowering's versions and starts afresh when either
changes. `cocolang++` keeps its headers as summaries under
`~/.cocolang/cpp`, one per header and level.

## The compiler, in four predicates

```prolog
?- use_module(library(cocolang)).
?- cocolang_ast('prog.c', AST),                     % the file, read whole, headers and all
   cocolang_ir([AST], IR),                          % the units lowered to one LLVM IR module (text)
   cocolang_compile(IR, 'prog.o', ['-O1']),          % the object file, through the embedded LLVM
   cocolang_link(['prog.o'], [], 'prog').           % the binary (or a library: ['-shared'])
```

`cocolang_ast(+File, -AST)` mirrors `phrase/2`: the whole file or a syntax
error naming the line the unread item begins on and the line the grammar
gave up at; `cocolang_ast/3` mirrors `phrase/3` and answers the tokens
left. Every statement carries its line as its first argument. An
`#include` is read as it is met, raw when the header reads whole, through
the preprocessor otherwise, and becomes `include(Line, Spec, file(Path,
How, Unit))`. `cocolang_ir` runs the C++ desugaring (in C++ mode), the
ownership check, then the lowering; `cocolang_compile` parses, verifies,
optimizes and emits through `library(ccl_llvm)`, a cocolog module over
`llvm-c`; `cocolang_link` drives the system linker, the one tool the
compiler runs. Everything else the library defines is `ccl_`-prefixed.

## `:=`, patterns, `name { }`, `defer`

```c
n := 42;                                   // int
d := n + 1.5;                              // double
{ a, b } := p;                             // int a = p.x; double b = p.y;
{ _, at: { x, y }, name: nm } := node;     // by position, by field, nested, through a pointer

point { int x; double y; }                 // typedef struct point { ... } point;

FILE *f = fopen(path, "r");
if (f == NULL) return -1;
defer(f) { fclose(f); }                    // runs at every exit of the scope, LIFO, no runtime
```

`:=` takes the type the same inference the macros use gives the right
side; arrays and functions decay, a top-level `const` is dropped, an
unknown type stops the read with `cannot_infer`. A `defer` lowers to a
static cleanup chain, so a `return` from inside a loop runs every pending
block in order.

## The safe part: `own`, `move`, borrows, ties

`own char *p = malloc(n);` declares an owner. An owner is consumed exactly
once on every path: by `free`, `fclose`, `move(p)` into another owner or as
an argument, `return p`, or a callee whose parameter is `own`. A borrow is
a plain pointer whose value came from an owner: `q = p + 1`, `&p->x`,
`a->name`. It dangles the moment the owner is consumed, may not be
returned, and may not be stored where the check cannot follow it. A plain
pointer parameter is a borrow of the caller's: readable, passable,
returnable, never stored, freed or moved. A struct's own fields are owners
named by their path (`p->name`, `c.inner.name`) and go with the struct.
`x tie y` declares that `x` lives within `y`: a tied value is a borrow of
`y`, a tied owner must be consumed before `y` is, a result tie on a
prototype is a contract the caller reads. An own array, `own node *C[4]`
or `own node *C[nc]` bounded by an earlier member, holds owners the
lowering drains when the holder goes.

Refused, each naming the statement's line:

| refused as | when |
|---|---|
| `use_after_move` | a consumed owner is read, passed or freed again (the double free) |
| `owner_unset` | an owner is used before it was given anything |
| `owner_leaked` | an owner is live at its scope's end or a `return`, on any path |
| `owner_overwritten` | assignment to a live owner |
| `owner_stored` | an owner's pointer stored into a plain slot |
| `move_in_loop` | an owner from outside a loop consumed inside it and not re-owned |
| `borrow_after_move`, `borrow_escapes`, `borrow_stored`, `borrow_consumed`, `borrow_incomplete` | a borrow used after its owner went, returned, stored, freed, or a parameter's own field left incomplete |
| `tie_unknown`, `tie_outlived`, `tie_escapes`, `tie_mismatch` | a tie to nothing declared, an owner outliving its tie, a tied owner moved beyond it, a value outside the slot's tie |
| `unconsumed`, `untied` | a plain pointer holding fresh memory never consumed; a slot the check cannot follow given a value with no owner behind it |
| `own_unbounded`, `own_array_by_value`, `own_array_untagged`, `array_unset` | an own pointer with no owner to name; an own array copied by value, untagged, or not zeroed at birth |

`clone(p)` hands a function a fresh copy of what an own pointer points to,
so `p` is not consumed. `test/c/run/owners.c`, `own_fields.c`,
`borrows.c`, `params.c`, `tie.c`, `btree.c` and `btree_del.c` run;
every program under `test/c/safe/` is refused with the error its
`.expect` names.

In C++ the same check reads the desugared program: a class with a
destructor is never copied, a temporary dies at the end of its statement,
a constructor's `this` starts with unset own fields and must complete
them, a destructor's caller takes the fields as moved. libc++'s own
bodies keep raw pointers by their own discipline and are not checked;
the program's are, wherever they are instantiated from.

## Macros: `#include "m.pl"` and `#cocolog ... #end`

A Prolog file included is a set of macros: `name(a, b)` in the source,
with `name/3` among its predicates, runs at parse time as `name(ASTa, ASTb,
R)` and `R` takes the call's place. In an expression the result is an
expression, as a statement a statement or a block, at file scope a
declaration; a list is spliced. A DCG rule `name(R) --> ...` is a variadic
macro over the arguments it parses. The symbol table is open to a macro
(`library(ccl_infer)`): `ccl_type_of/2`, `ccl_size_of/2`, the typedefs,
the tags, the scope as it stands at the call. An error names both the call
and the macro, and a diagnostic on a line a macro produced carries `note:
expanded from macro`.

```c
#cocolog
twice(X, bin('*', X, int(2))).
sum(R) --> [A], sum_rest(A, R).
sum_rest(A, R) --> [B], !, sum_rest(bin('+', A, B), R).
sum_rest(A, A) --> [].
#end
int main(void) { printf("%d %d\n", twice(21), sum(1, 2, 3, 4)); return 0; }   /* 42 10 */
```

`format`, `print`, `println` and `clone` are global macros, there in every
program without an include (`library/ccl_format.pl`). The format string
has Rust's holes, each becoming the `printf` conversion of its argument's
inferred type, a struct printed by its members. An empty hole `{}` takes the
next argument; a named hole `{name}` takes the variable of that name in scope:

```c
n := 42;
name := "ann";
p := (point_t){ 1, 2.5 };
println("n = {} name = {name} p = {p}", n);   // n = 42 name = ann p = point_t { x: 1, y: 2.5 }
s := format("{} + {} = {}", 1, 2, 3);          // char *
```

## C++: the levels and the library

`cocolang++` compiles against libc++ as the system ships it. **C++17 is
the baseline**; `-std=c++20`, `-std=c++23` and `-std=c++26` set the
level, whose predefined macros the preprocessor answers first, so a header
flattens as clang would flatten it for that level. The compiler runs no
exceptions, no RTTI and no vector extensions inside libc++, which compiles
its own configuration for that (`-fno-exceptions -fno-rtti`); the program's
own `throw`, `try`, `typeid` and `dynamic_cast` run over libc++abi, which
`-lc++` links.

Every C++ form is a rewrite to the C the check and the lowering have
(`library/ccl_cpp.pl`): a class a struct with its methods over `this`, a
virtual call a load through the table the constructor stored, a template
an instance made on use and named by its arguments, a lambda a class of
its captures, a temporary destroyed at the end of its statement, a
`constexpr` call folded by an evaluator with cells for its locals. A
member a library header declares and the shipped library defines is called
by its Itanium symbol, and a class that is not trivially copyable crosses
a call as the ABI has it, so cocolang's code calls libc++'s and clang's.

What runs, each fixture matching clang++ line for line
(`test/cpp/run/*.cpp`): the standard streams (`cout`, `cin`, `getline`,
the extractors and inserters for every arithmetic type, the manipulators
of `<iomanip>`); `vector` (of ints, of the program's own class, of a class
that copies and does not move, of strings, of vectors), `string` and its operations, `map`, `multimap`, `set`, `multiset`,
the four unordered containers, node handles, `optional` with its C++23
monadic operations, `tuple` with `tuple_cat`, `array`, `unique_ptr`,
`shared_ptr` and `weak_ptr`, `function`, `bind`, `mem_fn`, `invoke`, the
function objects and `reference_wrapper`, and the `<algorithm>` surface
from `all_of` to the heap and permutation algorithms; at C++20 `contains`,
`erase_if`, the constrained algorithms `ranges::sort`, `ranges::find` and
`ranges::count_if`, `views::filter` called and through the pipe,
`std::quoted`, and `std::format`, at C++26 `optional<T &>`. `test/libcxx.sh` reads
`<vector>`, `<string>`, `<iostream>`, `<map>`, `<set>`,
`<unordered_map>`, `<unordered_set>`, `<optional>`, `<memory>`,
`<functional>`, `<tuple>` and `<algorithm>` whole, and the containers,
`<string>`, `<iostream>` and `<ranges>` at C++20, `<optional>` and `<string>` at
C++23, `<optional>` at C++26.

Where a macro goes past a template: a macro sees and rewrites the syntax
tree itself, reads the symbol table as it stands, produces statements and
declarations, is variadic by grammar, fails with a message naming both
places, and runs before the check, so what it generates is checked as what
the programmer wrote.

## What lives here

```
bin/cocolang, bin/cocolang++   the commands: clang's arguments, one cocolog run over ~/.cocolang/KB
module/cocolang.cicili         the module: registration, the native lexer (C, in Cicili), cocolang_ast/2,3,
                               the objects-and-modules layer
module/ccl_llvm.cicili         the embedded LLVM, a cocolog module over llvm-c (module/build-llvm.sh)
library/ccl_syntax.pl          the lexer (the DCG the native one follows) and the parser; the symbol table
library/ccl_pp.pl              the preprocessor, in cocolog
library/ccl_include.pl         #include: the inclusion path, the knowledge base, the C++ summaries
library/ccl_infer.pl           what a macro can ask: type inference, sizes, lookups
library/ccl_format.pl          format, print, println, clone
library/ccl_check.pl           the safe part: the ownership check
library/ccl_cpp.pl             the C++ desugaring to that C
library/ccl_ir.pl              the lowering to LLVM IR text
library/ccl_build.pl           cocolang_compile and cocolang_link
library/ccl_driver.pl          what the command does: the steps, the diagnostics, the IR cache
library/include/               the compiler's own freestanding C headers
test/reader.sh, compile.sh, driver.sh, objects.sh, proof/run.sh   the C gates
test/cpp.sh, libcxx.sh, readhdr.pl, census.sh                     the C++ gates and their tools
test/gates.sh, parlib.sh       every gate in one chain; the memory-gated parallel pool the C++ gates run on
test/c/, test/cpp/             the fixtures: what runs, what is refused, what is read whole
bench/btree, bench/compile     the B-tree and the compile-time benchmarks
tutorials/                     the objects layer's lessons
DESIGN.md, CLAUDE.md           the architecture; how the repository is worked on, by topic
HISTORY.md                     the record of every step: what it did, what it found, its gate numbers
```

## Rules of the house

* **The three neighbours are used, never edited.** A limitation met in
  one of them is worked around here and raised with its owner.
* **Every predicate and function this library defines is `ccl_`-prefixed;
  only the four `cocolang_` doors keep the compiler's name.** cocolog has
  one namespace.
* **No transpiler.** The compiler lowers to LLVM IR; C is read, never
  written. No clang and no LLVM binary is run: the preprocessor is
  cocolog's and the back end is the embedded LLVM.
* **Nothing of the standard library is the compiler's own.** The C
  freestanding headers are the one exception; libc++ compiles as it is.
* **Nothing is claimed before its GREEN line.** A rule is a check in a
  gate; every commit runs the seven gates and raises the version.

## Not done

`std::format`'s compile-time check of the format string (the library's own
run-time parser catches a bad one); the range views beyond `filter` in one
program (`transform`, `reverse`, `iota`, `take`, `drop`, `take_while`, `keys`,
`values` and a chain of them each run alone, and together still stop), and the
adaptors not named; the tail padding of a non-POD base, which is not reused
(a class laid out here differs from clang's where code compiled by both
shares it); construction vtables in a diamond; a `\N{...}` abbreviation
alias (`\N{NUL}`, which clang refuses too); the arm64 ABI, written and not
proven. Each is named in `CLAUDE.md` with where it stops.
