/* <array.pl> (0.275; CCLLIB.md's phase 1a): the whole surface of ccllib's array, each function once at least. cicilang
   builds this file as C and cicilang++ as C++; array.cpp is its twin over std::array, which clang++ builds over
   libc++: the three print the same lines, array.expect. With a count, `array 1000000', it fills and compares two
   arrays of 64 numbers that many times: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <array.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const array<int, 4> *a) {
    printf("%s:", what);
    for (size_t i = 0; i < size(a); i++) printf(" %d", at(a, i));
    printf(" | %zu\n", size(a));
}
static int sum(array<int, 4> a) {
    int s = 0;
    for (const int *p = begin(a); p != end(a); p++) s += *p;
    return s;
}
static int many(long n) {
    array<int, 64> a;
    array<int, 64> b;
    unsigned x = 12345;
    long s = 0, less = 0;
    if (n < 1) n = 1;
    fill(a, 0);
    fill(b, 0);
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        a[(x >> 8) % 64] += 1;
        b[(x >> 16) % 64] += 2;
        less += a < b;
        s += at(a, i % 64) + back(b);
    }
    printf("%ld %ld %d %d\n", s, less, front(a), a == b);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    array<int, 4> a = [5, 3, 9];
    show("literal", &a);
    printf("%zu %zu %d %d %d %d %d\n", size(a), max_size(a), empty(a), at(a, 0), a[2], front(a), back(a));
    a[3] = 7;
    *data(a) = 6;
    show("index", &a);
    b := a;
    fill(a, 1);
    show("fill", &a);
    show("copy", &b);
    printf("%d %d\n", sum(a), sum(b));
    printf("%d %d %d %d %d %d\n", a == b, a != b, a < b, a > b, a <= b, a >= b);
    swap(a, b);
    show("swap", &a);
    show("swap", &b);
    array<double, 2> d = [1.5, 2.5];
    double ds = 0;
    for (const double *p = begin(d); p != end(d); p++) ds += *p;
    printf("%g %g %zu %zu\n", ds, back(d), size(d), len(d));
    array<point, 2> ps;
    ps[0] = (point){1, 2};
    ps[1] = (point){3, 4};
    ps[0].y = 20;
    printf("%d %d %d %zu\n", ps[0].x, ps[0].y, at(ps, 1).y, size(ps));
    return 0;
}
