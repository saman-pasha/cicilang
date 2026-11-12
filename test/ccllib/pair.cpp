// the twin of pair.c over std::pair (0.301): clang++ builds it over libc++, and what it prints is pair.expect
#include <utility>
#include <optional>
#include <cstdio>
#include <cstdlib>
struct point { int x, y; };
static void show(const char *what, const std::pair<int, double> *p) { std::printf("%s: %d %g\n", what, p->first, p->second); }
static double sum(std::pair<int, double> p) {
    p.first += 100;
    return p.first + p.second;
}
static void rel(const char *what, std::pair<int, int> a, std::pair<int, int> b) {
    std::printf("%s: %d %d %d %d %d %d\n", what, a == b, a != b, a < b, a > b, a <= b, a >= b);
}
static int many(long n) {
    std::pair<int, unsigned> a[64];
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
    std::printf("%ld %ld %ld\n", less, same, s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::pair<int, double> p = {1, 2.5};
    std::pair<int, double> q;
    show("braces", &p);
    show("born", &q);
    q.first = 7;
    q.second = p.second * 2;
    show("members", &q);
    auto r = p;
    p.first = 2;
    show("copy", &r);
    std::printf("%g %g\n", sum(p), sum(r));
    show("after sum", &p);
    p.swap(q);
    show("swap p", &p);
    show("swap q", &q);
    std::pair<int, int> a = {1, 2};
    std::pair<int, int> b = {1, 3};
    std::pair<int, int> c = {2, 0};
    rel("a a", a, a);
    rel("a b", a, b);
    rel("b a", b, a);
    rel("a c", a, c);
    rel("c b", c, b);
    std::pair<char, int> ch = {'x', 3};
    std::printf("%c %d\n", ch.first, ch.second);
    point origin = {0, 0};
    std::pair<point, int> pt = {origin, 4};
    pt.first.y = 9;
    std::printf("%d %d %d\n", pt.first.x, pt.first.y, pt.second);
    std::pair<std::pair<int, int>, int> n = {{1, 2}, 3};
    std::pair<std::pair<int, int>, int> m = {{1, 3}, 0};
    std::printf("%d %d %d %d\n", n == m, n < m, m < n, n.first.second);
    std::optional<std::pair<int, int>> op = n.first;
    std::optional<std::pair<int, int>> none;
    std::printf("%d %d %d %d\n", op.value().first, op.value().second, op == none, none < op);
    volatile double zero = 0.0;
    std::pair<double, double> d = {1.0, 2.0};
    std::pair<double, double> nan = {zero / zero, 1.0};
    std::printf("%d %d %d %d %d\n", nan == nan, nan != d, nan < d, d < nan, nan > d);
    return 0;
}
