// the twin of tuple.c over std::tuple (0.305): clang++ builds it over libc++, and what it prints is tuple.expect
#include <tuple>
#include <utility>
#include <array>
#include <optional>
#include <cstdio>
#include <cstdlib>
using std::get;
struct point { int x, y; };
static void show(const char *what, const std::tuple<int, double, char> *t) {
    std::printf("%s: %d %g %c\n", what, get<0>(*t), get<1>(*t), get<2>(*t));
}
static double sum(std::tuple<int, double, char> t) {
    get<0>(t) += 100;
    return get<0>(t) + get<1>(t);
}
static void rel(const char *what, std::tuple<int, int, int> a, std::tuple<int, int, int> b) {
    std::printf("%s: %d %d %d %d %d %d\n", what, a == b, a != b, a < b, a > b, a <= b, a >= b);
}
static int many(long n) {
    std::tuple<int, unsigned, short> a[64];
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
    std::printf("%ld %ld %ld\n", less, same, s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::tuple<int, double, char> t = {1, 2.5, 'a'};
    std::tuple<int, double, char> u;
    show("braces", &t);
    std::printf("born: %d %g %d\n", get<0>(u), get<1>(u), get<2>(u));
    get<0>(u) = 7;
    get<double>(u) = get<1>(t) * 2;
    get<char>(u) = 'b';
    ++get<2>(u);
    get<int>(u) -= 2;
    show("places", &u);
    std::printf("by type: %d %g %c\n", get<int>(t), get<double>(t), get<char>(t));
    int *pi = &get<0>(t);
    *pi = 3;
    show("through a pointer", &t);
    auto r = t;
    get<0>(t) = 4;
    show("copy", &r);
    std::printf("%g %g\n", sum(t), sum(r));
    show("after sum", &t);
    std::swap(t, u);
    show("swap t", &t);
    show("swap u", &u);
    std::tuple<int, double, char> *pt = &t;
    get<1>(*pt) = 0.5;
    show("through *pt", &t);
    std::tuple<int, int, int> a = {1, 2, 3};
    std::tuple<int, int, int> b = {1, 2, 4};
    std::tuple<int, int, int> c = {1, 3, 0};
    std::tuple<int, int, int> d = {2, 0, 0};
    rel("a a", a, a);
    rel("a b", a, b);
    rel("b a", b, a);
    rel("a c", a, c);
    rel("c d", c, d);
    rel("d a", d, a);
    std::tuple<int> one = {5};
    std::tuple<int> two = {6};
    std::printf("one: %d %d %d %d\n", get<0>(one), one < two, one == two, two >= one);
    point origin = {0, 0};
    std::tuple<point, int> tp = {origin, 4};
    get<0>(tp).y = 9;
    std::printf("struct: %d %d %d\n", get<0>(tp).x, get<point>(tp).y, get<1>(tp));
    std::tuple<std::pair<int, int>, int> tq = {{1, 2}, 3};
    std::tuple<std::pair<int, int>, int> tr = {{1, 3}, 0};
    get<1>(get<0>(tq)) = 5;
    std::printf("pair: %d %d %d %d %d\n", get<0>(get<0>(tq)), get<1>(get<0>(tq)), tq == tr, tq < tr, tr < tq);
    std::tuple<std::tuple<int, int>, char> tt = {{6, 7}, 'z'};
    std::printf("tuple: %d %d %c\n", get<0>(get<0>(tt)), get<1>(get<0>(tt)), get<1>(tt));
    std::optional<std::tuple<int, int>> ot = get<0>(tt);
    std::optional<std::tuple<int, int>> none;
    auto ov = ot.value();
    std::printf("optional: %d %d %d %d\n", get<0>(ov), get<1>(ov), ot == none, none < ot);
    volatile double zero = 0.0;
    std::tuple<double, int> e = {1.0, 2};
    std::tuple<double, int> nan = {zero / zero, 1};
    std::printf("NaN: %d %d %d %d %d %d\n", nan == nan, nan != e, nan < e, e < nan, nan <= e, nan >= nan);
    std::pair<int, double> p = {1, 2.5};
    get<0>(p) = 2;
    get<double>(p) *= 2;
    std::printf("pair's get: %d %g %d %g\n", get<0>(p), get<1>(p), get<int>(p), p.second);
    std::array<int, 3> ar = {5, 3, 9};
    get<2>(ar) = 1;
    ++get<0>(ar);
    std::printf("array's get: %d %d %d\n", get<0>(ar), get<1>(ar), get<2>(ar));
    return 0;
}
