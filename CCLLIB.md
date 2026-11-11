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
- A literal gives its types before a `;`: `[int; 5, 3, 9]` is a sequence, `[int:string; 5: "me", 3: "you"]` a map; a
  map's two types are written with a colon (2026-11-08: "Use : in map literal type section").
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
   changes, or the struct's last member `own T *a[n]` that exists. EVERY CONTAINER WHOSE ELEMENT HOLDS A POINTER
   WAITS FOR IT (0.274): `vector.pl` takes an element with no pointer in it and refuses the others by name, and the
   other modules of phase 1a go on over such elements. A proposal: inside the C text of a type macro's instance, a
   store of an element into the instance's own buffer is a move of it, a read of one by value a move out, and the
   type's drop drops each element that the buffer holds -- the text of a container is trusted for its elements, as
   libc++'s bodies are, and a program's own code is checked as before.
3. Member calls (`v.push_back(3)`) beside the generic calls (`push_back(v, 3)`).
5. The short names: `push`, `pop` and `len` stand beside C++'s `push_back`, `pop_back` and `size` since 0.274, as
   this plan's examples have them; one of the two sets may go.
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
    m := [int:string; 5: "me", 3: "you"];      // map<int, string>
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
  `vector_int_push(&v, 1)`. A new element type needs no edit, where `_Generic` needs one per type. Since 0.274 it is
  the reader's rule over the first argument's type, and no macro per name.
