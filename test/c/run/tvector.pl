%% TYPE MACROS (0.261; CCLLIB.md's phases 0.2 to 0.4): vector<T> in C. The instance -- a struct and its functions, read
%% from C text -- is made once in the unit, at its first use, and stands at file scope before the item that used it;
%% push, at and len find their instance by their argument's type. Its drop frees the buffer: each vector is dropped
%% where its scope ends (autodrop, 0.262; CCLLIB.md's phase 0.5); its from makes it of an array, which a list literal
%% calls (0.263; phase 0.6)
type_vector([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(vector, [T], N),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
void @{N}_push(@N *v, @T x) {
    if (v->len == v->cap) { v->cap = v->cap ? 2 * v->cap : 4; v->data = (@T *)realloc(v->data, v->cap * sizeof(@T)); }
    v->data[v->len++] = x;
}
@T @{N}_at(const @N *v, size_t i) { return v->data[i]; }
size_t @{N}_len(const @N *v) { return v->len; }
void @{N}_drop(@N *v) { free(v->data); }
@N @{N}_from(const @T *a, size_t n) { @N v = {0}; for (size_t i = 0; i < n; i++) @{N}_push(&v, a[i]); return v; }", ['N' = name(N), 'T' = type(T)], Items).
push(V, X, call(id(F), [addr(V), X])) :- vec_name(V, N), atom_concat(N, '_push', F).
at(V, I, call(id(F), [addr(V), I])) :- vec_name(V, N), atom_concat(N, '_at', F).
len(V, call(id(F), [addr(V)])) :- vec_name(V, N), atom_concat(N, '_len', F).
vec_name(V, N) :- ccl_type_of(V, base(_, [typedef(N)])).
%% a value argument: inplace<T, K>, a buffer of K elements
type_inplace([T, int(K)], base([], [typedef(N)]), Items) :-
    ccl_instance_name(inplace, [T, K], N), atom_number(KA, K),
    ccl_c_items("typedef struct @N { size_t len; @T a[@k]; } @N;", ['N' = name(N), 'T' = type(T), k = name(KA)], Items).
%% explicit types for a function macro: max<double>(a, b) compares and gives both as double
max(types([T]), A, B, cond(bin('>', cast(T, A), cast(T, B)), cast(T, A), cast(T, B))).
max(A, B, cond(bin('>', A, B), A, B)).
