%% LIST AND MAP LITERALS (0.263; CCLLIB.md's phase 0.6): map<K, V>, beside tvector.pl's vector<T>, with its <name>_from --
%% the function that a key: value literal calls, over the compound literals of its keys and of its values -- and its
%% drop. It keeps the first value of a key, as std::map's insert does. (A macro file's predicates are the process's: a
%% name that tvector.pl defines is not defined here again.)
type_map([K, V], base([], [typedef(N)]), Items) :-
    ccl_instance_name(map, [K, V], N),
    ccl_c_items("typedef struct @N { size_t len, cap; own @K *keys; own @V *vals; } @N;
void @{N}_put(@N *m, @K k, @V v) {
    for (size_t i = 0; i < m->len; i++) if (m->keys[i] == k) return;
    if (m->len == m->cap) { m->cap = m->cap ? 2 * m->cap : 4; m->keys = realloc(m->keys, m->cap * sizeof(@K)); m->vals = realloc(m->vals, m->cap * sizeof(@V)); }
    m->keys[m->len] = k; m->vals[m->len++] = v;
}
@N @{N}_from(const @K *k, const @V *v, size_t n) { @N m = {0}; for (size_t i = 0; i < n; i++) @{N}_put(&m, k[i], v[i]); return m; }
@V @{N}_get(const @N *m, @K k) { for (size_t i = 0; i < m->len; i++) if (m->keys[i] == k) return m->vals[i]; return m->vals[0]; }
size_t @{N}_size(const @N *m) { return m->len; }
void @{N}_drop(@N *m) { free(m->keys); free(m->vals); }", ['N' = name(N), 'K' = type(K), 'V' = type(V)], Items).
get(M, K, call(id(F), [addr(M), K])) :- map_name(M, N), atom_concat(N, '_get', F).
size(M, call(id(F), [addr(M)])) :- map_name(M, N), atom_concat(N, '_size', F).
map_name(M, N) :- ccl_type_of(M, base(_, [typedef(N)])).
