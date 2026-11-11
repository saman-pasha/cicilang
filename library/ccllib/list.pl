%% ccllib's <list.pl> (0.277; CCLLIB.md's phase 1a): std::list for cicilang's C, and for cicilang++ beside libc++'s.
%%
%%   #include <list.pl>
%%   list<int> l;                   an empty list; dropped where its scope ends (autodrop)
%%   push_back(l, 7);  p := insert(l, begin(l), 3);  l[p] = 9;  erase(l, p);
%%   for (size_t p = begin(l); p != end(l); p = next(l, p)) printf("%d ", at(l, p));
%%
%% type_list/3 gives the instance's type, `list_int', and its node's, `list_int_node'. The nodes stand in ONE own
%% buffer, an arena, and a node names its neighbours by their NUMBERS: there is no pointer from a node to a node, which
%% the safe part would refuse as a stored borrow. A PLACE -- what C++ calls an iterator -- is a node's number, a
%% size_t: begin(l) is the first node's, end(l) is 0, next(l, p) and prev(l, p) step, at(l, p) and l[p] give the
%% element. A place stays its element's while the element is in the list, over every insert and every erase of
%% another, as a C++ iterator of a list does; the number of an erased node is given to a later one. fn_list/3 gives ONE
%% function of the instance at its first call. The names are std::list's, in the forms of <vector.pl>. What differs
%% from C++:
%%   an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2);
%%   `w = l' and `f(l)' move, as every object of an instance's type does; clone(l) copies, and gives new places;
%%   at(l, p), l[p], next, prev, erase and insert stop the program (abort) at a place that is no element's, and front,
%%     back, pop_back and pop_front on an empty list; a failed allocation stops it too;
%%   pop_back and pop_front give the element that they take away; insert gives the new element's place, erase the place
%%     after the erased one; remove, remove_if, unique and erase_value give the count that they took away;
%%   &l[p] is a borrow of the arena, tied to the list, which each function that takes the list not as const ends; a
%%     place is a number and stays;
%%   splice and merge take the elements of the other list into this list's arena, element by element, and the other's
%%     places end; in C++ they move the nodes and keep the iterators. merge(l, l) does nothing, as in C++, and
%%     splice(l, p, l) of the whole list into itself stops the program;
%%   sort(l, lt), unique(l, eq), merge(l, m, lt) and remove_if(l, f) take a function, where C++ takes any callable.
:- ensure_loaded(library(ccllib/ccllib)).
type_list([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(list, [T], N), ccllib_plain_element('a list''s element', T),
    ccl_c_items("typedef struct @{N}_node { size_t prev, next; @T x; } @{N}_node;
typedef struct @N { size_t len, cap, top, free, head, tail; own @{N}_node *data; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_list(Name, [T], Items) :-
    ccllib_list_fn(Name, Text), ccl_instance_name(list, [T], N),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
%% a function's C text by its name. The node of the place p is v->data[p - 1]; `top' counts the nodes that the arena
%% ever gave, `free' is the first of the erased ones, which their `next' chains and whose `prev' is (size_t)-1
%% -- the capacity
ccllib_list_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_list_fn(len, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_list_fn(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_list_fn(max_size, "size_t @{N}_max_size(const @N *v) { return (size_t)-1 / 2 / sizeof(@{N}_node); }").
%% -- the places and the elements
ccllib_list_fn('_live', "static void @{N}__live(const @N *v, size_t p) { if (p == 0 || p > v->top || v->data[p - 1].prev == (size_t)-1) abort(); }").
ccllib_list_fn(begin, "size_t @{N}_begin(const @N *v) { return v->head; }").
ccllib_list_fn(end, "size_t @{N}_end(const @N *v) { return 0; }").
ccllib_list_fn(next, "size_t @{N}_next(const @N *v, size_t p) { @{N}__live(v, p); return v->data[p - 1].next; }").
ccllib_list_fn(prev, "size_t @{N}_prev(const @N *v, size_t p) { if (p == 0) return v->tail; @{N}__live(v, p); return v->data[p - 1].prev; }").
ccllib_list_fn(at, "@T @{N}_at(const @N *v, size_t p) { @{N}__live(v, p); return v->data[p - 1].x; }").
ccllib_list_fn(index, "@T *@{N}_index(const @N *v, size_t p) tie v { @{N}__live(v, p); return &v->data[p - 1].x; }").
ccllib_list_fn(front, "@T @{N}_front(const @N *v) { if (v->len == 0) abort(); return v->data[v->head - 1].x; }").
ccllib_list_fn(back, "@T @{N}_back(const @N *v) { if (v->len == 0) abort(); return v->data[v->tail - 1].x; }").
%% -- the modifiers. __node gives a node's number: an erased node's, or the arena's next, and the arena grows by twice
ccllib_list_fn('_node', "static size_t @{N}__node(@N *v) {
    size_t p = v->free;
    if (p) { v->free = v->data[p - 1].next; return p; }
    if (v->top == v->cap) {
        size_t c = v->cap ? 2 * v->cap : 4;
        if (c > (size_t)-1 / 2 / sizeof(@{N}_node)) abort();
        v->data = (@{N}_node *)realloc(v->data, c * sizeof(@{N}_node));
        if (!v->data) abort();
        v->cap = c;
    }
    return ++v->top;
}").
ccllib_list_fn(insert, "size_t @{N}_insert(@N *v, size_t p, @T x) {
    if (p) @{N}__live(v, p);
    size_t k = @{N}__node(v), b = p ? v->data[p - 1].prev : v->tail;
    v->data[k - 1].x = x;
    v->data[k - 1].prev = b;
    v->data[k - 1].next = p;
    if (b) v->data[b - 1].next = k; else v->head = k;
    if (p) v->data[p - 1].prev = k; else v->tail = k;
    v->len++;
    return k;
}").
ccllib_list_fn(emplace, "size_t @{N}_emplace(@N *v, size_t p, @T x) { return @{N}_insert(v, p, x); }").
ccllib_list_fn(insert4, "size_t @{N}_insert4(@N *v, size_t p, size_t n, @T x) {
    size_t f = p;
    for (size_t i = 0; i < n; i++) { size_t k = @{N}_insert(v, p, x); if (i == 0) f = k; }
    return f;
}").
ccllib_list_fn(insert_range, "size_t @{N}_insert_range(@N *v, size_t p, const @T *a, size_t n) {
    size_t f = p;
    for (size_t i = 0; i < n; i++) { size_t k = @{N}_insert(v, p, a[i]); if (i == 0) f = k; }
    return f;
}").
ccllib_list_fn(append_range, "void @{N}_append_range(@N *v, const @T *a, size_t n) { @{N}_insert_range(v, 0, a, n); }").
ccllib_list_fn(prepend_range, "void @{N}_prepend_range(@N *v, const @T *a, size_t n) { @{N}_insert_range(v, v->head, a, n); }").
ccllib_list_fn(push_back, "void @{N}_push_back(@N *v, @T x) { @{N}_insert(v, 0, x); }").
ccllib_list_fn(push, "void @{N}_push(@N *v, @T x) { @{N}_insert(v, 0, x); }").
ccllib_list_fn(emplace_back, "void @{N}_emplace_back(@N *v, @T x) { @{N}_insert(v, 0, x); }").
ccllib_list_fn(push_front, "void @{N}_push_front(@N *v, @T x) { @{N}_insert(v, v->head, x); }").
ccllib_list_fn(emplace_front, "void @{N}_emplace_front(@N *v, @T x) { @{N}_insert(v, v->head, x); }").
ccllib_list_fn(erase, "size_t @{N}_erase(@N *v, size_t p) {
    @{N}__live(v, p);
    size_t b = v->data[p - 1].prev, n = v->data[p - 1].next;
    if (b) v->data[b - 1].next = n; else v->head = n;
    if (n) v->data[n - 1].prev = b; else v->tail = b;
    v->data[p - 1].prev = (size_t)-1;
    v->data[p - 1].next = v->free;
    v->free = p;
    v->len--;
    return n;
}").
ccllib_list_fn(erase3, "size_t @{N}_erase3(@N *v, size_t p, size_t q) { while (p != q) p = @{N}_erase(v, p); return q; }").
ccllib_list_fn(pop_back, "@T @{N}_pop_back(@N *v) {
    if (v->len == 0) abort();
    @T x = v->data[v->tail - 1].x;
    @{N}_erase(v, v->tail);
    return x;
}").
ccllib_list_fn(pop, "@T @{N}_pop(@N *v) { return @{N}_pop_back(v); }").
ccllib_list_fn(pop_front, "@T @{N}_pop_front(@N *v) {
    if (v->len == 0) abort();
    @T x = v->data[v->head - 1].x;
    @{N}_erase(v, v->head);
    return x;
}").
ccllib_list_fn(clear, "void @{N}_clear(@N *v) { v->len = 0; v->top = 0; v->free = 0; v->head = 0; v->tail = 0; }").
ccllib_list_fn(resize3, "void @{N}_resize3(@N *v, size_t n, @T x) {
    while (v->len > n) @{N}_erase(v, v->tail);
    while (v->len < n) @{N}_insert(v, 0, x);
}").
ccllib_list_fn(resize, "void @{N}_resize(@N *v, size_t n) {
    @T z;
    memset(&z, 0, sizeof z);
    @{N}_resize3(v, n, z);
}").
ccllib_list_fn(assign, "void @{N}_assign(@N *v, size_t n, @T x) { @{N}_clear(v); @{N}_resize3(v, n, x); }").
ccllib_list_fn(assign_range, "void @{N}_assign_range(@N *v, const @T *a, size_t n) { @{N}_clear(v); @{N}_insert_range(v, 0, a, n); }").
ccllib_list_fn(swap, "void @{N}_swap(@N *a, @N *b) {
    size_t n = a->len, c = a->cap, t = a->top, f = a->free, h = a->head, l = a->tail;
    a->len = b->len; a->cap = b->cap; a->top = b->top; a->free = b->free; a->head = b->head; a->tail = b->tail;
    b->len = n; b->cap = c; b->top = t; b->free = f; b->head = h; b->tail = l;
    own @{N}_node *d = a->data;
    a->data = b->data;
    b->data = d;
}").
%% -- the list's own operations
ccllib_list_fn(remove, "size_t @{N}_remove(@N *v, @T x) {
    size_t n = 0, p = v->head;
    while (p) {
        if (v->data[p - 1].x == x) { p = @{N}_erase(v, p); n++; }
        else p = v->data[p - 1].next;
    }
    return n;
}").
ccllib_list_fn(erase_value, "size_t @{N}_erase_value(@N *v, @T x) { return @{N}_remove(v, x); }").
ccllib_list_fn(remove_if, "size_t @{N}_remove_if(@N *v, int (*f)(@T)) {
    size_t n = 0, p = v->head;
    while (p) {
        if (f(v->data[p - 1].x)) { p = @{N}_erase(v, p); n++; }
        else p = v->data[p - 1].next;
    }
    return n;
}").
ccllib_list_fn(unique, "size_t @{N}_unique(@N *v) {
    size_t n = 0, p = v->head;
    while (p) {
        size_t q = v->data[p - 1].next;
        if (q && v->data[q - 1].x == v->data[p - 1].x) { @{N}_erase(v, q); n++; }
        else p = q;
    }
    return n;
}").
ccllib_list_fn(unique2, "size_t @{N}_unique2(@N *v, int (*eq)(@T, @T)) {
    size_t n = 0, p = v->head;
    while (p) {
        size_t q = v->data[p - 1].next;
        if (q && eq(v->data[p - 1].x, v->data[q - 1].x)) { @{N}_erase(v, q); n++; }
        else p = q;
    }
    return n;
}").
ccllib_list_fn(reverse, "void @{N}_reverse(@N *v) {
    size_t p = v->head;
    while (p) {
        size_t n = v->data[p - 1].next;
        v->data[p - 1].next = v->data[p - 1].prev;
        v->data[p - 1].prev = n;
        p = n;
    }
    p = v->head;
    v->head = v->tail;
    v->tail = p;
}").
%% a merge sort by the nodes' links (ccllib_msort_text/5): no element moves, each keeps its place, and equal elements
%% keep their order; sort then gives each node its `prev' again
ccllib_list_fn(sort, Text) :- ccllib_list_sort_text("sort", "", "", Text).
ccllib_list_fn(sort2, Text) :- ccllib_list_sort_text("sort2", ", int (*lt)(@T, @T)", ", lt", Text).
ccllib_list_fn('_sort', Text) :- ccllib_msort_text("sort", "", "", "v->data[b - 1].x < v->data[a - 1].x", Text).
ccllib_list_fn('_sort2', Text) :-
    ccllib_msort_text("sort2", ", int (*lt)(@T, @T)", ", lt", "lt(v->data[b - 1].x, v->data[a - 1].x)", Text).
ccllib_list_fn(merge, Text) :- ccllib_list_merge_text("merge", "", "x < v->data[p - 1].x", Text).
ccllib_list_fn(merge3, Text) :- ccllib_list_merge_text("merge3", ", int (*lt)(@T, @T)", "lt(x, v->data[p - 1].x)", Text).
ccllib_list_fn(splice, "void @{N}_splice(@N *v, size_t p, @N *w) {
    if (v == w) abort();
    for (size_t q = w->head; q; q = w->data[q - 1].next) @{N}_insert(v, p, w->data[q - 1].x);
    @{N}_clear(w);
}").
ccllib_list_fn(splice4, "void @{N}_splice4(@N *v, size_t p, @N *w, size_t q) {
    @{N}__live(w, q);
    @{N}_insert(v, p, w->data[q - 1].x);
    @{N}_erase(w, q);
}").
ccllib_list_fn(splice5, "void @{N}_splice5(@N *v, size_t p, @N *w, size_t q, size_t r) {
    while (q != r) {
        @{N}__live(w, q);
        @{N}_insert(v, p, w->data[q - 1].x);
        q = @{N}_erase(w, q);
    }
}").
%% -- a value of an array, which a literal calls; a copy; the comparisons that the operators call
ccllib_list_fn(from, "@N @{N}_from(const @T *a, size_t n) { @N v = {0}; @{N}_insert_range(&v, 0, a, n); return v; }").
ccllib_list_fn(clone, "@N @{N}_clone(const @N *v) {
    @N w = {0};
    for (size_t p = v->head; p; p = v->data[p - 1].next) @{N}_insert(&w, 0, v->data[p - 1].x);
    return w;
}").
ccllib_list_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    size_t p = a->head, q = b->head;
    if (a->len != b->len) return 0;
    for (; p; p = a->data[p - 1].next, q = b->data[q - 1].next)
        if (!(a->data[p - 1].x == b->data[q - 1].x)) return 0;
    return 1;
}").
ccllib_list_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    size_t p = a->head, q = b->head;
    for (; p && q; p = a->data[p - 1].next, q = b->data[q - 1].next) {
        if (a->data[p - 1].x < b->data[q - 1].x) return 1;
        if (b->data[q - 1].x < a->data[p - 1].x) return 0;
    }
    return p == 0 && q != 0;
}").
ccllib_list_sort_text(Name, Param, Arg, Text) :-
    append(["void @{N}_", Name, "(@N *v", Param, ") {
    size_t rest, t = 0;
    if (v->len < 2) return;
    v->head = @{N}__", Name, "(v, v->head, v->len, &rest", Arg, ");
    for (size_t p = v->head; p; p = v->data[p - 1].next) { v->data[p - 1].prev = t; t = p; }
    v->tail = t;
}"], Text).
ccllib_list_merge_text(Name, Param, Lt, Text) :-
    append(["void @{N}_", Name, "(@N *v, @N *w", Param, ") {
    size_t p = v->head;
    if (v == w) return;
    for (size_t q = w->head; q; q = w->data[q - 1].next) {
        @T x = w->data[q - 1].x;
        while (p && !(", Lt, ")) p = v->data[p - 1].next;
        @{N}_insert(v, p, x);
    }
    @{N}_clear(w);
}"], Text).
