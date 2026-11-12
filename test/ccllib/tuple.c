/* <tuple.pl> (0.305; CCLLIB.md's phase 1b): the whole surface of ccllib's tuple -- its elements by get<I> and get<T>,
   as values and as places, its birth, a copy, swap and each relation -- over three numbers, one number, a character, a
   plain struct, a pair, a tuple and an optional of a tuple; the pair's and the array's get<I> beside it. cicilang
   builds this file as C and cicilang++ as C++; tuple.cpp is its twin over std::tuple, which clang++ builds over libc++:
   the three print the same lines, tuple.expect. With a count, `tuple 1000000', it sets and compares the tuples of an
   array of 64 that many times: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <tuple.pl>
#include <pair.pl>
#include <array.pl>
#include <optional.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const tuple<int, double, char> *t) {
    printf("%s: %d %g %c\n", what, get<0>(*t), get<1>(*t), get<2>(*t));
}
static double sum(tuple<int, double, char> t) {
    get<0>(t) += 100;
    return get<0>(t) + get<1>(t);
}
static void rel(const char *what, tuple<int, int, int> a, tuple<int, int, int> b) {
    printf("%s: %d %d %d %d %d %d\n", what, a == b, a != b, a < b, a > b, a <= b, a >= b);
}
static int many(long n) {
    tuple<int, unsigned, short> a[64];
    unsigned x = 12345;
    long less = 0, same = 0, s = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned k = (x >> 8) % 64, j = (x >> 16) % 64;
        get<0>(a[k]) = (int)(x >> 29);
        get<1>(a[k]) = x >> 22 & 7;
        get<2>(a[k]) = (short)(x >> 18 & 3);
        less += a[k] < a[j];
        same += a[k] == a[j];
        s += get<0>(a[j]) + (long)get<1>(a[j]) + get<2>(a[j]);
    }
    printf("%ld %ld %ld\n", less, same, s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    tuple<int, double, char> t = {1, 2.5, 'a'};
    tuple<int, double, char> u;
    show("braces", &t);
    printf("born: %d %g %d\n", get<0>(u), get<1>(u), get<2>(u));
    get<0>(u) = 7;
    get<double>(u) = get<1>(t) * 2;
    get<char>(u) = 'b';
    ++get<2>(u);
    get<int>(u) -= 2;
    show("places", &u);
    printf("by type: %d %g %c\n", get<int>(t), get<double>(t), get<char>(t));
    int *pi = &get<0>(t);
    *pi = 3;
    show("through a pointer", &t);
    r := t;
    get<0>(t) = 4;
    show("copy", &r);
    printf("%g %g\n", sum(t), sum(r));
    show("after sum", &t);
    swap(t, u);
    show("swap t", &t);
    show("swap u", &u);
    tuple<int, double, char> *pt = &t;
    get<1>(*pt) = 0.5;
    show("through *pt", &t);
    tuple<int, int, int> a = {1, 2, 3};
    tuple<int, int, int> b = {1, 2, 4};
    tuple<int, int, int> c = {1, 3, 0};
    tuple<int, int, int> d = {2, 0, 0};
    rel("a a", a, a);
    rel("a b", a, b);
    rel("b a", b, a);
    rel("a c", a, c);
    rel("c d", c, d);
    rel("d a", d, a);
    tuple<int> one = {5};
    tuple<int> two = {6};
    printf("one: %d %d %d %d\n", get<0>(one), one < two, one == two, two >= one);
    point origin = {0, 0};
    tuple<point, int> tp = {origin, 4};
    get<0>(tp).y = 9;
    printf("struct: %d %d %d\n", get<0>(tp).x, get<point>(tp).y, get<1>(tp));
    tuple<pair<int, int>, int> tq = {{1, 2}, 3};
    tuple<pair<int, int>, int> tr = {{1, 3}, 0};
    get<1>(get<0>(tq)) = 5;
    printf("pair: %d %d %d %d %d\n", get<0>(get<0>(tq)), get<1>(get<0>(tq)), tq == tr, tq < tr, tr < tq);
    tuple<tuple<int, int>, char> tt = {{6, 7}, 'z'};
    printf("tuple: %d %d %c\n", get<0>(get<0>(tt)), get<1>(get<0>(tt)), get<1>(tt));
    optional<tuple<int, int>> ot = get<0>(tt);
    optional<tuple<int, int>> none;
    ov := value(ot);
    printf("optional: %d %d %d %d\n", get<0>(ov), get<1>(ov), ot == none, none < ot);
    volatile double zero = 0.0;
    tuple<double, int> e = {1.0, 2};
    tuple<double, int> nan = {zero / zero, 1};
    printf("NaN: %d %d %d %d %d %d\n", nan == nan, nan != e, nan < e, e < nan, nan <= e, nan >= nan);
    pair<int, double> p = {1, 2.5};
    get<0>(p) = 2;
    get<double>(p) *= 2;
    printf("pair's get: %d %g %d %g\n", get<0>(p), get<1>(p), get<int>(p), p.second);
    array<int, 3> ar = [5, 3, 9];
    get<2>(ar) = 1;
    ++get<0>(ar);
    printf("array's get: %d %d %d\n", get<0>(ar), get<1>(ar), get<2>(ar));
    return 0;
}
