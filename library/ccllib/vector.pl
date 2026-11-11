%% ccllib's <vector.pl> (0.274; CCLLIB.md's phase 1a): std::vector for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <vector.pl>
%%   vector<int> v;                 an empty vector; dropped where its scope ends (autodrop)
%%   w := [double; 2.5, -1];        a literal makes one
%%   push_back(v, 7);  v[0] = 9;    a call finds the instance's function by the type of its first argument
%%
%% type_vector/3 gives the instance's type, `vector_int', a struct of a length, a capacity and an own buffer, and its
%% drop. fn_vector/3 gives ONE function of the instance at its first call (ccl_inst_ensure/1 in library(ccl_syntax)),
%% so a unit holds the functions that it calls and no other. The names are std::vector's; where C++ tells two forms by
%% their arguments' types, C tells them by their count (`resize(v, n)' and `resize(v, n, x)' are _resize and _resize3)
%% or by C++23's own names (_insert_range, _append_range, _assign_range), and a place is an index where C++ takes an
%% iterator. What differs from C++:
%%   an element is a value with no pointer in it -- a scalar, an enum, a plain struct of those: a vector of vectors, of
%%     owned pointers or of borrowed ones is refused by name where its type is written, and waits for the owner's rule
%%     on containers of owners (CCLLIB.md's open decision 2);
%%   `w = v' and `f(v)' move, as every object of an instance's type does; clone(v) copies;
%%   at(v, i), v[i], front, back and pop_back stop the program (abort) at an index past the end or on an empty vector,
%%     where C++'s at throws and the others are undefined; a failed allocation stops it too;
%%   pop_back gives the element that it takes away; erase_value and the comparisons compare with `==' and `<';
%%   begin(v), end(v), data(v) and &v[i] are borrows of the buffer, tied to the vector: the safe part refuses their use
%%     after a call that may replace it -- each function that takes the vector not as const: push_back, insert, erase,
%%     resize, reserve, shrink_to_fit, assign, clear, pop_back, swap -- and keeps them over the others, v[i] among
%%     them;
%%   vector<bool> is a vector of bool, one byte an element.
%% The buffer grows by twice (realloc), so n push_backs cost O(n).
type_vector([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(vector, [T], N),
    (   ccl_holds_pointer(T)
    ->  ccl_arg_words([T], [W]), atomic_list_concat(['a vector''s element is a value with no pointer in it, and ', W, ' holds one'], M), ccl_macro_error(M)
    ;   true ),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_vector(Name, [T], Items) :-
    ccllib_vector_fn(Name, Text), ccl_instance_name(vector, [T], N),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
%% a function's C text by its name; a text calls another function by its full name, `@{N}_reserve(v, n)'. A name that
%% begins with `_' is an inner helper's, which no call by name reaches (`@{N}__grow')
%% -- the capacity. __grow makes room for n more elements, by twice the capacity at least
ccllib_vector_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_vector_fn(len, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_vector_fn(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_vector_fn(capacity, "size_t @{N}_capacity(const @N *v) { return v->cap; }").
ccllib_vector_fn(max_size, "size_t @{N}_max_size(const @N *v) { return (size_t)-1 / 2 / sizeof(@T); }").
ccllib_vector_fn(reserve, "void @{N}_reserve(@N *v, size_t n) {
    if (n <= v->cap) return;
    if (n > (size_t)-1 / 2 / sizeof(@T)) abort();
    v->data = (@T *)realloc(v->data, n * sizeof(@T));
    if (!v->data) abort();
    v->cap = n;
}").
ccllib_vector_fn('_grow', "static void @{N}__grow(@N *v, size_t n) {
    size_t need = v->len + n, c = v->cap ? 2 * v->cap : 4;
    if (need < n) abort();
    @{N}_reserve(v, c < need ? need : c);
}").
ccllib_vector_fn(shrink_to_fit, "void @{N}_shrink_to_fit(@N *v) {
    if (v->len == v->cap) return;
    if (v->len == 0) { free(v->data); v->data = 0; v->cap = 0; return; }
    v->data = (@T *)realloc(v->data, v->len * sizeof(@T));
    if (!v->data) abort();
    v->cap = v->len;
}").
%% -- the elements
ccllib_vector_fn(at, "@T @{N}_at(const @N *v, size_t i) { if (i >= v->len) abort(); return v->data[i]; }").
ccllib_vector_fn(index, "@T *@{N}_index(const @N *v, size_t i) tie v { if (i >= v->len) abort(); return &v->data[i]; }").
ccllib_vector_fn(front, "@T @{N}_front(const @N *v) { if (v->len == 0) abort(); return v->data[0]; }").
ccllib_vector_fn(back, "@T @{N}_back(const @N *v) { if (v->len == 0) abort(); return v->data[v->len - 1]; }").
ccllib_vector_fn(data, "@T *@{N}_data(const @N *v) tie v { return v->data; }").
ccllib_vector_fn(begin, "@T *@{N}_begin(const @N *v) tie v { return v->data; }").
ccllib_vector_fn(end, "@T *@{N}_end(const @N *v) tie v { return v->data + v->len; }").
%% -- the modifiers
ccllib_vector_fn(push_back, "void @{N}_push_back(@N *v, @T x) {
    if (v->len == v->cap) @{N}__grow(v, 1);
    v->data[v->len++] = x;
}").
ccllib_vector_fn(push, "void @{N}_push(@N *v, @T x) { @{N}_push_back(v, x); }").
ccllib_vector_fn(emplace_back, "void @{N}_emplace_back(@N *v, @T x) { @{N}_push_back(v, x); }").
ccllib_vector_fn(pop_back, "@T @{N}_pop_back(@N *v) { if (v->len == 0) abort(); return v->data[--v->len]; }").
ccllib_vector_fn(pop, "@T @{N}_pop(@N *v) { return @{N}_pop_back(v); }").
ccllib_vector_fn(clear, "void @{N}_clear(@N *v) { v->len = 0; }").
ccllib_vector_fn(insert4, "void @{N}_insert4(@N *v, size_t i, size_t n, @T x) {
    if (i > v->len) abort();
    if (n > v->cap - v->len) @{N}__grow(v, n);
    memmove(v->data + i + n, v->data + i, (v->len - i) * sizeof(@T));
    for (size_t k = 0; k < n; k++) v->data[i + k] = x;
    v->len += n;
}").
ccllib_vector_fn(insert, "void @{N}_insert(@N *v, size_t i, @T x) { @{N}_insert4(v, i, 1, x); }").
ccllib_vector_fn(emplace, "void @{N}_emplace(@N *v, size_t i, @T x) { @{N}_insert4(v, i, 1, x); }").
ccllib_vector_fn(insert_range, "void @{N}_insert_range(@N *v, size_t i, const @T *a, size_t n) {
    if (i > v->len) abort();
    if (n > v->cap - v->len) @{N}__grow(v, n);
    memmove(v->data + i + n, v->data + i, (v->len - i) * sizeof(@T));
    for (size_t k = 0; k < n; k++) v->data[i + k] = a[k];
    v->len += n;
}").
ccllib_vector_fn(append_range, "void @{N}_append_range(@N *v, const @T *a, size_t n) { @{N}_insert_range(v, v->len, a, n); }").
ccllib_vector_fn(erase3, "void @{N}_erase3(@N *v, size_t i, size_t j) {
    if (i > j || j > v->len) abort();
    memmove(v->data + i, v->data + j, (v->len - j) * sizeof(@T));
    v->len -= j - i;
}").
ccllib_vector_fn(erase, "void @{N}_erase(@N *v, size_t i) { if (i >= v->len) abort(); @{N}_erase3(v, i, i + 1); }").
ccllib_vector_fn(erase_value, "size_t @{N}_erase_value(@N *v, @T x) {
    size_t k = 0;
    for (size_t i = 0; i < v->len; i++) if (!(v->data[i] == x)) v->data[k++] = v->data[i];
    size_t n = v->len - k;
    v->len = k;
    return n;
}").
ccllib_vector_fn(resize3, "void @{N}_resize3(@N *v, size_t n, @T x) {
    if (n > v->cap) @{N}__grow(v, n - v->len);
    for (size_t i = v->len; i < n; i++) v->data[i] = x;
    v->len = n;
}").
ccllib_vector_fn(resize, "void @{N}_resize(@N *v, size_t n) {
    if (n > v->cap) @{N}__grow(v, n - v->len);
    if (n > v->len) memset(v->data + v->len, 0, (n - v->len) * sizeof(@T));
    v->len = n;
}").
ccllib_vector_fn(assign, "void @{N}_assign(@N *v, size_t n, @T x) { v->len = 0; @{N}_resize3(v, n, x); }").
ccllib_vector_fn(assign_range, "void @{N}_assign_range(@N *v, const @T *a, size_t n) { v->len = 0; @{N}_insert_range(v, 0, a, n); }").
ccllib_vector_fn(swap, "void @{N}_swap(@N *a, @N *b) {
    size_t n = a->len, c = a->cap;
    a->len = b->len; a->cap = b->cap;
    b->len = n; b->cap = c;
    own @T *d = a->data;
    a->data = b->data;
    b->data = d;
}").
%% -- a value of an array, which a literal calls; a copy; the comparisons that the operators call
ccllib_vector_fn(from, "@N @{N}_from(const @T *a, size_t n) { @N v = {0}; @{N}_insert_range(&v, 0, a, n); return v; }").
ccllib_vector_fn(clone, "@N @{N}_clone(const @N *v) { @N w = {0}; @{N}_insert_range(&w, 0, v->data, v->len); return w; }").
ccllib_vector_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    if (a->len != b->len) return 0;
    for (size_t i = 0; i < a->len; i++) if (!(a->data[i] == b->data[i])) return 0;
    return 1;
}").
ccllib_vector_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    size_t n = a->len < b->len ? a->len : b->len;
    for (size_t i = 0; i < n; i++) {
        if (a->data[i] < b->data[i]) return 1;
        if (b->data[i] < a->data[i]) return 0;
    }
    return a->len < b->len;
}").
