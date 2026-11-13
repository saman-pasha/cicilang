/* WHAT STOPS A CCLLIB PROGRAM (0.281): each case goes past what its container holds -- an index past the end, the front
   of an empty one, a place that is no element's or that a new entry of the map ended -- where C++ throws or is
   undefined. Each runs in a child of its own, and a line says for each whether abort stopped it: 1, and 0 for the cases
   that stay in their bounds, which no stop may meet (a tree's place over 4000 inserts that find their keys and erases
   that find none; a hash table's place over such calls at each of its sizes up to 4000, 0.283; a bitset's last bit,
   read and written each way, 0.286; a string's place after its last character, and each change at that place, 0.291). A
   string's change past max_size stops, and a number of a text where there is none or where it is past its type's range,
   where C++ throws (0.291). A view's and a span's place or count past the end stops, and a view's place after its last
   character, which is in its bounds, does not (0.295). An optional's value where it has none stops, where C++ throws,
   and its value where it has one, value_or and emplace's place do not (0.300). A variant's get of an alternative that
   it does not hold stops, by an index and by a type, where C++ throws, and get_if, get and emplace of the one that it
   holds do not (0.308). A unique_ptr's *p and p->m where it is empty stop, where C++ is undefined, and get of an empty
   one and *p of a full one do not (0.309). cicilang builds this file as C and cicilang++ as C++; both print
   stops.expect. It has no twin: C++ throws at some of these, and says nothing of what follows the others */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector.pl>
#include <array.pl>
#include <deque.pl>
#include <list.pl>
#include <forward_list.pl>
#include <stack.pl>
#include <queue.pl>
#include <set.pl>
#include <map.pl>
#include <unordered_set.pl>
#include <unordered_map.pl>
#include <bitset.pl>
#include <string.pl>
#include <string_view.pl>
#include <span.pl>
#include <optional.pl>
#include <variant.pl>
#include <memory.pl>
/* the child takes abort's signal and leaves with a status of its own: so no core is written and no crash is reported,
   and a stop by abort is told from a fault */
