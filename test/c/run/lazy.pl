%% AN INSTANCE'S FUNCTIONS MADE AT THEIR FIRST CALL (0.274; CCLLIB.md's phase 1a): stack<T>. type_stack/3 gives the
%% instance's type and its drop; fn_stack/3 gives ONE function of the instance, which the reader asks for when the unit
%% first calls it (ccl_inst_ensure/1) -- by its own name over an object or a pointer (`push(s, 5)'), by its full name
%% (`stack_int_push(&s, 9)'), from another function's text (`@{N}__room'), by an operator (`s[0]', `s == c'), by a
%% literal (`_from') or by clone -- so the unit holds what it calls and no other. `fill(s, x)' and `fill(s, n, x)' are
%% two functions, told by the count of the arguments: _fill and _fill3. A name that begins with `_' is an inner
%% helper's, which no call by name reaches (`_room'). No macro here is named as a call is
type_stack([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(stack, [T], N),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
void @{N}_drop(@N *s) { free(s->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_stack(Name, [T], Items) :- stack_fn(Name, Text), ccl_instance_name(stack, [T], N), ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
stack_fn('_room', "static void @{N}__room(@N *s, size_t n) {
    if (n > s->cap) { s->data = (@T *)realloc(s->data, n * sizeof(@T)); s->cap = n; }
}").
stack_fn(push, "void @{N}_push(@N *s, @T x) { if (s->len == s->cap) @{N}__room(s, s->cap ? 2 * s->cap : 4); s->data[s->len++] = x; }").
stack_fn(pop, "@T @{N}_pop(@N *s) { return s->data[--s->len]; }").
stack_fn(size, "size_t @{N}_size(const @N *s) { return s->len; }").
stack_fn(top, "@T *@{N}_top(const @N *s) tie s { return &s->data[s->len - 1]; }").
stack_fn(fill, "void @{N}_fill(@N *s, @T x) { for (size_t i = 0; i < s->len; i++) s->data[i] = x; }").
stack_fn(fill3, "void @{N}_fill3(@N *s, size_t n, @T x) { @{N}__room(s, n); for (size_t i = 0; i < n; i++) s->data[i] = x; s->len = n; }").
stack_fn(never, "void @{N}_never(@N *s) { s->len = 0; }").
stack_fn(index, "@T *@{N}_index(const @N *s, size_t i) tie s { return &s->data[i]; }").
stack_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    if (a->len != b->len) return 0;
    for (size_t i = 0; i < a->len; i++) if (a->data[i] != b->data[i]) return 0;
    return 1;
}").
stack_fn(clone, "@N @{N}_clone(const @N *s) { @N c = {0}; for (size_t i = 0; i < s->len; i++) @{N}_push(&c, s->data[i]); return c; }").
stack_fn(from, "@N @{N}_from(const @T *a, size_t n) { @N s = {0}; for (size_t i = 0; i < n; i++) @{N}_push(&s, a[i]); return s; }").
