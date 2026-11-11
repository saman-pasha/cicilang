%% ccllib's <deque.pl> (0.276; CCLLIB.md's phase 1a): std::deque for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <deque.pl>
%%   deque<int> d;                  an empty deque; dropped where its scope ends (autodrop)
%%   push_back(d, 7);  push_front(d, 3);  d[0] = 9;  x := pop_front(d);
%%
%% type_deque/3 gives the instance's type, `deque_int', a struct of a length, a capacity, a head and an own buffer, and
%% its drop. The buffer is a RING: its capacity is a power of two, the element at the place i is
%% data[(head + i) & (cap - 1)], so each end takes and gives an element in constant time and d[i] is one mask away.
%% fn_deque/3 gives ONE function of the instance at its first call. The names are std::deque's, in the forms of
%% <vector.pl>: a place is an index, the count of the arguments tells two forms of a name apart (_insert and _insert4,
%% _erase and _erase3, _resize and _resize3), and a range is a pointer and a count (C++23's _insert_range,
%% _append_range, _prepend_range, _assign_range). What differs from C++:
%%   an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2);
%%   `w = d' and `f(d)' move, as every object of an instance's type does; clone(d) copies;
%%   at(d, i), d[i], front, back, pop_back and pop_front stop the program (abort) past the end or on an empty deque, and
%%     a failed allocation stops it too; pop_back and pop_front give the element that they take away;
%%   &d[i] is a borrow of the buffer, tied to the deque, which each function that takes the deque not as const ends.
%%     C++ keeps a reference to an element over a push at an end; a ring moves its elements when it grows;
%%   there is no begin, end or data: a ring is not one run of memory, and a loop goes by the index;
%%   insert and erase move the elements of the nearer end, as C++'s do.
:- ensure_loaded(library(ccllib/ccllib)).
type_deque([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(deque, [T], N), ccllib_plain_element('a deque''s element', T),
    ccl_c_items("typedef struct @N { size_t len, cap, head; own @T *data; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_deque(Name, [T], Items) :-
    ccllib_deque_fn(Name, Text), ccl_instance_name(deque, [T], N),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
%% a function's C text by its name
%% -- the capacity. __grow makes room for n more elements: the ring grows in its place (realloc), and the part of it
%%    that went round the old end is put after it
ccllib_deque_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_deque_fn(len, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_deque_fn(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_deque_fn(max_size, "size_t @{N}_max_size(const @N *v) { return (size_t)-1 / 2 / sizeof(@T); }").
ccllib_deque_fn('_grow', "static void @{N}__grow(@N *v, size_t n) {
    size_t need = v->len + n, c = v->cap ? v->cap : 8;
    if (need < n || need > (size_t)-1 / 2 / sizeof(@T)) abort();
    while (c < need) c *= 2;
    if (c == v->cap) return;
    v->data = (@T *)realloc(v->data, c * sizeof(@T));
    if (!v->data) abort();
    if (v->head + v->len > v->cap) memcpy(v->data + v->cap, v->data, (v->head + v->len - v->cap) * sizeof(@T));
    v->cap = c;
}").
ccllib_deque_fn(shrink_to_fit, "void @{N}_shrink_to_fit(@N *v) {
    size_t c = 8;
    if (v->len == 0) { free(v->data); v->data = 0; v->cap = 0; v->head = 0; return; }
    while (c < v->len) c *= 2;
    if (c >= v->cap) return;
    own @T *d = (@T *)malloc(c * sizeof(@T));
    if (!d) abort();
    for (size_t i = 0; i < v->len; i++) d[i] = v->data[(v->head + i) & (v->cap - 1)];
    free(v->data);
    v->data = d;
    v->cap = c;
    v->head = 0;
}").
%% -- the elements
ccllib_deque_fn(at, "@T @{N}_at(const @N *v, size_t i) { if (i >= v->len) abort(); return v->data[(v->head + i) & (v->cap - 1)]; }").
ccllib_deque_fn(index, "@T *@{N}_index(const @N *v, size_t i) tie v { if (i >= v->len) abort(); return &v->data[(v->head + i) & (v->cap - 1)]; }").
ccllib_deque_fn(front, "@T @{N}_front(const @N *v) { if (v->len == 0) abort(); return v->data[v->head]; }").
ccllib_deque_fn(back, "@T @{N}_back(const @N *v) { if (v->len == 0) abort(); return v->data[(v->head + v->len - 1) & (v->cap - 1)]; }").
%% -- the modifiers at the ends
ccllib_deque_fn(push_back, "void @{N}_push_back(@N *v, @T x) {
    if (v->len == v->cap) @{N}__grow(v, 1);
    v->data[(v->head + v->len) & (v->cap - 1)] = x;
    v->len++;
}").
ccllib_deque_fn(push, "void @{N}_push(@N *v, @T x) { @{N}_push_back(v, x); }").
ccllib_deque_fn(emplace_back, "void @{N}_emplace_back(@N *v, @T x) { @{N}_push_back(v, x); }").
ccllib_deque_fn(push_front, "void @{N}_push_front(@N *v, @T x) {
    if (v->len == v->cap) @{N}__grow(v, 1);
    v->head = (v->head + v->cap - 1) & (v->cap - 1);
    v->data[v->head] = x;
    v->len++;
}").
ccllib_deque_fn(emplace_front, "void @{N}_emplace_front(@N *v, @T x) { @{N}_push_front(v, x); }").
ccllib_deque_fn(pop_back, "@T @{N}_pop_back(@N *v) {
    if (v->len == 0) abort();
    v->len--;
    return v->data[(v->head + v->len) & (v->cap - 1)];
}").
ccllib_deque_fn(pop, "@T @{N}_pop(@N *v) { return @{N}_pop_back(v); }").
ccllib_deque_fn(pop_front, "@T @{N}_pop_front(@N *v) {
    if (v->len == 0) abort();
    @T x = v->data[v->head];
    v->head = (v->head + 1) & (v->cap - 1);
    v->len--;
    return x;
}").
ccllib_deque_fn(clear, "void @{N}_clear(@N *v) { v->len = 0; v->head = 0; }").
%% -- the modifiers at a place. __open makes n places at the place i, by a move of the elements of the nearer end
ccllib_deque_fn('_open', "static void @{N}__open(@N *v, size_t i, size_t n) {
    if (i > v->len) abort();
    if (n > v->cap - v->len) @{N}__grow(v, n);
    size_t m = v->cap - 1;
    if (i < v->len - i) {
        size_t h = (v->head + v->cap - n) & m;
        for (size_t k = 0; k < i; k++) v->data[(h + k) & m] = v->data[(v->head + k) & m];
        v->head = h;
    } else
        for (size_t k = v->len; k > i; k--) v->data[(v->head + k - 1 + n) & m] = v->data[(v->head + k - 1) & m];
    v->len += n;
}").
ccllib_deque_fn(insert4, "void @{N}_insert4(@N *v, size_t i, size_t n, @T x) {
    @{N}__open(v, i, n);
    for (size_t k = 0; k < n; k++) v->data[(v->head + i + k) & (v->cap - 1)] = x;
}").
ccllib_deque_fn(insert, "void @{N}_insert(@N *v, size_t i, @T x) { @{N}_insert4(v, i, 1, x); }").
ccllib_deque_fn(emplace, "void @{N}_emplace(@N *v, size_t i, @T x) { @{N}_insert4(v, i, 1, x); }").
ccllib_deque_fn(insert_range, "void @{N}_insert_range(@N *v, size_t i, const @T *a, size_t n) {
    @{N}__open(v, i, n);
    for (size_t k = 0; k < n; k++) v->data[(v->head + i + k) & (v->cap - 1)] = a[k];
}").
ccllib_deque_fn(append_range, "void @{N}_append_range(@N *v, const @T *a, size_t n) { @{N}_insert_range(v, v->len, a, n); }").
ccllib_deque_fn(prepend_range, "void @{N}_prepend_range(@N *v, const @T *a, size_t n) { @{N}_insert_range(v, 0, a, n); }").
ccllib_deque_fn(erase3, "void @{N}_erase3(@N *v, size_t i, size_t j) {
    if (i > j || j > v->len) abort();
    size_t m = v->cap - 1, n = j - i;
    if (i < v->len - j) {
        for (size_t k = i; k > 0; k--) v->data[(v->head + k - 1 + n) & m] = v->data[(v->head + k - 1) & m];
        v->head = (v->head + n) & m;
    } else
        for (size_t k = j; k < v->len; k++) v->data[(v->head + k - n) & m] = v->data[(v->head + k) & m];
    v->len -= n;
}").
ccllib_deque_fn(erase, "void @{N}_erase(@N *v, size_t i) { if (i >= v->len) abort(); @{N}_erase3(v, i, i + 1); }").
ccllib_deque_fn(erase_value, "size_t @{N}_erase_value(@N *v, @T x) {
    size_t k = 0, m = v->cap - 1;
    for (size_t i = 0; i < v->len; i++) {
        @T e = v->data[(v->head + i) & m];
        if (!(e == x)) { v->data[(v->head + k) & m] = e; k++; }
    }
    size_t n = v->len - k;
    v->len = k;
    return n;
}").
ccllib_deque_fn(resize3, "void @{N}_resize3(@N *v, size_t n, @T x) {
    if (n > v->cap) @{N}__grow(v, n - v->len);
    for (size_t i = v->len; i < n; i++) v->data[(v->head + i) & (v->cap - 1)] = x;
    v->len = n;
}").
ccllib_deque_fn(resize, "void @{N}_resize(@N *v, size_t n) {
    @T z;
    memset(&z, 0, sizeof z);
    @{N}_resize3(v, n, z);
}").
ccllib_deque_fn(assign, "void @{N}_assign(@N *v, size_t n, @T x) { v->len = 0; v->head = 0; @{N}_resize3(v, n, x); }").
ccllib_deque_fn(assign_range, "void @{N}_assign_range(@N *v, const @T *a, size_t n) { v->len = 0; v->head = 0; @{N}_insert_range(v, 0, a, n); }").
ccllib_deque_fn(swap, "void @{N}_swap(@N *a, @N *b) {
    size_t n = a->len, c = a->cap, h = a->head;
    a->len = b->len; a->cap = b->cap; a->head = b->head;
    b->len = n; b->cap = c; b->head = h;
    own @T *d = a->data;
    a->data = b->data;
    b->data = d;
}").
%% -- a value of an array, which a literal calls; a copy; the comparisons that the operators call
ccllib_deque_fn(from, "@N @{N}_from(const @T *a, size_t n) { @N v = {0}; @{N}_insert_range(&v, 0, a, n); return v; }").
ccllib_deque_fn(clone, "@N @{N}_clone(const @N *v) {
    @N w = {0};
    if (v->len) @{N}__grow(&w, v->len);
    for (size_t i = 0; i < v->len; i++) w.data[i] = v->data[(v->head + i) & (v->cap - 1)];
    w.len = v->len;
    return w;
}").
ccllib_deque_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    if (a->len != b->len) return 0;
    for (size_t i = 0; i < a->len; i++)
        if (!(a->data[(a->head + i) & (a->cap - 1)] == b->data[(b->head + i) & (b->cap - 1)])) return 0;
    return 1;
}").
ccllib_deque_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    size_t n = a->len < b->len ? a->len : b->len;
    for (size_t i = 0; i < n; i++) {
        @T x = a->data[(a->head + i) & (a->cap - 1)];
        @T y = b->data[(b->head + i) & (b->cap - 1)];
        if (x < y) return 1;
        if (y < x) return 0;
    }
    return a->len < b->len;
}").
