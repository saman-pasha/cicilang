/* <deque.pl> (0.276; CCLLIB.md's phase 1a): the whole surface of ccllib's deque, each function once at least. cicilang
   builds this file as C and cicilang++ as C++; deque.cpp is its twin over std::deque, which clang++ builds over
   libc++: the three print the same lines, deque.expect. With a count, `deque 1000000', it sends that many numbers
   through a deque -- in at the back, each fourth out at the front, some in at the front -- then copies, erases, inserts
   and walks it: the run that the costs time. After it comes a walk of chance over the operations at a place */
#include <stdio.h>
#include <stdlib.h>
#include <deque.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const deque<int> *d) {
    printf("%s:", what);
    for (size_t i = 0; i < size(d); i++) printf(" %d", at(d, i));
    printf(" | %zu\n", size(d));
}
static long total(deque<int> d) {
    long s = 0;
    for (size_t i = 0; i < size(d); i++) s += d[i];
    return s;
}
static int many(long n) {
    deque<int> q;
    unsigned x = 12345;
    long s = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        push_back(q, (int)((x >> 8) % 1000));
        if (i % 4 == 3) s += pop_front(q);
        if (i % 16 == 5) push_front(q, (int)(i % 100));
    }
    w := clone(q);
    size_t gone = erase_value(w, 7);
    insert(w, size(w) / 4, 4, -1);
    erase(w, size(w) - 3);
    for (size_t i = 0; i < size(w); i++) s += w[i];
    for (size_t i = 0; i < size(q); i += 1 + size(q) / 16) s += at(q, i);
    printf("%zu %zu %zu %ld %d\n", size(q), size(w), gone, s, q < w);
    return 0;
}
/* a walk of chance over every operation at a place, 300,000 steps at most: what each leaves is put into one number */
static int walk(long n) {
    deque<int> d;
    unsigned x = 54321;
    unsigned long h = 0;
    int three[3] = {1, 2, 3};
    if (n > 300000) n = 300000;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned op = (x >> 16) % 16, r = (x >> 8) & 0xffff;
        size_t z = size(d);
        if (op < 3) push_back(d, (int)r);
        else if (op < 6) push_front(d, (int)r);
        else if (op == 6 && z) h += (unsigned long)pop_back(d);
        else if (op == 7 && z) h += (unsigned long)pop_front(d);
        else if (op == 8) insert(d, r % (z + 1), (int)i);
        else if (op == 9) insert(d, r % (z + 1), r % 5, (int)i);
        else if (op == 10 && z) erase(d, r % z);
        else if (op == 11 && z) {
            size_t a = r % z, b = a + (r >> 3) % (z - a + 1);
            erase(d, a, b > a + 6 ? a + 6 : b);
        }
        else if (op == 12 && z) h = h * 31 + (unsigned long)at(d, r % z);
        else if (op == 13 && z) d[r % z] = (int)i;
        else if (op == 14 && r % 64 == 0) shrink_to_fit(d);
        else if (op == 14 && r % 64 == 1) resize(d, z / 2);
        else if (op == 14 && r % 64 == 2) resize(d, z + r % 7, -1);
        else if (op == 15 && r % 512 == 0) {
            insert_range(d, r % (z + 1), three, 3);
            prepend_range(d, three, 2);
            append_range(d, three, 1);
        }
        h = h * 131 + size(d);
    }
    for (size_t i = 0; i < size(d); i++) h = h * 31 + (unsigned long)d[i];
    printf("%lu %zu\n", h, size(d));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1])) + walk(atol(argv[1]));
    deque<int> d;
    printf("%d %zu %d\n", empty(d), size(d), max_size(d) > 1000000);
    push_back(d, 5); push_front(d, 3); push(d, 9); emplace_back(d, 1); emplace_front(d, 4);
    show("push", &d);
    printf("%d %d %d %d %zu %zu\n", at(d, 2), d[1], front(d), back(d), size(d), len(d));
    d[1] = 42;
    show("index", &d);
    for (int i = 0; i < 20; i++) { push_front(d, 100 + i); push_back(d, 200 + i); }
    show("round", &d);
    insert(d, 1, 11);
    insert(d, size(d) - 1, 12);
    insert(d, 0, 2, 8);
    emplace(d, size(d), 6);
    show("insert", &d);
    int more[3] = {70, 71, 72};
    insert_range(d, 2, more, 3);
    append_range(d, more, 2);
    prepend_range(d, more, 1);
    show("ranges", &d);
    erase(d, 0);
    erase(d, 1, 3);
    erase(d, size(d) - 4, size(d) - 2);
    show("erase", &d);
    int last = pop_back(d);
    int before = pop(d);
    int first = pop_front(d);
    printf("%d %d %d\n", last, before, first);
    push_back(d, 9); push_front(d, 9);
    size_t gone = erase_value(d, 9);
    show("erase_value", &d);
    printf("%zu\n", gone);
    resize(d, 3);
    show("resize", &d);
    resize(d, 5);
    resize(d, 7, -4);
    show("resize up", &d);
    shrink_to_fit(d);
    show("shrink", &d);
    deque<int> w = [1, 2, 3];
    u := clone(w);
    push_back(u, 4);
    printf("%d %d %d %d %d %d\n", w == u, w != u, w < u, w > u, w <= u, w >= u);
    swap(w, u);
    show("swap", &w);
    show("swap", &u);
    assign(w, 3, 6);
    assign_range(u, more, 3);
    show("assign", &w);
    show("assign", &u);
    clear(w);
    printf("%d %zu\n", empty(w), size(w));
    deque<double> f = [2.5, -1, 0.25];
    push_front(f, 4);
    double fs = 0;
    for (size_t i = 0; i < size(f); i++) fs += f[i];
    printf("%g %g %g %zu\n", fs, front(f), back(f), size(f));
    deque<point> ps;
    push_back(ps, (point){1, 2});
    push_front(ps, (point){3, 4});
    ps[0].y = 20;
    printf("%d %d %d %zu\n", ps[0].x, ps[0].y, at(ps, 1).y, size(ps));
    printf("%ld\n", total(d));
    return 0;
}
