// the twin of set.c over std::set and std::multiset (0.281): clang++ builds it over libc++, and what it prints is
// set.expect
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <iterator>
#include <set>
#include <utility>
struct point { int x, y; };
struct by_x { bool operator()(const point &a, const point &b) const { return a.x < b.x; } };
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static void show(const char *what, const std::set<int> *s) {
    std::printf("%s:", what);
    for (auto p = s->begin(); p != s->end(); ++p) std::printf(" %d", *p);
    std::printf(" | %zu\n", s->size());
}
static void show_multi(const char *what, const std::multiset<int> *s) {
    std::printf("%s:", what);
    for (auto p = s->begin(); p != s->end(); ++p) std::printf(" %d", *p);
    std::printf(" | %zu\n", s->size());
}
static long total(std::set<int> s) {
    long t = 0;
    for (auto p = s.begin(); p != s.end(); ++p) t += *p;
    return t;
}
static int many(long n) {
    std::set<int> s;
    long hits = 0, sum = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) s.insert((int)rnd());
    for (long i = 0; i < n; i++) hits += s.contains((int)rnd());
    for (long i = 0; i < n / 2; i++) hits += (long)s.erase((int)rnd());
    for (auto p = s.begin(); p != s.end(); ++p) sum += *p % 7;
    std::printf("%zu %ld %ld\n", s.size(), hits, sum);
    return 0;
}
static unsigned long walk_set(long n, int range) {
    std::set<int> s;
    unsigned long h = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) h = h * 3 + (unsigned long)s.insert(k).second;
        else if (op < 10) h = h * 3 + s.erase(k);
        else if (op == 10) h = h * 3 + (unsigned long)s.contains(k) + s.count(k);
        else if (op == 11) {
            auto p = s.find(k);
            if (p != s.end()) { h += (unsigned long)s.insert(k).second; h += s.erase(range); }
            h = h * 5 + (p != s.end() ? (unsigned long)*p : 1u);
        }
        else if (op == 12) {
            auto p = s.lower_bound(k), q = s.upper_bound(k);
            h = h * 7 + (p != s.end() ? (unsigned long)*p : 3u) + (q != s.end() ? (unsigned long)*q : 5u);
        }
        else if (op == 13) {
            auto p = s.lower_bound(k);
            for (int j = 0; j < 5 && p != s.end(); j++) { h = h * 3 + (unsigned long)*p; ++p; }
            for (int j = 0; j < 7; j++) {
                if (p == s.begin()) break;
                --p;
                if (p == s.begin()) break;
                h = h * 3 + (unsigned long)*p;
            }
        }
        else if (op == 14) {
            auto p = s.lower_bound(k);
            if (p != s.end()) { p = s.erase(p); h = h * 5 + (p != s.end() ? (unsigned long)*p : 9u); }
        }
        else if (i % 4096 == 0) { std::set<int> c = s; h = h * 3 + (unsigned long)(c == s) + c.size(); }
        h += s.size();
    }
    for (auto p = s.begin(); p != s.end(); ++p) h = h * 31 + (unsigned long)*p;
    return h;
}
static unsigned long walk_multiset(long n, int range) {
    std::multiset<int> s;
    unsigned long h = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) { s.insert(k); h = h * 3 + 1; }
        else if (op < 8) h = h * 3 + s.erase(k);
        else if (op < 10) {
            auto p = s.lower_bound(k);
            if (p != s.end() && *p == k) { p = s.erase(p); h = h * 5 + (p != s.end() ? (unsigned long)*p : 9u); }
        }
        else if (op == 10) h = h * 3 + (unsigned long)s.contains(k) + s.count(k);
        else if (op == 12) {
            auto p = s.lower_bound(k), q = s.upper_bound(k);
            h = h * 7 + (p != s.end() ? (unsigned long)*p : 3u) + (q != s.end() ? (unsigned long)*q : 5u);
        }
        else if (op == 13) {
            auto p = s.lower_bound(k);
            for (int j = 0; j < 5 && p != s.end(); j++) { h = h * 3 + (unsigned long)*p; ++p; }
            for (int j = 0; j < 7; j++) {
                if (p == s.begin()) break;
                --p;
                if (p == s.begin()) break;
                h = h * 3 + (unsigned long)*p;
            }
        }
        h += s.size();
    }
    for (auto p = s.begin(); p != s.end(); ++p) h = h * 31 + (unsigned long)*p;
    return h;
}
static int walk(long n) {
    if (n > 100000) n = 100000;
    seed = 54321;
    unsigned long a = walk_set(n, 64), b = walk_set(n, 100000);
    std::printf("%lu %lu ", a, b);
    a = walk_multiset(n, 64); b = walk_multiset(n, 20000);
    std::printf("%lu %lu\n", a, b);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1])) + walk(std::atol(argv[1]));
    std::set<int> s;
    std::printf("%d %zu %d\n", s.empty(), s.size(), s.max_size() > 1000000);
    for (int i = 0; i < 40; i++) std::printf("%d", (int)s.insert(i * 7 % 23).second);
    std::printf(" %d\n", (int)s.emplace(100).second);
    show("insert", &s);
    std::printf("%zu %zu %d %d %zu %zu\n", s.size(), s.size(), s.contains(5), s.contains(99), s.count(7), s.count(99));
    auto p = s.find(9);
    std::printf("%d %d %d %d\n", *p, *std::next(p), *std::prev(p), s.find(50) == s.end());
    std::printf("%d %d %d %d\n", *s.lower_bound(10), *s.upper_bound(10), *s.lower_bound(23),
                s.upper_bound(100) == s.end());
    size_t e1 = s.erase(5), e2 = s.erase(5);
    std::printf("%zu %zu %d\n", e1, e2, *std::prev(s.end()));
    p = s.erase(s.find(9));
    std::printf("%d\n", *p);
    int more[4] = {50, 3, 60, 50};
    s.insert(more, more + 4);
    show("erase", &s);
    std::set<int> t = {70, 3, 80, 4};
    s.merge(t);
    show("merge", &s);
    show("merged", &t);
    std::set<int> c = s;
    c.insert(1000);
    std::printf("%d %d %d %d %d %d\n", s == c, s != c, s < c, s > c, s <= c, s >= c);
    std::swap(s, c);
    std::printf("%zu %zu\n", s.size(), c.size());
    c.clear();
    std::printf("%d %zu\n", c.empty(), c.size());
    std::set<int, std::greater<int>> d = {5, 3, 9, 1};
    d.insert(4);
    for (auto q = d.begin(); q != d.end(); ++q) std::printf("%d ", *q);
    std::printf("| %zu %d\n", d.size(), *d.lower_bound(6));
    std::set<point, by_x> ps;
    ps.insert(point{3, 30});
    ps.insert(point{1, 10});
    std::printf("%d", (int)ps.insert(point{3, 99}).second);
    for (auto q = ps.begin(); q != ps.end(); ++q) std::printf(" %d:%d", q->x, q->y);
    std::printf(" | %zu\n", ps.size());
    std::set<double> f = {2.5, -1, 0.25};
    std::printf("%g %g %zu\n", *f.begin(), *std::prev(f.end()), f.size());
    std::multiset<int> ms = {5, 3, 5, 1, 5};
    ms.insert(3);
    ms.emplace(9);
    show_multi("multiset", &ms);
    std::printf("%zu %zu %d %d %d\n", ms.count(5), ms.count(4), ms.contains(3), *ms.lower_bound(4), *ms.upper_bound(5));
    auto mp = ms.erase(ms.lower_bound(5));
    size_t c5 = ms.count(5), e3 = ms.erase(3);
    std::printf("%d %zu %zu %zu\n", *mp, c5, e3, ms.size());
    std::multiset<int> mt = {5, 2};
    ms.merge(mt);
    std::multiset<int> mc = ms;
    show_multi("multiset merge", &ms);
    std::printf("%zu %d %d\n", mt.size(), ms == mc, ms < mc);
    std::multiset<int, std::greater<int>> md = {1, 7, 7, 3};
    for (auto q = md.begin(); q != md.end(); ++q) std::printf("%d ", *q);
    std::printf("| %zu\n", md.size());
    std::printf("%ld\n", total(std::move(s)));
    return 0;
}
