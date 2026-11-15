%% ccllib's <memory.pl> (0.309; CCLLIB.md's phase 1b): std::unique_ptr, std::shared_ptr and std::weak_ptr for
%% cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <memory.pl>
%%   unique_ptr<point> p;                           born null
%%   unique_ptr<point> q = make_unique<point>(pt);  a copy of pt on the heap; make_unique<point>() is zero
%%   q->x = 3;  (*q).y = 4;  point *b = get(q);     the object's place, a borrow tied to q
%%   own point *r = release(q);  reset(p, r);  reset(p);  swap(p, q);  if (p == q || p < q) ...
%%
%%   shared_ptr<point> s;                           born empty
%%   shared_ptr<point> t = make_shared<point>(pt);  a copy of pt on the heap; make_shared<point>() is zero
%%   shared_ptr<point> u = clone(t);                a second owner: use_count(t) is 2
%%   t->x = 3;  (*t).y = 4;  point *b = get(t);     the object's place, a borrow tied to t
%%   reset(t);  reset(t, pt);  swap(t, u);  if (t == u || t < u) ...
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
%%
%% type_shared_ptr/3 gives `shared_ptr_point', a struct of ONE OWN POINTER that names a block's slot, the pool's own
%% address, and its drop: the block is one of a pool of 4096 that the instance keeps (a static own array), and a block
%% holds the object's value and the two counts, strong and weak. A HANDLE BELONGS TO THE UNIT THAT MADE IT: the pool is
%% the unit's own, and a handle handed to another unit's function stops the program (abort) rather than read that unit's
%% pool. The last drop of a strong count frees the block's slot (sets it null), and the pool
%% reuses it: a program's blocks are bounded at once by the pool's size, never in all, and a creation past 4096 live
%% blocks of one instance stops the program (abort). fn_shared_ptr/3 gives ONE function at its first use, as
%% fn_unique_ptr/3 does. The fact pointer_shared_ptr makes `*p' and `p->m' its deref and arrow; maker_shared_ptr_make_shared
%% and maker_shared_ptr_make_shared_for_overwrite make `make_shared<point>(x)' and `make_shared<point>()' its makers. What
%% differs from C++:
%%   clone(t) is the copy, `shared_ptr<point> u = clone(t);' -- a second owner, which use_count(t) shows; `w = t' and
%%     `f(t)' MOVE t, as every object of an instance's type is moved, where C++ copies unless std::move says otherwise;
%%   make_shared<T>(x) takes a value of T and make_shared<T>() makes T's zero, where C++ passes its arguments to a
%%     constructor; make_shared_for_overwrite<T>() is a block whose bytes are not set, as C++20's;
%%   the object is a value with no pointer in it (CCLLIB.md's open decision 2), no array and no void, and there is no
%%     deleter and no aliasing constructor;
%%   *p and p->m over an empty shared_ptr stop the program (abort), where C++ is undefined; get(p) gives the null
%%     pointer; `if (p)', `p == nullptr' and `p == 0' have no form;
%%   weak_ptr<T> is there (1.1.5): `weak_ptr<int> w = p;', lock, expired, use_count, reset, swap and clone, below;
%%   the relations compare the objects' addresses, as C++'s do; use_count(p) and unique(p) read the strong count, and
%%     a block whose last strong owner is gone but whose weak count is not stays until the weak count ends;
%%   a shared_ptr is made and used in one unit: the pool is the unit's own, and a handle handed to another unit stops
%%     the program (abort), where the pool it names is another's.
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
%% ---- shared_ptr (1.1.3) ---------------------------------------------------
%% the instance's names: the type, its block and its pool
ccllib_shared_ptr_names(T, N, B, P) :-
    ccl_instance_name(shared_ptr, [T], N), atomic_list_concat([N, '_block'], B), atomic_list_concat([N, '_pool'], P).
