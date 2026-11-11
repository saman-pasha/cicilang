// the twin of unordered_set.c over std::unordered_set and std::unordered_multiset (0.283): clang++ builds it over
// libc++, and what it prints is unordered_set.expect
#include <cstdio>
#include <cstdlib>
#include <unordered_set>
#include <utility>
struct point { int x, y; };
struct point_hash { size_t operator()(point p) const { return (unsigned long)p.x * 31u + (unsigned long)p.y; } };
struct point_eq { bool operator()(point a, point b) const { return a.x == b.x && a.y == b.y; } };
struct weak { size_t operator()(int k) const { return (unsigned long)(k & 3); } };
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static void show(const char *what, const std::unordered_set<int> &s) {
    size_t walked = 0;
    printf("%s:", what);
    for (int k = -5; k <= 1000; k++) if (s.contains(k)) printf(" %d", k);
    for (auto p = s.begin(); p != s.end(); ++p) walked++;
    printf(" | %zu %zu\n", s.size(), walked);
}
static void show_multi(const char *what, const std::unordered_multiset<int> &s) {
    size_t walked = 0;
    printf("%s:", what);
    for (int k = -5; k <= 1000; k++) for (size_t i = 0; i < s.count(k); i++) printf(" %d", k);
    for (auto p = s.begin(); p != s.end(); ++p) walked++;
    printf(" | %zu %zu\n", s.size(), walked);
}
static long total(std::unordered_set<int> s) {
    long t = 0;
    for (int k : s) t += k;
    return t;
}
static int many(long n) {
    std::unordered_set<int> s;
    long hits = 0, sum = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) s.insert((int)(rnd() % (unsigned)(2 * n)));
    for (long i = 0; i < n; i++) hits += s.contains((int)(rnd() % (unsigned)(2 * n)));
    for (long i = 0; i < n / 2; i++) hits += (long)s.erase((int)(rnd() % (unsigned)(2 * n)));
    for (auto p = s.begin(); p != s.end(); ++p) sum += *p % 7;
    printf("%zu %ld %ld\n", s.size(), hits, sum);
    return 0;
}
static unsigned long walk_set(long n, int range) {
    std::unordered_set<int> s;
    unsigned long h = 0, sum = 0, x = 0;
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
            auto p = s.find(k);
            if (p != s.end()) { s.erase(p); h = h * 5 + 9u; }
        }
        else if (op == 13 && i % 64 == 0) {
            size_t met = 0, before = s.size();
            for (auto p = s.begin(); p != s.end(); ) {
                met++;
                if (*p < k) p = s.erase(p); else ++p;
            }
            h = h * 7 + (unsigned long)(met == before) + s.size();
        }
        else if (i % 4096 == 0) { std::unordered_set<int> c = s; h = h * 3 + (unsigned long)(c == s) + c.size(); }
        h += s.size();
        if (!s.empty()) {
            auto p = s.begin();
            int first = *p;
            h += (unsigned long)s.insert(first).second;
            h += s.erase(range);
            h += (unsigned long)(*p == first);
        }
    }
    for (auto p = s.begin(); p != s.end(); ++p) {
        sum += (unsigned long)*p * 2654435761u;
        x ^= (unsigned long)*p * 40503u + 7u;
    }
    return h * 31 + sum + x;
}
static unsigned long walk_multiset(long n, int range) {
    std::unordered_multiset<int> s;
    unsigned long h = 0, sum = 0, x = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) { s.insert(k); h = h * 3 + 1u; }
        else if (op < 8) h = h * 3 + s.erase(k);
        else if (op < 10) {
            auto p = s.find(k);
            if (p != s.end()) { s.erase(p); h = h * 5 + s.count(k); }
        }
        else if (op == 10) h = h * 3 + (unsigned long)s.contains(k) + s.count(k);
        else if (op == 11) {
            size_t seen = 0;
            auto r = s.equal_range(k);
            for (auto p = r.first; p != r.second; ++p) seen += (size_t)(*p == k);
            h = h * 5 + seen + 1u;
        }
        else if (op == 13 && i % 64 == 0) {
            size_t met = 0, before = s.size();
            for (auto p = s.begin(); p != s.end(); ) {
                met++;
                if (*p < k) p = s.erase(p); else ++p;
            }
            h = h * 7 + (unsigned long)(met == before) + s.size();
        }
        else if (i % 4096 == 0) { std::unordered_multiset<int> c = s; h = h * 3 + (unsigned long)(c == s) + c.size(); }
        h += s.size();
        if (!s.empty()) {
            auto p = s.begin();
            int first = *p;
            h += s.erase(range);
            h += (unsigned long)(*p == first);
        }
    }
    for (auto p = s.begin(); p != s.end(); ++p) {
        sum += (unsigned long)*p * 2654435761u;
        x ^= (unsigned long)*p * 40503u + 7u;
    }
    return h * 31 + sum + x;
}
static int walk(long n) {
    if (n > 100000) n = 100000;
    seed = 54321;
    unsigned long a = walk_set(n, 64), b = walk_set(n, 100000);
    printf("%lu %lu ", a, b);
    a = walk_multiset(n, 64); b = walk_multiset(n, 20000);
    printf("%lu %lu\n", a, b);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) { int r = many(atol(argv[1])); return r + walk(atol(argv[1])); }
    std::unordered_set<int> s;
    size_t met = 0;
    printf("%d %zu %d\n", (int)s.empty(), s.size(), (int)(s.max_size() > 1000000));
    for (int i = 0; i < 40; i++) printf("%d", (int)s.insert(i * 7 % 23).second);
    printf(" %d\n", (int)s.emplace(100).second);
    show("insert", s);
    printf("%zu %zu %d %d %zu %zu\n", s.size(), s.size(), (int)s.contains(5), (int)s.contains(99), s.count(7),
           s.count(99));
    auto p = s.find(9);
    printf("%d %d\n", *p, (int)(s.find(50) == s.end()));
    size_t e1 = s.erase(5), e2 = s.erase(5);
    printf("%zu %zu\n", e1, e2);
    s.erase(s.find(9));
    for (p = s.begin(); p != s.end(); ) {
        met++;
        if (*p % 2 == 0) p = s.erase(p); else ++p;
    }
    printf("%zu\n", met);
    show("odd", s);
    int more[4] = {50, 3, 60, 50};
    s.insert(more, more + 4);
    show("range", s);
    std::unordered_set<int> t = {70, 3, 80, 4};
    s.merge(t);
    show("merge", s);
    show("merged", t);
    std::unordered_set<int> c = s;
    printf("%d %d", (int)(s == c), (int)(s != c));
    c.insert(1000);
    printf(" %d %d\n", (int)(s == c), (int)(s != c));
    s.swap(c);
    printf("%zu %zu\n", s.size(), c.size());
    c.clear();
    printf("%d %zu\n", (int)c.empty(), c.size());
    std::unordered_set<int> r;
    r.reserve(1000);
    size_t slots = r.bucket_count();
    for (int i = 0; i < 1000; i++) r.insert(i * 3);
    printf("%d %d %d\n", (int)(r.bucket_count() == slots), (int)(r.load_factor() <= r.max_load_factor()),
           (int)(r.load_factor() > 0));
    r.rehash(4096);
    printf("%d %zu %d %d\n", (int)(r.bucket_count() >= 4096), r.size(), (int)r.contains(2997), (int)r.contains(2998));
    std::unordered_set<point, point_hash, point_eq> ps;
    ps.insert(point{3, 30});
    ps.insert(point{1, 10});
    bool again = ps.insert(point{3, 30}).second;
    printf("%d %d %d %zu\n", (int)again, (int)ps.contains(point{1, 10}), (int)ps.contains(point{1, 11}), ps.size());
    std::unordered_set<int, weak> w;
    long sum = 0;
    for (int i = 0; i < 200; i++) w.insert(i);
    for (auto q = w.begin(); q != w.end(); ++q) sum += *q;
    size_t n0 = w.size();
    bool has = w.contains(199);
    printf("%zu %ld %d %zu\n", n0, sum, (int)has, w.erase(77));
    std::unordered_set<double> f = {2.5, -1, 0.25, 0.0};
    bool c0 = f.contains(-0.0), c1 = f.contains(2.5), i0 = f.insert(-0.0).second;
    printf("%d %d %d %zu\n", (int)c0, (int)c1, (int)i0, f.size());
    std::unordered_multiset<int> ms = {5, 3, 5, 1, 5};
    ms.insert(3);
    ms.emplace(9);
    show_multi("multiset", ms);
    printf("%zu %zu %d %d\n", ms.count(5), ms.count(4), (int)ms.contains(3), (int)(ms.find(4) == ms.end()));
    met = 0;
    auto rg = ms.equal_range(5);
    for (auto q = rg.first; q != rg.second; ++q) met += (size_t)(*q == 5);
    printf("%zu %d\n", met, (int)(ms.count(5) <= 3));
    ms.erase(ms.find(5));
    size_t c5 = ms.count(5), e3 = ms.erase(3);
    printf("%zu %zu %zu\n", c5, e3, ms.size());
    std::unordered_multiset<int> mt = {5, 2};
    ms.merge(mt);
    std::unordered_multiset<int> mc = ms;
    show_multi("multiset merge", ms);
    printf("%zu %d", mt.size(), (int)(ms == mc));
    mc.erase(mc.find(5));
    printf(" %d\n", (int)(ms == mc));
    std::unordered_multiset<point, point_hash, point_eq> pm;
    for (int i = 0; i < 9; i++) pm.insert(point{i % 2, 7});
    size_t p0 = pm.count(point{0, 7}), p1 = pm.count(point{1, 7});
    printf("%zu %zu %zu\n", p0, p1, pm.erase(point{1, 7}));
    printf("%ld\n", total(s));
    return 0;
}
