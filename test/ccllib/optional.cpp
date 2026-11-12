// the twin of optional.c over std::optional (0.300): clang++ builds it over libc++, and what it prints is optional.expect
#include <optional>
#include <cstdio>
#include <cstdlib>
struct point { int x, y; };
static void show(const char *what, const std::optional<int> *o) {
    if (o->has_value()) std::printf("%s: %d\n", what, o->value());
    else std::printf("%s: none\n", what);
}
static int twice(std::optional<int> o) {
    if (!o.has_value()) return -1;
    o.emplace(o.value() * 2);
    return o.value();
}
static void rel(const char *what, std::optional<int> a, std::optional<int> b) {
    std::printf("%s: %d %d %d %d %d %d\n", what, a == b, a != b, a < b, a > b, a <= b, a >= b);
}
static void relv(const char *what, std::optional<int> a, int x) {
    std::printf("%s: %d %d %d %d %d %d | %d %d %d %d %d %d\n", what, a == x, a != x, a < x, a > x, a <= x, a >= x,
                x == a, x != a, x < a, x > a, x <= a, x >= a);
}
static void reln(const char *what, std::optional<int> a) {
    std::printf("%s: %d %d %d %d %d %d | %d %d %d %d %d %d\n", what, a == std::nullopt, a != std::nullopt,
                a < std::nullopt, a > std::nullopt, a <= std::nullopt, a >= std::nullopt, std::nullopt == a,
                std::nullopt != a, std::nullopt < a, std::nullopt > a, std::nullopt <= a, std::nullopt >= a);
}
static int many(long n) {
    std::optional<long> a[64];
    unsigned x = 12345;
    long s = 0, has = 0, less = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned k = (x >> 8) % 64;
        if (x >> 31) a[k] = (long)(x >> 12 & 1023);
        else a[k] = std::nullopt;
        s += a[(x >> 16) % 64].value_or(1L);
        has += a[k].has_value();
        less += a[k] < a[(k + 1) % 64];
    }
    std::printf("%ld %ld %ld\n", s, has, less);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::optional<int> a;
    std::optional<int> b = 5;
    show("born", &a);
    show("five", &b);
    a = 7;
    show("seven", &a);
    std::printf("%d %d %d %d\n", a.has_value(), a.value(), a.value_or(3), b.value_or(3));
    auto q = a;
    a = std::nullopt;
    show("nullopt", &a);
    show("copy", &q);
    std::printf("%d %d %d\n", a.value_or(3), twice(q), twice(a));
    show("after twice", &q);
    int *p = &a.emplace(40);
    *p += 2;
    show("emplace", &a);
    a.swap(b);
    show("swap a", &a);
    show("swap b", &b);
    b.reset();
    show("reset", &b);
    std::optional<int> none;
    std::optional<int> one = 1;
    std::optional<int> two = 2;
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
    std::optional<double> d = 2.5;
    std::optional<double> e;
    std::printf("%g %g %d %d %d %d\n", d.value(), e.value_or(-1.0), d == 2.5, e < d, d > 2.0, 3.0 > d);
    e = d;
    d.emplace(0.5);
    std::printf("%g %g %d %d\n", d.value(), e.value(), d < e, e == std::nullopt);
    std::optional<char> c = (char)'x';
    std::optional<char> f;
    std::printf("%c %c %d %d %d\n", c.value(), f.value_or((char)'-'), c == (char)'x', f < c, (char)'y' > c);
    point origin = {0, 0};
    point corner = {3, 4};
    std::optional<point> pt = corner;
    std::optional<point> gone;
    std::printf("%d %d %d %d\n", pt.value().x, pt.value().y, gone.has_value(), gone.value_or(origin).y);
    gone.emplace(origin).x = 9;
    std::printf("%d %d\n", gone.value().x, gone.value().y);
    pt.swap(gone);
    gone.reset();
    std::printf("%d %d %d\n", pt.value().x, pt.has_value(), gone.has_value());
    return 0;
}
