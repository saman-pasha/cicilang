/* <optional.pl> (0.300; CCLLIB.md's phase 1b): the whole surface of ccllib's optional, each function once at least,
   and each relation over each pair of an optional with no value, with one, with a value and with nullopt, on either
   side. cicilang builds this file as C and cicilang++ as C++; optional.cpp is its twin over std::optional, which
   clang++ builds over libc++: the three print the same lines, optional.expect. With a count, `optional 1000000', it
   fills, empties, reads and compares an array of 64 optional numbers that many times: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <optional.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const optional<int> *o) {
    if (has_value(o)) printf("%s: %d\n", what, value(o));
    else printf("%s: none\n", what);
}
static int twice(optional<int> o) {
    if (!has_value(o)) return -1;
    emplace(o, value(o) * 2);
    return value(o);
}
static void rel(const char *what, optional<int> a, optional<int> b) {
    printf("%s: %d %d %d %d %d %d\n", what, a == b, a != b, a < b, a > b, a <= b, a >= b);
}
static void relv(const char *what, optional<int> a, int x) {
    printf("%s: %d %d %d %d %d %d | %d %d %d %d %d %d\n", what, a == x, a != x, a < x, a > x, a <= x, a >= x,
           x == a, x != a, x < a, x > a, x <= a, x >= a);
}
static void reln(const char *what, optional<int> a) {
    printf("%s: %d %d %d %d %d %d | %d %d %d %d %d %d\n", what, a == nullopt, a != nullopt, a < nullopt,
           a > nullopt, a <= nullopt, a >= nullopt, nullopt == a, nullopt != a, nullopt < a, nullopt > a,
           nullopt <= a, nullopt >= a);
}
static int many(long n) {
    optional<long> a[64];
    unsigned x = 12345;
    long s = 0, has = 0, less = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned k = (x >> 8) % 64;
        if (x >> 31) a[k] = (long)(x >> 12 & 1023);
        else a[k] = nullopt;
        s += value_or(a[(x >> 16) % 64], 1L);
        has += has_value(a[k]);
        less += a[k] < a[(k + 1) % 64];
    }
    printf("%ld %ld %ld\n", s, has, less);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    optional<int> a;
    optional<int> b = 5;
    show("born", &a);
    show("five", &b);
    a = 7;
    show("seven", &a);
    printf("%d %d %d %d\n", has_value(a), value(a), value_or(a, 3), value_or(b, 3));
    q := a;
    a = nullopt;
    show("nullopt", &a);
    show("copy", &q);
    printf("%d %d %d\n", value_or(a, 3), twice(q), twice(a));
    show("after twice", &q);
    int *p = emplace(a, 40);
    *p += 2;
    show("emplace", &a);
    swap(a, b);
    show("swap a", &a);
    show("swap b", &b);
    reset(b);
    show("reset", &b);
    optional<int> none;
    optional<int> one = 1;
    optional<int> two = 2;
    rel("none none", none, none);
    rel("none one", none, one);
    rel("one none", one, none);
    rel("one two", one, two);
    rel("two one", two, one);
    rel("one one", one, one);
    relv("none 1", none, 1);
    relv("one 0", one, 0);
    relv("one 1", one, 1);
    relv("one 2", one, 2);
    reln("none", none);
    reln("one", one);
    optional<double> d = 2.5;
    optional<double> e;
    printf("%g %g %d %d %d %d\n", value(d), value_or(e, -1.0), d == 2.5, e < d, d > 2.0, 3.0 > d);
    e = d;
    emplace(d, 0.5);
    printf("%g %g %d %d\n", value(d), value(e), d < e, e == nullopt);
    optional<char> c = (char)'x';
    optional<char> f;
    printf("%c %c %d %d %d\n", value(c), value_or(f, (char)'-'), c == (char)'x', f < c, (char)'y' > c);
    point origin = {0, 0};
    point corner = {3, 4};
    optional<point> pt = corner;
    optional<point> gone;
    printf("%d %d %d %d\n", value(pt).x, value(pt).y, has_value(gone), value_or(gone, origin).y);
    emplace(gone, origin)->x = 9;
    printf("%d %d\n", value(gone).x, value(gone).y);
    swap(pt, gone);
    reset(gone);
    printf("%d %d %d\n", value(pt).x, has_value(pt), has_value(gone));
    return 0;
}
