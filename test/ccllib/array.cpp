// the twin of array.c over std::array (0.275): clang++ builds it over libc++, and what it prints is array.expect
#include <array>
#include <cstdio>
#include <cstdlib>
struct point { int x, y; };
static void show(const char *what, const std::array<int, 4> *a) {
    std::printf("%s:", what);
    for (size_t i = 0; i < a->size(); i++) std::printf(" %d", a->at(i));
    std::printf(" | %zu\n", a->size());
}
static int sum(std::array<int, 4> a) {
    int s = 0;
    for (const int *p = a.data(); p != a.data() + a.size(); p++) s += *p;
    return s;
}
static int many(long n) {
    std::array<int, 64> a;
    std::array<int, 64> b;
    unsigned x = 12345;
    long s = 0, less = 0;
    if (n < 1) n = 1;
    a.fill(0);
    b.fill(0);
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        a[(x >> 8) % 64] += 1;
        b[(x >> 16) % 64] += 2;
        less += a < b;
        s += a.at(i % 64) + b.back();
    }
    std::printf("%ld %ld %d %d\n", s, less, a.front(), a == b);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::array<int, 4> a = {5, 3, 9};
    show("literal", &a);
    std::printf("%zu %zu %d %d %d %d %d\n", a.size(), a.max_size(), a.empty(), a.at(0), a[2], a.front(), a.back());
    a[3] = 7;
    *a.data() = 6;
    show("index", &a);
    std::array<int, 4> b = a;
    a.fill(1);
    show("fill", &a);
    show("copy", &b);
    std::printf("%d %d\n", sum(a), sum(b));
    std::printf("%d %d %d %d %d %d\n", a == b, a != b, a < b, a > b, a <= b, a >= b);
    a.swap(b);
    show("swap", &a);
    show("swap", &b);
    std::array<double, 2> d = {1.5, 2.5};
    double ds = 0;
    for (const double *p = d.data(); p != d.data() + d.size(); p++) ds += *p;
    std::printf("%g %g %zu %zu\n", ds, d.back(), d.size(), d.size());
    std::array<point, 2> ps;
    ps[0] = point{1, 2};
    ps[1] = point{3, 4};
    ps[0].y = 20;
    std::printf("%d %d %d %zu\n", ps[0].x, ps[0].y, ps.at(1).y, ps.size());
    return 0;
}
