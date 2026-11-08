# ccllib -- a standard library for cicilang's C, made by cocolog macros

ccllib gives a C developer what libc++ gives a C++ developer: containers, strings, views, algorithms, iostreams, the
vocabulary types, and the additions of C++23 and C++26. It is written as cocolog macro files (`#include <vector.pl>`)
that cicilang's C reader runs while it reads a program. A type such as `vector<int>` becomes one plain C struct and
its functions, made only for the types that the program uses. C++ keeps libc++, and cicilang++ takes ccllib too: one
ccllib program is built by cicilang as C and by cicilang++ as C++, and both are measured against its twin over libc++
22, built by clang++ (the owner's decision of 2026-11-08; Tests and measures, below).

This file is the plan. `RULES.md` gets each rule when its step makes it, and `HISTORY.md` each step's record.

## Why: the cost of libc++

The major point of ccllib is to remove the weakness of C++'s library: thousands of defined types and the template
handling that they need (traits, SFINAE, overload resolution, instantiation in depth). Measured on 2026-11-07, a
13-line C++23 program over libc++ 22 -- `vector<int>`, `push_back`, `sort`, `map<int, string>`, `cout`:

| | |
|---|---|
| lines after the preprocessor | 79,322 |
| class and struct names in that text | 1,050, of which 858 start with `_` |
| clang++ 22 -O0: the IR | 76 types, 292 functions, 7,305 lines; 1.3 s, a 168 KB object |
| cicilang++, warm summaries: the IR | 361 types, 919 functions, 19,537 lines; 36 s, peak 615 MB |

ccllib makes the same program from a few structs and the functions it calls. There is no internal type hierarchy and
no `__` name zoo: cocolog decides at read time what the C++ library decides by template machinery, and the C reader
reads only plain C. "Cheaper" is measured, never claimed: each phase 1 program is built in three runs (Tests, below).

## The owner's decisions (2026-11-07 and 2026-11-08)

- The library covers what C++ has, iostreams included: first the library before C++23, then C++23 and C++26.
- Types are spelled as in C++: `vector<int> v;`, `map<int, string> m;`.
- A literal gives its types before a `;`: `[int; 5, 3, 9]` is a sequence, `[int, string; 5: "me", 3: "you"]` a map.
- Instances are implicit: each unit that uses `vector<int>` makes it once, as `linkonce_odr`, and the linker keeps one.
- C-text comes first: a macro author writes C text with holes, and the reader reads it.
- cocolog is pulled and built again on the owner's word (until then it stays 3.37.0, `74183ae`).
- ccllib objects have AUTODROP (2026-11-08): the compiler drops each object of an instance type at the end of its scope,
  on every way out of it, as C++ runs a destructor; a moved object is not dropped (phase 0.5). This was open decision 3.
- Every comparison has THREE RUNS (2026-11-08): the ccllib program built by cicilang as C and by cicilang++ as C++, and
  its twin over libc++ 22 built by clang++ (Tests and measures; ccllib in cicilang++ is phase 0.10).

Open decisions:

1. The place. ccllib in cicilang as `library/ccllib/` needs an exception to the owner's rule "Nothing of the standard
   library is the compiler's own", as `library/include/` has. This plan assumes it.
2. Containers of owners (`vector<own char *>`, `map<int, string>`): a new owner's rule for an own buffer whose bound
   changes, or the struct's last member `own T *a[n]` that exists.
3. Member calls (`v.push_back(3)`) beside the generic calls (`push(v, 3)`).
4. A literal at file scope, and a global of an instance type: refused, or made before `main` and dropped after it, as
   C++ globals are.

## What a C developer writes

```c
#include <vector.pl>
#include <map.pl>
#include <string.pl>
#include <iostream.pl>
#include <algorithm.pl>
int main(void) {
    v := [int; 5, 3, 9];                       // vector<int>, inferred
    vector<double> w = [1, 2.5];               // the declared type gives the element type
    m := [int, string; 5: "me", 3: "you"];     // map<int, string>
    push(v, 1);
    sort(v);                                   // the instance for vector<int>, found by v's type
    sort_by(w, a, b, a > b);                   // an expression, put into the loop: no function pointer
    cout << at(v, 0) << " " << get(m, 5) << endl;
    println("{} {}", len(v), len(m));          // the global macro that exists
    return 0;                                  // m, w and v dropped at the scope's end: autodrop
}
```

## How ccllib works

- One macro file per C++ header, in `library/ccllib/`, found on `COCOLOG_LIBRARY`: `<vector.pl>`, `<map.pl>`,
  `<string.pl>`, `<algorithm.pl>`, `<iostream.pl>` ... A header that includes one gives its macros to its includer.
- A TYPE MACRO takes types and gives the instance's type and the items that define it: `vector<int>` is the struct
  `vector_int` and its functions. The table of a unit's instances makes each one once.
- A GENERIC CALL finds its instance by the types of its arguments, at read time: `push(v, 1)` is
  `vector_int_push(&v, 1)`. A new element type needs no edit, where `_Generic` needs one per type.
- Each instance is C-TEXT with holes, read by the reader's own grammar: a macro file decides and fills holes; it
  writes no AST by hand.
- Instance names are readable and stable: `vector_int`, `vector_ptr_point`, `map_int_string`. A public name is the
  C++ one; a name with `_` or `__` is made only where the C standard keeps it for the implementation.
- An error is the macro's own message at the user's line, in clang's words, with the note `expanded from macro`.
- AUTODROP: an object of an instance type is dropped at the end of its scope by the drop that its type macro gives
  (`vector_int_drop`); a moved object is not, and a container's drop drops its elements.
- The safe part holds: a container owns its buffer, an element's address is a borrow of it, and a call that can
  replace the buffer ends those borrows (iterator invalidation found at compile time).
- No back pointers, since the safe part refuses a stored borrow: `map` and `set` are B-trees (`test/c/run/btree.c`
  and `btree_del.c` pass the safe part), `unordered_*` open addressing, `list` an index arena. Where pointer
  stability differs from C++, the rule says so.

## Phase 0: what cicilang needs

Each item is a step or two of cicilang, each with its fixtures, its rules in `RULES.md`, the flow gate after each
edit, and the chain. A grammar change raises the reader's version, a change to what is emitted the lowering's.

### 0.1 C-text (first)

A macro author writes C text; the reader lexes it (`ccl_tokens/3`) and reads it with its own grammar
(`ccl_externals//2`, the statement and expression grammars) in the read that runs: its typedef names, tags, scope and
macros. Probed on 2026-11-07: a `typedef struct` with an own member and a static function read so give the AST that
the file reader gives, and the typedef name joins the environment.

- The doors, for `.pl` macro files and `#cocolog` blocks: `ccl_c_items(Text, Holes, Items)` (file-scope items),
  `ccl_c_stmts(Text, Holes, Stmts)` (block items), `ccl_c_expr(Text, Holes, Expr)`, `ccl_c_type(Text, Holes, Type)`.
- The holes: `@Name` in the text, bound in `Holes` as `Name = type(T)`, `expr(E)`, `stmt(S)` or `name(Atom)`; a
  type's qualifiers join it as a typedef's do (`const @T` over `int *` is `int *const`); `@{Name}` pastes a name
  into an identifier (`@{N}_push`).
- Lines: every item takes the line of the macro's call; an error inside the text names that line, the macro file
  and the text's own line.
- Hygiene: the text is lexed, not preprocessed, so the user's `#define`s never reach it.
- Done when: reader checks of each door and each hole, an error inside a text, a text that uses a macro; a run fixture
  `test/c/run/ctext.c` over `ctext.pl` that makes a struct and its functions and runs them.
- DONE AT 0.260 (`RULES.md`, the topic of the macro files): the four doors over `ccl_ctext/4`; a type hole is a typedef
  name of its own while the text is read; the expansions that a text makes keep the program's arguments; an error is
  the macro's, at its call, with the text's own line. Reader `k96` to `k104`, the driver gate, `test/c/run/ctext.c`.
  The run fixture met the drop, which the owner then decided (autodrop, 0.5): a `drop` that frees the buffer through
  `&v` is refused in the callee (`a borrowed struct's own field not whole at the return`), and with the field set to
  `NULL` after the free, `main` is refused (`owner leaked: 'v.data'`): the check does not see that a callee freed its
  caller's owner. The fixture frees `v.data` in `main`.

### 0.2 Type macros in C++'s form: `vector<int> v;`

- A macro file names a type macro (`type_vector/3`: the types in, the instance's type and its items out).
- The reader: a name that the macro registry holds as a type macro, then `<`, opens a list of types and constant
  values, closed by `>`; `>>` is split as the C++ reader splits it (`ccl_tclose`). C reads no `name < type` as an
  expression, so the form is never ambiguous.
- Where a type stands: declarations, members, parameters, results, casts, `sizeof`, `_Alignof`, `typeof`, compound
  literals, and inside another list (`map<string, vector<int>>`). In an expression, explicit types for a function
  macro: `max<double>(a, b)`.
- A value parameter as C++26's `inplace_vector<int, 8>`: the first `>` that is not nested closes the list.

- DONE AT 0.261 with 0.3 and 0.4 (`RULES.md`, the topic of the macro files): `type_N/3` read where a type stands
  (`ccl_tmacro_spec//2`), its arguments by C++'s template grammar, `max<double>(a, b)` a typed call
  (`ccl_typed_call/5`), the instance's name from its arguments' words (`ccl_instance_name/3`, `ccl_type_word/2`). Reader
  `k105` to `k111`, `test/c/run/tvector.c` over `tvector.pl`, `tvhdr.h` and `tvhdr2.h`. `vector<vector<int>>` reads, and
  the safe part refuses its push: an element with an own field stored into the buffer is no move of the field (open
  decision 2; autodrop, 0.5, drops the elements).

### 0.3 Items at file scope from a macro

A macro used in a function or in a type puts its items at file scope, before the item that the reader reads now, in
order. Today a macro's list result is spliced where the macro stands.

- DONE AT 0.261: `ccl_hoist/1`, and each item of each item loop takes its own (`ccl_externals/4`).

### 0.4 Implicit instances, `linkonce_odr`

- One instance per type macro and argument list in a unit: a table that each unit starts empty.
- Its functions and objects have the `linkonce` storage that the lowering has (`define linkonce_odr`), as C++
  templates have.
- Done when: two units that both use `vector<int>` link and run (as `test/cpp/link/units_*.cpp` for C++).
- DONE AT 0.261: the unit's table (`ccl_tmacro_instance/5`), emptied at a top file's read and after the
  preprocessor's run; the instance's functions `linkonce` (`ccl_inst_linkonce/2`); a read that made or met an instance
  kept in no cache, since what it holds is its unit's; a header's raw attempt that does not read whole gives its
  instances back. The driver gate links `test/c/link/inst_a.c` and `inst_b.c`.

### 0.5 Autodrop (the owner's decision of 2026-11-08)

- A type macro gives its instance's drop: the function `<name>_drop(<name> *)` that its items define. A container's
  drop drops its elements, by their own drops (`vector<vector<int>>`, open decision 2).
- Each object of an instance type that a block declares is dropped at the block's end and on every way out of it --
  `return`, `break`, `continue`, `goto` -- in the reverse order of the declarations, as an implicit `defer` that the
  language has (no runtime); a C++ destructor runs at the same places. A moved object (`move(v)`) is not dropped, a
  returned one is the caller's, and a parameter by value is the callee's.
- The safe part: a drop releases the object's owners, so the check takes the object as consumed at the drop, and a
  drop's body may free the owners of the struct that its parameter points to -- the rule that 0.260's run fixture met
  (`a borrowed struct's own field not whole at the return`). A use after a move is refused, as it is now.
- A global of an instance type: open decision 4.
- Done when: `test/c/run/tvector.c` frees nothing by hand and the check passes; refused in `test/c/safe/`: a use after a
  move, a second drop by hand; run fixtures: a `return`, a `break` and a `goto` out of a block drop what it declared.

### 0.6 List and map literals

```
literal  : '[' types ';' elements? ']'  |  '[' elements ']'
types    : type-name  |  type-name ',' type-name
elements : element (',' element)* ','?
element  : expression  |  key ':' expression        a key is a conditional expression
```

- `:=` infers the container: one type `vector<T>`, two types `map<K, V>`. A declared type picks it:
  `set<int> s = [3, 1, 2];`, `unordered_map<int, string> u = [5: "me"];`.
- With no types the elements give them by C's usual conversions: `[1, 2.5]` is `vector<double>`; `[5: "me"]` holds
  static strings, `char *`. An empty literal names its types: `[int;]`, `[int, string;]`.
- Each element converts to the element type; a narrowing conversion is refused (`[int; 1.5]`), as C++'s braced
  lists refuse it. Two equal constant keys are refused; at run time the first stays, as `std::map` keeps it.
- The type macro's literal hook makes the value: one call over a compound literal.
- `FOO([int; 1, 2])` of a `#define` macro is two arguments, as a compound literal is: written `FOO(([int; 1, 2]))`.

### 0.7 Arguments read after the outer macro

A macro can take an argument unread and read it after it declares its names. Today the inner macro runs first:
`loop(m, println("{}", m))` stops with `cannot_format(m)`, where a plain expression in the same place works.

### 0.8 Two safety rules

Found by three probes on 2026-11-07:

- `int *p = &v.data[0];` over an own field is refused ("plain pointer not consumed"): an element's address must be a
  borrow of the field.
- `int *p = v.data; grow(&v); printf("%d", *p);` is accepted and runs, a use after `realloc`: a call that takes a
  plain pointer to a struct with own fields may replace them (`ck_complete_owners/2`), so it must end the caller's
  borrows of them.
- Done when: both programs refused in `test/c/safe/`, and the right forms accepted in `test/c/run/`.

### 0.9 Operators on instances

A type macro gives its instances operators that the reader writes as calls: `v[i]`, `m[k]`, `a == b`, `a < b`,
`s + t`, `out << x`, `in >> x`. iostreams needs `<<` and `>>`.

### 0.10 ccllib in cicilang++ (the owner's decision of 2026-11-08)

- cicilang++ reads the same macro files: a type macro where no template of its name is visible (`vector<int>` over
  `<vector.pl>`, with no `<vector>`), each instance's C text read by the C++ reader. The text is written in the part
  that C and C++ share: a cast where C converts `void *` and C++ does not (`(int *)realloc(...)`), no name that C++
  keeps.
- The instances are `linkonce_odr` there too; autodrop runs where a destructor would.
- Done when: each ccllib run fixture, built by cicilang++, prints what its cicilang build prints.

### Order

0.1, then 0.2 to 0.4 together (`vector<int>` needs all three), then 0.5 (autodrop), 0.6, 0.7, 0.8, 0.9 and 0.10. The
first proof after phase 0: `vector<int>` with `push`, `at`, `len` and `sort`, dropped at its scope's end, in the three
runs.

## Phase 1: the library before C++23, the most used part first

- 1a. Containers and strings: `vector`, `array`, `deque`, `list`, `forward_list`, `map`, `set`, `multimap`,
  `multiset`, `unordered_map`, `unordered_set` and their multi forms, `stack`, `queue`, `priority_queue`, `bitset`,
  `string`, `string_view`, `span`.
- 1b. The vocabulary: `optional`, `variant` and `visit`, `tuple`, `pair`, `any`, `unique_ptr` (the own pointer),
  `shared_ptr`, `hash`, `less` and the other function objects.
- 1c. Algorithms and numbers: `<algorithm>`, `<numeric>`, the C++20 ranges views as loops, `<limits>`, `<complex>`,
  `<random>`, `<ratio>`, `<chrono>`.
- 1d. iostreams: `ostream`, `istream`, `fstream`, `stringstream`, `<iomanip>`, `cout`, `cin`, `cerr`, over C's stdio.

## Phase 2: the rest before C++23

`<regex>`, `<filesystem>`, `<thread>`, `<mutex>`, `<condition_variable>`, `<atomic>` (over C11's), `<charconv>`,
`<format>` (std::format's specifications, beside the global macro that exists), a part of `<locale>`,
`source_location`.

## Phase 3: C++23

`expected`, `flat_map`, `flat_set` and their multi forms, `mdspan`, `print` and `println` (the global macros, with
std::format's specifications), the ranges added in C++23 (`zip`, `enumerate`, `chunk`, `slide`, `join_with`,
`cartesian_product`, `to`), `spanstream`, `stacktrace`, `byteswap`.

## Phase 4: C++26

`inplace_vector`, `linalg` (over `mdspan`), `simd` (over the vector types that cicilang has), `text_encoding`,
`<debugging>`, saturation arithmetic (C23's `ckd_*` exist), contracts (`pre`, `post`, `contract_assert`), a
reflection interface (the macros see the types and the members at read time), `hive`, hazard pointers and RCU (each
against the borrow rules first).

## Not in C, and what takes its place

- Coroutines and `generator`: C has no coroutines.
- Exceptions: C has none; a call that can fail returns `expected` or a code.
- `std::execution`: too large for a first library; after phase 4.
- Concepts and template metaprogramming: the macro's own checks at read time, with clang's words.

## Tests and measures

- THREE RUNS (the owner's decision of 2026-11-08): every comparison builds one ccllib program by cicilang as C and by
  cicilang++ as C++ (phase 0.10), and its twin that uses `std::` by clang++ over libc++ 22. The three print the same
  lines; the twin makes the `.expect`.
- SAFETY: what the safe part must refuse goes into `test/c/safe/`.
- COST, for each program, of each of the three runs: the build time, the IR's types and functions and lines, the
  object's size, the peak memory, and the run's own time. Phase 1 sets its targets from the first programs.
- The flow gate charts `library/ccllib/*.pl` with the library.
