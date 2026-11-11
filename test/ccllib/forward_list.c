/* <forward_list.pl> (0.278; CCLLIB.md's phase 1a): the whole surface of ccllib's forward_list, each function once at
   least. cicilang builds this file as C and cicilang++ as C++; forward_list.cpp is its twin over std::forward_list,
   which clang++ builds over libc++: the three print the same lines, forward_list.expect. With a count,
   `forward_list 1000000', it fills a list of that many numbers, takes some away, sorts it, takes the doubles away,
   turns it round and walks it: the run that the costs time. After it comes a walk of chance over the operations at a
   place */
#include <stdio.h>
#include <stdlib.h>
#include <forward_list.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const forward_list<int> *l) {
    size_t n = 0;
    printf("%s:", what);
    for (size_t p = begin(l); p != end(l); p = next(l, p)) { printf(" %d", at(l, p)); n++; }
    printf(" | %zu\n", n);
}
static int odd(int x) { return x & 1; }
static int greater(int a, int b) { return a > b; }
static int same_tens(int a, int b) { return a / 10 == b / 10; }
static long total(forward_list<int> l) {
    long s = 0;
    for (size_t p = begin(l); p != end(l); p = next(l, p)) s += l[p];
    return s;
}
static int many(long n) {
    forward_list<int> l;
    unsigned x = 12345;
    long s = 0;
    size_t count = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        push_front(l, (int)((x >> 8) % 100000));
    }
    size_t gone = remove(l, 7);
    size_t p = before_begin(l);
    for (long i = 0; i < n / 2 && next(l, p) != end(l); i++) {
        if (i % 3 == 0) erase_after(l, p);
        else p = next(l, p);
    }
    sort(l);
    size_t doubles = unique(l);
    reverse(l);
    for (size_t q = begin(l); q != end(l); q = next(l, q)) { s += at(l, q) % 7; count++; }
    printf("%zu %zu %zu %ld %d\n", count, gone, doubles, s, front(l));
    return 0;
}
/* a walk of chance over every operation at a place, 300,000 steps at most, with a place c that the walk keeps: what
   each step leaves is put into one number. The place stays its element's over every insert, every erase of another
   element, a sort and a turn round */
