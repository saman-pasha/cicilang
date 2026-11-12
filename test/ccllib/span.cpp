// span.c's twin over std::span (0.295): what clang++ and libc++ print is span.expect
#include <array>
#include <cstdio>
#include <cstdlib>
#include <span>
#include <vector>
static long total(std::span<const int> s) {
    long t = 0;
    for (const int *p = s.data(); p != s.data() + s.size(); p++) t += *p;
    return t;
}
static void twice(std::span<int> s) {
    for (size_t i = 0; i < s.size(); i++) s[i] *= 2;
}
static void show(const char *what, std::span<const int> s) {
    std::printf("%s=[", what);
    for (size_t i = 0; i < s.size(); i++) std::printf(i ? " %d" : "%d", s[i]);
    std::printf("] %zu\n", s.size());
}
static std::span<int> middle(std::span<int> s) { return s.subspan(1, s.size() - 2); }
static int many(long n) {
    std::vector<int> v;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        v.push_back((int)((x >> 8) % 1000));
    }
    std::span<int> w = v;
    twice(w.first(w.size() / 4));
    std::span<const int> s = v;
    long whole = total(s);
    long halves = total(s.first(s.size() / 2)) + total(s.last(s.size() - s.size() / 2));
    long windows = 0;
    for (size_t at = 0; at + 64 <= s.size(); at += 64) windows += total(s.subspan(at, 64));
    std::printf("%ld %ld %ld %ld\n", whole, halves, windows, total(s.subspan(s.size() / 3)));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    int a[6] = {1, 2, 3, 4, 5, 6};
    std::vector<int> v = {10, 20, 30, 40};
    std::array<int, 3> r = {7, 8, 9};
    std::span<int> s = a;
    std::span<int> t(a + 1, 3);
    std::span<int> sv = v;
    std::span<int> sr = r;
    std::span<const int> c = s;
    std::span<const int> cv = v;
    std::span<const int> cr = r;
    std::span<int> e;
    std::printf("%zu %zu %zu %zu %zu %d %d\n", s.size(), t.size_bytes(), sv.size(), sr.size(), e.size(), (int) e.empty(),
                (int) s.empty());
    std::printf("%d %d %d %d %d %d\n", s[0], s[2], t.front(), t.back(), *sr.data(), cv[3]);
    s[0] = 100;
    twice(t);
    sv[3] = 41;
    sr[1] += 1;
    std::span<const int> ca = c;
    show("a", ca);
    show("v", cv);
    show("r", cr);
    int sum = 0;
    for (int *p = sv.data(); p != sv.data() + sv.size(); p++) sum += *p;
    std::printf("%d %ld %ld\n", sum, total(cv), total(c));
    std::span<const int> f = c.first(2);
    std::span<const int> l = c.last(2);
    std::span<const int> o = c.subspan(4);
    std::span<const int> m = c.subspan(1, 3);
    std::span<const int> all = c.subspan(0, std::dynamic_extent);
    std::span<const int> none = c.subspan(6);
    show("first", f);
    show("last", l);
    show("off", o);
    show("mid", m);
    show("all", all);
    show("none", none);
    std::span<int> mid = middle(s);
    twice(mid);
    show("a", c);
    std::span<int> l3 = s.last(3);
    std::span<int> one = l3.first(1);
    one[0] = -1;
    show("a", c);
    return 0;
}
