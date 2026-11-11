/* <list.pl> (0.277; CCLLIB.md's phase 1a): the whole surface of ccllib's list, each function once at least. cicilang
   builds this file as C and cicilang++ as C++; list.cpp is its twin over std::list, which clang++ builds over libc++:
   the three print the same lines, list.expect. With a count, `list 1000000', it fills a list of that many numbers,
   takes some away, sorts it, takes the doubles away, turns it round and walks it: the run that the costs time. After
   it comes a walk of chance over the operations at a place */
#include <stdio.h>
#include <stdlib.h>
#include <list.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const list<int> *l) {
    printf("%s:", what);
    for (size_t p = begin(l); p != end(l); p = next(l, p)) printf(" %d", at(l, p));
    printf(" | %zu\n", size(l));
}
static int odd(int x) { return x & 1; }
static int greater(int a, int b) { return a > b; }
static int same_tens(int a, int b) { return a / 10 == b / 10; }
static long total(list<int> l) {
    long s = 0;
    for (size_t p = begin(l); p != end(l); p = next(l, p)) s += l[p];
    return s;
}
static int many(long n) {
    list<int> l;
    unsigned x = 12345;
    long s = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        if (i % 8 == 5) push_front(l, (int)((x >> 8) % 100000));
        else push_back(l, (int)((x >> 8) % 100000));
    }
    size_t gone = remove(l, 7);
    size_t p = begin(l);
    for (long i = 0; i < n / 2 && p != end(l); i++) p = i % 3 == 0 ? erase(l, p) : next(l, p);
    sort(l);
    size_t doubles = unique(l);
    reverse(l);
    for (size_t q = begin(l); q != end(l); q = next(l, q)) s += at(l, q) % 7;
    printf("%zu %zu %zu %ld %d %d\n", size(l), gone, doubles, s, front(l), back(l));
    return 0;
}
/* a walk of chance over every operation at a place, 300,000 steps at most, with a place c that the walk keeps: what
   each step leaves is put into one number. The place stays its element's over every insert, every erase of another
   element, a sort and a turn round */
