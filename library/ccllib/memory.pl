%% ccllib's <memory.pl> (0.309; CCLLIB.md's phase 1b): std::unique_ptr for cicilang's C, and for cicilang++ beside
%% libc++'s.
%%
%%   #include <memory.pl>
%%   unique_ptr<point> p;                           born null
%%   unique_ptr<point> q = make_unique<point>(pt);  a copy of pt on the heap; make_unique<point>() is zero
%%   q->x = 3;  (*q).y = 4;  point *b = get(q);     the object's place, a borrow tied to q
%%   own point *r = release(q);  reset(p, r);  reset(p);  swap(p, q);  if (p == q || p < q) ...
%%
%% type_unique_ptr/3 gives the instance's type, `unique_ptr_point', a struct of one own pointer, and its drop, which
%% frees the object: the compiler drops the object of the instance at its scope's end, as C++ runs the destructor, and
%% `w = p' and `f(p)' move it, as every object of an instance's type is moved, where C++ writes std::move. fn_unique_ptr/3
%% gives ONE function of the instance at its first use. The fact pointer_unique_ptr makes `*p' and `p->m' the
%% instance's deref and arrow (the reader's pointer's type macro, 0.309), and the fact maker_unique_ptr_make_unique
%% makes `make_unique<point>(x)' the instance's make_unique (the reader's maker by name). What differs from C++:
%%   the object is a value with no pointer in it (CCLLIB.md's open decision 2), no array -- unique_ptr<T[]> waits, since
%%     a type of no bound has no word -- and no void; there is no deleter: the object is freed, and a release of
%%     another kind waits for the owner's word (0.307's question of a FILE and an SSL_SESSION);
%%   make_unique<T>(x) takes a value of T and make_unique<T>() makes T's zero, where C++ passes its arguments to a
%%     constructor; a unique_ptr is made of an own pointer, `unique_ptr<point> p = r;', which moves r into it;
%%   *p and p->m over an empty unique_ptr stop the program (abort), where C++ is undefined; get(p) gives the null
%%     pointer;
%%   `if (p)', `p == nullptr' and `p == 0' have no form: `get(p)' and `get(p) == 0' are their spelling;
%%   a unique_ptr is not copied: clone(p) is refused by name, as C++ deletes the copy;
%%   the relations compare the pointers, as C++'s do; hash comes with phase 1b's hash, and operator<< with 1d.
:- ensure_loaded(library(ccllib/ccllib)).
type_unique_ptr([T], base([], [typedef(N)]), Items) :- !,
    ccl_instance_name(unique_ptr, [T], N), ccllib_plain_element('a unique_ptr''s object', T),
    ( catch(ccl_resolve_type(T, arr(_, _)), _, fail) -> ccl_macro_error('a unique_ptr''s object is no array: unique_ptr<T[]> waits') ; true ),
    ( catch(ccl_resolve_type(T, base(_, [void])), _, fail) -> ccl_macro_error('a unique_ptr''s object is no void') ; true ),
    ccl_c_items("typedef struct @N { own @T *p; } @N;
void @{N}_drop(@N *u) { free(u->p); }", ['N' = name(N), 'T' = type(T)], Items).
type_unique_ptr(_, _, _) :- ccl_macro_error('a unique_ptr takes one type, its object''s: a deleter waits').
fn_unique_ptr(Name, [T], Items) :-
    ccllib_unique_ptr_text(Name, T, Text), ccl_instance_name(unique_ptr, [T], N),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
%% a function's C text by its name. A name that the table has not is no function and fails with no error: a call by
%% name asks `<name><count>' first (`get1' for `get(p)'), and the reader refuses a name that no form fits by that name
ccllib_unique_ptr_text(get, _, "@T *@{N}_get(const @N *u) tie u { return u->p; }") :- !.
ccllib_unique_ptr_text(deref, _, "@T *@{N}_deref(const @N *u) tie u { if (!u->p) abort(); return u->p; }") :- !.
ccllib_unique_ptr_text(arrow, _, "@T *@{N}_arrow(const @N *u) tie u { if (!u->p) abort(); return u->p; }") :- !.
ccllib_unique_ptr_text(release, _, "own @T *@{N}_release(@N *u) { own @T *p = u->p; u->p = 0; return p; }") :- !.
ccllib_unique_ptr_text(reset, _, "void @{N}_reset(@N *u) { free(u->p); u->p = 0; }") :- !.
ccllib_unique_ptr_text(reset2, _, "void @{N}_reset2(@N *u, own @T *x) { free(u->p); u->p = x; }") :- !.
ccllib_unique_ptr_text(swap, _, "void @{N}_swap(@N *a, @N *b) { own @T *t = a->p; a->p = b->p; b->p = t; }") :- !.
ccllib_unique_ptr_text(make_unique, _,
    "@N @{N}_make_unique(@T x) { @N u; u.p = malloc(sizeof *u.p); if (!u.p) abort(); *u.p = x; return u; }") :- !.
ccllib_unique_ptr_text(make_unique0, _,
    "@N @{N}_make_unique0(void) { @N u; u.p = calloc(1, sizeof *u.p); if (!u.p) abort(); return u; }") :- !.
ccllib_unique_ptr_text(make_unique_for_overwrite, _,
    "@N @{N}_make_unique_for_overwrite(void) { @N u; u.p = malloc(sizeof *u.p); if (!u.p) abort(); return u; }") :- !.
%% the relations compare the pointers; the reader writes `!=' and `>' of `==' and `<'
ccllib_unique_ptr_text(eq, _, "int @{N}_eq(const @N *a, const @N *b) { return a->p == b->p; }") :- !.
ccllib_unique_ptr_text(lt, _, "int @{N}_lt(const @N *a, const @N *b) { return a->p < b->p; }") :- !.
ccllib_unique_ptr_text(le, _, "int @{N}_le(const @N *a, const @N *b) { return a->p <= b->p; }") :- !.
ccllib_unique_ptr_text(ge, _, "int @{N}_ge(const @N *a, const @N *b) { return a->p >= b->p; }") :- !.
%% `unique_ptr<point> p = r;' over an own pointer r: the birth by the word of r's type, ptr_own_point, moves r in
ccllib_unique_ptr_text(Name, T, Text) :- atom(Name), atom_concat(of_ptr_own_, W, Name), catch(ccl_type_word(T, W), _, fail), !,
    atomic_list_concat(['@N @{N}_', Name, '(own @T *x) { @N u; u.p = x; return u; }'], Text).
%% the instance's `*p' and `p->m' are its deref and arrow, and make_unique and make_unique_for_overwrite its makers
pointer_unique_ptr.
maker_unique_ptr_make_unique.
maker_unique_ptr_make_unique_for_overwrite.
