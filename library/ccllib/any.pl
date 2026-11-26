%% ccllib's <any.pl> (1.1.5; CCLLIB.md's phase 1b): std::any for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <any.pl>
%%   any<> a;                          born empty; `any' is a type of no arguments, and ccllib spells it `any<>'
%%   any<> n = 5;                      a copy of the value, with its type; the birth is `any_of_int(5)'
%%   any<> d = 2.5;  any<> p = pt;     a double's and a struct's
%%   if (has_value(n)) printf("%d", any_cast<int>(n));
%%   printf("%d", has_value(n));     a's value is there
%%   any<> c = clone(n);  swap(n, d);  reset(n);  if (!has_value(n)) ...
%%
%% The type is a struct of one own pointer to a copy of the value, its size, and the word of its type; the compiler
%% drops it at its scope's end (autodrop). `any<>' IS THE TYPE'S SPELLING: ccllib's type macros are written with their
%% `<...>', and std::any takes none, so the empty list is its. The birth from a value is `any_of_<type>', made at its
%% first use; `any_cast<T>(a)' is the instance's `any_any_cast_<type>', by the reader's typed call by name; the two are
%% made for the type that the call names, and no table of types is the module's. What differs from C++:
%%   the object is a value with no pointer in it (CCLLIB.md's open decision 2): a pointer, an array and a function are
%%     refused where the value is made, with `a type 'ptr_int': an any holds a value with no pointer in it, and that
%%     type is a pointer, an array or a function';
%%   an any is moved by an assignment and by a call, as every object of an instance's type is moved; clone(a) copies it;
%%   `make_any<T>(x)' is not there: `any<> a = x;' is its birth, since the maker's list names the any and not the value's
%%     type; `any_cast<T>(&a)' the pointer form waits, since a function has one result type;
%%   any_cast of a type that a does not hold, and of an empty a, stop the program (abort), where C++ throws;
%%   `type(a)' waits: the any keeps a number for its type, not its name, so a value's type is not printed;
%%   `operator=' from another type (`a = 5') waits: `any<> b = 5;  a = b;' is the move, and clone(a) the copy.
:- ensure_loaded(library(ccllib/ccllib)).

type_any([], base([], [typedef(any)]), Items) :- !,
    ccl_c_items("typedef struct any { own void *p; size_t size; size_t tag; } any;
void any_drop(any *a) { if (a->p) { free(a->p); a->p = 0; } a->size = 0; a->tag = 0; }", [], Items).
type_any(_, _, _) :- ccl_macro_error('an any takes no type arguments: write any<>').
fn_any(Name, [], Items) :-
    ccl_instance_name(any, [], N), atomic_list_concat([N, '_', Name], F),
    ccllib_any_text(Name, F, Text), ccllib_any_holes(Name, F, Holes), ccl_c_items(Text, Holes, Items).
ccllib_any_holes(Name, F, ['F' = name(F), 'T' = type(T)]) :- ccllib_any_word(Name, _, T), !.
ccllib_any_holes(_, F, ['F' = name(F)]).
%% a function's C text by its name. `of_<word>' and `any_cast_<word>' are the two whose type is the call's: the word is
%% resolved to the type here, and the C text names it
ccllib_any_text(Name, _F, Text) :- ccllib_any_word(Name, W, _T), W \== none, !, ccllib_any_tag(W, K),
    (   atom_concat(of_, _, Name)
    ->  atomic_list_concat(['any @F(@T x) { any a; a.p = malloc(sizeof x); if (!a.p) abort(); *(@T *)a.p = x; a.size = sizeof x; a.tag = ', K, '; return a; }'], Text)
    ;   atom_concat(any_cast_, _, Name)
    ->  atomic_list_concat(['@T @F(const any *a) { if (!a->p || a->tag != ', K, ') abort(); return *(@T *)a->p; }'], Text)
    ;   fail ).
ccllib_any_text(has_value, _, "int any_has_value(const any *a) { return a->p != 0; }") :- !.
ccllib_any_text(reset, _, "void any_reset(any *a) { if (a->p) { free(a->p); a->p = 0; } a->size = 0; a->tag = 0; }") :- !.
ccllib_any_text(swap, _, "void any_swap(any *a, any *b) { own void *p = a->p; a->p = b->p; b->p = p; size_t s = a->size; a->size = b->size; b->size = s; size_t t = a->tag; a->tag = b->tag; b->tag = t; }") :- !.
ccllib_any_text(clone, _, "any any_clone(const any *a) { any b; b.p = 0; b.size = 0; b.tag = 0; if (!a->p) return b; own void *p = malloc(a->size); if (!p) abort(); memcpy(p, a->p, a->size); b.p = p; b.size = a->size; b.tag = a->tag; return b; }") :- !.
%% the type a word names: the words of ccl_type_word/2 for the C types, and a name the program declares for the rest;
%% a pointer, an array, a function or a void is refused, as no object of any holds one
ccllib_any_word(Name, W, T) :-
    ( atom_concat(of_, W, Name) ; atom_concat(any_cast_, W, Name) ), !, ccllib_any_word_type(W, T).
ccllib_any_word_type(W, T) :- ccllib_any_builtin(W, T), !.
ccllib_any_word_type(W, _) :- ( atom_concat(ptr_, _, W) ; atom_concat(arr_, _, W) ), !,
    ccl_macro_error_words(W, 'an any holds a value with no pointer in it, and that type is a pointer or an array').
ccllib_any_word_type(W, base([], [typedef(W)])) :- atom(W).
ccllib_any_tag(W, K) :- atom_codes(W, Cs), ccllib_any_tag(Cs, 0, K).
ccllib_any_tag([], K, K).
ccllib_any_tag([C|Cs], K0, K) :- K1 is (K0 * 131 + C) mod 1000000007, ccllib_any_tag(Cs, K1, K).
ccllib_any_builtin(char, base([], [char])).
ccllib_any_builtin(schar, base([signed], [char])).
ccllib_any_builtin(uchar, base([unsigned], [char])).
ccllib_any_builtin(short, base([], [short])).
ccllib_any_builtin(ushort, base([unsigned], [short])).
ccllib_any_builtin(int, base([], [int])).
ccllib_any_builtin(uint, base([unsigned], [int])).
ccllib_any_builtin(long, base([], [long])).
ccllib_any_builtin(ulong, base([unsigned], [long])).
ccllib_any_builtin(llong, base([], [long, long])).
ccllib_any_builtin(ullong, base([unsigned], [long, long])).
ccllib_any_builtin(float, base([], [float])).
ccllib_any_builtin(double, base([], [double])).
ccllib_any_builtin(bool, base([], [bool])).
ccllib_any_builtin('_Bool', base([], ['_Bool'])).
ccllib_any_builtin(size_t, base([], [typedef(size_t)])).
ccl_macro_error_words(W, M) :- atomic_list_concat(['a type ''', W, ''': ', M], Text), ccl_macro_error(Text).
