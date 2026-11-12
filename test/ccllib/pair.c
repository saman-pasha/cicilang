/* <pair.pl> (0.301; CCLLIB.md's phase 1b): the whole surface of ccllib's pair -- its members, its birth, a copy, swap
   and each relation -- over two numbers, a character and a number, a plain struct and a number, a pair of pairs, and
   an optional of a pair. cicilang builds this file as C and cicilang++ as C++; pair.cpp is its twin over std::pair,
   which clang++ builds over libc++: the three print the same lines, pair.expect. With a count, `pair 1000000', it sets
   and compares the pairs of an array of 64 that many times: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <pair.pl>
#include <optional.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const pair<int, double> *p) { printf("%s: %d %g\n", what, p->first, p->second); }
static double sum(pair<int, double> p) {
    p.first += 100;
    return p.first + p.second;
}
static void rel(const char *what, pair<int, int> a, pair<int, int> b) {
    printf("%s: %d %d %d %d %d %d\n", what, a == b, a != b, a < b, a > b, a <= b, a >= b);
}
static int many(long n) {
    pair<int, unsigned> a[64];
    unsigned x = 12345;
    long less = 0, same = 0, s = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned k = (x >> 8) % 64, j = (x >> 16) % 64;
        a[k].first = (int)(x >> 28);
        a[k].second = x >> 20 & 15;
        less += a[k] < a[j];
        same += a[k] == a[j];
        s += a[j].first + (long)a[j].second;
    }
    printf("%ld %ld %ld\n", less, same, s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    pair<int, double> p = {1, 2.5};
    pair<int, double> q;
    show("braces", &p);
    show("born", &q);
    q.first = 7;
    q.second = p.second * 2;
    show("members", &q);
    r := p;
    p.first = 2;
    show("copy", &r);
    printf("%g %g\n", sum(p), sum(r));
    show("after sum", &p);
    swap(p, q);
    show("swap p", &p);
    show("swap q", &q);
    pair<int, int> a = {1, 2};
    pair<int, int> b = {1, 3};
    pair<int, int> c = {2, 0};
    rel("a a", a, a);
    rel("a b", a, b);
    rel("b a", b, a);
    rel("a c", a, c);
    rel("c b", c, b);
    pair<char, int> ch = {'x', 3};
    printf("%c %d\n", ch.first, ch.second);
    point origin = {0, 0};
    pair<point, int> pt = {origin, 4};
    pt.first.y = 9;
    printf("%d %d %d\n", pt.first.x, pt.first.y, pt.second);
    pair<pair<int, int>, int> n = {{1, 2}, 3};
    pair<pair<int, int>, int> m = {{1, 3}, 0};
    printf("%d %d %d %d\n", n == m, n < m, m < n, n.first.second);
    optional<pair<int, int>> op = n.first;
    optional<pair<int, int>> none;
    printf("%d %d %d %d\n", value(op).first, value(op).second, op == none, none < op);
    volatile double zero = 0.0;
    pair<double, double> d = {1.0, 2.0};
    pair<double, double> nan = {zero / zero, 1.0};
    printf("%d %d %d %d %d\n", nan == nan, nan != d, nan < d, d < nan, nan > d);
    return 0;
}