type_shared_ptr([T], base([], [typedef(N)]), Items) :- !,
    ccllib_shared_ptr_names(T, N, B, P), ccllib_plain_element('a shared_ptr''s object', T),
    ( catch(ccl_resolve_type(T, arr(_, _)), _, fail) -> ccl_macro_error('a shared_ptr''s object is no array: shared_ptr<T[]> waits') ; true ),
    ( catch(ccl_resolve_type(T, base(_, [void])), _, fail) -> ccl_macro_error('a shared_ptr''s object is no void') ; true ),
    ccl_c_items("typedef struct @B { size_t strong, weak; int live; @T v; } @B;
typedef struct @N { own size_t *slot; size_t pool; } @N;
static own @B *@P[4096];
void @{N}_drop(@N *u) {
    if (!u->slot) return;
    if (u->pool != (size_t)(uintptr_t)@P) abort();
    size_t i = *u->slot;
    @B *b = @P[i - 1];
    free(u->slot); u->slot = 0;
    if (b && b->strong && --b->strong == 0) { b->live = 0; if (!b->weak) @P[i - 1] = 0; }
}",
        ['N' = name(N), 'T' = type(T), 'B' = name(B), 'P' = name(P)], Items).
type_shared_ptr(_, _, _) :- ccl_macro_error('a shared_ptr takes one type, its object''s: a deleter waits').
fn_shared_ptr(Name, [T], Items) :-
    ccllib_shared_ptr_text(Name, Text), ccllib_shared_ptr_names(T, N, B, P),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T), 'B' = name(B), 'P' = name(P)], Items).
%% a function's C text by its name. A block is a slot of the pool, born with the object's value; a handle owns the
%% number of its slot (one own size_t) and the pool's own address as a number, so a move leaves the handle empty, as
%% every own field of a moved object is null
ccllib_shared_ptr_text(make_shared, "@N @{N}_make_shared(@T x) {
    @N u;
    size_t i;
    for (i = 0; i < 4096; i++) if (!@P[i]) break;
    if (i == 4096) abort();
    own @B *b = calloc(1, sizeof *b);
    if (!b) abort();
    b->strong = 1; b->weak = 0; b->live = 1; b->v = x;
    @P[i] = b;
    own size_t *s = malloc(sizeof *s);
    if (!s) abort();
    *s = i + 1; u.slot = s; u.pool = (size_t)(uintptr_t)@P;
    return u; }") :- !.
ccllib_shared_ptr_text(make_shared0, "@N @{N}_make_shared0(void) {
    @N u;
    size_t i;
    for (i = 0; i < 4096; i++) if (!@P[i]) break;
    if (i == 4096) abort();
    own @B *b = calloc(1, sizeof *b);
    if (!b) abort();
    b->strong = 1; b->weak = 0; b->live = 1;
    @P[i] = b;
    own size_t *s = malloc(sizeof *s);
    if (!s) abort();
    *s = i + 1; u.slot = s; u.pool = (size_t)(uintptr_t)@P;
    return u; }") :- !.
ccllib_shared_ptr_text(make_shared_for_overwrite, "@N @{N}_make_shared_for_overwrite(void) {
    @N u;
    size_t i;
    for (i = 0; i < 4096; i++) if (!@P[i]) break;
    if (i == 4096) abort();
    own @B *b = malloc(sizeof *b);
    if (!b) abort();
    b->strong = 1; b->weak = 0; b->live = 1;
    @P[i] = b;
    own size_t *s = malloc(sizeof *s);
    if (!s) abort();
    *s = i + 1; u.slot = s; u.pool = (size_t)(uintptr_t)@P;
    return u; }") :- !.