static int walk(long n) {
    list<int> l;
    list<int> o;
    unsigned x = 54321;
    unsigned long h = 0;
    size_t c = end(l);
    int three[3] = {1, 2, 3};
    if (n > 300000) n = 300000;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned op = (x >> 16) % 16, r = (x >> 8) & 0xffff;
        size_t z = size(l);
        if (op < 3) push_back(l, (int)(r % 512));
        else if (op < 5) push_front(l, (int)(r % 512));
        else if (op == 5 && z) { if (c == prev(l, end(l))) c = end(l); h += (unsigned long)pop_back(l); }
        else if (op == 6 && z) { if (c == begin(l)) c = end(l); h += (unsigned long)pop_front(l); }
        else if (op == 7) insert(l, c, (int)(i % 512));
        else if (op == 8) insert(l, c, r % 4, (int)(i % 512));
        else if (op == 9 && c != end(l)) c = erase(l, c);
        else if (op == 10) c = c == end(l) ? begin(l) : next(l, c);
        else if (op == 11) c = c == begin(l) ? end(l) : prev(l, c);
        else if (op == 12 && c != end(l)) h = h * 31 + (unsigned long)at(l, c);
        else if (op == 13 && c != end(l)) l[c] = (int)(i % 512);
        else if (op == 14 && r % 64 == 0) reverse(l);
        else if (op == 14 && r % 64 == 1) sort(l);
        else if (op == 14 && r % 64 == 2) { c = end(l); h += unique(l); }
        else if (op == 14 && r % 64 == 3) { c = end(l); h += remove(l, (int)(r % 512)); }
        else if (op == 14 && r % 64 == 4) { c = end(l); resize(l, z / 2); }
        else if (op == 14 && r % 64 == 5) resize(l, z + r % 7, -1);
        else if (op == 15 && r % 256 == 0) {
            insert_range(l, c, three, 3);
            prepend_range(l, three, 2);
            append_range(l, three, 1);
        }
        else if (op == 15 && r % 256 == 1) { assign_range(o, three, 3); splice(l, c, o); }
        else if (op == 15 && r % 256 == 2) { assign(o, 2, 7); sort(l); merge(l, o); }
        h = h * 131 + size(l) + (c != end(l) ? (unsigned long)at(l, c) : 7u);
    }
    for (size_t p = begin(l); p != end(l); p = next(l, p)) h = h * 31 + (unsigned long)l[p];
    printf("%lu %zu\n", h, size(l));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1])) + walk(atol(argv[1]));
    list<int> l;
    printf("%d %zu %d\n", empty(l), size(l), max_size(l) > 1000000);
    push_back(l, 5); push_front(l, 3); push(l, 9); emplace_back(l, 1); emplace_front(l, 4);
    show("push", &l);
    printf("%d %d %zu %zu\n", front(l), back(l), size(l), len(l));
    size_t p = next(l, begin(l));
    l[p] = 42;
    printf("%d %d %d\n", at(l, p), at(l, prev(l, p)), at(l, prev(l, end(l))));
    show("index", &l);
    size_t q = insert(l, p, 11);
    insert(l, end(l), 12);
    insert(l, begin(l), 2, 8);
    emplace(l, q, 6);
    show("insert", &l);
    printf("%d %d\n", at(l, p), at(l, q));
    int more[3] = {70, 71, 72};
    size_t r = insert_range(l, q, more, 3);
    append_range(l, more, 2);
    prepend_range(l, more, 1);
    show("ranges", &l);
    printf("%d\n", at(l, r));
    r = erase(l, begin(l));
    printf("%d\n", at(l, r));
    erase(l, next(l, begin(l)), q);
    show("erase", &l);
    int last = pop_back(l);
    int before = pop(l);
    int first = pop_front(l);
    printf("%d %d %d\n", last, before, first);
    push_back(l, 9); push_front(l, 9);
    size_t gone = remove(l, 9);
    show("remove", &l);
    printf("%zu %zu\n", gone, erase_value(l, 12));
    for (int i = 0; i < 12; i++) push_back(l, i * 7 % 5 + i % 2 * 10);
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
    resize(l, 3);
    show("resize", &l);
    resize(l, 5);
    resize(l, 7, -4);
    show("resize up", &l);
    list<int> w = [1, 5, 9];
    list<int> u = [2, 5, 6, 10];
    merge(w, u);
    show("merge", &w);
    show("merged", &u);
    list<int> g = [9, 4];
    list<int> h = [7, 5, 1];
    merge(g, h, greater);
    show("merge by", &g);
    c := clone(w);
    push_back(c, 4);
    printf("%d %d %d %d %d %d\n", w == c, w != c, w < c, w > c, w <= c, w >= c);
    swap(w, c);
    show("swap", &w);
    show("swap", &c);
    splice(c, next(c, begin(c)), g);
    show("splice", &c);
    show("spliced", &g);
    splice(c, begin(c), w, prev(w, end(w)));
    show("splice one", &c);
    show("spliced one", &w);
    splice(c, end(c), w, next(w, begin(w)), prev(w, end(w)));
    show("splice some", &c);
    show("spliced some", &w);
    assign(w, 3, 6);
    assign_range(c, more, 3);
    show("assign", &w);
    show("assign", &c);
    clear(w);
    printf("%d %zu\n", empty(w), size(w));
    list<double> f = [2.5, -1, 0.25];
    push_front(f, 4);
    double fs = 0;
    for (size_t i = begin(f); i != end(f); i = next(f, i)) fs += f[i];
    printf("%g %g %g %zu\n", fs, front(f), back(f), size(f));
    list<point> ps;
    push_back(ps, (point){1, 2});
    push_front(ps, (point){3, 4});
    ps[begin(ps)].y = 20;
    printf("%d %d %d %zu\n", front(ps).x, front(ps).y, back(ps).y, size(ps));
    printf("%ld\n", total(l));
    return 0;
}
