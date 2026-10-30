# cicilang

**A Safe Modern C and C++ compiler to LLVM, written on cocolog.**

cicilang reads C and C++, checks it, and lowers it straight to **LLVM IR**.
It is not a transpiler: no C is ever emitted. Every pass -- the preprocessor,
the reader, the type inference, the ownership check, the C++ desugaring and
the lowering -- is [cocolog](https://github.com/saman-pasha/cocolog) clauses,
and the embedded LLVM turns the IR into a native binary. The philosophy is
[Cicili](https://github.com/saman-pasha/cicili)'s Safe Modern C: memory
safe, ownership checked at compile time, zero runtime overhead, no garbage
collector. cicilang is a new implementation of that philosophy, and its
native pieces are written in Cicili.

It uses Cicili, cocolog and [ZiguratIP](https://github.com/saman-pasha/ziguratip)
and **modifies none of them**. `DESIGN.md` is the architecture; `CLAUDE.md`
is how the repository is worked on, the owner's rules; `RULES.md` is the
rules of the code by topic; `HISTORY.md` is the record of every step.

## Features

* **C17 and C23, whole.** Every form of C17, and C23's: `_BitInt(N)`,
  `_Generic`, `typeof` and `typeof_unqual`, `nullptr`, `constexpr` objects,
  `static_assert`, `[[attributes]]`, `#embed`, `__VA_OPT__`, `#elifdef`, the
  digit separator, binary literals, `wb` suffixes, the checked arithmetic of
  `<stdckdint.h>` and the bit utilities of `<stdbit.h>`, C11's atomics
  through the compiler's own `<stdatomic.h>`, variable length arrays, thread
  locals, wide and UTF-8 literals, variadic functions over the compiler's
  own `<stdarg.h>`, `long double` as x87's 80-bit type on x86-64 (its
  literals exact, as clang reads them), hex floats, designated initializers,
  anonymous members, K&R definitions, `#line`, `__int128`, `va_arg` of a
  struct on x86-64 and arm64, the SysV argument register budget, the decimal
  floating types as gcc builds them (to and from a 128-bit integer and a
  `_BitInt` past it through the compiler's own helpers, their constants
  folded with infinities and NaNs), the binary floating constants folded as
  clang folds them (a negative zero, an infinity, a NaN, a long double's
  arithmetic, an integer operation in its own type), GCC's and clang's
  vector types (`vector_size`, `ext_vector_type`: their operators lane by
  lane, their lanes, masks, conversions and builtins, crossing a call as
  clang passes them), and trigraphs and `__STRICT_ANSI__` in the ISO modes,
  and GNU's inline assembly (a file-scope `asm`, and `asm` statements with
  outputs, inputs, clobbers, named operands and register variables, lowered
  as clang lowers them). C17 in a GNU mode is the default, as clang's;
  `-std=c17` is its ISO mode and `-std=c23` gives C23. The program's
  feature-test macros (`_POSIX_C_SOURCE`, `_GNU_SOURCE`,
  `__STDC_WANT_LIB_EXT2__` ...) and `NDEBUG` reach the C library's headers
  as they do under clang, each where clang's headers read it (under
  `-DNDEBUG` an `#undef NDEBUG` before `<assert.h>` asserts again). An
  identifier takes each level's characters past ASCII (C23's and C++'s XID
  sets, C11's and C99's Annex D), the Unicode white space clang takes is
  blank, and `__has_attribute` answers the GNU attributes the compiler
  keeps.