ccllib_shared_ptr_text(clone, "@N @{N}_clone(const @N *u) { @N v; v.slot = 0; v.pool = 0; if (!u->slot) return v; if (u->pool != (size_t)(uintptr_t)@P) abort(); own size_t *s = malloc(sizeof *s); if (!s) abort(); *s = *u->slot; ++@P[*s - 1]->strong; v.slot = s; v.pool = u->pool; return v; }") :- !.
ccllib_shared_ptr_text(get, "@T *@{N}_get(const @N *u) tie @P { if (!u->slot) return 0; if (u->pool != (size_t)(uintptr_t)@P) abort(); @B *b = @P[*u->slot - 1]; if (!b || !b->live) return 0; return &b->v; }") :- !.
ccllib_shared_ptr_text(deref, "@T *@{N}_deref(const @N *u) tie @P { @T *p = @{N}_get(u); if (!p) abort(); return p; }") :- !.
ccllib_shared_ptr_text(arrow, "@T *@{N}_arrow(const @N *u) tie @P { @T *p = @{N}_get(u); if (!p) abort(); return p; }") :- !.
ccllib_shared_ptr_text(use_count, "size_t @{N}_use_count(const @N *u) { if (!u->slot) return 0; if (u->pool != (size_t)(uintptr_t)@P) abort(); @B *b = @P[*u->slot - 1]; if (!b) return 0; return b->strong; }") :- !.
ccllib_shared_ptr_text(unique, "int @{N}_unique(const @N *u) { if (!u->slot) return 0; if (u->pool != (size_t)(uintptr_t)@P) abort(); @B *b = @P[*u->slot - 1]; return b && b->strong == 1; }") :- !.
ccllib_shared_ptr_text(reset, "void @{N}_reset(@N *u) {
    if (!u->slot) return;
    if (u->pool != (size_t)(uintptr_t)@P) abort();
    size_t i = *u->slot;
    @B *b = @P[i - 1];
    free(u->slot); u->slot = 0; u->pool = 0;
    if (b && b->strong && --b->strong == 0) { b->live = 0; if (!b->weak) @P[i - 1] = 0; } }") :- !.
ccllib_shared_ptr_text(reset2, "void @{N}_reset2(@N *u, @T x) {
    if (u->slot) { if (u->pool != (size_t)(uintptr_t)@P) abort(); size_t i = *u->slot; @B *o = @P[i - 1]; free(u->slot); u->slot = 0; if (o && o->strong && --o->strong == 0) { o->live = 0; if (!o->weak) @P[i - 1] = 0; } }
    size_t i;
    for (i = 0; i < 4096; i++) if (!@P[i]) break;
    if (i == 4096) abort();
    own @B *b = calloc(1, sizeof *b);
    if (!b) abort();
    b->strong = 1; b->weak = 0; b->live = 1; b->v = x;
    @P[i] = b;
    own size_t *s = malloc(sizeof *s);
    if (!s) abort();
    *s = i + 1; u->slot = s; u->pool = (size_t)(uintptr_t)@P; }") :- !.
