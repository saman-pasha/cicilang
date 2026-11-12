%% ccllib's <forward_list.pl> (0.278; CCLLIB.md's phase 1a): std::forward_list for cicilang's C, and for cicilang++
%% beside libc++'s.
%%
%%   #include <forward_list.pl>
%%   forward_list<int> l;           an empty list; dropped where its scope ends (autodrop)
%%   push_front(l, 7);  p := insert_after(l, begin(l), 3);  l[p] = 9;  erase_after(l, before_begin(l));
%%   for (size_t p = begin(l); p != end(l); p = next(l, p)) printf("%d ", at(l, p));
%%
%% type_forward_list/3 gives the instance's type, `forward_list_int', and its node's. As <list.pl>'s, the nodes stand
%% in ONE own buffer, an arena, and a node names the next one by its NUMBER; a PLACE is a node's number, a size_t:
%% begin(l) is the first node's, end(l) is 0, before_begin(l) is (size_t)-1, next(l, p) steps. A place stays its
%% element's while the element is in the list. fn_forward_list/3 gives ONE function of the instance at its first call.
%% The names are std::forward_list's, in the forms of <vector.pl>. What differs from C++:
%%   an element is a value with no pointer in it, as a vector's is (CCLLIB.md's open decision 2);
%%   `w = l' and `f(l)' move, as every object of an instance's type does; clone(l) copies, and gives new places;
%%   at(l, p), l[p], next, insert_after and erase_after stop the program (abort) at a place that is no element's, and
%%     front and pop_front on an empty list; a failed allocation stops it too;
%%   size(l) and len(l) are there, which C++'s forward_list has not: the arena counts its elements;
%%   pop_front gives the element that it takes away; insert_after gives the new element's place -- the last one's of
%%     several --, erase_after the place after the erased one; remove, remove_if, unique and erase_value give the count
%%     that they took away;
%%   &l[p] is a borrow of the arena, tied to the list, which each function that takes the list not as const ends; a
%%     place is a number and stays;
%%   splice_after and merge take the elements of the other list into this list's arena, element by element, and the
%%     other's places end; in C++ they move the nodes and keep the iterators. merge(l, l) does nothing, as in C++, and
%%     splice_after(l, p, l) of the whole list into itself stops the program;
%%   sort(l, lt), unique(l, eq), merge(l, m, lt) and remove_if(l, f) take a function, where C++ takes any callable.
:- ensure_loaded(library(ccllib/ccllib)).
type_forward_list([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(forward_list, [T], N), ccllib_plain_element('a forward_list''s element', T),
    ccl_c_items("typedef struct @{N}_node { size_t next; @T x; } @{N}_node;
typedef struct @N { size_t len, cap, top, free, head; own @{N}_node *data; } @N;
void @{N}_drop(@N *v) { free(v->data); }", ['N' = name(N), 'T' = type(T)], Items).
fn_forward_list(Name, [T], Items) :-
    ccllib_forward_list_fn(Name, Text), ccl_instance_name(forward_list, [T], N),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
%% a function's C text by its name. The node of the place p is v->data[p - 1]; `top' counts the nodes that the arena
%% ever gave, `free' is the first of the erased ones; an erased node's `next' is the complement of the next erased
%% one's number, which is past every number of a node, so __live knows it
%% -- the capacity
ccllib_forward_list_fn(size, "size_t @{N}_size(const @N *v) { return v->len; }").
ccllib_forward_list_fn(len, "size_t @{N}_len(const @N *v) { return v->len; }").
ccllib_forward_list_fn(empty, "int @{N}_empty(const @N *v) { return v->len == 0; }").
ccllib_forward_list_fn(max_size, "size_t @{N}_max_size(const @N *v) { return (size_t)-1 / 4 / sizeof(@{N}_node); }").
%% -- the places and the elements
ccllib_forward_list_fn('_live', "static void @{N}__live(const @N *v, size_t p) { if (p == 0 || p > v->top || v->data[p - 1].next > v->top) abort(); }").
ccllib_forward_list_fn(before_begin, "size_t @{N}_before_begin(const @N *v) { return (size_t)-1; }").
ccllib_forward_list_fn(begin, "size_t @{N}_begin(const @N *v) { return v->head; }").
ccllib_forward_list_fn(end, "size_t @{N}_end(const @N *v) { return 0; }").
ccllib_forward_list_fn(next, "size_t @{N}_next(const @N *v, size_t p) {
    if (p == (size_t)-1) return v->head;
    @{N}__live(v, p);
    return v->data[p - 1].next;
}").
ccllib_forward_list_fn(at, "@T @{N}_at(const @N *v, size_t p) { @{N}__live(v, p); return v->data[p - 1].x; }").
ccllib_forward_list_fn(index, "@T *@{N}_index(const @N *v, size_t p) tie v { @{N}__live(v, p); return &v->data[p - 1].x; }").
ccllib_forward_list_fn(front, "@T @{N}_front(const @N *v) { if (v->len == 0) abort(); return v->data[v->head - 1].x; }").
%% -- the modifiers. __node gives a node's number: an erased node's, or the arena's next, and the arena grows by twice
ccllib_forward_list_fn('_node', "static size_t @{N}__node(@N *v) {
    size_t p = v->free;
    if (p) { v->free = ~v->data[p - 1].next; return p; }
    if (v->top == v->cap) {
        size_t c = v->cap ? 2 * v->cap : 4;
        if (c > (size_t)-1 / 4 / sizeof(@{N}_node)) abort();
        v->data = (@{N}_node *)realloc(v->data, c * sizeof(@{N}_node));
        if (!v->data) abort();
        v->cap = c;
    }
    return ++v->top;
}").
ccllib_forward_list_fn(insert_after, "size_t @{N}_insert_after(@N *v, size_t p, @T x) {
    if (p != (size_t)-1) @{N}__live(v, p);
    size_t k = @{N}__node(v);
    v->data[k - 1].x = x;
    if (p == (size_t)-1) { v->data[k - 1].next = v->head; v->head = k; }
    else { v->data[k - 1].next = v->data[p - 1].next; v->data[p - 1].next = k; }
    v->len++;
    return k;
}").
ccllib_forward_list_fn(emplace_after, "size_t @{N}_emplace_after(@N *v, size_t p, @T x) { return @{N}_insert_after(v, p, x); }").
ccllib_forward_list_fn(insert_after4, "size_t @{N}_insert_after4(@N *v, size_t p, size_t n, @T x) {
    for (size_t i = 0; i < n; i++) p = @{N}_insert_after(v, p, x);
    return p;
}").
ccllib_forward_list_fn(insert_range_after, "size_t @{N}_insert_range_after(@N *v, size_t p, const @T *a, size_t n) {
    for (size_t i = 0; i < n; i++) p = @{N}_insert_after(v, p, a[i]);
    return p;
}").
ccllib_forward_list_fn(prepend_range, "void @{N}_prepend_range(@N *v, const @T *a, size_t n) { @{N}_insert_range_after(v, (size_t)-1, a, n); }").
ccllib_forward_list_fn(push_front, "void @{N}_push_front(@N *v, @T x) { @{N}_insert_after(v, (size_t)-1, x); }").
ccllib_forward_list_fn(emplace_front, "void @{N}_emplace_front(@N *v, @T x) { @{N}_insert_after(v, (size_t)-1, x); }").
ccllib_forward_list_fn(erase_after, "size_t @{N}_erase_after(@N *v, size_t p) {
    size_t k, n;
    if (p == (size_t)-1) k = v->head;
    else { @{N}__live(v, p); k = v->data[p - 1].next; }
    if (k == 0) abort();
    n = v->data[k - 1].next;
    if (p == (size_t)-1) v->head = n; else v->data[p - 1].next = n;
    v->data[k - 1].next = ~v->free;
    v->free = k;
    v->len--;
    return n;
}").
ccllib_forward_list_fn(erase_after3, "size_t @{N}_erase_after3(@N *v, size_t p, size_t q) {
    while (@{N}_next(v, p) != q) @{N}_erase_after(v, p);
    return q;
}").
ccllib_forward_list_fn(pop_front, "@T @{N}_pop_front(@N *v) {
    if (v->len == 0) abort();
    @T x = v->data[v->head - 1].x;
    @{N}_erase_after(v, (size_t)-1);
    return x;
}").
ccllib_forward_list_fn(clear, "void @{N}_clear(@N *v) { v->len = 0; v->top = 0; v->free = 0; v->head = 0; }").
ccllib_forward_list_fn(resize3, "void @{N}_resize3(@N *v, size_t n, @T x) {
    size_t p = (size_t)-1, i = 0;
    for (size_t q = v->head; q && i < n; q = v->data[q - 1].next) { p = q; i++; }
    while (v->len > n) @{N}_erase_after(v, p);
    while (v->len < n) p = @{N}_insert_after(v, p, x);
}").
ccllib_forward_list_fn(resize, "void @{N}_resize(@N *v, size_t n) {
    @T z;
    memset(&z, 0, sizeof z);
    @{N}_resize3(v, n, z);
}").
ccllib_forward_list_fn(assign, "void @{N}_assign(@N *v, size_t n, @T x) { @{N}_clear(v); @{N}_resize3(v, n, x); }").
ccllib_forward_list_fn(assign_range, "void @{N}_assign_range(@N *v, const @T *a, size_t n) { @{N}_clear(v); @{N}_insert_range_after(v, (size_t)-1, a, n); }").
ccllib_forward_list_fn(swap, "void @{N}_swap(@N *a, @N *b) {
    size_t n = a->len, c = a->cap, t = a->top, f = a->free, h = a->head;
    a->len = b->len; a->cap = b->cap; a->top = b->top; a->free = b->free; a->head = b->head;
    b->len = n; b->cap = c; b->top = t; b->free = f; b->head = h;
    own @{N}_node *d = a->data;
    a->data = b->data;
    b->data = d;
}").
%% -- the list's own operations
ccllib_forward_list_fn(remove, "size_t @{N}_remove(@N *v, @T x) {
    size_t n = 0, p = (size_t)-1, q = v->head;
    while (q) {
        if (v->data[q - 1].x == x) { q = @{N}_erase_after(v, p); n++; }
        else { p = q; q = v->data[q - 1].next; }
    }
    return n;
}").
ccllib_forward_list_fn(erase_value, "size_t @{N}_erase_value(@N *v, @T x) { return @{N}_remove(v, x); }").
ccllib_forward_list_fn(remove_if, "size_t @{N}_remove_if(@N *v, int (*f)(@T)) {
    size_t n = 0, p = (size_t)-1, q = v->head;
    while (q) {
        if (f(v->data[q - 1].x)) { q = @{N}_erase_after(v, p); n++; }
        else { p = q; q = v->data[q - 1].next; }
    }
    return n;
}").
ccllib_forward_list_fn(unique, "size_t @{N}_unique(@N *v) {
    size_t n = 0, p = v->head;
    while (p) {
        size_t q = v->data[p - 1].next;
        if (q && v->data[p - 1].x == v->data[q - 1].x) { @{N}_erase_after(v, p); n++; }
        else p = q;
    }
    return n;
}").
ccllib_forward_list_fn(unique2, "size_t @{N}_unique2(@N *v, int (*eq)(@T, @T)) {
    size_t n = 0, p = v->head;
    while (p) {
        size_t q = v->data[p - 1].next;
        if (q && eq(v->data[p - 1].x, v->data[q - 1].x)) { @{N}_erase_after(v, p); n++; }
        else p = q;
    }
    return n;
}").
ccllib_forward_list_fn(reverse, "void @{N}_reverse(@N *v) {
    size_t p = v->head, r = 0;
    while (p) {
        size_t n = v->data[p - 1].next;
        v->data[p - 1].next = r;
        r = p;
        p = n;
    }
    v->head = r;
}").
ccllib_forward_list_fn(sort, "void @{N}_sort(@N *v) {
    size_t rest;
    if (v->len > 1) v->head = @{N}__sort(v, v->head, v->len, &rest);
}").
ccllib_forward_list_fn(sort2, "void @{N}_sort2(@N *v, int (*lt)(@T, @T)) {
    size_t rest;
    if (v->len > 1) v->head = @{N}__sort2(v, v->head, v->len, &rest, lt);
}").
ccllib_forward_list_fn('_sort', Text) :- ccllib_msort_text("sort", "", "", "v->data[b - 1].x < v->data[a - 1].x", Text).
ccllib_forward_list_fn('_sort2', Text) :-
    ccllib_msort_text("sort2", ", int (*lt)(@T, @T)", ", lt", "lt(v->data[b - 1].x, v->data[a - 1].x)", Text).
ccllib_forward_list_fn(merge, Text) :- ccllib_forward_list_merge_text("merge", "", "x < v->data[q - 1].x", Text).
ccllib_forward_list_fn(merge3, Text) :- ccllib_forward_list_merge_text("merge3", ", int (*lt)(@T, @T)", "lt(x, v->data[q - 1].x)", Text).
ccllib_forward_list_fn(splice_after, "void @{N}_splice_after(@N *v, size_t p, @N *w) {
    if (v == w) abort();
    for (size_t q = w->head; q; q = w->data[q - 1].next) p = @{N}_insert_after(v, p, w->data[q - 1].x);
    @{N}_clear(w);
}").
ccllib_forward_list_fn(splice_after4, "void @{N}_splice_after4(@N *v, size_t p, @N *w, size_t q) {
    size_t k = @{N}_next(w, q);
    if (k == 0) abort();
    @{N}_insert_after(v, p, w->data[k - 1].x);
    @{N}_erase_after(w, q);
}").
ccllib_forward_list_fn(splice_after5, "void @{N}_splice_after5(@N *v, size_t p, @N *w, size_t q, size_t r) {
    for (size_t k = @{N}_next(w, q); k != r; k = @{N}_erase_after(w, q)) {
        if (k == 0) abort();
        p = @{N}_insert_after(v, p, w->data[k - 1].x);
    }
}").
%% -- a value of an array, which a literal calls; a copy; the comparisons that the operators call
ccllib_forward_list_fn(from, "@N @{N}_from(const @T *a, size_t n) { @N v = {0}; @{N}_insert_range_after(&v, (size_t)-1, a, n); return v; }").
ccllib_forward_list_fn(clone, "@N @{N}_clone(const @N *v) {
    @N w = {0};
    size_t t = (size_t)-1;
    for (size_t p = v->head; p; p = v->data[p - 1].next) t = @{N}_insert_after(&w, t, v->data[p - 1].x);
    return w;
}").
ccllib_forward_list_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    size_t p = a->head, q = b->head;
    if (a->len != b->len) return 0;
    for (; p; p = a->data[p - 1].next, q = b->data[q - 1].next)
        if (!(a->data[p - 1].x == b->data[q - 1].x)) return 0;
    return 1;
}").
%% THE RELATIONS ARE C++20'S (0.304): the synthesized three-way order of the elements, where a pair that is neither
%% `<' nor `==' either way -- a NaN -- is unordered and ends the comparison, every relation false; `<=' and `>=' are
%% _le and _ge, which the reader asks first
ccllib_forward_list_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    size_t p = a->head, q = b->head;
    for (; p && q; p = a->data[p - 1].next, q = b->data[q - 1].next) {
        if (a->data[p - 1].x < b->data[q - 1].x) return 1;
        if (b->data[q - 1].x < a->data[p - 1].x) return 0;
        if (!(a->data[p - 1].x == b->data[q - 1].x)) return 0;
    }
    return p == 0 && q != 0;
}").
ccllib_forward_list_fn(le, "int @{N}_le(const @N *a, const @N *b) {
    size_t p = a->head, q = b->head;
    for (; p && q; p = a->data[p - 1].next, q = b->data[q - 1].next) {
        if (a->data[p - 1].x < b->data[q - 1].x) return 1;
        if (b->data[q - 1].x < a->data[p - 1].x) return 0;
        if (!(a->data[p - 1].x == b->data[q - 1].x)) return 0;
    }
    return p == 0;
}").
ccllib_forward_list_fn(ge, "int @{N}_ge(const @N *a, const @N *b) { return @{N}_le(b, a); }").
%% merge: each element of w, in its order, goes after the last element of v that is not after it
ccllib_forward_list_merge_text(Name, Param, Lt, Text) :-
    append(["void @{N}_", Name, "(@N *v, @N *w", Param, ") {
    size_t p = (size_t)-1;
    if (v == w) return;
    for (size_t k = w->head; k; k = w->data[k - 1].next) {
        @T x = w->data[k - 1].x;
        for (size_t q = @{N}_next(v, p); q && !(", Lt, "); q = v->data[q - 1].next) p = q;
        p = @{N}_insert_after(v, p, x);
    }
    @{N}_clear(w);
}"], Text).