static void on_abort(int sig) { (void)sig; _exit(77); }
static int stopped(void (*f)(void)) {
    int st = 0;
    pid_t p = fork();
    if (p == 0) { signal(SIGABRT, on_abort); f(); _exit(0); }
    if (p < 0 || waitpid(p, &st, 0) != p) return -1;
    return WIFEXITED(st) && WEXITSTATUS(st) == 77;
}
static void vector_at(void) { vector<int> v = [1, 2, 3]; printf("%d", at(v, 3)); }
static void vector_index(void) { vector<int> v = [1, 2, 3]; v[3] = 1; }
static void vector_front(void) { vector<int> v; printf("%d", front(v)); }
static void vector_pop(void) { vector<int> v; pop_back(v); }
static void vector_insert(void) { vector<int> v = [1]; insert(v, 2, 5); }
static void vector_erase(void) { vector<int> v = [1]; erase(v, 1); }
static void vector_ok(void) { vector<int> v = [1, 2, 3]; v[2] = at(v, 0) + back(v); pop_back(v); }
static void array_at(void) { array<int, 4> a = [1]; printf("%d", at(a, 4)); }
static void array_index(void) { array<int, 4> a = [1]; a[4] = 1; }
static void array_literal(void) { int n = 5; array<int, 2> a = [1, 2, n]; printf("%d", a[0]); }
static void deque_at(void) { deque<int> d = [1, 2]; printf("%d", at(d, 2)); }
static void deque_back(void) { deque<int> d; printf("%d", back(d)); }
static void deque_pop_front(void) { deque<int> d; pop_front(d); }
static void deque_erase(void) { deque<int> d = [1, 2]; erase(d, 1, 3); }
static void list_place(void) { list<int> l = [1, 2]; printf("%d", at(l, 7)); }
static void list_erased(void) { list<int> l = [1, 2]; size_t p = begin(l); erase(l, p); printf("%d", at(l, p)); }
static void list_end(void) { list<int> l = [1]; printf("%d", at(l, end(l))); }
static void list_next_end(void) { list<int> l = [1]; next(l, end(l)); }
static void list_pop(void) { list<int> l; pop_front(l); }
static void list_splice(void) { list<int> l = [1, 2]; splice(l, begin(l), l); }
static void forward_list_place(void) {
    forward_list<int> l = [1];
    size_t p = begin(l);
    pop_front(l);
    printf("%d", at(l, p));
}
static void forward_list_erase(void) { forward_list<int> l = [1]; erase_after(l, begin(l)); }
static void forward_list_front(void) { forward_list<int> l; printf("%d", front(l)); }
static void stack_top(void) { stack<int> s; printf("%d", top(s)); }
static void stack_pop(void) { stack<int> s = [1]; pop(s); pop(s); }
static void queue_front(void) { queue<int> q; printf("%d", front(q)); }
static void queue_pop(void) { queue<int> q; pop(q); }
static void heap_top(void) { priority_queue<int> h; printf("%d", top(h)); }
static void heap_pop(void) { priority_queue<int> h; pop(h); }
static void set_key_end(void) { set<int> s = [1]; printf("%d", key(s, end(s))); }
static void set_stale(void) { set<int> s = [1, 2]; size_t p = begin(s); insert(s, 3); printf("%d", key(s, p)); }
static void set_erase_at(void) { set<int> s = [1]; size_t p = begin(s); erase(s, 1); erase_at(s, p); }
static void set_clear(void) { set<int> s = [1, 2]; size_t p = begin(s); clear(s); printf("%d", key(s, p)); }
static void set_swap(void) {
    set<int> s = [1, 2];
    set<int> t = [3];
    size_t p = begin(s);
    swap(s, t);
    printf("%d", key(s, p));
}
static void set_kept(void) {
    set<int> s;
    for (int i = 0; i < 4000; i++) insert(s, 2 * i);
    size_t p = find(s, 2468);
    for (int i = 0; i < 4000; i++) { insert(s, 2 * i); erase(s, 2 * i + 1); }
    if (key(s, p) != 2468 || key(s, next(s, p)) != 2470) abort();
}
static void multiset_stale(void) {
    multiset<int> s = [1, 1];
    size_t p = begin(s);
    insert(s, 1);
    printf("%d", key(s, p));
}
static void map_at(void) { map<int, int> m = [1: 10]; printf("%d", at(m, 2)); }
static void map_stale(void) { map<int, int> m = [1: 10]; size_t p = find(m, 1); m[2] = 20; printf("%d", value(m, p)); }
static void map_kept(void) {
    map<int, int> m;
    for (int i = 0; i < 4000; i++) m[2 * i] = i;
    size_t p = find(m, 2468);
    for (int i = 0; i < 4000; i++) {
        m[2 * i] = -i;
        insert(m, 2 * i, 0);
        insert_or_assign(m, 2 * i, i);
        erase(m, 2 * i + 1);
    }
    set_value(m, p, 7);
    if (key(m, p) != 2468 || value(m, p) != 7 || at(m, 2470) != 1235) abort();
}
static void multimap_stale(void) {
    multimap<int, int> m = [1: 10];
    size_t p = begin(m);
    insert(m, 1, 11);
    printf("%d", value(m, p));
}
static void map_next_end(void) { map<int, int> m = [1: 10]; next(m, end(m)); }
static void uset_key_end(void) { unordered_set<int> s = [1]; printf("%d", key(s, end(s))); }
static void uset_stale(void) {
    unordered_set<int> s = [1, 2];
    size_t p = begin(s);
    insert(s, 3);
    printf("%d", key(s, p));
}
static void uset_reserve(void) {
    unordered_set<int> s = [1, 2];
    size_t p = begin(s);
    reserve(s, 100);
    printf("%d", key(s, p));
}
static void uset_reserve_small(void) {
    unordered_set<int> s = [1, 2];
    size_t p = begin(s);
    reserve(s, 1);
    printf("%d", key(s, p));
}
static void uset_rehash(void) {
    unordered_set<int> s = [1, 2];
    size_t p = begin(s);
    rehash(s, 0);
    printf("%d", key(s, p));
}
static void uset_erase_at(void) { unordered_set<int> s = [1]; size_t p = begin(s); erase(s, 1); erase_at(s, p); }
/* a table stands at its limit where one entry more makes it again: at 6 entries, 12, 24 and on to 3072. So the calls
   that change no entry are made at EACH size from 1 to 4000, and a place is used after them: a table of 4000 entries
   alone stands under its limit, and passes a text that makes the table again before it looks for the key */
