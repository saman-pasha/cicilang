/* <vector.pl> (0.274; CCLLIB.md's phase 1a): the whole surface of ccllib's vector, each function once at least. cicilang
   builds this file as C and cicilang++ as C++; vector.cpp is its twin over std::vector, which clang++ builds over
   libc++: the three print the same lines, vector.expect. With a count, `vector 1000000', it fills, copies, erases,
   inserts and walks a vector of that many numbers: the run that the costs time */
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <vector.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const vector<int> *v) {
    printf("%s:", what);
    for (size_t i = 0; i < size(v); i++) printf(" %d", at(v, i));
    printf(" | %zu\n", size(v));
}
static long total(vector<int> v) {
    long s = 0;
    for (const int *p = begin(v); p != end(v); p++) s += *p;
    return s;
}
static int many(long n) {
    vector<int> v;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) { x = x * 1103515245u + 12345u; push_back(v, (int)((x >> 8) % 1000)); }
    w := clone(v);
    size_t gone = erase_value(w, 7);
    insert(w, size(w) / 2, 4, -1);
    resize(w, size(w) + 3, 5);
    long s = 0;
    for (const int *p = begin(w); p != end(w); p++) s += *p;
    for (size_t i = 0; i < size(v); i += 1 + size(v) / 16) s += v[i];
    printf("%zu %zu %zu %ld %d\n", size(v), size(w), gone, s, v < w);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    vector<int> v;
    printf("%d %zu %d\n", empty(v), size(v), max_size(v) > 1000000);
    push_back(v, 5); push_back(v, 3); push(v, 9); emplace_back(v, 1);
    show("push_back", &v);
    printf("%d %d %d %d %zu %zu\n", at(v, 2), v[1], front(v), back(v), size(v), len(v));
    v[1] = 42;
    *data(v) = 7;
    show("index", &v);
    reserve(v, 100);
    printf("%zu %d\n", capacity(v), capacity(v) >= size(v));
    shrink_to_fit(v);
    printf("%zu\n", capacity(v));
    insert(v, 1, 11);
    insert(v, 0, 2, 8);
    emplace(v, size(v), 6);
    show("insert", &v);
    int more[3] = {70, 71, 72};
    insert_range(v, 2, more, 3);
    append_range(v, more, 2);
    show("ranges", &v);
    erase(v, 0);
    erase(v, 1, 3);
    show("erase", &v);
    int last = pop_back(v);
    int before = pop(v);
    printf("%d %d\n", last, before);
    push_back(v, 9); push_back(v, 9);
    size_t gone = erase_value(v, 9);
    show("erase_value", &v);
    printf("%zu\n", gone);
    resize(v, 3);
    show("resize", &v);
    resize(v, 5);
    resize(v, 7, -4);
    show("resize up", &v);
    w := [int; 1, 2, 3];
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
    vector<double> d = [2.5, -1, 0.25];
    push_back(d, 4);
    double ds = 0;
    for (const double *p = begin(d); p != end(d); p++) ds += *p;
    printf("%g %g %zu\n", ds, back(d), size(d));
    vector<point> ps;
    push_back(ps, (point){1, 2});
    push_back(ps, (point){3, 4});
    ps[0].y = 20;
    printf("%d %d %d %zu\n", ps[0].x, ps[0].y, at(ps, 1).y, size(ps));
    vector<bool> bs;
    push_back(bs, 1); push_back(bs, 0); push_back(bs, 1);
    printf("%d %d %d %zu\n", (int)at(bs, 0), (int)at(bs, 1), (int)bs[2], size(bs));
    printf("%ld\n", total(v));
    return 0;
}
