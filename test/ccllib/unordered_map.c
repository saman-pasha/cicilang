/* <unordered_map.pl> (0.283; CCLLIB.md's phase 1a): the whole surface of ccllib's unordered_map and
   unordered_multimap, each function once at least. cicilang builds this file as C and cicilang++ as C++;
   unordered_map.cpp is its twin over std::unordered_map and std::unordered_multimap, which clang++ builds over
   libc++: the three print the same lines, unordered_map.expect. A walk gives the entries in the table's order, which
   is not C++'s, so no line depends on it: the keys are asked for one by one, and a key's values are put in their
   order. With a count, `unordered_map 3000000', it counts that many numbers in a map, asks for as many, takes half of
   as many away and walks the map: the run that the costs time. After it comes a walk of chance over the operations of
   a map and of a multimap, in which a place is used after the calls that change no entry, and a walk that erases
   meets each entry once */
#include <stdio.h>
#include <stdlib.h>
#include <unordered_map.pl>
typedef struct point { int x, y; } point;
static unsigned long point_hash(point p) { return (unsigned long)p.x * 31u + (unsigned long)p.y; }
static int point_eq(point a, point b) { return a.x == b.x && a.y == b.y; }
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static void show(const char *what, const unordered_map<int, long> *m) {
    size_t walked = 0;
    printf("%s:", what);
    for (int k = -5; k <= 1000; k++) if (contains(m, k)) printf(" %d=%ld", k, at(m, k));
    for (size_t p = begin(m); p != end(m); p = next(m, p)) walked++;
    printf(" | %zu %zu\n", size(m), walked);
}
/* a key's values in their order: the table says nothing of the order in which it gives them */
static void show_multi(const char *what, const unordered_multimap<int, long> *m) {
    size_t walked = 0;
    printf("%s:", what);
    for (int k = -5; k <= 1000; k++) {
        long vals[32];
        size_t n = count(m, k);
        if (n > 32) n = 32;
        for (size_t i = 0; i < n; i++) vals[i] = value(m, find(m, k, i));
        for (size_t i = 1; i < n; i++) {
            for (size_t j = i; j > 0 && vals[j - 1] > vals[j]; j--) {
                long t = vals[j];
                vals[j] = vals[j - 1];
                vals[j - 1] = t;
            }
        }
        for (size_t i = 0; i < n; i++) printf(" %d=%ld", k, vals[i]);
    }
    for (size_t p = begin(m); p != end(m); p = next(m, p)) walked++;
    printf(" | %zu %zu\n", size(m), walked);
}
static long total(unordered_map<int, long> m) {
    long t = 0;
    for (size_t p = begin(m); p != end(m); p = next(m, p)) t += key(m, p) * value(m, p);
    return t;
}
static int many(long n) {
    unordered_map<int, int> m;
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
/* a walk of chance over a map's operations, n steps: what each leaves is put into one number, and nothing of it
   depends on the order of a walk */
static unsigned long walk_map(long n, int range) {
    unordered_map<int, long> m;
    unsigned long h = 0, sum = 0, x = 0;
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
                h = h * 5 + (unsigned long)value(m, p) + (unsigned long)key(m, p);
            }
        }
        else if (op == 12) {
            size_t p = find(m, k);
            if (p != end(m)) { h = h * 5 + (unsigned long)value(m, p); erase_at(m, p); }
        }
        else if (op == 13 && i % 64 == 0) {
            /* a walk that erases each entry whose key is under k meets every entry once */
            size_t met = 0, before = size(m);
            for (size_t p = begin(m); p != end(m); ) {
                met++;
                if (key(m, p) < k) p = erase_at(m, p); else p = next(m, p);
            }
            h = h * 7 + (unsigned long)(met == before) + size(m);
        }
        else if (i % 4096 == 0) { c := clone(m); h = h * 3 + (unsigned long)(c == m) + size(c); }
        h += size(m);
        if (!empty(m)) {
            /* at each step, in whatever state the table stands: a write to a key that is there, an insert that finds
               its key and an erase that finds none change no entry, and a place stays over them */
            size_t p = begin(m);
            int first = key(m, p);
            long was = value(m, p);
            m[first] += 2;
            h += (unsigned long)insert(m, first, 0);
            h += (unsigned long)insert_or_assign(m, first, was);
            h += erase(m, range);
            h += (unsigned long)(key(m, p) == first && value(m, p) == was);
        }
    }
    for (size_t p = begin(m); p != end(m); p = next(m, p)) {
        unsigned long e = (unsigned long)key(m, p) * 2654435761u + (unsigned long)value(m, p) * 40503u;
        sum += e;
        x ^= e + 7u;
    }
    return h * 31 + sum + x;
}
static unsigned long walk_multimap(long n, int range) {
    unordered_multimap<int, long> m;
    unsigned long h = 0, sum = 0, x = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) h = h * 3 + (unsigned long)insert(m, k, i);
        else if (op < 8) h = h * 3 + erase(m, k);
        else if (op < 10) {
            /* the key's entry of the least value is taken away: which entry a find gives is the table's own choice */
            size_t c = count(m, k), best = 0;
            for (size_t j = 1; j < c; j++) if (value(m, find(m, k, j)) < value(m, find(m, k, best))) best = j;
            if (c) {
                h = h * 5 + (unsigned long)value(m, find(m, k, best));
                erase_at(m, find(m, k, best));
                h = h * 5 + count(m, k);
            }
        }
        else if (op == 10) h = h * 3 + (unsigned long)contains(m, k) + count(m, k);
        else if (op == 11) {
            unsigned long vs = 0;
            for (size_t j = 0; j < count(m, k); j++) vs += (unsigned long)value(m, find(m, k, j));
            h = h * 5 + vs + (unsigned long)(find(m, k, count(m, k)) == end(m));
        }
        else if (op == 13 && i % 64 == 0) {
            size_t met = 0, before = size(m);
            for (size_t p = begin(m); p != end(m); ) {
                met++;
                if (key(m, p) < k) p = erase_at(m, p); else p = next(m, p);
            }
            h = h * 7 + (unsigned long)(met == before) + size(m);
        }
        else if (i % 4096 == 0) { c := clone(m); h = h * 3 + (unsigned long)(c == m) + size(c); }
        h += size(m);
        if (!empty(m)) {
            /* at each step: an erase that finds none and a write at a place change no entry, and a place stays */
            size_t p = begin(m);
            int first = key(m, p);
            long was = value(m, p);
            h += erase(m, range);
            set_value(m, p, was);
            h += (unsigned long)(key(m, p) == first && value(m, p) == was);
        }
    }
    for (size_t p = begin(m); p != end(m); p = next(m, p)) {
        unsigned long e = (unsigned long)key(m, p) * 2654435761u + (unsigned long)value(m, p) * 40503u;
        sum += e;
        x ^= e + 7u;
    }
    return h * 31 + sum + x;
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
    unordered_map<int, long> m;
    size_t met = 0;
    printf("%d %zu %d\n", empty(m), size(m), max_size(m) > 1000000);
    for (int i = 0; i < 40; i++) printf("%d", insert(m, i * 7 % 23, (long)i * 10));
    printf(" %d", emplace(m, 100, 1));
    printf(" %d", try_emplace(m, 100, 2));
    printf(" %d\n", try_emplace(m, 101, 3));
    show("insert", &m);
    printf("%zu %zu %d %d %zu %zu\n", size(m), len(m), contains(m, 5), contains(m, 99), count(m, 7), count(m, 99));
    printf("%ld %ld %ld\n", at(m, 7), get(m, 14), m[21]);
    m[21] = 5;
    m[300] += 7;
    m[300] += 7;
    printf("%d", insert_or_assign(m, 7, 77));
    printf(" %d %ld %ld\n", insert_or_assign(m, 400, 4), at(m, 7), m[300]);
    put(m, 8, 88);
    size_t p = find(m, 9);
    set_value(m, p, 99);
    printf("%d %ld %d\n", key(m, p), value(m, p), find(m, 50) == end(m));
    size_t gone = erase(m, 5);
    printf("%zu %zu\n", gone, erase(m, 5));
    erase_at(m, find(m, 9));
    for (p = begin(m); p != end(m); ) {
        met++;
        if (value(m, p) % 20 == 0) p = erase_at(m, p); else p = next(m, p);
    }
    printf("%zu\n", met);
    show("erase", &m);
    unordered_map<int, long> t = [70: 7, 3: 333, 80: 8];
    merge(m, t);
    show("merge", &m);
    show("merged", &t);
    c := clone(m);
    printf("%d %d", m == c, m != c);
    c[0] = -1;
    printf(" %d %d\n", m == c, m != c);
    swap(m, c);
    printf("%ld %d\n", at(m, 0), contains(c, 0));
    clear(c);
    printf("%d %zu\n", empty(c), size(c));
    unordered_map<int, long> r;
    reserve(r, 1000);
    size_t slots = bucket_count(r);
    for (int i = 0; i < 1000; i++) r[i * 3] = i;
    printf("%d %d %d\n", bucket_count(r) == slots, load_factor(r) <= max_load_factor(r), load_factor(r) > 0);
    rehash(r, 4096);
    printf("%d %zu %ld %d\n", bucket_count(r) >= 4096, size(r), at(r, 2997), contains(r, 2998));
    unordered_map<point, int, point_hash, point_eq> pm;
    pm[(point){3, 30}] = 1;
    pm[(point){1, 10}] = 2;
    pm[(point){3, 30}] += 10;
    printf("%d %d %d %zu\n", at(pm, (point){3, 30}), at(pm, (point){1, 10}), contains(pm, (point){1, 11}), size(pm));
    unordered_map<int, point> ps;
    ps[3] = (point){3, 30};
    ps[1] = (point){1, 10};
    ps[3].y = 31;
    printf("%d %d %zu\n", at(ps, 3).y, at(ps, 1).x, size(ps));
    unordered_map<double, int> f = [2.5: 1, 0.0: 2];
    f[-0.0] += 5;
    printf("%d %d %zu\n", at(f, 0.0), at(f, 2.5), size(f));
    unordered_multimap<int, long> mm;
    for (int i = 0; i < 12; i++) insert(mm, i * 5 % 4, (long)i);
    emplace(mm, 2, 100);
    show_multi("multimap", &mm);
    printf("%zu %zu %d %d\n", count(mm, 2), count(mm, 9), contains(mm, 3), find(mm, 9) == end(mm));
    long vs = 0;
    for (size_t i = 0; i < count(mm, 1); i++) vs += value(mm, find(mm, 1, i));
    printf("%ld %d\n", vs, find(mm, 1, 3) == end(mm));
    for (size_t i = 0; i < count(mm, 2); i++) {
        if (value(mm, find(mm, 2, i)) == 6) { erase_at(mm, find(mm, 2, i)); break; }
    }
    size_t held = count(mm, 2);
    gone = erase(mm, 3);
    printf("%zu %zu %zu\n", held, gone, size(mm));
    unordered_multimap<int, long> mt;
    insert(mt, 2, 500);
    insert(mt, 0, 600);
    merge(mm, mt);
    show_multi("multimap merge", &mm);
    mc := clone(mm);
    printf("%zu %d", size(mt), mm == mc);
    /* the key's values in another order of inserts are the same entries */
    erase(mc, 2);
    insert(mc, 2, 500);
    insert(mc, 2, 100);
    insert(mc, 2, 10);
    insert(mc, 2, 2);
    printf(" %d", mm == mc);
    set_value(mc, find(mc, 0), -1);
    printf(" %d\n", mm == mc);
    printf("%ld\n", total(m));
    return 0;
}