static int walk(long n) {
    forward_list<int> l;
    forward_list<int> o;
    unsigned x = 54321;
    unsigned long h = 0;
    size_t c = before_begin(l);
    int three[3] = {1, 2, 3};
    if (n > 300000) n = 300000;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned op = (x >> 16) % 16, r = (x >> 8) & 0xffff;
        if (op < 4) push_front(l, (int)(r % 512));
        else if (op == 4 && !empty(l)) { if (c == begin(l)) c = before_begin(l); h += (unsigned long)pop_front(l); }
        else if (op < 7) insert_after(l, c, (int)(i % 512));
        else if (op == 7) insert_after(l, c, r % 4, (int)(i % 512));
        else if (op < 10 && next(l, c) != end(l)) erase_after(l, c);
        else if (op == 10 || op == 11) c = next(l, c) == end(l) ? before_begin(l) : next(l, c);
        else if (op == 12 && c != before_begin(l)) h = h * 31 + (unsigned long)at(l, c);
        else if (op == 13 && c != before_begin(l)) l[c] = (int)(i % 512);
        else if (op == 14 && r % 64 == 0) reverse(l);
        else if (op == 14 && r % 64 == 1) sort(l);
        else if (op == 14 && r % 64 == 2) { c = before_begin(l); h += unique(l); }
        else if (op == 14 && r % 64 == 3) { c = before_begin(l); h += remove(l, (int)(r % 512)); }
        else if (op == 14 && r % 64 == 4) { c = before_begin(l); resize(l, size(l) / 2); }
        else if (op == 14 && r % 64 == 5) resize(l, size(l) + r % 7, -1);
        else if (op == 15 && r % 256 == 0) { insert_range_after(l, c, three, 3); prepend_range(l, three, 2); }
        else if (op == 15 && r % 256 == 1) { assign_range(o, three, 3); splice_after(l, c, o); }
        else if (op == 15 && r % 256 == 2) { assign(o, 2, 7); sort(l); merge(l, o); }
        h = h * 131 + size(l) + (c != before_begin(l) ? (unsigned long)at(l, c) : 7u);
    }
    for (size_t p = begin(l); p != end(l); p = next(l, p)) h = h * 31 + (unsigned long)l[p];
    printf("%lu %zu\n", h, size(l));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1])) + walk(atol(argv[1]));
    forward_list<int> l;
    printf("%d %d\n", empty(l), max_size(l) > 1000000);
    push_front(l, 5); push_front(l, 3); emplace_front(l, 4);
    show("push", &l);
    printf("%d %zu %zu\n", front(l), size(l), len(l));
    size_t p = next(l, begin(l));
    l[p] = 42;
    printf("%d %d\n", at(l, p), at(l, next(l, before_begin(l))));
    show("index", &l);
    size_t q = insert_after(l, p, 11);
    insert_after(l, before_begin(l), 2, 8);
    emplace_after(l, q, 6);
    show("insert", &l);
    printf("%d %d\n", at(l, p), at(l, q));
    int more[3] = {70, 71, 72};
    size_t r = insert_range_after(l, q, more, 3);
    prepend_range(l, more, 2);
    show("ranges", &l);
    printf("%d\n", at(l, r));
    r = erase_after(l, before_begin(l));
    printf("%d\n", at(l, r));
    erase_after(l, begin(l), q);
    show("erase", &l);
    erase_after(l, begin(l), next(l, begin(l)));
    show("erase none", &l);
    int first = pop_front(l);
    printf("%d\n", first);
    push_front(l, 9); insert_after(l, q, 9);
    size_t gone = remove(l, 9);
    show("remove", &l);
    printf("%zu %zu\n", gone, erase_value(l, 72));
    for (int i = 0; i < 12; i++) push_front(l, i * 7 % 5 + i % 2 * 10);
    show("more", &l);
    printf("%zu\n", remove_if(l, odd));
    show("remove_if", &l);
    sort(l);
    show("sort", &l);
    printf("%zu\n", unique(l));
    show("unique", &l);
    printf("%zu\n", unique(l, same_tens));
    show("unique by", &l);
    sort(l, greater);
    show("sort by", &l);
    reverse(l);
    show("reverse", &l);
    resize(l, 2);
    show("resize", &l);
    resize(l, 4);
    resize(l, 6, -4);
    show("resize up", &l);
    forward_list<int> w = [1, 5, 9];
    forward_list<int> u = [2, 5, 6, 10];
    merge(w, u);
    show("merge", &w);
    show("merged", &u);
    forward_list<int> g = [9, 4];
    forward_list<int> h = [7, 5, 1];
    merge(g, h, greater);
    show("merge by", &g);
    c := clone(w);
    push_front(c, 0);
    printf("%d %d %d %d %d %d\n", w == c, w != c, w < c, w > c, w <= c, w >= c);
    swap(w, c);
    show("swap", &w);
    show("swap", &c);
    splice_after(c, begin(c), g);
    show("splice", &c);
    show("spliced", &g);
    splice_after(c, before_begin(c), w, begin(w));
    show("splice one", &c);
    show("spliced one", &w);
    splice_after(c, begin(c), w, begin(w), end(w));
    show("splice some", &c);
    show("spliced some", &w);
    assign(w, 3, 6);
    assign_range(c, more, 3);
    show("assign", &w);
    show("assign", &c);
    clear(w);
    printf("%d\n", empty(w));
    forward_list<double> f = [2.5, -1, 0.25];
    push_front(f, 4);
    double fs = 0;
    for (size_t i = begin(f); i != end(f); i = next(f, i)) fs += f[i];
    printf("%g %g\n", fs, front(f));
    forward_list<point> ps;
    push_front(ps, (point){1, 2});
    push_front(ps, (point){3, 4});
    ps[begin(ps)].y = 20;
    printf("%d %d %d\n", front(ps).x, front(ps).y, at(ps, next(ps, begin(ps))).y);
    printf("%ld\n", total(l));
    return 0;
}
