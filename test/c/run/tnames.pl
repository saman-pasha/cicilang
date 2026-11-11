%% CALLS BY NAME TOLD BY AN ARGUMENT'S TYPE (0.288): text<T>, a buffer of characters with a NUL after them. Its
%% functions are made at their first call (fn_text/3 over text_fn/2). A name with a type's word after it is the form
%% for an argument of that type: `_append' takes a text, `_append_ptr_const_char' a C string -- C's literal, a `char
%% *', asks the pointer to const's name too --, `_append3' a count and a character, `_append3_ptr_const_char' a C
%% string and a count; `_insert_ptr_const_char' is told by its THIRD argument; `_find_int' takes C's character
%% constant and `_find_char' a char object and C++'s constant
type_text([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(text, [T], N),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_text(Name, [T], Items) :-
    text_fn(Name, Text), ccl_instance_name(text, [T], N), ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
text_fn('_put', "static void @{N}__put(@N *v, size_t at, const @T *p, size_t n) {
    if (v->len + n + 1 > v->cap) {
        v->cap = 2 * (v->len + n + 1);
        v->data = (@T *)realloc(v->data, v->cap * sizeof(@T));
        if (!v->data) abort();
    }
    memmove(v->data + at + n, v->data + at, (v->len - at) * sizeof(@T));
    memcpy(v->data + at, p, n * sizeof(@T));
    v->len += n;
    v->data[v->len] = 0;
}").
text_fn(c_str, "const @T *@{N}_c_str(const @N *v) tie v { return v->data ? v->data : \"\"; }").
text_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
text_fn(of_ptr_const_char, "@N @{N}_of_ptr_const_char(const char *s) {
    @N r = {0};
    @{N}__put(&r, 0, s, strlen(s));
    return r;
}").
text_fn(append, "void @{N}_append(@N *v, const @N *t) { @{N}__put(v, v->len, t->data, t->len); }").
text_fn(append_ptr_const_char, "void @{N}_append_ptr_const_char(@N *v, const char *s) {
    @{N}__put(v, v->len, s, strlen(s));
}").
text_fn(append3, "void @{N}_append3(@N *v, size_t n, @T c) {
    for (size_t i = 0; i < n; i++) @{N}__put(v, v->len, &c, 1);
}").
text_fn(append3_ptr_const_char, "void @{N}_append3_ptr_const_char(@N *v, const char *s, size_t n) {
    @{N}__put(v, v->len, s, n);
}").
text_fn(insert, "void @{N}_insert(@N *v, size_t at, const @N *t) {
    if (at > v->len) abort();
    @{N}__put(v, at, t->data, t->len);
}").
text_fn(insert_ptr_const_char, "void @{N}_insert_ptr_const_char(@N *v, size_t at, const char *s) {
    if (at > v->len) abort();
    @{N}__put(v, at, s, strlen(s));
}").
text_fn('_find', "static long @{N}__find(const @N *v, const @T *p, size_t n) {
    for (size_t i = 0; i + n <= v->len; i++) if (memcmp(v->data + i, p, n * sizeof(@T)) == 0) return (long)i;
    return -1;
}").
text_fn(find, "long @{N}_find(const @N *v, const @N *t) { return @{N}__find(v, t->data, t->len); }").
text_fn(find_ptr_const_char, "long @{N}_find_ptr_const_char(const @N *v, const char *s) {
    return @{N}__find(v, s, strlen(s));
}").
text_fn(find_int, "long @{N}_find_int(const @N *v, int c) { @T x = (@T)c; return @{N}__find(v, &x, 1); }").
text_fn(find_char, "long @{N}_find_char(const @N *v, char c) { return @{N}__find(v, &c, 1); }").
text_fn(add_assign, "void @{N}_add_assign(@N *v, const @N *t) { @{N}__put(v, v->len, t->data, t->len); }").
text_fn(add_assign_ptr_const_char, "void @{N}_add_assign_ptr_const_char(@N *v, const char *s) {
    @{N}__put(v, v->len, s, strlen(s));
}").
text_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    return a->len == b->len && (a->len == 0 || memcmp(a->data, b->data, a->len) == 0);
}").
text_fn(eq_ptr_const_char, "int @{N}_eq_ptr_const_char(const @N *a, const char *s) {
    return strlen(s) == a->len && (a->len == 0 || memcmp(a->data, s, a->len) == 0);
}").
