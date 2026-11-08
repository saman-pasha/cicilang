%% C TEXT (0.260; CCLLIB.md's phase 0.1): macros that write C with holes, which the reader reads with its own grammar
%% in the read that runs. vec_of(0); at file scope: a vector of the argument's type, its struct and two functions; a
%% type hole joins the qualifiers before it (own, const), a name hole is pasted into a name (@{N}_push)
vec_of(X, Items) :-
    ccl_type_of(X, T), T = base(_, [W]), atom_concat(vec_, W, N),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
static void @{N}_push(@N *v, @T x) {
    if (v->len == v->cap) { v->cap = v->cap ? 2 * v->cap : 4; v->data = realloc(v->data, v->cap * sizeof(@T)); }
    v->data[v->len++] = x;   /* @T in a comment is no hole */
}
static @T @{N}_at(const @N *v, size_t i) { return v->data[i]; }", ['N' = name(N), 'T' = type(T)], Items).
%% an expression; a block whose temporary is a fresh name; a statement hole; a text that calls a macro
twice(X, E) :- ccl_c_expr("(@x) * 2", [x = expr(X)], E).
swap_any(A, B, S) :- ccl_type_of(A, T), ccl_gensym(t, Tmp),
    ccl_c_stmts("{ @T @tmp = @a; @a = @b; @b = @tmp; }", ['T' = type(T), tmp = name(Tmp), a = expr(A), b = expr(B)], S).
repeat2(E, S) :- ccl_c_stmts("{ @s; @s; }", [s = stmt(expr(E))], S).
quad(X, E) :- ccl_c_expr("twice(twice(@x))", [x = expr(X)], E).
