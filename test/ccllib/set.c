/* <set.pl> (0.281; CCLLIB.md's phase 1a): the whole surface of ccllib's set and multiset, each function once at least.
   cicilang builds this file as C and cicilang++ as C++; set.cpp is its twin over std::set and std::multiset, which
   clang++ builds over libc++: the three print the same lines, set.expect. With a count, `set 300000', it puts that
   many numbers into a set, asks for as many, takes half of as many away and walks the set: the run that the costs
   time. After it comes a walk of chance over the operations of a set and of a multiset, in which a place is used
   after an insert that finds its element and an erase that finds none */
#include <stdio.h>
#include <stdlib.h>
#include <set.pl>
typedef struct point { int x, y; } point;
static int later(int a, int b) { return a > b; }
static int by_x(point a, point b) { return a.x < b.x; }
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static void show(const char *what, const set<int> *s) {
    printf("%s:", what);
    for (size_t p = begin(s); p != end(s); p = next(s, p)) printf(" %d", key(s, p));
    printf(" | %zu\n", size(s));
}
static void show_multi(const char *what, const multiset<int> *s) {
    printf("%s:", what);
    for (size_t p = begin(s); p != end(s); p = next(s, p)) printf(" %d", key(s, p));
    printf(" | %zu\n", size(s));
}
static long total(set<int> s) {
    long t = 0;
    for (size_t p = begin(s); p != end(s); p = next(s, p)) t += key(s, p);
    return t;
}
static int many(long n) {
    set<int> s;
    long hits = 0, sum = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) insert(s, (int)rnd());
    for (long i = 0; i < n; i++) hits += contains(s, (int)rnd());
    for (long i = 0; i < n / 2; i++) hits += (long)erase(s, (int)rnd());
    for (size_t p = begin(s); p != end(s); p = next(s, p)) sum += key(s, p) % 7;
    printf("%zu %ld %ld\n", size(s), hits, sum);
    return 0;
}
/* a walk of chance over a set's operations, n steps: what each leaves is put into one number */
static unsigned long walk_set(long n, int range) {
    set<int> s;
    unsigned long h = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) h = h * 3 + (unsigned long)insert(s, k);
        else if (op < 10) h = h * 3 + erase(s, k);
        else if (op == 10) h = h * 3 + (unsigned long)contains(s, k) + count(s, k);
        else if (op == 11) {
            /* an insert that finds its element and an erase that finds none change nothing: the place stays */
            size_t p = find(s, k);
            if (p != end(s)) { h += (unsigned long)insert(s, k); h += erase(s, range); }
            h = h * 5 + (p != end(s) ? (unsigned long)key(s, p) : 1u);
        }
        else if (op == 12) {
            size_t p = lower_bound(s, k), q = upper_bound(s, k);
            h = h * 7 + (p != end(s) ? (unsigned long)key(s, p) : 3u) + (q != end(s) ? (unsigned long)key(s, q) : 5u);
        }
        else if (op == 13) {
            size_t p = lower_bound(s, k);
            for (int j = 0; j < 5 && p != end(s); j++) { h = h * 3 + (unsigned long)key(s, p); p = next(s, p); }
            for (int j = 0; j < 7; j++) {
                p = prev(s, p);
                if (p == begin(s)) break;
                h = h * 3 + (unsigned long)key(s, p);
            }
        }
        else if (op == 14) {
            size_t p = lower_bound(s, k);
            if (p != end(s)) { p = erase_at(s, p); h = h * 5 + (p != end(s) ? (unsigned long)key(s, p) : 9u); }
        }
        else if (i % 4096 == 0) { c := clone(s); h = h * 3 + (unsigned long)(c == s) + size(c); }
        h += size(s);
    }
    for (size_t p = begin(s); p != end(s); p = next(s, p)) h = h * 31 + (unsigned long)key(s, p);
    return h;
}
static unsigned long walk_multiset(long n, int range) {
    multiset<int> s;
    unsigned long h = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) h = h * 3 + (unsigned long)insert(s, k);
        else if (op < 8) h = h * 3 + erase(s, k);
        else if (op < 10) {
            size_t p = lower_bound(s, k);
            if (p != end(s) && key(s, p) == k) {
                p = erase_at(s, p);
                h = h * 5 + (p != end(s) ? (unsigned long)key(s, p) : 9u);
            }
        }
        else if (op == 10) h = h * 3 + (unsigned long)contains(s, k) + count(s, k);
        else if (op == 12) {
            size_t p = lower_bound(s, k), q = upper_bound(s, k);
            h = h * 7 + (p != end(s) ? (unsigned long)key(s, p) : 3u) + (q != end(s) ? (unsigned long)key(s, q) : 5u);
        }
        else if (op == 13) {
            size_t p = lower_bound(s, k);
            for (int j = 0; j < 5 && p != end(s); j++) { h = h * 3 + (unsigned long)key(s, p); p = next(s, p); }
            for (int j = 0; j < 7; j++) {
                p = prev(s, p);
                if (p == begin(s)) break;
                h = h * 3 + (unsigned long)key(s, p);
            }
        }
        h += size(s);
    }
    for (size_t p = begin(s); p != end(s); p = next(s, p)) h = h * 31 + (unsigned long)key(s, p);
    return h;
}
static int walk(long n) {
    if (n > 100000) n = 100000;
    seed = 54321;
    printf("%lu %lu ", walk_set(n, 64), walk_set(n, 100000));
    printf("%lu %lu\n", walk_multiset(n, 64), walk_multiset(n, 20000));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1])) + walk(atol(argv[1]));
    set<int> s;
    printf("%d %zu %d\n", empty(s), size(s), max_size(s) > 1000000);
    for (int i = 0; i < 40; i++) printf("%d", insert(s, i * 7 % 23));
    printf(" %d\n", emplace(s, 100));
    show("insert", &s);
    printf("%zu %zu %d %d %zu %zu\n", size(s), len(s), contains(s, 5), contains(s, 99), count(s, 7), count(s, 99));
    size_t p = find(s, 9);
    printf("%d %d %d %d\n", key(s, p), key(s, next(s, p)), key(s, prev(s, p)), find(s, 50) == end(s));
    printf("%d %d %d %d\n", key(s, lower_bound(s, 10)), key(s, upper_bound(s, 10)), key(s, lower_bound(s, 23)),
           upper_bound(s, 100) == end(s));
    printf("%zu %zu %d\n", erase(s, 5), erase(s, 5), key(s, prev(s, end(s))));
    p = erase_at(s, find(s, 9));
    printf("%d\n", key(s, p));
    int more[4] = {50, 3, 60, 50};
    insert_range(s, more, 4);
    show("erase", &s);
    set<int> t = [70, 3, 80, 4];
    merge(s, t);
    show("merge", &s);
    show("merged", &t);
    c := clone(s);
    insert(c, 1000);
    printf("%d %d %d %d %d %d\n", s == c, s != c, s < c, s > c, s <= c, s >= c);
    swap(s, c);
    printf("%zu %zu\n", size(s), size(c));
    clear(c);
    printf("%d %zu\n", empty(c), size(c));
    set<int, later> d = [5, 3, 9, 1];
    insert(d, 4);
    for (size_t q = begin(d); q != end(d); q = next(d, q)) printf("%d ", key(d, q));
    printf("| %zu %d\n", size(d), key(d, lower_bound(d, 6)));
    set<point, by_x> ps;
    insert(ps, (point){3, 30});
    insert(ps, (point){1, 10});
    printf("%d", insert(ps, (point){3, 99}));
    for (size_t q = begin(ps); q != end(ps); q = next(ps, q)) printf(" %d:%d", key(ps, q).x, key(ps, q).y);
    printf(" | %zu\n", size(ps));
    set<double> f = [2.5, -1, 0.25];
    printf("%g %g %zu\n", key(f, begin(f)), key(f, prev(f, end(f))), size(f));
    multiset<int> ms = [5, 3, 5, 1, 5];
    insert(ms, 3);
    emplace(ms, 9);
    show_multi("multiset", &ms);
    printf("%zu %zu %d %d %d\n", count(ms, 5), count(ms, 4), contains(ms, 3), key(ms, lower_bound(ms, 4)),
           key(ms, upper_bound(ms, 5)));
    p = erase_at(ms, lower_bound(ms, 5));
    printf("%d %zu %zu %zu\n", key(ms, p), count(ms, 5), erase(ms, 3), size(ms));
    multiset<int> mt = [5, 2];
    merge(ms, mt);
    mc := clone(ms);
    show_multi("multiset merge", &ms);
    printf("%zu %d %d\n", size(mt), ms == mc, ms < mc);
    multiset<int, later> md = [1, 7, 7, 3];
    for (size_t q = begin(md); q != end(md); q = next(md, q)) printf("%d ", key(md, q));
    printf("| %zu\n", size(md));
    printf("%ld\n", total(s));
    return 0;
}
