%% OPERATORS ON INSTANCES (0.266; CCLLIB.md's phase 0.9): an instance's functions named for its operators, which the
%% reader writes its operators as. pt<T>: a point, + and - by value (so that they chain), == and < by address
type_pt([T], base([], [typedef(N)]), Items) :- ccl_instance_name(pt, [T], N),
    ccl_c_items("typedef struct @N { @T x, y; } @N;
@N @{N}_add(@N a, @N b) { @N r = { a.x + b.x, a.y + b.y }; return r; }
@N @{N}_sub(@N a, @N b) { @N r = { a.x - b.x, a.y - b.y }; return r; }
int @{N}_eq(const @N *a, const @N *b) { return a->x == b->x && a->y == b->y; }
int @{N}_lt(const @N *a, const @N *b) { return a->x < b->x || (a->x == b->x && a->y < b->y); }", ['N' = name(N), 'T' = type(T)], Items).
%% ring<T, K>: K elements from a head, r[i] the element i places after it
type_ring([T, int(K)], base([], [typedef(N)]), Items) :- ccl_instance_name(ring, [T, K], N), atom_number(KA, K),
    ccl_c_items("typedef struct @N { size_t head; @T a[@k]; } @N;
@T *@{N}_index(@N *r, size_t i) tie r { return &r->a[(r->head + i) % @k]; }", ['N' = name(N), 'T' = type(T), k = name(KA)], Items).
%% tbuf<char>: text, << writes a string, an int or a double into it and answers it, so that << chains; >> reads an int;
%% s + t a new text, s's and then t's. A string literal is `char *' in C and `const char *' in C++ ([lex.string]/10), so
%% << takes both (0.270): cicilang++ builds this file's operators.c
type_tbuf([T], base([], [typedef(N)]), Items) :- ccl_instance_name(tbuf, [T], N),
    ccl_c_items("typedef struct @N { size_t len, cap, at; own @T *data; } @N;
static void @{N}_put(@N *b, const char *s) {
    size_t n = strlen(s);
    if (b->len + n + 1 > b->cap) { b->cap = 2 * (b->len + n + 1); b->data = (@T *)realloc(b->data, b->cap); }
    memcpy(b->data + b->len, s, n + 1); b->len += n;
}
@N *@{N}_shl_ptr_char(@N *b, char *s) { @{N}_put(b, s); return b; }
@N *@{N}_shl_ptr_const_char(@N *b, const char *s) { @{N}_put(b, s); return b; }
@N *@{N}_shl_int(@N *b, int x) { char t[32]; snprintf(t, sizeof t, \"%d\", x); @{N}_put(b, t); return b; }
@N *@{N}_shl_double(@N *b, double x) { char t[64]; snprintf(t, sizeof t, \"%g\", x); @{N}_put(b, t); return b; }
@N *@{N}_shr_int(@N *b, int *x) {
    int v = 0;
    while (b->at < b->len && b->data[b->at] == ' ') b->at++;
    while (b->at < b->len && b->data[b->at] >= '0' && b->data[b->at] <= '9') v = 10 * v + (b->data[b->at++] - '0');
    *x = v; return b;
}
const char *@{N}_str(const @N *b) { return b->len ? b->data : \"\"; }
@N @{N}_add(const @N *a, const @N *b) { @N r = {0}; @{N}_put(&r, @{N}_str(a)); @{N}_put(&r, @{N}_str(b)); return r; }
void @{N}_drop(@N *b) { free(b->data); }", ['N' = name(N), 'T' = type(T)], Items).
%% dict<K, V>: m[k] the value of the key k, a new key's value zero, as std::map's [] makes it
type_dict([K, V], base([], [typedef(N)]), Items) :- ccl_instance_name(dict, [K, V], N),
    ccl_c_items("typedef struct @N { size_t len, cap; own @K *keys; own @V *vals; } @N;
@V *@{N}_index(@N *m, @K k) tie m {
    for (size_t i = 0; i < m->len; i++) if (m->keys[i] == k) return &m->vals[i];
    if (m->len == m->cap) { m->cap = m->cap ? 2 * m->cap : 4; m->keys = (@K *)realloc(m->keys, m->cap * sizeof(@K)); m->vals = (@V *)realloc(m->vals, m->cap * sizeof(@V)); }
    m->keys[m->len] = k; m->vals[m->len] = 0; return &m->vals[m->len++];
}
size_t @{N}_size(const @N *m) { return m->len; }
void @{N}_drop(@N *m) { free(m->keys); free(m->vals); }", ['N' = name(N), 'K' = type(K), 'V' = type(V)], Items).
