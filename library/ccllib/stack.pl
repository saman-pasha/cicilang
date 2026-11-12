%% ccllib's <stack.pl> (0.280; CCLLIB.md's phase 1a): std::stack for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <stack.pl>
%%   stack<int> s;                  an empty stack; dropped where its scope ends (autodrop)
%%   push(s, 7);  x := top(s);  y := pop(s);
%%
%% type_stack/3 gives the instance's type, `stack_int', a struct of a length, a capacity and an own buffer that grows
%% by twice, and its drop; fn_stack/3 gives ONE function of the instance at its first call. The names are
%% std::stack's. What differs from C++:
%%   a stack is its own buffer and no adaptor over another container: `stack<int, vector<int>>' is not read;
%%   an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2);
%%   `w = s' and `f(s)' move, as every object of an instance's type does; clone(s) copies;
%%   pop gives the element that it takes away, where C++'s gives nothing; top gives the element's value, and no
%%     place to write through; top and pop stop the program (abort) on an empty stack, and a failed allocation
%%     stops it too;
%%   a literal's last element is the top: `stack<int> s = [1, 2, 3];' has 3 on top, as C++23's range constructor.
:- ensure_loaded(library(ccllib/ccllib)).
type_stack([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(stack, [T], N), ccllib_plain_element('a stack''s element', T),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_stack(Name, [T], Items) :-
    ccllib_stack_fn(Name, Text), ccl_instance_name(stack, [T], N),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
%% a function's C text by its name. __grow makes room for n more elements, by twice the capacity at least
ccllib_stack_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_stack_fn(len, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_stack_fn(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_stack_fn(top, "@T @{N}_top(const @N *v) { if (v->len == 0) abort(); return v->data[v->len - 1]; }").
ccllib_stack_fn('_grow', "static void @{N}__grow(@N *v, size_t n) {
    size_t need = v->len + n, c = v->cap ? 2 * v->cap : 4;
    if (need < n) abort();
    if (c < need) c = need;
    if (c > (size_t)-1 / 2 / sizeof(@T)) abort();
    v->data = (@T *)realloc(v->data, c * sizeof(@T));
    if (!v->data) abort();
    v->cap = c;
}").
ccllib_stack_fn(push, "void @{N}_push(@N *v, @T x) {
    if (v->len == v->cap) @{N}__grow(v, 1);
    v->data[v->len++] = x;
}").
ccllib_stack_fn(emplace, "void @{N}_emplace(@N *v, @T x) { @{N}_push(v, x); }").
ccllib_stack_fn(push_range, "void @{N}_push_range(@N *v, const @T *a, size_t n) {
    if (n > v->cap - v->len) @{N}__grow(v, n);
    for (size_t i = 0; i < n; i++) v->data[v->len + i] = a[i];
    v->len += n;
}").
ccllib_stack_fn(pop, "@T @{N}_pop(@N *v) { if (v->len == 0) abort(); return v->data[--v->len]; }").
ccllib_stack_fn(swap, "void @{N}_swap(@N *a, @N *b) {
    size_t n = a->len, c = a->cap;
    a->len = b->len; a->cap = b->cap;
    b->len = n; b->cap = c;
    own @T *d = a->data;
    a->data = b->data;
    b->data = d;
}").
%% -- a value of an array, which a literal calls; a copy; the comparisons that the operators call
ccllib_stack_fn(from, "@N @{N}_from(const @T *a, size_t n) { @N v = {0}; @{N}_push_range(&v, a, n); return v; }").
ccllib_stack_fn(clone, "@N @{N}_clone(const @N *v) { @N w = {0}; @{N}_push_range(&w, v->data, v->len); return w; }").
ccllib_stack_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    if (a->len != b->len) return 0;
    for (size_t i = 0; i < a->len; i++) if (!(a->data[i] == b->data[i])) return 0;
    return 1;
}").
%% THE RELATIONS ARE C++20'S (0.304): the synthesized three-way order of the elements, where a pair that is neither
%% `<' nor `==' either way -- a NaN -- is unordered and ends the comparison, every relation false; `<=' and `>=' are
%% _le and _ge, which the reader asks first
ccllib_stack_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    size_t n = a->len < b->len ? a->len : b->len;
    for (size_t i = 0; i < n; i++) {
        if (a->data[i] < b->data[i]) return 1;
        if (b->data[i] < a->data[i]) return 0;
        if (!(a->data[i] == b->data[i])) return 0;
    }
    return a->len < b->len;
}").
ccllib_stack_fn(le, "int @{N}_le(const @N *a, const @N *b) {
    size_t n = a->len < b->len ? a->len : b->len;
    for (size_t i = 0; i < n; i++) {
        if (a->data[i] < b->data[i]) return 1;
        if (b->data[i] < a->data[i]) return 0;
        if (!(a->data[i] == b->data[i])) return 0;
    }
    return a->len <= b->len;
}").
ccllib_stack_fn(ge, "int @{N}_ge(const @N *a, const @N *b) { return @{N}_le(b, a); }").