- EACH FUNCTION OF AN INSTANCE IS MADE AT ITS FIRST CALL (0.274): a unit holds what it calls.
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
- DONE AT 0.262 (`RULES.md`, the topic of the macro files and the safe part's topic of autodrop): the drop
  `<name>_drop(<name> *)` found among the instance's items and its parameter marked `dying` (`ccl_inst_drop/4`); a defer
  of the drop after each automatic object's declaration, marked `'$autodrop'(V)`, which the lowering runs at every exit
  and the check takes as the end of V's owners; zero for an object declared with no initializer, so `vector<int> v;` is
  an empty vector; a parameter by value the callee's; a `for`'s object dropped where the loop ends; an object named
  whole by value moved, `move(v)`, which leaves it zero, so its drop frees nothing. `test/c/run/autodrop.c` prints what
  clang's build of its hand expansion prints (a return, a break, a continue, a goto and a block's end, the last declared
  first, a moved object's drop printing nothing), and `tvector.c` frees nothing. Refused in `test/c/safe/`: a use after
  a move (`drop_moved.c`), a drop by hand (`drop_by_hand.c`), an owner taken out (`drop_field.c`), a copy that the
  reader does not move (`drop_copied.c`), a temporary thrown away (`drop_temporary.c`), a new value over a full object
  (`drop_overwritten.c`), a case label past a declaration (`drop_switch.c`), a member of a plain struct not dropped
  (`drop_member.c`) and a drop that frees nothing (`drop_leaks.c`).
- WHAT 0.262 LEAVES (Not done): a temporary is not dropped (refused); a member of such a type in a plain struct is not
  dropped with it; an array of such objects is refused; an assignment does not drop the old value first (refused while
  the object may hold memory), where C++'s assignment does; a global is not dropped (open decision 4). A parameter by
  value is dropped by the callee, where C++ destroys it in the caller at the end of the full expression -- a difference
  of the order of the output that phase 0.10 meets.

### 0.6 List and map literals

```
literal  : '[' types ';' elements? ']'  |  '[' elements ']'
types    : type-name  |  type-name ':' type-name
elements : element (',' element)* ','?
element  : expression  |  key ':' expression        a key is a conditional expression
```

- `:=` infers the container: one type `vector<T>`, two types `map<K, V>`. A declared type picks it:
  `set<int> s = [3, 1, 2];`, `unordered_map<int, string> u = [5: "me"];`.
- With no types the elements give them by C's usual conversions: `[1, 2.5]` is `vector<double>`; `[5: "me"]` holds
  static strings, `char *`. An empty literal names its types: `[int;]`, `[int:string;]`.
- Each element converts to the element type; a narrowing conversion is refused (`[int; 1.5]`), as C++'s braced
  lists refuse it. Two equal constant keys are refused; at run time the first stays, as `std::map` keeps it.
- The type macro's literal hook makes the value: one call over a compound literal.
- `FOO([int; 1, 2])` of a `#define` macro is two arguments, as a compound literal is: written `FOO(([int; 1, 2]))`.
- DONE AT 0.263 (`RULES.md`, the topic of the macro files): the grammar above in C, `[` a primary
  (`ccl_list_literal//1`); the type from the place -- a declaration's declared type, the left side of `=`, a call's
  parameter, a return's function's result -- and at `:=` `vector<T>` or `map<K, V>`, the types the literal's or its
  elements' by the usual conversions; the value a call of the instance's `<name>_from` over compound literals
  (`vector_int_from((int[3]){5, 3, 9}, 3)`, a map's over its keys and its values), an empty one the empty object;
  narrowing refused as C++'s braced lists refuse it, two equal constant keys refused, a key given twice at run time
  keeping its first value. `test/c/run/literal.c` over `tvector.pl` and `literal.pl` prints what clang's build of its
  hand expansion prints; reader `k118` to `k124` hold the forms and eleven refusals. The "literal hook" is the
  instance's function `<name>_from(const T *, size_t)`, a map's `<name>_from(const K *, const V *, size_t)`.
- WHAT 0.263 LEAVES (Not done): a literal where no place gives its type (a conditional's branch, a macro's argument) is
  refused by name, and one at file scope is no constant; a container of plain pointers (`map<int, char *>`, `[5: "me"]`)
  is refused by the borrow rules until ccllib's `string` (phase 1a); `set<int>` and `unordered_map` wait for their type
  macros (phase 1a).

### 0.7 Arguments read after the outer macro

A macro can take an argument unread and read it after it declares its names. Today the inner macro runs first:
`loop(m, println("{}", m))` stops with `cannot_format(m)`, where a plain expression in the same place works.

- DONE AT 0.264 (`RULES.md`, the topic of the macro files): `unread(B)` at a place of a macro's clause head takes that
  argument unread, its tokens; a C text's hole bound to `unread(B)` reads them where the text puts them, after the text
  declares its names. `test/c/run/unread.c` over `unread.pl`: `loop(m, 3, println("m = {}", m))`, a loop in a loop's
  body, `each(v, x, ...)` over a `vector<int>`, `sum_by(v, x, x * x)` as a value, and this plan's
  `sort_by(v, a, b, a > b)`, the comparison put into the loop; it prints what clang's build of its hand expansion prints.
  Refused at the call: a macro that gives the argument back unread, and an argument that does not read where the text
  puts it. Two defects that the fixture met are fixed with it: the reader's scope kept a `for`'s init names after the
  loop (`println` of the outer `double m` printed it by `%d`), and a type that the reader's tables held through a C
  text's type hole reached the AST as the hole's stand-in (`x := at(v, 1);` was `not lowered yet:
  typedef(ccl_hole_1_T)` since 0.261).
- WHAT 0.264 LEAVES (Not done): cicilang++ refuses such a call by name until phase 0.10; a DCG macro takes no argument
  unread; a text that puts an unread argument twice reads it twice.

### 0.8 Two safety rules

Found by three probes on 2026-11-07:

- `int *p = &v.data[0];` over an own field is refused ("plain pointer not consumed"): an element's address must be a
  borrow of the field.
- `int *p = v.data; grow(&v); printf("%d", *p);` is accepted and runs, a use after `realloc`: a call that takes a
  plain pointer to a struct with own fields may replace them (`ck_complete_owners/2`), so it must end the caller's
  borrows of them.
- Done when: both programs refused in `test/c/safe/`, and the right forms accepted in `test/c/run/`.
- DONE AT 0.265 (`RULES.md`, the safe part's topic of borrows): `&a[i]` over a pointer is `a + i`, so `&v.data[0]` is a
  borrow of the buffer; a call that takes the struct by a plain pointer whose pointee is not const ends the caller's
  borrows of its own fields, `borrow_after_call` ("use of a borrow after a call that may replace its owner"):
  `test/c/safe/borrow_after_grow.c`, `borrow_after_push.c`, `elem_after_push.c`, `grow_through_ptr.c` refused, and
  `test/c/run/elemborrow.c` builds the right forms, `at` and `len` (const) keeping a borrow, `push` ending it. A const
  pointee keeps the borrows because an own field of a const object is no modifiable lvalue now, refused in clang's words
  (`const_replace.c`, `const_local.c`). The probes found a third defect, fixed with it: `int *f(int *p) { return &p[1];
  }` was `a borrow leaves the function` since 0.219.
- WHAT 0.265 LEAVES (Not done): both rules are C's until phase 0.10; C's const constraint is held for own fields alone.

### 0.9 Operators on instances

A type macro gives its instances operators that the reader writes as calls: `v[i]`, `m[k]`, `a == b`, `a < b`,
`s + t`, `out << x`, `in >> x`. iostreams needs `<<` and `>>`.

- DONE AT 0.266 (`RULES.md`, the topic of the macro files): where the left operand, or the object of `[]`, is an object
  of an instance's type, the reader writes the operator as the call of the function that the instance's items define
  for it, named as its drop is: `v[i]` is `*<name>_index(&v, i)`, an lvalue; `==` and `!=` are `<name>_eq` and its
  `!`; `< > <= >=` are `<name>_lt`, its operands swapped or its value negated; `+ - * /` are `_add`, `_sub`, `_mul`,
  `_div`; `out << x` is `<name>_shl_<word>(out, x)`, `in >> x` `<name>_shr_<word>(in, &x)`, the word of x's type, and
  `out << a << b` chains on the pointer that `<<` answers. An operand goes by its address where the function's
  parameter is a pointer, by value where it is not. `test/c/run/operators.c` over `topers.pl` -- a point with
  arithmetic and comparisons, a ring and a dictionary with `[]`, a text with `<<`, `>>` and `+` -- prints what clang's
  build of its hand expansion prints. Refused at the operator: one that the macro does not define, an rvalue or an
  operand of another type where the address goes, an instance on the right only, `>>` into no lvalue. The fixture found
  a hole, closed with it: a result tied to a struct with own fields was a borrow of the struct, so `int *p = &m[3];
  m[9] = 1; *p` read the buffer that the insertion freed; it is a borrow of the struct's own fields now, which a call
  that may replace them ends (`test/c/safe/index_after_insert.c`, `tied_after_call.c`).
- WHAT 0.266 LEAVES (Not done): the unary operators (`-a`, `!a`, `*it`, `++it`) and the compound assignments over an
  instance (`a += b`) are no calls; `%`, `&`, `|` and `^` are not in the table; the left operand decides, so `2 * a`
  is refused; the word of `<<`'s operand is its exact type's, so a `const char *` asks `_shl_ptr_const_char`; a tied
  result's borrow is of one own field, so a hand free of another does not end it, as before; C++ keeps its own
  operators until phase 0.10.

### 0.10 ccllib in cicilang++ (the owner's decision of 2026-11-08)

- cicilang++ reads the same macro files: a type macro where no template of its name is visible (`vector<int>` over
  `<vector.pl>`, with no `<vector>`), each instance's C text read by the C++ reader. The text is written in the part
  that C and C++ share: a cast where C converts `void *` and C++ does not (`(int *)realloc(...)`), no name that C++
  keeps.
- The instances are `linkonce_odr` there too; autodrop runs where a destructor would.
- Done when: each ccllib run fixture, built by cicilang++, prints what its cicilang build prints.
- DONE AT 0.267, PARTS 1 AND 2 (`RULES.md`, the topic of the macro files and the safe part's of autodrop): a type
  macro's unqualified name in C++, outside a library header's read (a C++ read starts from template names that hold
  `vector` and `map`, so "no template is visible" was no test); a typed function macro in C++; a C text's functions
  noexcept in C++, linkonce under the mark; the empty object of `= {0}` in C++'s check; the macro files' `realloc`
  cast; autodrop in C++, its moves and the check's rules of 0.262 -- the drop runs where an exception unwinds past the
  scope too, as a C++ landing pad runs the defers of the scopes that it leaves. The C++ gate builds
  `test/c/run/ctext.c` and `autodrop.c` with cicilang++ and compares each with its `.expect`; two C++ units that make
  one instance link. Found and fixed with it: a terminate handler did not end its path in the check; and a hole of
  C's, a null own field that a call may fill was null after the call, so `buf v = {0, NULL}; grow(&v);` leaked with
  no refusal (`test/c/safe/null_filled.c`).
- DONE AT 0.268 (`RULES.md`, the topic of includes): in C++ the program's own header is read as the program's file is
  -- its directives run, its macros expanded, its includes passed on to the reader -- so a header that reads only
  through the preprocessor is the program's, its functions defined once, and a header's function that uses the
  header's own macro holds the expansion. Both faults were older than ccllib. The C++ gate builds `tvector.c` with
  cicilang++ too, its type macros in the program's own headers `tvhdr.h` and `tvhdr2.h`.
- DONE AT 0.269 (`RULES.md`, the topic of the language's own forms): list and map literals in C++, beside a lambda's
  introducer: a `[` begins a literal where the `]` that closes it is followed by none of what follows an introducer, so
  `v := [int; 5, 3, 9];`, `vector<int> e = [];` and `count([4, 5])` read as in C and the lambdas beside them as lambdas.
  The C++ gate builds `literal.c` with cicilang++ too. `[[` begins an attribute in C++, so a literal's first element is
  no literal there.
- DONE AT 0.270 (`RULES.md`, the topic of the language's own forms): the operators on instances and an argument taken
  unread in C++. An instance's operator is its type macro's where the macro defines the function, and C++'s own where
  it does not -- the program's `operator*` over an instance, an instance on the right alone (`2.0 * b`) -- an operand of
  a reference type the object it refers to. A C++ string literal is `const char[N]`, so `topers.pl` gives `<<` a
  `const char *` too. The C++ gate builds `operators.c` and `unread.c` with cicilang++, and runs
  `test/cpp/run/opcpp.cpp`, the macro's operators beside the program's.
- DONE AT 0.272 (`RULES.md`, the safe part's topic of borrows): the safety rules of 0.265 to 0.267 in C++. An
  element's address over a pointer is a borrow of what the pointer borrows; a call that may replace an object's own
  fields ends the caller's borrows of them -- a member function that is not const, a reference parameter that is not
  const, a call through a local reference --, and a const member function and a reference to const keep them; a result
  tied to a struct with own fields is a borrow of them; a null own field that such a call may fill is live after it; an
  own field of a const object is not assigned, in clang++'s words. `test/cpp/run/elemborrowpp.cpp` is `elemborrow.c`
  the C++ way and prints what it prints; `test/cpp/run/borrowkeep.cpp` prints what clang++'s build prints; seven
  refusals in `test/cpp/`, and five C fixtures of `test/c/safe/` refused as C++ with the same words.
- PHASE 0.10 IS DONE WITH IT: each ccllib run fixture built by cicilang++ prints what its cicilang build prints --
  `ctext.c`, `autodrop.c`, `tvector.c`, `literal.c`, `operators.c` and `unread.c` as they stand, `elemborrow.c` as
  `elemborrowpp.cpp`, its plain functions noexcept, since C++'s defer rule refuses a plain struct's live owner across a
  call that may throw.
- WHAT PHASE 0.10 LEAVES (`RULES.md`, Not done): a `mutable` own member in a const member function; a member function's
  result tied to its object; a list literal's first element that is a list literal.

### Order

0.1, then 0.2 to 0.4 together (`vector<int>` needs all three), then 0.5 (autodrop), 0.6, 0.7, 0.8, 0.9 and 0.10. The
first proof after phase 0: `vector<int>` with `push`, `at`, `len` and `sort`, dropped at its scope's end, in the three
runs.

### The first proof (0.273)

`test/ccllib/first.c` over its macro file `first.pl`, and its twin `first.cpp` over `std::vector` and `std::sort`: the
three runs print the same lines, with a count of 10,000,000 too, and under valgrind each frees every block
(`sh test/ccllib.sh`, the ccllib gate, GREEN over libc++ 22, 21 and 18). The costs over libc++ 22 on the gates' box
(4 CPUs), the twin by clang++ 22.1.8 at `-std=c++23`, the builds at `-O0` and the best of seven:

| | build | peak | IR types | IR functions | IR lines | object | `first 10000000` at `-O2` | its peak |
|---|---|---|---|---|---|---|---|---|
| cicilang, C | 0.24 s | 110 MB | 2 | 21 | 1,818 | 11,512 B | 0.28 to 0.34 s | 40 MB |
| cicilang++, C++ | 0.46 s | 135 MB | 2 | 21 | 2,089 | 13,152 B | 0.28 to 0.34 s | 40 MB |
| clang++ 22, `std::` | 0.67 s | 140 MB | 35 | 229 | 5,573 | 126,040 B | 0.38 s | 67 MB |
| cicilang++, `std::` | 9.2 s | 309 MB | 224 | 681 | 14,397 | 92,008 B | 0.43 s | 67 MB |

The last line is no run of the three: cicilang++ building the twin itself, over warm summaries, which is what a
cicilang++ user pays for libc++ and what ccllib takes away. The nearest cost of the three is the peak of cicilang++'s
build, which the twin's over libc++ 21 is under (129 to 133 MB). Over libc++ 18 the twin costs more: by clang++
18.1.3, 0.94 s, 149 MB, 34 types, 268 functions, 6,181 lines, 142,296 B, and 0.76 s for the run.

What the proof found for phase 1:

- `sort`'s partition has no branch on a comparison, as libc++ 22's has none for arithmetic types: with a plain
  quicksort the run took twice the twin's time (0.16 s against 0.08 s for 2,000,000), with this one 0.06 s.
- `at` checks its index and stops the program, where C++ throws; `push` stops it where no memory is left.
- A vector that grows by `realloc` holds one buffer where `std::vector` holds two: 40 MB against 67 MB.
- A macro named as a predicate of cocolog's is written `ccl_macro_NAME`: `sort(V, R)` gave the call to cocolog's
  `sort/2`, and `append(V, W, R)` joins cocolog's own `append/3` (`RULES.md`, the topic of the macro files and Not
  done). ccllib's generic calls are written so.
- A C text is not preprocessed, so `NULL` is no name in it, and `stdout`, `EOF` and `errno` are none either: phase 1d
  needs a road for them (`RULES.md`, Not done).

## Phase 1: the library before C++23, the most used part first

### What phase 1 stands on (0.274)

- AN INSTANCE'S FUNCTIONS ARE MADE AT THEIR FIRST CALL: `fn_vector(Name, Args, Items)` gives one function's items when
  the unit first calls it, so a unit holds the functions that it calls and no other, as C++ instantiates the members
  that a program uses. A module is a table of C texts by name.
- A CALL FINDS ITS FUNCTION BY THE TYPE OF ITS FIRST ARGUMENT, with no macro per name: `push_back(v, 1)` is
  `vector_int_push_back(&v, 1)`; `v` may be a pointer to the vector; the count of the arguments tells two forms of a
  name apart (`resize(v, n, x)` is `_resize3`).
- `#include <vector.pl>` ALONE: the path holds `library/ccllib/`, and `vector.pl.h` beside the macro file brings the C
  declarations that its text calls.
- THE NAMES ARE C++'S; `push`, `pop` and `len`, the short names of this plan's examples, stand beside `push_back`,
  `pop_back` and `size`. A place is an index where C++ takes an iterator.
- WHAT TWO MODULES NEED IS WRITTEN ONCE (0.275): `library/ccllib/ccllib.pl`, which a module loads by a directive. No
  program includes it, and the flow gate refuses a predicate that two modules define.

### 1a, `vector.pl` (0.274)

The whole surface of `std::vector`, 38 functions and the drop, for an element that is a value with no pointer in it
(`RULES.md`, the topic of ccllib, says what differs from C++). `test/ccllib/vector.c` calls each function over `int`,
`double`, a plain struct and `bool`; its twin over `std::vector` prints the same lines; seven programs of
`test/ccllib/safe/` are refused, as C and as C++. The costs over libc++ 22 on the gates' box, the twin by clang++
22.1.8 at `-std=c++23`, the builds at `-O0` and the best of three:

| | build | peak | IR types | IR functions | IR lines | object | `vector 10000000` at `-O2` | its peak |
|---|---|---|---|---|---|---|---|---|
| cicilang, C | 0.33 s | 126 MB | 5 | 67 | 2,597 | 23,760 B | 0.07 s | 78 MB |
| cicilang++, C++ | 0.77 s | 162 MB | 5 | 67 | 3,529 | 28,240 B | 0.07 s | 78 MB |
| clang++ 22, `std::` | 0.80 s | 141 MB | 73 | 519 | 14,649 | 300,216 B | 0.14 s | 79 MB |

The unit holds 67 functions for its four instances where the twin's holds 519, and an object of 24 KB where the
twin's is 300 KB. cicilang's C build takes less than half of clang++'s time; cicilang++'s build of this program, which
calls every function of the vector, takes as long as clang++'s build of the twin and more memory (162 MB against 141
MB): the nearest costs, and phase 1's first target.

DECISION 2 STANDS BEFORE THE CONTAINERS OF OWNERS: `vector<string>`, `vector<vector<int>>`, `map<int, string>` and
every container of pointers need the owner's rule on containers of owners. `vector.pl` refuses such an element by name
until then; with functions made at their first call, nothing else would refuse it. The other modules of 1a go on over
elements with no pointer in them, each one a step.

### 1a, `array.pl` (0.275)

`array<T, N>` is a struct of one C array: a value with no heap and no drop, which `b := a` and `f(a)` copy as
`std::array`'s do. 16 functions. `test/ccllib/array.c` over `int`, `double` and a plain struct, its twin over
`std::array`, and three programs of `test/ccllib/safe/`. The costs over libc++ 22, as above, the run `array 100000000`:

| | build | peak | IR types | IR functions | IR lines | object | `array 100000000` at `-O2` | its peak |
|---|---|---|---|---|---|---|---|---|
| cicilang, C | 0.24 s | 113 MB | 5 | 35 | 1,044 | 11,160 B | 0.17 s | 2 MB |
| cicilang++, C++ | 0.37 s | 129 MB | 5 | 35 | 1,147 | 11,160 B | 0.17 s | 2 MB |
| clang++ 22, `std::` | 0.21 s | 106 MB | 12 | 68 | 1,664 | 36,072 B | 0.54 s | 3 MB |

`<array>` is a light header: clang++ builds the twin for less than cicilang builds the ccllib program, the first such
program. What a cicilang build costs here is its floor, the first proof's 0.24 s and 110 MB. The unit is a third of the
twin's, and the count run takes a third of its time.

### 1a, `deque.pl` (0.276)

`deque<T>` is a ring: a buffer whose capacity is a power of two, with a head, so each end takes and gives an element in
constant time and `d[i]` is one mask away; `insert` and `erase` move the elements of the nearer end. 36 functions and
the drop. There is no `begin`, `end` or `data`, and a push at an end ends the borrows of the buffer, where C++ keeps a
reference over it. `test/ccllib/deque.c`, its twin over `std::deque`, three programs of `test/ccllib/safe/`; its count
run ends with a walk of chance over the operations at a place. The costs over libc++ 22, as above:

| | build | peak | IR types | IR functions | IR lines | object | `deque 10000000` at `-O2` | its peak |
|---|---|---|---|---|---|---|---|---|
| cicilang, C | 0.35 s | 124 MB | 4 | 61 | 3,723 | 27,568 B | 0.09 s | 65 MB |
| cicilang++, C++ | 1.08 s | 166 MB | 4 | 61 | 4,649 | 31,944 B | 0.09 s | 65 MB |
| clang++ 22, `std::` | 0.60 s | 127 MB | 83 | 715 | 26,588 | 450,752 B | 0.09 s | 66 MB |

The unit holds 61 functions where the twin's holds 715, and the three runs take the same time and memory. cicilang++'s
build is the dearest again, 1.08 s and 166 MB against clang++'s 0.60 s and 127 MB for the twin, three times the C build:
phase 1's first target, as the vector's program showed.

### 1a, `list.pl` (0.277)

`list<T>` is an arena: its nodes stand in one own buffer and name one another by their numbers, as this plan had it. A
place -- C++'s iterator -- is a node's number, and it stays its element's over every insert, every erase of another
element, a `sort` and a `reverse`. 51 functions and the drop, `sort`, `unique`, `merge`, `splice`, `remove` and
`reverse` among them; `splice` and `merge` take the other list's elements one by one, where C++ moves the nodes.
`test/ccllib/list.c`, its twin over `std::list`, three programs of `test/ccllib/safe/`. The costs over libc++ 22, as
above:

| | build | peak | IR types | IR functions | IR lines | object | `list 1000000` at `-O2` | its peak |
|---|---|---|---|---|---|---|---|---|
| cicilang, C | 0.43 s | 138 MB | 7 | 89 | 4,914 | 40,816 B | 0.53 s | 25 MB |
| cicilang++, C++ | 1.15 s | 168 MB | 7 | 89 | 6,455 | 50,280 B | 0.62 s | 25 MB |
| clang++ 22, `std::` | 0.41 s | 119 MB | 49 | 327 | 11,675 | 202,312 B | 0.69 s | 34 MB |

The unit holds 89 functions where the twin's holds 327, and the count run is faster and smaller than the twin's: a node
is the element and two numbers in one buffer, with no block of the allocator's for each. The builds are the other way:
clang++ builds the twin as fast as cicilang builds the program and with less memory, and cicilang++'s build is the
dearest again, 1.15 s and 168 MB. The run as C++ is slower than the run as C, 0.62 s against 0.53 s, from one text: a
second thing for phase 1 to find out.

### 1a, `forward_list.pl` (0.278)

`forward_list<T>` is the list's arena with one link a node: `before_begin`, `insert_after`, `erase_after`,
`splice_after`, `push_front`, and the list's own operations, 44 functions and the drop. Its sort is the list's, one text
for both. `size` and `len` are there, which C++'s has not. `test/ccllib/forward_list.c`, its twin over
`std::forward_list`, three programs of `test/ccllib/safe/`. The costs over libc++ 22, as above:

| | build | peak | IR types | IR functions | IR lines | object | `forward_list 1000000` at `-O2` | its peak |
|---|---|---|---|---|---|---|---|---|
| cicilang, C | 0.41 s | 134 MB | 7 | 79 | 4,505 | 38,064 B | 0.35 s | 17 MB |
| cicilang++, C++ | 1.12 s | 163 MB | 7 | 79 | 5,951 | 47,656 B | 0.34 s | 18 MB |
| clang++ 22, `std::` | 0.41 s | 119 MB | 54 | 313 | 11,133 | 201,736 B | 0.72 s | 34 MB |

The unit holds 79 functions where the twin's holds 313, and the count run takes half the twin's time and half its
memory: a node is the element and one number in one buffer. The builds are as the list's: the C build and clang++'s
build of the twin take the same time, and cicilang++'s build is the dearest, 1.12 s and 163 MB.

### The parts of phase 1

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
  lines; the twin makes the `.expect`. THE CCLLIB GATE runs them (0.273, `sh test/ccllib.sh`, the chain's last gate):
  `test/ccllib/NAME.c`, its twin `NAME.cpp`, `NAME.expect`, and `NAME.count` for a longer run; where valgrind is, each
  run frees every block.
- SAFETY: what the safe part must refuse goes into `test/c/safe/`.
- COST, for each program, of each of the three runs: the build time, the IR's types and functions and lines, the
  object's size, the peak memory, and the run's own time. Phase 1 sets its targets from the first programs. The gate
  prints them, a line a run, measured by `test/cost.c`; they are a record and no check.
- The flow gate charts `library/ccllib/*.pl` with the library.
