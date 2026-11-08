%% TYPE MACROS (0.261; CCLLIB.md's phases 0.2 to 0.4): vector<T> in C. The instance -- a struct and its functions, read
%% from C text -- is made once in the unit, at its first use, and stands at file scope before the item that used it;
%% push, at and len find their instance by their argument's type
type_vector([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(vector, [T], N),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
void @{N}_push(@N *v, @T x) {
    if (v->len == v->cap) { v->cap = v->cap ? 2 * v->cap : 4; v->data = realloc(v->data, v->cap * sizeof(@T)); }
    v->data[v->len++] = x;
}
@T @{N}_at(const @N *v, size_t i) { return v->data[i]; }
size_t @{N}_len(const @N *v) { return v->len; }", ['N' = name(N), 'T' = type(T)], Items).
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
