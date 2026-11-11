/* <unordered_set.pl> (0.283; CCLLIB.md's phase 1a): the whole surface of ccllib's unordered_set and
   unordered_multiset, each function once at least. cicilang builds this file as C and cicilang++ as C++;
   unordered_set.cpp is its twin over std::unordered_set and std::unordered_multiset, which clang++ builds over
   libc++: the three print the same lines, unordered_set.expect. A walk gives the elements in the table's order, which
   is not C++'s, so no line depends on it: the elements are asked for one by one, or added up. With a count,
   `unordered_set 3000000', it puts that many numbers into a set, asks for as many, takes half of as many away and
   walks the set: the run that the costs time. After it comes a walk of chance over the operations of a set and of a
   multiset, in which a place is used after an insert that finds its element and an erase that finds none, and a walk
   that erases meets each element once */
#include <stdio.h>
#include <stdlib.h>
#include <unordered_set.pl>
typedef struct point { int x, y; } point;
static unsigned long point_hash(point p) { return (unsigned long)p.x * 31u + (unsigned long)p.y; }
static int point_eq(point a, point b) { return a.x == b.x && a.y == b.y; }
static unsigned long weak(int k) { return (unsigned long)(k & 3); }
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static void show(const char *what, const unordered_set<int> *s) {
    size_t walked = 0;
    printf("%s:", what);
    for (int k = -5; k <= 1000; k++) if (contains(s, k)) printf(" %d", k);
    for (size_t p = begin(s); p != end(s); p = next(s, p)) walked++;
    printf(" | %zu %zu\n", size(s), walked);
}
static void show_multi(const char *what, const unordered_multiset<int> *s) {
    size_t walked = 0;
    printf("%s:", what);
    for (int k = -5; k <= 1000; k++) for (size_t i = 0; i < count(s, k); i++) printf(" %d", k);
    for (size_t p = begin(s); p != end(s); p = next(s, p)) walked++;
    printf(" | %zu %zu\n", size(s), walked);
}
static long total(unordered_set<int> s) {
    long t = 0;
    for (size_t p = begin(s); p != end(s); p = next(s, p)) t += key(s, p);
    return t;
}
static int many(long n) {
    unordered_set<int> s;
    long hits = 0, sum = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) insert(s, (int)(rnd() % (unsigned)(2 * n)));
    for (long i = 0; i < n; i++) hits += contains(s, (int)(rnd() % (unsigned)(2 * n)));
    for (long i = 0; i < n / 2; i++) hits += (long)erase(s, (int)(rnd() % (unsigned)(2 * n)));
    for (size_t p = begin(s); p != end(s); p = next(s, p)) sum += key(s, p) % 7;
    printf("%zu %ld %ld\n", size(s), hits, sum);
    return 0;
}
/* a walk of chance over a set's operations, n steps: what each leaves is put into one number, and nothing of it
   depends on the order of a walk */