* **C++17, C++20, C++23 and C++26.** Classes, virtual dispatch, multiple
  and virtual inheritance, templates with partial specialization, SFINAE,
  concepts and `requires`, lambdas (generic, capturing `this` and `*this`),
  structured bindings, `if constexpr`, `consteval` at compile time, the
  three-way comparison and the defaulted comparisons, pack indexing, the
  `_` placeholder, class template argument deduction, pointers to members
  (a member function's `const` and ref-qualifier kept), `constexpr`
  functions evaluated at compile time over locals, aggregates, pointers and
  `this`, RTTI (`typeid` of every type, `dynamic_cast`), exceptions (`throw`,
  `try`, `catch`, `std::exception_ptr`), `new T[n]` of a class with the
  ABI's array cookie, multiple polymorphic bases with their secondary vtables,
  virtual bases reached through the vtable and laid out at the end of the
  complete object as the Itanium ABI lays them (a program class over a
  stream too), the diamond with one shared base, its paths holding it
  directly or further in, a class over several virtual bases through
  its paths, a diamond over them too, later virtual bases (`X : B, virtual
  A`), with virtual bases of their own too, a nearly empty virtual base as the
  primary base, the one clang chooses, stolen or further in, its own
  virtual bases inside it or outside, a virtual
  base's own vcall offsets, the slots of a primary table in the ABI's order,
  and the base-variant constructors and destructors built under
  construction vtables of their own at any depth, from a VTT,
  `noexcept` enforced, trailing return types, access control for
  the program's own classes, deducing `this` on a class's methods, user-defined
  literals, `mutable` lambdas checked, placement `new[]`, arrays of arrays of
  objects, scalar globals initialized before `main`, braced temporaries through
  an `initializer_list` constructor,
  coroutines (`co_await`, `co_yield`, `co_return`, `operator co_await`,
  `std::coroutine_traits`, over LLVM's coroutine intrinsics), modules
  (`export module`, `import`, header units, exports enforced), contracts enforced at
  run time, `__PRETTY_FUNCTION__` and `std::source_location` as clang++ spells them,
  definitions by namespace-qualified names, and the Itanium ABI's layout, name mangling and calling
  convention, so cicilang's objects link with clang's, on x86-64 and on
  aarch64 Linux (pointers to member functions in ARM's form there). A
  library header's static assertions are asked, with libc++'s own message, as
  clang++ asks them.
* **libc++ compiled from its own headers.** Nothing of the standard
  library is written here: `std::vector`, `std::string`, `std::map`,
  `std::set`, the unordered containers, `std::optional`, `std::tuple`,
  `std::array`, `std::unique_ptr` and `std::shared_ptr`, `std::function`,
  `std::bind`, `<algorithm>`, `std::cout`, `std::cin`, `std::getline`,
  `std::stringstream`, `std::fstream`, `std::bitset`, `std::complex`,
  `std::span`, `std::byte` and the manipulators all compile from libc++'s
  own bodies and run, on Linux with libc++ 18, with libc++ 21 and, since 0.227, with libc++ 22 (the gates run the three,
  `LLVM=/usr/lib/llvm-18`, `-21` or `-22` chooses the tree), on aarch64 Linux under qemu over that machine's libc++ 18
  in the cross sysroot, and, as of 0.90, on macOS (libc++ 21).
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
* **clang's arguments.** `cicilang` and `cicilang++` take what `clang` and
  `clang++` take: `-c -S -E -emit-llvm -fsyntax-only -o -O0..-Oz -I -l -L
  -shared -std= -fno-rtti --version`. Diagnostics are `file:line: error: what`.
* **Fast, once warm.** The C headers a program includes are read once into
  the user's knowledge base, `~/.cicilang/KB`, and served from it in every
  later run; a C++ library header is flattened once and summarized to
  `~/.cicilang/cpp`. A built C file's IR is cached beside its unit in the
  knowledge base, and since 0.221 a C++ file's under `~/.cicilang/cpp/ir`: a
  rebuild of an unchanged file is served its IR (`CICILANG_NO_IR_CACHE=1`
  builds uncached, as every gate does). The B-tree benchmark matches clang
  `-O3` and beats Rust's `BTreeSet` on insert and search.

## Install and build

cicilang needs the three neighbours checked out beside it (the paths are
the `CICILI`, `COCOLOG` and `ZIGURATIP` variables, defaulting to
`~/Projects/GitHub/<name>`), an LLVM with its C API (Homebrew's `llvm@18` or
`llvm` on macOS, `llvm-18-dev` or newer on Debian and Ubuntu), a `cc` and a `c++`
for the link, and libc++ for the C++ side. `test/toolchain.pins` names the
neighbours' commits and the LLVM and libc++ versions the gates last passed
on, and `sh test/toolchain.sh` checks a box against it, each tool's version
printed and what to do where one is missing. `sh test/ci.sh smoke` (or
`full`) is the CI job's own steps: it clones the neighbours at their pins,
builds them with cocolog's installer, builds the two modules and runs the
gates; GitHub runs it on each push, on Ubuntu 24.04 and on an Intel Mac
(`.github/workflows/gates.yml`).

```sh
CICILI=~/Projects/GitHub/cicili COCOLOG=~/Projects/GitHub/cocolog sh module/build.sh   # -> library/cicilang.so
LLVM=/usr/local/opt/llvm sh module/build-llvm.sh                                     # -> library/ccl_llvm.so
sh test/toolchain.sh                                                                 # each tool beside the pins
sh test/flow.sh                                                                      # the flow gate: the library charted, nothing run (two minutes)  
sh test/reader.sh; sh test/compile.sh; sh test/driver.sh; sh test/objects.sh         # the C gates
sh proof/run.sh; sh test/cross.sh                                                    # the proof, and aarch64 Linux under qemu
sh test/libcxx.sh; sh test/cpp.sh                                                    # the C++ gates: the library read warms the cache first
sh test/gates.sh                                                                     # the check, then the nine gates
sh test/why.sh prog.cpp                                                              # a failed build: the call where it gave up
sh test/prof.sh prog.cpp                                                             # where a build's inferences and time go: windows along its run
```

`module/build.sh` transpiles `module/cicilang.cicili` with Cicili and
compiles it against cocolog's module SDK. `library/*.pl` needs no build.

## The commands

```sh
cicilang prog.c -o prog              # read, check, lower, compile, link
cicilang -c prog.c                   # prog.o        cicilang -S prog.c   # prog.s
cicilang -emit-llvm -c prog.c        # prog.ll       cicilang -fsyntax-only prog.c
cicilang -E prog.c -o flat.c         # the preprocessed text, from cocolog's preprocessor
cicilang -O2 a.c b.c util.o -lm -o app
cicilang -std=c23 prog.c -o prog     # C23's forms
cicilang++ -std=c++20 prog.cpp -o prog
cicilang -I include prog.c           cicilang -ast-dump prog.c           cicilang --version
```

`cicilang++` is `cicilang` for C++: the same arguments, every input read as
C++, C++17 the default level and `-std=c++20`, `-std=c++23`, `-std=c++26`
the others, the link through `c++`. The exit status is 1 when there is a
diagnostic. `cicilang -v` says each step, and `served main.c from the
store` when a file's IR came from the cache (`served main.cpp from the IR
cache` for a C++ file).

The knowledge base is the user's, `~/.cicilang/KB` (or `$CICILANG_KB`;
`--no-kb` keeps everything in memory). The first call is the initialization
phase, reading the C standard library's headers once. It is stamped with
the reader's and the lowering's versions and starts afresh when either
changes. `cicilang++` keeps its headers as summaries under
`~/.cicilang/cpp`, one per header and level. Where two or more of the
library headers a C++ file names have no summary yet, `cicilang++` reads
each of them in a process of its own, as many at a time as the machine
has processors (`CICILANG_JOBS=N` sets another number; `1` reads them in
the build's own process), and the build then reads their summaries:
`cicilang++ -v` names each process.

## The compiler, in four predicates

```prolog
?- use_module(library(cicilang)).
?- cicilang_ast('prog.c', AST),                     % the file, read whole, headers and all
   cicilang_ir([AST], IR),                          % the units lowered to one LLVM IR module (text)
   cicilang_compile(IR, 'prog.o', ['-O1']),          % the object file, through the embedded LLVM
   cicilang_link(['prog.o'], [], 'prog').           % the binary (or a library: ['-shared'])
```

`cicilang_ast(+File, -AST)` mirrors `phrase/2`: the whole file or a syntax
error naming the line the unread item begins on and the line the grammar
gave up at; `cicilang_ast/3` mirrors `phrase/3` and answers the tokens
left. Every statement carries its line as its first argument. An
`#include` is read as it is met, raw when the header reads whole, through
the preprocessor otherwise, and becomes `include(Line, Spec, file(Path,
How, Unit))`. `cicilang_ir` runs the C++ desugaring (in C++ mode), the
ownership check, then the lowering; `cicilang_compile` parses, verifies,
optimizes and emits through `library(ccl_llvm)`, a cocolog module over
`llvm-c`; `cicilang_link` drives the system linker, the one tool the
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
returned, and may not be stored where the check cannot follow it. A
local's address is a borrow too: a struct's member, an array's element or
a library object given one holds it, so the holder returned, or read after
the local's scope, is refused, and so is the address stored where it
outlives the function -- through a pointer parameter, in a global; a
function that keeps its parameter in a library object makes its call keep
it there. A plain pointer parameter is a borrow of the caller's: readable,
passable, returnable, never stored, freed or moved; a parameter by value
is the callee's own. A struct's own fields are owners
named by their path (`p->name`, `c.inner.name`) and go with the struct.
`x tie y` declares that `x` lives within `y`: a tied value is a borrow of
`y`, a tied owner must be consumed before `y` is, a result tie on a
prototype is a contract the caller reads. An own array, `own node *C[4]`
or `own node *C[nc]` bounded by an earlier member, holds owners the
lowering drains when the holder goes. A `goto` is an edge of the flow: the
state at a label is the join of the state that falls through and of each
`goto` that reaches it, the scopes a jump leaves closed as a `break` closes
them, and the jump runs their `defer` blocks (and, in C++, their destructors).
A jump into a block, or over a declaration, leaves each owner it skipped
unset on its path (0.138).

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
| `goto_with_owners` | a `goto` over the declaration of a plain pointer holding fresh memory, or of an own array |
| `goto_over_defer` | a `goto` over a `defer` (or, in C++, a local with a destructor) to a label in its scope |

`clone(p)` hands a function a fresh copy of what an own pointer points to,
so `p` is not consumed. `test/c/run/owners.c`, `own_fields.c`,
`borrows.c`, `params.c`, `tie.c`, `btree.c` and `btree_del.c` run;
every program under `test/c/safe/` is refused with the error its
`.expect` names.

In C++ the same check reads the desugared program: a class with a
destructor is never copied, a temporary dies at the end of its statement,
a constructor's `this` starts with unset own fields and must complete
them before it is handed to a function, a destructor's caller takes the
fields as moved. libc++'s own
bodies keep raw pointers by their own discipline and are not checked;
the program's are, wherever they are instantiated from. A library
object that holds borrows -- a vector of pointers, a view, a
`std::function`, an iterator -- borrows what it is handed, so returning
it, or storing it where it outlives a local, obeys the borrow rules.

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

`cicilang++` compiles against libc++ as the system ships it. **C++17 is
the baseline**; `-std=c++20`, `-std=c++23` and `-std=c++26` set the
level, whose predefined macros the preprocessor answers first, so a header
flattens as clang would flatten it for that level. libc++ is built with
RTTI, as clang++ builds it (`std::any::type()`, `std::function::target`,
`std::get_deleter`), and `-fno-rtti` gives libc++'s no-RTTI configuration
and refuses `typeid`, as clang++ `-fno-rtti` does. The compiler runs no
exceptions inside libc++, which compiles its own configuration for that
(`-fno-exceptions`), and libc++ 21's vectorized algorithms over vector
types as clang builds them; the program's own `throw`, `try`, `typeid`
and `dynamic_cast` run over libc++abi, which `-lc++` links. Where several
libc++ are installed side by side (Debian's and
Ubuntu's `/usr/lib/llvm-18` and `/usr/lib/llvm-21`, say), `$LLVM` names the tree
whose headers are read and whose library is linked; without it the newest is read.

Every C++ form is a rewrite to the C the check and the lowering have
(`library/ccl_cpp.pl` and its parts): a class a struct with its methods
over `this`, a virtual call a load through the table the constructor
stored, a template an instance made on use and named by its arguments, a
lambda a class of its captures, a temporary destroyed at the end of its
statement, a `constexpr` call folded by an evaluator with cells for its
locals. A member a library header declares and the shipped library
defines is called by its Itanium symbol, and a class that is not
trivially copyable crosses a call as the ABI has it, the caller
destroying it at the end of its full-expression, so cicilang's code
calls libc++'s and clang's, and theirs call cicilang's.

What runs, each fixture matching clang++ line for line (`test/cpp/run/*.cpp`):
the standard streams (`cout`, `cin`, `getline`, the extractors and inserters
for every arithmetic type, the manipulators of `<iomanip>`); `vector` (of
ints, of the program's own class, of a class that copies and does not move, of
strings, of vectors), `string` and its operations, `map`, `multimap`, `set`,
`multiset`, the four unordered containers, node handles, `optional` with its
C++23 monadic operations, `tuple` with `tuple_cat`, `array`, `unique_ptr`,
`shared_ptr` and `weak_ptr`, `function`, `bind`, `mem_fn`, `invoke`, the
function objects and `reference_wrapper`, and the `<algorithm>` surface from
`all_of` to the heap and permutation algorithms; at C++20 `contains`,
`erase_if`, the constrained algorithms `ranges::sort`, `ranges::find` and
`ranges::count_if`, the views `filter`, `transform`, `reverse`, `iota`,
`take`, `drop`, `take_while`, `keys` and `values` alone, chained and all in
one program, `std::quoted`, the wide streams, `seekg` and `seekp`,
`std::format` with `vformat`, a formatter the program writes and the wide
format, at C++23 `std::print` and `std::println`, at C++26 `optional<T &>`;
since 0.117 also `std::stringstream`, `std::ofstream`, `std::ifstream` and
`std::fstream`, a class derived from `std::ostream` over its own streambuf,
`std::span`, `std::bitset`, `std::vector<bool>`, `std::byte`, `std::complex`
with the `<cmath>` functions, the `"x"s` and `"x"sv` literals and the
program's own literal operators, `<memory>`'s `construct_at`,
`uninitialized_*` and `destroy_*`, `std::list`, `std::deque`, `std::queue`,
`std::stack`, `std::priority_queue`, `<numeric>`, `std::from_chars` and
`std::to_chars`, `std::thread` and `std::mutex` (with `std::ref` arguments),
and at C++20 `std::atomic`'s `wait`, `notify_one` and `notify_all` and `<bit>`
with `std::bit_cast`; since 0.121 also `std::variant` with `std::visit` (a
function object, a generic lambda, C++17's `overloaded` idiom, two variants),
and the forms it needed: classes defined in a function, `using Base::f;` and
`using Bs::operator()...;`, aggregates with bases, a member template called
through a pointer, unions with a constructor, a destructor or a method, and
objects that hold their own address (a map, a list, a `std::function`)
constructed in place when a temporary or a call initializes them; at C++20 also
`variant <=> variant` and `std::string` compared with `const char *`; since
0.132 the C++23 views that libc++ 18 has (`empty`, `single`, `counted`,
`chunk_by`, `common`, `zip`, `elements`, `drop_while`, `as_rvalue`, `repeat`,
`join`, `split`, `lazy_split`) and `ranges::to`; since 0.133 range and tuple
formatting (`std::format` of a vector, a map, a pair, a tuple, strings in the
debug form) and, over libc++ 21, `views::join_with`; since 0.134 the money and
time facets (`put_money`, `get_money`, `put_time`, `get_time`), a stream's
exceptions mask, the wide file streams and `std::filesystem` (`path` and the
operations, a range-for over a `directory_iterator`); since 0.136 `<random>`
(the engines through the distributions, `std::shuffle`), `std::valarray`,
chrono formatting and `std::rel_ops` through a using-directive; since 0.138
libc++'s time zones under `-fexperimental-library`, as clang++ takes it; since
0.164 `std::format`'s format string checked at compile time (since 0.168 a
pair's, a tuple's and a map's too), a bad one refused with libc++'s own
message, as clang++ refuses it; since 0.179 `<chrono>`'s durations, clocks
and time points with their literals (`1500ms`, `3us`), and `<complex>`'s
(`3i`, `2.0if`); since 0.182, over libc++ 22, `std::vector` and the C++23
views that tree adds (`pairwise`, `adjacent`, `zip_transform`,
`adjacent_transform`), a gate's tree since 0.227; since 0.191
libc++ with RTTI, as clang++ builds it, and its no-RTTI configuration under
`-fno-rtti`, `std::any` and `std::any_cast` in both, and a `shared_ptr` with
a deleter; since 0.192 programs of several units built apart: each unit's
lambdas, local classes and unnamed namespace stay its own at the link, a
header's inline variables are one object, and every static object is
destroyed at exit, one constructed at compile time too; since 0.200 the
type traits of a construction, a conversion and an assignment
(`is_constructible`, `is_convertible`, `is_assignable` and their nothrow
forms) answer as clang++'s do, deleted and implicit special members
included; since 0.201 the rest of libc++'s facilities: `<future>` with
`std::async`, `<regex>`, `<memory_resource>` under the pmr containers,
`<forward_list>`, `<shared_mutex>`, `std::condition_variable` and
`std::call_once`, `<numbers>`, `<scoped_allocator>`, `<system_error>` and
`<typeindex>`, at C++20 `std::jthread` with `<stop_token>`, `<latch>`,
`<barrier>`, `<semaphore>` and `<syncstream>`, at C++23 `std::expected` and
`<mdspan>`, over libc++ 21 `std::flat_map` and `std::flat_set`, the
execution policies, and every other standard header, each included by a
fixture; and a constructor, an initialization or a `new` that throws cleans
up what it built, as the standard says; since 0.202 the allocation functions:
a `new` calls the program's replacement of the global `operator new` (the
library's allocations too), a class's own and its bases', the aligned form
past an alignment of 16, the nothrow and the placement forms and C++20's
destroying `operator delete`, a `delete` the matching deallocation function,
the dynamic type's through a virtual destructor, and a coroutine's state its
promise type's; since 0.203 GCC's `packed` and `aligned` attributes, which
glibc's headers use (`struct epoll_event`), on a C++ class too, a volatile
object's members, and an enumeration's value as a template argument, of its
own type; since 0.205 a lambda's noexcept, a function type's conditional
noexcept and the noexcept operator over member calls, temporaries, deduced
templates, overload sets and calls of objects as clang++ answers them, a
prototype's and an out-of-class member's trailing requires-clause, a static
assertion among a class's or a struct's members, the scoped attributes of
`__has_cpp_attribute`, GCC's attributes in the standard spelling
(`[[gnu::packed]]`, `[[gnu::aligned(N)]]`) and `aligned` on an enum, GNU's
`__alignof__` of an expression, and C++20's `std::atomic_ref` of a struct;
since 0.206 every facility that libc++ 18 and 21 name by a feature-test
macro from C++17 to C++26 (`std::sample` and the searchers, the scans,
`std::to_array`, `std::ssize`, the saturation arithmetic, `std::byteswap`,
the ranges algorithms and the containers' ranges members of C++23, a
floating `std::atomic` and an atomic of a struct, the constexpr containers
of C++26 ...), `std::nullptr_t` a type of its own in both languages (C23's
`nullptr_t` too), a class's `final` for `std::is_final`, an initializer list
of objects (`std::vector<std::list<int>> v{{1, 2}, {3}}`), and C23's library
over glibc (`memccpy`, `strfromd`, `mbrtoc8`, `printf`'s `%b` and `%w32d`);
since 0.218 a static data member of a library type, defined out of its class
or `static inline` in it with no initializer, and a class template's defined
out of it with no initializer; since 0.219 `<compare>`'s customization point
objects (`std::strong_order`, `std::weak_order`, `std::partial_order`, and
their fallbacks over a type with `<=>`), and a library class that two
headers declare in two namespaces found in its own namespace whatever the
order of the includes; since 0.221 `<compare>`'s fallbacks over a class with
`==` and `<` alone, a function of the program's namespace with a library
function's name (`ns::max` beside `std::max`), the library's own algorithms
finding it by argument-dependent lookup, a global function of the program's
with a library function's name (`max` beside `std::max`), `std::invoke` and
the unordered containers over a transparent hash, and libc++ 21's vectorized
`std::mismatch` and `std::find`.
`test/libcxx.sh` reads `<vector>`, `<string>`,
`<iostream>`, `<map>`, `<set>`, `<unordered_map>`, `<unordered_set>`,
`<optional>`, `<memory>`, `<functional>`, `<tuple>` and `<algorithm>` whole,
and the containers, `<string>`, `<iostream>` and `<ranges>` at C++20,
`<optional>` and `<string>` at C++23, `<optional>` at C++26.

Where a macro goes past a template: a macro sees and rewrites the syntax
tree itself, reads the symbol table as it stands, produces statements and
declarations, is variadic by grammar, fails with a message naming both
places, and runs before the check, so what it generates is checked as what
the programmer wrote.

## What lives here

```
bin/cicilang, bin/cicilang++   the commands: clang's arguments, one cocolog run over ~/.cicilang/KB
module/cicilang.cicili         the module: registration, the native lexer (C, in Cicili), cicilang_ast/2,3,
                               the objects-and-modules layer
module/ccl_llvm.cicili         the embedded LLVM, a cocolog module over llvm-c (module/build-llvm.sh)
library/ccl_syntax.pl          the lexer (the DCG the native one follows) and the parser; the symbol table
library/ccl_pp.pl              the preprocessor, in cocolog
library/ccl_include.pl         #include: the inclusion path, the knowledge base, the C++ summaries
library/ccl_infer.pl           what a macro can ask: type inference, sizes, lookups
library/ccl_format.pl          format, print, println, clone
library/ccl_check.pl           the safe part: the ownership check
library/ccl_cpp.pl             the C++ desugaring to that C, and its sixteen parts ccl_cpp_*.pl: namespaces,
                               the mangler, the library's functions, classes and their layout, overloads, RTTI,
                               initialization, statements, expressions, the constant evaluator, templates,
                               deduction, traits, lambdas, concepts
library/ccl_ir.pl              the lowering to LLVM IR text
library/ccl_build.pl           cicilang_compile and cicilang_link
library/ccl_driver.pl          what the command does: the steps, the diagnostics, the IR cache
library/include/               the compiler's own freestanding C headers
test/reader.sh, compile.sh, driver.sh, objects.sh, proof/run.sh   the C gates
test/cpp.sh, libcxx.sh, readhdr.pl, census.sh                     the C++ gates and their tools
test/gates.sh, parlib.sh       every gate in one chain; the memory-gated parallel pool the C++ gates run on
test/toolchain.sh, .pins       the toolchain check, first in the chain; the neighbours' pinned commits
test/ci.sh, .github/workflows  the CI job's steps, and the workflow that runs them on GitHub
test/flow.sh, flow.pl, flow.expect   the flow gate: cocolog's library(flow/chart) over the library, nothing run,
                               its findings held to the expect file
test/why.sh, why.pl            where a failed build gave up: the build under library(flow/debug), the branch and the
                               failed call named
test/prof.sh, prof.pl          where a build's inferences and time go: windows along its run, by library(flow/debug)
test/c/, test/cpp/             the fixtures: what runs, what is refused, what is read whole
bench/btree, bench/compile     the B-tree and the compile-time benchmarks
tutorials/                     the objects layer's lessons
DESIGN.md, CLAUDE.md           the architecture; how the repository is worked on, the owner's rules
RULES.md                       the rules of the code, by topic: the gates, each pass, what runs, what is not done
HISTORY.md                     the record of every step: what it did, what it found, its gate numbers
```

## Rules of the house

* **The three neighbours are used, never edited.** A limitation met in
  one of them is worked around here and raised with its owner.
* **Every predicate and function this library defines is `ccl_`-prefixed;
  only the four `cicilang_` doors keep the compiler's name.** cocolog has
  one namespace.
* **No transpiler.** The compiler lowers to LLVM IR; C is read, never
  written. No clang and no LLVM binary is run: the preprocessor is
  cocolog's and the back end is the embedded LLVM.
* **Nothing of the standard library is the compiler's own.** The C
  freestanding headers are the one exception; libc++ compiles as it is.
* **Nothing is claimed before its GREEN line.** A rule is a check in a
  gate; every commit runs the nine gates and raises the version.

## Not done

a format string whose compile-time check the evaluator cannot take (the
library's own run-time parser checks it); the range adaptors not named;
a `\N{...}` abbreviation
alias (`\N{NUL}`, which clang refuses too); the arm64 ABI on Apple's machines
(Linux on aarch64 is proven under qemu, C and C++). Each is named in `RULES.md`'s Not done with where it stops.