ccllib_shared_ptr_text(swap, "void @{N}_swap(@N *a, @N *b) { if (a->slot && a->pool != (size_t)(uintptr_t)@P) abort(); if (b->slot && b->pool != (size_t)(uintptr_t)@P) abort(); own size_t *t = a->slot; a->slot = b->slot; b->slot = t; size_t k = a->pool; a->pool = b->pool; b->pool = k; }") :- !.
ccllib_shared_ptr_text(eq, "int @{N}_eq(const @N *a, const @N *b) { return @{N}_get(a) == @{N}_get(b); }") :- !.
ccllib_shared_ptr_text(lt, "int @{N}_lt(const @N *a, const @N *b) { return @{N}_get(a) < @{N}_get(b); }") :- !.
ccllib_shared_ptr_text(le, "int @{N}_le(const @N *a, const @N *b) { return @{N}_get(a) <= @{N}_get(b); }") :- !.
ccllib_shared_ptr_text(ge, "int @{N}_ge(const @N *a, const @N *b) { return @{N}_get(a) >= @{N}_get(b); }") :- !.
%% the instance's `*p' and `p->m' are its deref and arrow, and make_shared and make_shared_for_overwrite its makers
pointer_shared_ptr.
maker_shared_ptr_make_shared.
maker_shared_ptr_make_shared_for_overwrite.
%% ---- weak_ptr (1.1.5) ------------------------------------------------------
%% the instance's names: the weak type, the shared type it observes, its block and its pool. The shared instance is
%% made with the weak one, so that both name the same block's layout in the unit.
ccllib_weak_ptr_names(T, W, S, B, P) :-
    ccl_instance_name(weak_ptr, [T], W), ccl_instance_name(shared_ptr, [T], S),
    atomic_list_concat([S, '_block'], B), atomic_list_concat([S, '_pool'], P).
type_weak_ptr([T], base([], [typedef(W)]), Items) :- !,
    ccllib_weak_ptr_names(T, W, S, B, P), ccllib_plain_element('a weak_ptr''s object', T),
    ccl_tmacro_instance(shared_ptr, type_shared_ptr, [T], 0, _),
    ccl_c_items("typedef struct @W { own size_t *slot; size_t pool; } @W;
void @{W}_drop(@W *u) {
    if (!u->slot) return;
    if (u->pool != (size_t)(uintptr_t)@P) abort();
    size_t i = *u->slot;
    @B *b = @P[i - 1];
    free(u->slot); u->slot = 0;
    if (b) { if (b->weak) b->weak--; if (!b->strong && !b->weak) @P[i - 1] = 0; }
}",
        ['W' = name(W), 'S' = name(S), 'B' = name(B), 'P' = name(P)], Items).
type_weak_ptr(_, _, _) :- ccl_macro_error('a weak_ptr takes one type, its object''s').
fn_weak_ptr(Name, [T], Items) :-
    ccllib_weak_ptr_names(T, W, S, B, P), ccllib_weak_ptr_text(Name, W, S, Text),
    ccl_c_items(Text, ['W' = name(W), 'S' = name(S), 'B' = name(B), 'P' = name(P)], Items).
%% a function's C text by its name; `of_shared_ptr_T` is the birth from a shared_ptr, which takes the shared handle by
%% its address through the reader's `_of' form, so the caller's handle is not moved
ccllib_weak_ptr_text(Name, W, S, Text) :- atomic_list_concat([of_, S], Name), !,
    atomic_list_concat(['@W @{W}_', Name, '(const @S *s) {
    @W v; v.slot = 0; v.pool = 0;
    if (!s->slot) return v;
    if (s->pool != (size_t)(uintptr_t)@P) abort();
    @B *b = @P[*s->slot - 1]; if (!b) return v;
    own size_t *t = malloc(sizeof *t); if (!t) abort(); *t = *s->slot; b->weak++;
    v.slot = t; v.pool = s->pool; return v; }'], Text).
ccllib_weak_ptr_text(clone, _, _, "@W @{W}_clone(const @W *u) { @W v; v.slot = 0; v.pool = 0; if (!u->slot) return v; if (u->pool != (size_t)(uintptr_t)@P) abort(); @B *b = @P[*u->slot - 1]; if (!b) return v; own size_t *t = malloc(sizeof *t); if (!t) abort(); *t = *u->slot; b->weak++; v.slot = t; v.pool = u->pool; return v; }") :- !.
ccllib_weak_ptr_text(lock, _, _, "@S @{W}_lock(const @W *u) { @S s; s.slot = 0; s.pool = 0; if (!u->slot) return s; if (u->pool != (size_t)(uintptr_t)@P) abort(); @B *b = @P[*u->slot - 1]; if (!b || !b->live || !b->strong) return s; own size_t *t = malloc(sizeof *t); if (!t) abort(); *t = *u->slot; b->strong++; s.slot = t; s.pool = u->pool; return s; }") :- !.
ccllib_weak_ptr_text(expired, _, _, "int @{W}_expired(const @W *u) { if (!u->slot) return 1; if (u->pool != (size_t)(uintptr_t)@P) abort(); @B *b = @P[*u->slot - 1]; return !b || !b->live; }") :- !.
ccllib_weak_ptr_text(use_count, _, _, "size_t @{W}_use_count(const @W *u) { if (!u->slot) return 0; if (u->pool != (size_t)(uintptr_t)@P) abort(); @B *b = @P[*u->slot - 1]; return b ? b->strong : 0; }") :- !.
ccllib_weak_ptr_text(reset, _, _, "void @{W}_reset(@W *u) { if (!u->slot) return; if (u->pool != (size_t)(uintptr_t)@P) abort(); size_t i = *u->slot; @B *b = @P[i - 1]; free(u->slot); u->slot = 0; if (b) { if (b->weak) b->weak--; if (!b->strong && !b->weak) @P[i - 1] = 0; } }") :- !.
ccllib_weak_ptr_text(swap, _, _, "void @{W}_swap(@W *a, @W *b) { if (a->slot && a->pool != (size_t)(uintptr_t)@P) abort(); if (b->slot && b->pool != (size_t)(uintptr_t)@P) abort(); own size_t *t = a->slot; a->slot = b->slot; b->slot = t; size_t k = a->pool; a->pool = b->pool; b->pool = k; }") :- !.