static unsigned long walk_set(long n, int range) {
    unordered_set<int> s;
    unsigned long h = 0, sum = 0, x = 0;
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
            size_t p = find(s, k);
            if (p != end(s)) { erase_at(s, p); h = h * 5 + 9u; }
        }
        else if (op == 13 && i % 64 == 0) {
            /* a walk that erases each element under k meets every element once */
            size_t met = 0, before = size(s);
            for (size_t p = begin(s); p != end(s); ) {
                met++;
                if (key(s, p) < k) p = erase_at(s, p); else p = next(s, p);
            }
            h = h * 7 + (unsigned long)(met == before) + size(s);
        }
        else if (i % 4096 == 0) { c := clone(s); h = h * 3 + (unsigned long)(c == s) + size(c); }
        h += size(s);
        if (!empty(s)) {
            /* at each step, in whatever state the table stands: an insert that finds its element and an erase that
               finds none change nothing, and a place stays over them */
            size_t p = begin(s);
            int first = key(s, p);
            h += (unsigned long)insert(s, first);
            h += erase(s, range);
            h += (unsigned long)(key(s, p) == first);
        }
    }
    for (size_t p = begin(s); p != end(s); p = next(s, p)) {
        sum += (unsigned long)key(s, p) * 2654435761u;
        x ^= (unsigned long)key(s, p) * 40503u + 7u;
    }
    return h * 31 + sum + x;
}
static unsigned long walk_multiset(long n, int range) {
    unordered_multiset<int> s;
    unsigned long h = 0, sum = 0, x = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) h = h * 3 + (unsigned long)insert(s, k);
        else if (op < 8) h = h * 3 + erase(s, k);
        else if (op < 10) {
            size_t p = find(s, k);
            if (p != end(s)) { erase_at(s, p); h = h * 5 + count(s, k); }
        }
        else if (op == 10) h = h * 3 + (unsigned long)contains(s, k) + count(s, k);
        else if (op == 11) {
            /* each of the key's elements is found by its number */
            size_t seen = 0;
            for (size_t j = 0; j < count(s, k); j++) seen += (size_t)(key(s, find(s, k, j)) == k);
            h = h * 5 + seen + (unsigned long)(find(s, k, count(s, k)) == end(s));
        }
        else if (op == 13 && i % 64 == 0) {
            size_t met = 0, before = size(s);
            for (size_t p = begin(s); p != end(s); ) {
                met++;
                if (key(s, p) < k) p = erase_at(s, p); else p = next(s, p);
            }
            h = h * 7 + (unsigned long)(met == before) + size(s);
        }
        else if (i % 4096 == 0) { c := clone(s); h = h * 3 + (unsigned long)(c == s) + size(c); }
        h += size(s);
        if (!empty(s)) {
            /* at each step: an erase that finds none changes nothing, and a place stays over it */
            size_t p = begin(s);
            int first = key(s, p);
            h += erase(s, range);
            h += (unsigned long)(key(s, p) == first);
        }
    }
    for (size_t p = begin(s); p != end(s); p = next(s, p)) {
        sum += (unsigned long)key(s, p) * 2654435761u;
        x ^= (unsigned long)key(s, p) * 40503u + 7u;
    }
    return h * 31 + sum + x;
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
    unordered_set<int> s;
    size_t met = 0;
    printf("%d %zu %d\n", empty(s), size(s), max_size(s) > 1000000);
    for (int i = 0; i < 40; i++) printf("%d", insert(s, i * 7 % 23));
    printf(" %d\n", emplace(s, 100));
    show("insert", &s);
    printf("%zu %zu %d %d %zu %zu\n", size(s), len(s), contains(s, 5), contains(s, 99), count(s, 7), count(s, 99));
    size_t p = find(s, 9);
    printf("%d %d\n", key(s, p), find(s, 50) == end(s));
    size_t gone = erase(s, 5);
    printf("%zu %zu\n", gone, erase(s, 5));
    erase_at(s, find(s, 9));
    for (p = begin(s); p != end(s); ) {
        met++;
        if (key(s, p) % 2 == 0) p = erase_at(s, p); else p = next(s, p);
    }
    printf("%zu\n", met);
    show("odd", &s);
    int more[4] = {50, 3, 60, 50};
    insert_range(s, more, 4);
    show("range", &s);
    unordered_set<int> t = [70, 3, 80, 4];
    merge(s, t);
    show("merge", &s);
    show("merged", &t);
    c := clone(s);
    printf("%d %d", s == c, s != c);
    insert(c, 1000);
    printf(" %d %d\n", s == c, s != c);
    swap(s, c);
    printf("%zu %zu\n", size(s), size(c));
    clear(c);
    printf("%d %zu\n", empty(c), size(c));
    unordered_set<int> r;
    reserve(r, 1000);
    size_t slots = bucket_count(r);
    for (int i = 0; i < 1000; i++) insert(r, i * 3);
    printf("%d %d %d\n", bucket_count(r) == slots, load_factor(r) <= max_load_factor(r), load_factor(r) > 0);
    rehash(r, 4096);
    printf("%d %zu %d %d\n", bucket_count(r) >= 4096, size(r), contains(r, 2997), contains(r, 2998));
    unordered_set<point, point_hash, point_eq> ps;
    insert(ps, (point){3, 30});
    insert(ps, (point){1, 10});
    printf("%d %d %d %zu\n", insert(ps, (point){3, 30}), contains(ps, (point){1, 10}), contains(ps, (point){1, 11}),
           size(ps));
    unordered_set<int, weak> w;
    long sum = 0;
    for (int i = 0; i < 200; i++) insert(w, i);
    for (size_t q = begin(w); q != end(w); q = next(w, q)) sum += key(w, q);
    size_t held = size(w);
    int has = contains(w, 199);
    printf("%zu %ld %d %zu\n", held, sum, has, erase(w, 77));
    unordered_set<double> f = [2.5, -1, 0.25, 0.0];
    printf("%d %d %d %zu\n", contains(f, -0.0), contains(f, 2.5), insert(f, -0.0), size(f));
    unordered_multiset<int> ms = [5, 3, 5, 1, 5];
    insert(ms, 3);
    emplace(ms, 9);
    show_multi("multiset", &ms);
    printf("%zu %zu %d %d\n", count(ms, 5), count(ms, 4), contains(ms, 3), find(ms, 4) == end(ms));
    met = 0;
    for (size_t i = 0; i < count(ms, 5); i++) met += (size_t)(key(ms, find(ms, 5, i)) == 5);
    printf("%zu %d\n", met, find(ms, 5, 3) == end(ms));
    erase_at(ms, find(ms, 5));
    held = count(ms, 5);
    gone = erase(ms, 3);
    printf("%zu %zu %zu\n", held, gone, size(ms));
    unordered_multiset<int> mt = [5, 2];
    merge(ms, mt);
    mc := clone(ms);
    show_multi("multiset merge", &ms);
    printf("%zu %d", size(mt), ms == mc);
    erase_at(mc, find(mc, 5));
    printf(" %d\n", ms == mc);
    unordered_multiset<point, point_hash, point_eq> pm;
    for (int i = 0; i < 9; i++) insert(pm, (point){i % 2, 7});
    held = count(pm, (point){0, 7});
    gone = count(pm, (point){1, 7});
    printf("%zu %zu %zu\n", held, gone, erase(pm, (point){1, 7}));
    printf("%ld\n", total(s));
    return 0;
}
