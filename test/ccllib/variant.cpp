// the twin of variant.c over std::variant (0.308): clang++ builds it over libc++, and it prints variant.expect, the
// lines that the C build and the C++ build of variant.c print. visit's callable is a lambda over overloads of one name,
// where variant.c calls a function by each alternative's type word
#include <cstdio>
#include <cstdlib>
#include <optional>
#include <utility>
#include <variant>
struct point { int x, y; };
static void show(int x) { std::printf("int %d\n", x); }
static void show(double x) { std::printf("double %g\n", x); }
static void show(char x) { std::printf("char %c\n", x); }
static void show(const point &p) { std::printf("point %d %d\n", p.x, p.y); }
static void show(std::monostate) { std::printf("monostate\n"); }
static void show(const std::pair<int, int> &p) { std::printf("pair %d %d\n", p.first, p.second); }
static int weight(int x) { return x; }
static int weight(double x) { return (int)(x * 10); }
static int weight(char x) { return x - 'a'; }
static void twice(int *x) { *x *= 2; }
static void twice(double *x) { *x *= 2; }
static void twice(char *x) { *x = (char)(*x + 1); }
static void say(const char *what, const std::variant<int, double, char> *v) {
    std::printf("%s: %zu ", what, v->index());
    std::visit([](const auto &x) { show(x); }, *v);
}
static void rel(const char *what, std::variant<int, double> a, std::variant<int, double> b) {
    std::printf("%s: %d %d %d %d %d %d\n", what, a == b, a != b, a < b, a > b, a <= b, a >= b);
}
static int many(long n) {
    std::variant<int, double, char> a[64];
    unsigned x = 12345;
    long less = 0, same = 0, s = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned k = (x >> 8) % 64, j = (x >> 16) % 64;
        switch (x >> 29 & 3) {
        case 0: a[k] = (int)(x >> 20 & 15); break;
        case 1: a[k] = (double)(x >> 22 & 7) / 2; break;
        default: a[k] = (char)('a' + (x >> 18 & 7)); break;
        }
        less += a[k] < a[j];
        same += a[k] == a[j];
        s += std::visit([](auto y) { return weight(y); }, a[j]);
    }
    std::printf("%ld %ld %ld\n", less, same, s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::variant<int, double, char> v;
    say("born", &v);
    v = 2.5;
    say("of a double", &v);
    v = 7;
    say("of an int", &v);
    v = (char)'q';
    say("of a char", &v);
    std::variant<int, double, char> w = 1.25;
    say("made of a double", &w);
    std::printf("holds: %d %d %d\n", std::holds_alternative<int>(w), std::holds_alternative<double>(w),
                std::holds_alternative<char>(w));
    std::get<1>(w) += 1;
    std::get<double>(w) *= 2;
    say("places", &w);
    double *pd = std::get_if<double>(&w);
    int *pi = std::get_if<0>(&w);
    std::printf("get_if: %d %g\n", pi != 0, pd ? *pd : -1.0);
    if (pd) *pd = 0.5;
    say("through get_if", &w);
    w.emplace<int>(3) += 1;
    say("emplace", &w);
    w.emplace<2>('m');
    say("emplace a char", &w);
    auto u = w;
    std::get<char>(u) = 'n';
    say("the first", &w);
    say("its copy", &u);
    v = 5;
    w = 0.25;
    std::swap(v, w);
    say("swap v", &v);
    say("swap w", &w);
    auto wt = [](auto y) { return weight(y); };
    std::printf("visit: %d %d %d\n", std::visit(wt, v), std::visit(wt, w), std::visit(wt, u));
    auto tw = [](auto &y) { twice(&y); };
    std::visit(tw, v);
    std::visit(tw, w);
    std::visit(tw, u);
    say("twice v", &v);
    say("twice w", &w);
    say("twice u", &u);
    std::printf("valueless: %d\n", v.valueless_by_exception());
    std::variant<int, double> a = 1, b = 2, c = 1.5, d = 0.5;
    rel("a a", a, a);
    rel("a b", a, b);
    rel("b a", b, a);
    rel("a c", a, c);
    rel("c a", c, a);
    rel("c d", c, d);
    volatile double zero = 0.0;
    std::variant<int, double> nan = zero / zero;
    rel("nan nan", nan, nan);
    rel("nan a", nan, a);
    rel("c nan", c, nan);
    std::variant<std::monostate, int> m;
    std::variant<std::monostate, int> m5 = 5;
    std::printf("monostate: %zu %d %d %d %d\n", m.index(), m == m, m < m5, m5 <= m, m >= m);
    auto sh = [](const auto &y) { show(y); };
    std::visit(sh, m);
    std::visit(sh, m5);
    point origin = {1, 2};
    std::variant<point, int> sp = origin;
    std::get<point>(sp).y = 3;
    std::visit(sh, sp);
    sp = 4;
    std::visit(sh, sp);
    std::pair<int, int> one = {1, 2};
    std::variant<std::pair<int, int>, int> vp = one;
    std::variant<std::pair<int, int>, int> vq = 9;
    std::get<0>(vp).second = 5;
    std::visit(sh, vp);
    std::printf("pair: %d %d %d\n", vp == vp, vp < vq, vq < vp);
    std::variant<int, char> vc = (char)'k';
    std::pair<std::variant<int, char>, int> pv = {vc, 3};
    std::printf("in a pair: %zu %c %d\n", pv.first.index(), std::get<char>(pv.first), pv.second);
    std::optional<std::variant<int, double>> ov = c;
    auto oc = ov.value();
    std::printf("in an optional: %d %zu %g\n", ov.has_value(), oc.index(), std::get<1>(oc));
    return 0;
}
