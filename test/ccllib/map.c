/* <map.pl> (0.281; CCLLIB.md's phase 1a): the whole surface of ccllib's map and multimap, each function once at least.
   cicilang builds this file as C and cicilang++ as C++; map.cpp is its twin over std::map and std::multimap, which
   clang++ builds over libc++: the three print the same lines, map.expect. With a count, `map 300000', it counts that
   many numbers in a map, asks for as many, takes half of as many away and walks the map: the run that the costs
   time. After it comes a walk of chance over the operations of a map and of a multimap, in which a place is used
   after the calls that change no entry */
#include <stdio.h>
#include <stdlib.h>
#include <map.pl>
typedef struct point { int x, y; } point;
static int later(int a, int b) { return a > b; }
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static void show(const char *what, const map<int, long> *m) {
    printf("%s:", what);
    for (size_t p = begin(m); p != end(m); p = next(m, p)) printf(" %d=%ld", key(m, p), value(m, p));
    printf(" | %zu\n", size(m));
}
static void show_multi(const char *what, const multimap<int, long> *m) {
    printf("%s:", what);
    for (size_t p = begin(m); p != end(m); p = next(m, p)) printf(" %d=%ld", key(m, p), value(m, p));
    printf(" | %zu\n", size(m));
}
static long total(map<int, long> m) {
    long t = 0;
    for (size_t p = begin(m); p != end(m); p = next(m, p)) t += key(m, p) * value(m, p);
    return t;
}
static int many(long n) {
    map<int, int> m;
    long hits = 0, sum = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) m[(int)(rnd() % (unsigned)n)] += 1;
    for (long i = 0; i < n; i++) { int k = (int)(rnd() % (unsigned)n); if (contains(m, k)) hits += at(m, k); }
    for (long i = 0; i < n / 2; i++) hits += (long)erase(m, (int)(rnd() % (unsigned)n));
    for (size_t p = begin(m); p != end(m); p = next(m, p)) sum += key(m, p) % 5 + value(m, p);
    printf("%zu %ld %ld\n", size(m), hits, sum);
    return 0;
}
/* a walk of chance over a map's operations, n steps: what each leaves is put into one number */
static unsigned long walk_map(long n, int range) {
    map<int, long> m;
    unsigned long h = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 3) h = h * 3 + (unsigned long)insert(m, k, i);
        else if (op < 5) h = h * 3 + (unsigned long)insert_or_assign(m, k, i * 2);
        else if (op == 5) { m[k] += 1; h = h * 3 + (unsigned long)m[k]; }
        else if (op < 10) h = h * 3 + erase(m, k);
        else if (op == 10) h = h * 3 + (contains(m, k) ? (unsigned long)at(m, k) + (unsigned long)get(m, k) : 1u);
        else if (op == 11) {
            /* a write to a key that is there, an insert that finds its key and an erase that finds none change no
               entry: the place stays */
            size_t p = find(m, k);
            if (p != end(m)) {
                m[k] += 2;
                h += (unsigned long)insert(m, k, 0);
                h += (unsigned long)insert_or_assign(m, k, value(m, p) + 3);
                h += erase(m, range);
                set_value(m, p, value(m, p) + 5);
                h = h * 5 + (unsigned long)value(m, p);
            }
        }
        else if (op == 12) {
            size_t p = lower_bound(m, k), q = upper_bound(m, k);
            h = h * 7 + (p != end(m) ? (unsigned long)value(m, p) : 3u) + (q != end(m) ? (unsigned long)key(m, q) : 5u);
        }
        else if (op == 13) {
            size_t p = lower_bound(m, k);
            for (int j = 0; j < 5 && p != end(m); j++) {
                h = h * 3 + (unsigned long)key(m, p) + (unsigned long)value(m, p);
                p = next(m, p);
            }
        }
        else if (op == 14) {
            size_t p = lower_bound(m, k);
            if (p != end(m)) { p = erase_at(m, p); h = h * 5 + (p != end(m) ? (unsigned long)value(m, p) : 9u); }
        }
        else if (i % 4096 == 0) {
            c := clone(m);
            h = h * 3 + (unsigned long)(c == m) + (unsigned long)(c < m) + size(c);
        }
        h += size(m);
    }
    for (size_t p = begin(m); p != end(m); p = next(m, p))
        h = h * 31 + (unsigned long)key(m, p) * 3 + (unsigned long)value(m, p);
    return h;
}
static unsigned long walk_multimap(long n, int range) {
    multimap<int, long> m;
    unsigned long h = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) h = h * 3 + (unsigned long)insert(m, k, i);
        else if (op < 8) h = h * 3 + erase(m, k);
        else if (op < 10) {
            size_t p = lower_bound(m, k);
            if (p != end(m) && key(m, p) == k) {
                if (rnd() % 2 && next(m, p) != end(m)) p = next(m, p);
                h = h * 5 + (unsigned long)value(m, p);
                p = erase_at(m, p);
                h = h * 5 + (p != end(m) ? (unsigned long)value(m, p) : 9u);
            }
        }
        else if (op == 10) h = h * 3 + count(m, k);
        else if (op == 12) {
            size_t p = lower_bound(m, k), q = upper_bound(m, k);
            h = h * 7 + (p != end(m) ? (unsigned long)value(m, p) : 3u)
                + (q != end(m) ? (unsigned long)value(m, q) : 5u);
        }
        else if (op == 13) {
            size_t p = lower_bound(m, k);
            for (int j = 0; j < 5 && p != end(m); j++) {
                h = h * 3 + (unsigned long)key(m, p) + (unsigned long)value(m, p);
                p = next(m, p);
            }
            for (int j = 0; j < 7; j++) {
                p = prev(m, p);
                if (p == begin(m)) break;
                h = h * 3 + (unsigned long)value(m, p);
            }
        }
        h += size(m);
    }
    for (size_t p = begin(m); p != end(m); p = next(m, p))
        h = h * 31 + (unsigned long)key(m, p) * 3 + (unsigned long)value(m, p);
    return h;
}
static int walk(long n) {
    if (n > 100000) n = 100000;
    seed = 54321;
    printf("%lu %lu ", walk_map(n, 64), walk_map(n, 100000));
    printf("%lu %lu\n", walk_multimap(n, 64), walk_multimap(n, 20000));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1])) + walk(atol(argv[1]));
    map<int, long> m;
    printf("%d %zu %d\n", empty(m), size(m), max_size(m) > 1000000);
    for (int i = 0; i < 40; i++) printf("%d", insert(m, i * 7 % 23, (long)i * 10));
    printf(" %d %d %d\n", emplace(m, 100, 1), try_emplace(m, 100, 2), try_emplace(m, 101, 3));
    show("insert", &m);
    printf("%zu %zu %d %d %zu %zu\n", size(m), len(m), contains(m, 5), contains(m, 99), count(m, 7), count(m, 99));
    printf("%ld %ld %ld\n", at(m, 7), get(m, 14), m[21]);
    m[21] = 5;
    m[300] += 7;
    m[300] += 7;
    printf("%d %d %ld %ld\n", insert_or_assign(m, 7, 77), insert_or_assign(m, 400, 4), at(m, 7), m[300]);
    put(m, 8, 88);
    size_t p = find(m, 9);
    set_value(m, p, 99);
    printf("%d %ld %d %d %d\n", key(m, p), value(m, p), key(m, next(m, p)), key(m, prev(m, p)), find(m, 50) == end(m));
    printf("%d %d %d %d\n", key(m, lower_bound(m, 10)), key(m, upper_bound(m, 10)), key(m, lower_bound(m, 23)),
           upper_bound(m, 400) == end(m));
    printf("%zu %zu %d\n", erase(m, 5), erase(m, 5), key(m, prev(m, end(m))));
    p = erase_at(m, find(m, 9));
    printf("%d %ld\n", key(m, p), value(m, p));
    show("erase", &m);
    map<int, long> t = [70: 7, 3: 333, 80: 8];
    merge(m, t);
    show("merge", &m);
    show("merged", &t);
    c := clone(m);
    c[0] = -1;
    printf("%d %d %d %d %d %d\n", m == c, m != c, m < c, m > c, m <= c, m >= c);
    swap(m, c);
    printf("%ld %ld\n", at(m, 0), at(c, 0));
    clear(c);
    printf("%d %zu\n", empty(c), size(c));
    map<int, double, later> d = [5: 0.5, 3: 0.25, 9: 1.5];
    d[4] = 2;
    for (size_t q = begin(d); q != end(d); q = next(d, q)) printf("%d=%g ", key(d, q), value(d, q));
    printf("| %zu %d\n", size(d), key(d, lower_bound(d, 6)));
    map<int, point> ps;
    ps[3] = (point){3, 30};
    ps[1] = (point){1, 10};
    ps[3].y = 31;
    printf("%d %d %d %zu\n", at(ps, 3).y, at(ps, 1).x, value(ps, begin(ps)).y, size(ps));
    e := [int:double; 1: 2.5, 2: 0.5];
    printf("%g %g %zu\n", at(e, 1), e[2], size(e));
    multimap<int, long> mm;
    for (int i = 0; i < 12; i++) insert(mm, i * 5 % 4, (long)i);
    emplace(mm, 2, 100);
    show_multi("multimap", &mm);
    printf("%zu %zu %d %ld %d\n", count(mm, 2), count(mm, 9), contains(mm, 3), value(mm, find(mm, 1)),
           key(mm, upper_bound(mm, 1)));
    p = erase_at(mm, next(mm, lower_bound(mm, 2)));
    printf("%d %ld %zu %zu %zu\n", key(mm, p), value(mm, p), count(mm, 2), erase(mm, 3), size(mm));
    multimap<int, long> mt;
    insert(mt, 2, 500);
    insert(mt, 0, 600);
    merge(mm, mt);
    mc := clone(mm);
    show_multi("multimap merge", &mm);
    printf("%zu %d %d\n", size(mt), mm == mc, mm < mc);
    printf("%ld\n", total(m));
    return 0;
}