static void uset_kept(void) {
    unordered_set<int> s;
    for (int i = 0; i < 4000; i++) {
        insert(s, 2 * i);
        size_t p = find(s, 2 * (i / 2));
        insert(s, 2 * i);
        insert(s, 0);
        erase(s, 2 * i + 1);
        if (key(s, p) != 2 * (i / 2)) abort();
    }
    if (size(s) != 4000 || !contains(s, 2470)) abort();
}
static void umap_at(void) { unordered_map<int, int> m = [1: 10]; printf("%d", at(m, 2)); }
static void umap_stale(void) {
    unordered_map<int, int> m = [1: 10];
    size_t p = find(m, 1);
    m[2] = 20;
    printf("%d", value(m, p));
}
static void umap_next_end(void) { unordered_map<int, int> m = [1: 10]; next(m, end(m)); }
static void umap_kept(void) {
    unordered_map<int, int> m;
    for (int i = 0; i < 4000; i++) {
        m[2 * i] = i;
        size_t p = find(m, 2 * (i / 2));
        m[2 * i] = -i;
        insert(m, 2 * i, 0);
        insert_or_assign(m, 2 * i, i);
        erase(m, 2 * i + 1);
        set_value(m, p, i / 2);
        if (key(m, p) != 2 * (i / 2) || value(m, p) != i / 2) abort();
    }
    if (size(m) != 4000 || at(m, 2470) != 1235) abort();
}
static void umultimap_stale(void) {
    unordered_multimap<int, int> m = [1: 10];
    size_t p = begin(m);
    insert(m, 1, 11);
    printf("%d", value(m, p));
}
static void bitset_test(void) { bitset<12> b; printf("%d", test(b, 12)); }
static void bitset_item(void) { bitset<70> b; printf("%d", b[70]); }
static void bitset_write(void) { bitset<70> b; b[70] = 1; }
static void bitset_set(void) { bitset<12> b; set(b, 12); }
static void bitset_set_to(void) { bitset<64> b; set(b, 64, 0); }
static void bitset_reset(void) { bitset<12> b; reset(b, 12); }
static void bitset_flip(void) { bitset<64> b; flip(b, 64); }
static void bitset_wide(void) { bitset<70> b; set(b, 64); printf("%llu", to_ullong(b)); }
static void bitset_wide_long(void) { bitset<200> b; set(b, 199); printf("%lu", to_ulong(b)); }
static void bitset_text(void) { bitset<12> b = "10x1"; printf("%d", b[0]); }
static void bitset_text_past(void) { bitset<4> b = "10102"; printf("%d", b[0]); }
/* in its bounds: the last bit read and written each way, and a number of a set whose top bit of the word is set */
static void bitset_ok(void) {
    bitset<70> b = "101";
    bitset<64> w;
    b[69] = 1;
    flip(b, 69);
    set(b, 69);
    set(b, 69, 0);
    reset(b, 69);
    set(b, 63);
    set(w, 63);
    flip(w, 63);
    w[63] = 1;
    printf("%d %d %llu %lu %llu", test(b, 69), b[69], to_ullong(b), to_ulong(b), to_ullong(w));
}
static void string_at(void) { string s = "abc"; printf("%c", at(s, 3)); }
static void string_index(void) { string s = "abc"; printf("%c", s[4]); }
static void string_front(void) { string s; printf("%c", front(s)); }
static void string_back(void) { string s; printf("%c", back(s)); }
static void string_pop(void) { string s; pop_back(s); }
static void string_insert(void) { string s = "abc"; insert(s, 4, "x"); }
static void string_erase(void) { string s = "abc"; erase(s, 4); }
static void string_replace(void) { string s = "abc"; replace(s, 4, 1, "x"); }
static void string_substr(void) { string s = "abc"; string t = substr(s, 4); printf("%s", c_str(t)); }
static void string_substr_none(void) { string s = "abc"; string t = substr(s, 4, 0); printf("%zu", size(t)); }
static void string_copy(void) { string s = "abc"; char b[4]; printf("%zu", copy(s, b, 1, 4)); }
static void string_compare(void) { string s = "abc"; printf("%d", compare(s, 4, 1, "x")); }
static void string_part(void) { string s = "abc", t = "de"; append(s, t, 3); }
static void string_part_far(void) { string s = "abc", t = "de"; append(s, t, (size_t)-1); }
static void string_reserve(void) { string s; reserve(s, (size_t)-1); }
static void string_count(void) { string s = "abc"; append(s, "x", (size_t)-1); }
static void string_fill(void) { string s = "abc"; append(s, (size_t)-1, 'x'); }
static void string_stoi_none(void) { string s = "  x1"; printf("%d", stoi(s)); }
static void string_stoi_past(void) { string s = "4294967296"; printf("%d", stoi(s)); }
static void string_stoul_past(void) { string s = "99999999999999999999999"; printf("%lu", stoul(s)); }
static void string_stod_none(void) { string s = "e5"; printf("%g", stod(s)); }
static void string_ok(void) {
    string s = "abc", t = "de";
    char b[4] = {0};
    insert(s, 3, "x");
    erase(s, 4);
    replace(s, 4, 0, "y");
    append(s, t, 2);
    string u = substr(s, 5);
    printf("%d %c %zu %zu %d [%s] [%s]", s[5], at(s, 4), copy(s, b, 2, 5), size(u), compare(s, 5, 1, ""), c_str(s),
           c_str(u));
}
static void view_at(void) { string_view v = "abc"; printf("%c", at(v, 3)); }
static void view_index(void) { string_view v = "abc"; printf("%c", v[3]); }
static void view_front(void) { string_view v; printf("%c", front(v)); }
static void view_back(void) { string_view v; printf("%c", back(v)); }
static void view_prefix(void) { string_view v = "abc"; remove_prefix(v, 4); }
static void view_suffix(void) { string_view v = "abc"; remove_suffix(v, 4); }
static void view_substr(void) { string_view v = "abc"; string_view w = substr(v, 4); printf("%zu", size(w)); }
static void view_copy(void) { string_view v = "abc"; char b[4]; printf("%zu", copy(v, b, 1, 4)); }
static void view_compare(void) { string_view v = "abc"; printf("%d", compare(v, 4, 1, "x")); }
static void view_compare_other(void) { string_view v = "abc", w = "de"; printf("%d", compare(v, 0, 1, w, 3, 1)); }
static void view_ok(void) {
    string_view v = "abc";
    string_view w = substr(v, 3);
    char b[4];
    printf("%zu %zu %d %zu", size(w), copy(v, b, 1, 3), compare(v, 3, 1, ""), find(v, "", 3));
    remove_suffix(v, 0);
    remove_prefix(v, 3);
}
static void span_at(void) { int a[3] = {1, 2, 3}; span<int> s = a; printf("%d", at(s, 3)); }
static void span_index(void) { int a[3] = {1, 2, 3}; span<int> s = a; s[3] = 1; }
static void span_front(void) { span<int> s; printf("%d", front(s)); }
static void span_back(void) { span<int> s; printf("%d", back(s)); }
static void span_first(void) { int a[3] = {1, 2, 3}; span<int> s = a; span<int> f = first(s, 4); printf("%zu", size(f)); }
static void span_last(void) { int a[3] = {1, 2, 3}; span<int> s = a; span<int> l = last(s, 4); printf("%zu", size(l)); }
static void span_subspan(void) { int a[3] = {1, 2, 3}; span<int> s = a; span<int> m = subspan(s, 4); printf("%zu", size(m)); }
static void span_count(void) { int a[3] = {1, 2, 3}; span<int> s = a; span<int> m = subspan(s, 1, 3); printf("%zu", size(m)); }
static void span_ok(void) {
    int a[3] = {1, 2, 3};
    span<int> s = a;
    span<int> e = subspan(s, 3);
    span<int> f = first(s, 3);
    span<int> l = last(s, 0);
    span<int> m = subspan(s, 1, 2);
    span<int> d = subspan(s, 3, dynamic_extent);
    printf("%zu %zu %zu %zu %zu", size(e), size(f), size(l), size(m), size(d));
}
static void optional_value(void) { optional<int> o; printf("%d", value(o)); }
static void variant_get_index(void) { variant<int, double> v; printf("%g", get<1>(v)); }
static void variant_get_type(void) { variant<int, double> v = 2.5; printf("%d", get<int>(v)); }
typedef struct spot { int x, y; } spot;
static void unique_ptr_deref(void) { unique_ptr<int> p; printf("%d", *p); }
static void unique_ptr_arrow(void) { unique_ptr<spot> p; printf("%d", p->x); }
static void unique_ptr_ok(void) {
    unique_ptr<int> p;
    unique_ptr<int> q = make_unique<int>(3);
    printf("%d %d", get(p) == 0, *q);
}
static void variant_ok(void) {
    variant<int, double> v = 2.5;
    int *q = get_if<int>(&v);
    get<1>(v) += 1;
    double d = get<double>(v);
    emplace<0>(v, 3) += 1;
    printf("%d %g %d", q != 0, d, get<int>(v));
}
static void optional_ok(void) {
    optional<int> o;
    optional<int> p = 3;
    int s = value_or(o, 1) + value(p);
    *emplace(o, 4) += s;
    reset(p);
    p = nullopt;
    printf("%d %d", value(o), value_or(p, 2));
}
int main(void) {
    printf("vector: at %d, index %d, front %d, pop_back %d, ", stopped(vector_at), stopped(vector_index),
           stopped(vector_front), stopped(vector_pop));
    printf("insert %d, erase %d; in its bounds %d\n", stopped(vector_insert), stopped(vector_erase),
           stopped(vector_ok));
    printf("array: at %d, index %d, a literal of too many %d\n", stopped(array_at), stopped(array_index),
           stopped(array_literal));
    printf("deque: at %d, back %d, pop_front %d, erase %d\n", stopped(deque_at), stopped(deque_back),
           stopped(deque_pop_front), stopped(deque_erase));
    printf("list: a place that is none %d, an erased element's %d, the end's %d, next of the end %d, pop_front %d, ",
           stopped(list_place), stopped(list_erased), stopped(list_end), stopped(list_next_end), stopped(list_pop));
    printf("splice of itself %d\n", stopped(list_splice));
    printf("forward_list: an erased element's place %d, erase_after the last %d, front %d\n",
           stopped(forward_list_place), stopped(forward_list_erase), stopped(forward_list_front));
    printf("stack: top %d, pop %d; queue: front %d, pop %d; priority_queue: top %d, pop %d\n", stopped(stack_top),
           stopped(stack_pop), stopped(queue_front), stopped(queue_pop), stopped(heap_top), stopped(heap_pop));
    printf("set: the end's key %d, a place after an insert %d, after clear %d, after swap %d, erase_at of one %d\n",
           stopped(set_key_end), stopped(set_stale), stopped(set_clear), stopped(set_swap), stopped(set_erase_at));
    printf("set: a place after inserts of elements that are there and erases of ones that are not %d\n",
           stopped(set_kept));
    printf("multiset: a place after an insert of an equal element %d\n", stopped(multiset_stale));
    printf("map: at of no key %d, a place after a new key %d, next of the end %d; ", stopped(map_at),
           stopped(map_stale), stopped(map_next_end));
    printf("a multimap's place after a second value of its key %d\n", stopped(multimap_stale));
    printf("map: a place after writes to keys that are there and erases of keys that are not %d\n",
           stopped(map_kept));
    printf("unordered_set: the end's key %d, a place after an insert %d, erase_at of one %d\n",
           stopped(uset_key_end), stopped(uset_stale), stopped(uset_erase_at));
    printf("unordered_set: a place after a reserve that makes a new table %d, after one that makes none %d, ",
           stopped(uset_reserve), stopped(uset_reserve_small));
    printf("after rehash %d\n", stopped(uset_rehash));
    printf("unordered_set: a place after inserts of elements that are there and erases of ones that are not %d\n",
           stopped(uset_kept));
    printf("unordered_map: at of no key %d, a place after a new key %d, next of the end %d; ", stopped(umap_at),
           stopped(umap_stale), stopped(umap_next_end));
    printf("an unordered_multimap's place after a second value of its key %d\n", stopped(umultimap_stale));
    printf("unordered_map: a place after writes to keys that are there and erases of keys that are not %d\n",
           stopped(umap_kept));
    printf("bitset: test %d, [] %d, a bit written %d, set %d and %d, reset %d, flip %d; ", stopped(bitset_test),
           stopped(bitset_item), stopped(bitset_write), stopped(bitset_set), stopped(bitset_set_to),
           stopped(bitset_reset), stopped(bitset_flip));
    printf("to_ullong of a bit past its width %d, to_ulong %d; a text with a letter %d, with one past the bits taken ",
           stopped(bitset_wide), stopped(bitset_wide_long), stopped(bitset_text));
    printf("%d; in its bounds %d\n", stopped(bitset_text_past), stopped(bitset_ok));
    printf("string: at %d, [] past the NUL %d, front %d, back %d, pop_back %d, insert %d, erase %d, replace %d, ",
           stopped(string_at), stopped(string_index), stopped(string_front), stopped(string_back), stopped(string_pop),
           stopped(string_insert), stopped(string_erase), stopped(string_replace));
    printf("substr %d, of no character %d, copy %d, compare %d, a part of another past its end %d, at npos %d, ",
           stopped(string_substr), stopped(string_substr_none), stopped(string_copy), stopped(string_compare),
           stopped(string_part), stopped(string_part_far));
    printf("reserve past max_size %d, a text's count past it %d, a count of characters past it %d\n",
           stopped(string_reserve), stopped(string_count), stopped(string_fill));
    printf("string: stoi of no number %d, past an int %d; stoul past its range %d; stod of no number %d; ",
           stopped(string_stoi_none), stopped(string_stoi_past), stopped(string_stoul_past), stopped(string_stod_none));
    printf("in its bounds, each change at the place after the last character %d\n", stopped(string_ok));
    printf("string_view: at %d, [] %d, front %d, back %d, remove_prefix %d, remove_suffix %d, substr %d, copy %d, ",
           stopped(view_at), stopped(view_index), stopped(view_front), stopped(view_back), stopped(view_prefix),
           stopped(view_suffix), stopped(view_substr), stopped(view_copy));
    printf("compare %d, compare of another's part %d; in its bounds, at the place after the last character %d\n",
           stopped(view_compare), stopped(view_compare_other), stopped(view_ok));
    printf("span: at %d, [] %d, front %d, back %d, first %d, last %d, subspan %d, a count past the end %d; ",
           stopped(span_at), stopped(span_index), stopped(span_front), stopped(span_back), stopped(span_first),
           stopped(span_last), stopped(span_subspan), stopped(span_count));
    printf("in its bounds %d\n", stopped(span_ok));
    printf("optional: value of none %d; in its bounds %d\n", stopped(optional_value), stopped(optional_ok));
    printf("variant: get of an index that it does not hold %d, of a type %d; in its bounds %d\n",
           stopped(variant_get_index), stopped(variant_get_type), stopped(variant_ok));
    printf("unique_ptr: *p of an empty one %d, p->m %d; in its bounds %d\n", stopped(unique_ptr_deref),
           stopped(unique_ptr_arrow), stopped(unique_ptr_ok));
    return 0;
}
