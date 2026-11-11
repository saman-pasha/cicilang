/* WHAT STOPS A CCLLIB PROGRAM (0.281): each case goes past what its container holds -- an index past the end, the
   front of an empty one, a place that is no element's or that a new entry of the map ended -- where C++ throws or is
   undefined. Each runs in a child of its own, and a line says for each whether abort stopped it: 1, and 0 for the
   cases that stay in their bounds, which no stop may meet (a tree's place over 4000 inserts that find their keys and
   erases that find none; a hash table's place over such calls at each of its sizes up to 4000, 0.283; a bitset's last
   bit, read and written each way, 0.286). cicilang builds this file as C and cicilang++ as C++; both print
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
    return 0;
}
