%% ccllib's <queue.pl> (0.280; CCLLIB.md's phase 1a): std::queue and std::priority_queue for cicilang's C, and for
%% cicilang++ beside libc++'s.
%%
%%   #include <queue.pl>
%%   queue<int> q;                  first in, first out: push(q, 7);  x := front(q);  y := pop(q);
%%   priority_queue<int> h;         the greatest first: push(h, 7);  x := top(h);  y := pop(h);
%%   priority_queue<int, later> m;  the order is the function's: `int later(int a, int b)' answers whether a comes
%%                                  out after b, as C++'s comparison type does (std::greater gives the least first)
%%
%% type_queue/3 gives `queue_int', a ring as <deque.pl>'s: a buffer whose capacity is a power of two, with a head.
%% type_priority_queue/3 gives `priority_queue_int', a binary heap in a buffer that grows by twice, and with a
%% comparison's name `priority_queue_int_later': the name is written where C++ writes the comparison's type, and the
%% heap's text calls that function by its name, so no pointer to it is kept or called. fn_queue/3 and
%% fn_priority_queue/3 give ONE function of the instance at its first call. The names are C++'s. What differs from C++:
%%   each is its own buffer and no adaptor over another container: `queue<int, list<int>>' and
%%     `priority_queue<int, vector<int>, greater<int>>' are not read;
%%   an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2);
%%   `w = q' and `f(q)' move, as every object of an instance's type does; clone(q) copies;
%%   pop gives the element that it takes away, where C++'s gives nothing; front, back and top give the element's
%%     value, and no place to write through; they and pop stop the program (abort) on an empty queue, and a failed
%%     allocation stops it too;
%%   the order in which a priority_queue gives elements that its comparison holds for equal is not C++'s to the
%%     letter: neither says which comes first.
:- ensure_loaded(library(ccllib/ccllib)).
type_queue([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(queue, [T], N), ccllib_plain_element('a queue''s element', T),
    ccl_c_items("typedef struct @N { size_t len, cap, head; own @T *data; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_queue(Name, [T], Items) :-
    ccllib_queue_fn(Name, Text), ccl_instance_name(queue, [T], N),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
type_priority_queue(As, base([], [typedef(N)]), Items) :-
    ccllib_pq_args(As, T, N, _), ccllib_plain_element('a priority_queue''s element', T),
    ccl_c_items("typedef struct @N { size_t len, cap; own @T *data; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_priority_queue(Name, As, Items) :-
    ccllib_pq_args(As, T, N, Cmp), ccllib_pq_fn(Name, Cmp, Text),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
%% a priority_queue's arguments: the element's type, and maybe the name of its comparison
ccllib_pq_args([T], T, N, none) :- !, ccl_instance_name(priority_queue, [T], N).
ccllib_pq_args([T, id(F)], T, N, F) :- atom(F), !,
    ccl_instance_name(priority_queue, [T], N0), atomic_list_concat([N0, '_', F], N).
ccllib_pq_args(_, _, _, _) :-
    atom_concat('a priority_queue takes its element''s type, and after it the name of a function that compares two ',
                elements, M),
    ccl_macro_error(M).
%% -- the queue: a function's C text by its name. __grow makes room for n more elements, as the deque's
ccllib_queue_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_queue_fn(len, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_queue_fn(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_queue_fn(front, "@T @{N}_front(const @N *v) { if (v->len == 0) abort(); return v->data[v->head]; }").
ccllib_queue_fn(back, "@T @{N}_back(const @N *v) { if (v->len == 0) abort(); return v->data[(v->head + v->len - 1) & (v->cap - 1)]; }").
ccllib_queue_fn('_grow', "static void @{N}__grow(@N *v, size_t n) {
    size_t need = v->len + n, c = v->cap ? v->cap : 8;
    if (need < n || need > (size_t)-1 / 2 / sizeof(@T)) abort();
    while (c < need) c *= 2;
    if (c == v->cap) return;
    v->data = (@T *)realloc(v->data, c * sizeof(@T));
    if (!v->data) abort();
    if (v->head + v->len > v->cap) memcpy(v->data + v->cap, v->data, (v->head + v->len - v->cap) * sizeof(@T));
    v->cap = c;
}").
ccllib_queue_fn(push, "void @{N}_push(@N *v, @T x) {
    if (v->len == v->cap) @{N}__grow(v, 1);
    v->data[(v->head + v->len) & (v->cap - 1)] = x;
    v->len++;
}").
ccllib_queue_fn(emplace, "void @{N}_emplace(@N *v, @T x) { @{N}_push(v, x); }").
ccllib_queue_fn(push_range, "void @{N}_push_range(@N *v, const @T *a, size_t n) {
    if (n > v->cap - v->len) @{N}__grow(v, n);
    for (size_t i = 0; i < n; i++) v->data[(v->head + v->len + i) & (v->cap - 1)] = a[i];
    v->len += n;
}").
ccllib_queue_fn(pop, "@T @{N}_pop(@N *v) {
    if (v->len == 0) abort();
    @T x = v->data[v->head];
    v->head = (v->head + 1) & (v->cap - 1);
    v->len--;
    return x;
}").
ccllib_queue_fn(swap, "void @{N}_swap(@N *a, @N *b) {
    size_t n = a->len, c = a->cap, h = a->head;
    a->len = b->len; a->cap = b->cap; a->head = b->head;
    b->len = n; b->cap = c; b->head = h;
    own @T *d = a->data;
    a->data = b->data;
    b->data = d;
}").
ccllib_queue_fn(from, "@N @{N}_from(const @T *a, size_t n) { @N v = {0}; @{N}_push_range(&v, a, n); return v; }").
ccllib_queue_fn(clone, "@N @{N}_clone(const @N *v) {
    @N w = {0};
    if (v->len) @{N}__grow(&w, v->len);
    for (size_t i = 0; i < v->len; i++) w.data[i] = v->data[(v->head + i) & (v->cap - 1)];
    w.len = v->len;
    return w;
}").
ccllib_queue_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    if (a->len != b->len) return 0;
    for (size_t i = 0; i < a->len; i++)
        if (!(a->data[(a->head + i) & (a->cap - 1)] == b->data[(b->head + i) & (b->cap - 1)])) return 0;
    return 1;
}").
ccllib_queue_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    size_t n = a->len < b->len ? a->len : b->len;
    for (size_t i = 0; i < n; i++) {
        @T x = a->data[(a->head + i) & (a->cap - 1)];
        @T y = b->data[(b->head + i) & (b->cap - 1)];
        if (x < y) return 1;
        if (y < x) return 0;
    }
    return a->len < b->len;
}").
%% -- the priority_queue: a heap, the element that comes out first at data[0]. A text that compares is made for the
%%    instance's comparison (ccllib_pq_lt/4: `A < B', or the call of the function that the type names)
ccllib_pq_fn(size, _, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_pq_fn(len, _, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_pq_fn(empty, _, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_pq_fn(top, _, "@T @{N}_top(const @N *v) { if (v->len == 0) abort(); return v->data[0]; }").
ccllib_pq_fn('_grow', _, "static void @{N}__grow(@N *v, size_t n) {
    size_t need = v->len + n, c = v->cap ? 2 * v->cap : 4;
    if (need < n) abort();
    if (c < need) c = need;
    if (c > (size_t)-1 / 2 / sizeof(@T)) abort();
    v->data = (@T *)realloc(v->data, c * sizeof(@T));
    if (!v->data) abort();
    v->cap = c;
}").
ccllib_pq_fn('_up', Cmp, Text) :-
    ccllib_pq_lt(Cmp, "v->data[p]", "x", Lt),
    append(["static void @{N}__up(@N *v, size_t i) {
    @T x = v->data[i];
    while (i > 0) {
        size_t p = (i - 1) / 2;
        if (!(", Lt, ")) break;
        v->data[i] = v->data[p];
        i = p;
    }
    v->data[i] = x;
}"], Text).
ccllib_pq_fn('_down', Cmp, Text) :-
    ccllib_pq_lt(Cmp, "v->data[c]", "v->data[c + 1]", Lt1), ccllib_pq_lt(Cmp, "x", "v->data[c]", Lt2),
    append(["static void @{N}__down(@N *v, size_t i) {
    @T x = v->data[i];
    for (;;) {
        size_t c = 2 * i + 1;
        if (c >= v->len) break;
        if (c + 1 < v->len && ", Lt1, ") c++;
        if (!(", Lt2, ")) break;
        v->data[i] = v->data[c];
        i = c;
    }
    v->data[i] = x;
}"], Text).
ccllib_pq_fn(push, _, "void @{N}_push(@N *v, @T x) {
    if (v->len == v->cap) @{N}__grow(v, 1);
    v->data[v->len] = x;
    v->len++;
    @{N}__up(v, v->len - 1);
}").
ccllib_pq_fn(emplace, _, "void @{N}_emplace(@N *v, @T x) { @{N}_push(v, x); }").
ccllib_pq_fn(push_range, _, "void @{N}_push_range(@N *v, const @T *a, size_t n) {
    for (size_t i = 0; i < n; i++) @{N}_push(v, a[i]);
}").
ccllib_pq_fn(pop, _, "@T @{N}_pop(@N *v) {
    if (v->len == 0) abort();
    @T x = v->data[0];
    v->len--;
    if (v->len) { v->data[0] = v->data[v->len]; @{N}__down(v, 0); }
    return x;
}").
ccllib_pq_fn(swap, _, "void @{N}_swap(@N *a, @N *b) {
    size_t n = a->len, c = a->cap;
    a->len = b->len; a->cap = b->cap;
    b->len = n; b->cap = c;
    own @T *d = a->data;
    a->data = b->data;
    b->data = d;
}").
ccllib_pq_fn(from, _, "@N @{N}_from(const @T *a, size_t n) { @N v = {0}; @{N}_push_range(&v, a, n); return v; }").
ccllib_pq_fn(clone, _, "@N @{N}_clone(const @N *v) {
    @N w = {0};
    if (v->len) @{N}__grow(&w, v->len);
    for (size_t i = 0; i < v->len; i++) w.data[i] = v->data[i];
    w.len = v->len;
    return w;
}").
%% the text of `A comes out after B': the element's `<', or the call of the comparison that the type names
ccllib_pq_lt(none, A, B, Lt) :- !, append([A, " < ", B], Lt).
ccllib_pq_lt(F, A, B, Lt) :- atom_codes(F, Fs), append([Fs, "(", A, ", ", B, ")"], Lt).
