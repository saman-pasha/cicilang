// the twin of map.c over std::map and std::multimap (0.281): clang++ builds it over libc++, and what it prints is
// map.expect
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <iterator>
#include <map>
#include <utility>
struct point { int x, y; };
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static void show(const char *what, const std::map<int, long> *m) {
    std::printf("%s:", what);
    for (auto p = m->begin(); p != m->end(); ++p) std::printf(" %d=%ld", p->first, p->second);
    std::printf(" | %zu\n", m->size());
}
static void show_multi(const char *what, const std::multimap<int, long> *m) {
    std::printf("%s:", what);
    for (auto p = m->begin(); p != m->end(); ++p) std::printf(" %d=%ld", p->first, p->second);
    std::printf(" | %zu\n", m->size());
}
static long total(std::map<int, long> m) {
    long t = 0;
    for (auto p = m.begin(); p != m.end(); ++p) t += p->first * p->second;
    return t;
}
static int many(long n) {
    std::map<int, int> m;
    long hits = 0, sum = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) m[(int)(rnd() % (unsigned)n)] += 1;
    for (long i = 0; i < n; i++) { int k = (int)(rnd() % (unsigned)n); if (m.contains(k)) hits += m.at(k); }
    for (long i = 0; i < n / 2; i++) hits += (long)m.erase((int)(rnd() % (unsigned)n));
    for (auto p = m.begin(); p != m.end(); ++p) sum += p->first % 5 + p->second;
    std::printf("%zu %ld %ld\n", m.size(), hits, sum);
    return 0;
}
static unsigned long walk_map(long n, int range) {
    std::map<int, long> m;
    unsigned long h = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 3) h = h * 3 + (unsigned long)m.insert({k, i}).second;
        else if (op < 5) h = h * 3 + (unsigned long)m.insert_or_assign(k, i * 2).second;
        else if (op == 5) { m[k] += 1; h = h * 3 + (unsigned long)m[k]; }
        else if (op < 10) h = h * 3 + m.erase(k);
        else if (op == 10) h = h * 3 + (m.contains(k) ? (unsigned long)m.at(k) + (unsigned long)m.at(k) : 1u);
        else if (op == 11) {
            auto p = m.find(k);
            if (p != m.end()) {
                m[k] += 2;
                h += (unsigned long)m.insert({k, 0}).second;
                h += (unsigned long)m.insert_or_assign(k, p->second + 3).second;
                h += m.erase(range);
                p->second += 5;
                h = h * 5 + (unsigned long)p->second;
            }
        }
        else if (op == 12) {
            auto p = m.lower_bound(k), q = m.upper_bound(k);
            h = h * 7 + (p != m.end() ? (unsigned long)p->second : 3u) + (q != m.end() ? (unsigned long)q->first : 5u);
        }
        else if (op == 13) {
            auto p = m.lower_bound(k);
            for (int j = 0; j < 5 && p != m.end(); j++) {
                h = h * 3 + (unsigned long)p->first + (unsigned long)p->second;
                ++p;
            }
        }
        else if (op == 14) {
            auto p = m.lower_bound(k);
            if (p != m.end()) { p = m.erase(p); h = h * 5 + (p != m.end() ? (unsigned long)p->second : 9u); }
        }
        else if (i % 4096 == 0) {
            std::map<int, long> c = m;
            h = h * 3 + (unsigned long)(c == m) + (unsigned long)(c < m) + c.size();
        }
        h += m.size();
    }
    for (auto p = m.begin(); p != m.end(); ++p) h = h * 31 + (unsigned long)p->first * 3 + (unsigned long)p->second;
    return h;
}
static unsigned long walk_multimap(long n, int range) {
    std::multimap<int, long> m;
    unsigned long h = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) { m.insert({k, i}); h = h * 3 + 1; }
        else if (op < 8) h = h * 3 + m.erase(k);
        else if (op < 10) {
            auto p = m.lower_bound(k);
            if (p != m.end() && p->first == k) {
                if (rnd() % 2 && std::next(p) != m.end()) ++p;
                h = h * 5 + (unsigned long)p->second;
                p = m.erase(p);
                h = h * 5 + (p != m.end() ? (unsigned long)p->second : 9u);
            }
        }
        else if (op == 10) h = h * 3 + m.count(k);
        else if (op == 12) {
            auto p = m.lower_bound(k), q = m.upper_bound(k);
            h = h * 7 + (p != m.end() ? (unsigned long)p->second : 3u) + (q != m.end() ? (unsigned long)q->second : 5u);
        }
        else if (op == 13) {
            auto p = m.lower_bound(k);
            for (int j = 0; j < 5 && p != m.end(); j++) {
                h = h * 3 + (unsigned long)p->first + (unsigned long)p->second;
                ++p;
            }
            for (int j = 0; j < 7; j++) {
                if (p == m.begin()) break;
                --p;
                if (p == m.begin()) break;
                h = h * 3 + (unsigned long)p->second;
            }
        }
        h += m.size();
    }
    for (auto p = m.begin(); p != m.end(); ++p) h = h * 31 + (unsigned long)p->first * 3 + (unsigned long)p->second;
    return h;
}
static int walk(long n) {
    if (n > 100000) n = 100000;
    seed = 54321;
    unsigned long a = walk_map(n, 64), b = walk_map(n, 100000);
    std::printf("%lu %lu ", a, b);
    a = walk_multimap(n, 64); b = walk_multimap(n, 20000);
    std::printf("%lu %lu\n", a, b);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1])) + walk(std::atol(argv[1]));
    std::map<int, long> m;
    std::printf("%d %zu %d\n", m.empty(), m.size(), m.max_size() > 1000000);
    for (int i = 0; i < 40; i++) std::printf("%d", (int)m.insert({i * 7 % 23, (long)i * 10}).second);
    int r1 = m.emplace(100, 1).second, r2 = m.try_emplace(100, 2).second, r3 = m.try_emplace(101, 3).second;
    std::printf(" %d %d %d\n", r1, r2, r3);
    show("insert", &m);
    std::printf("%zu %zu %d %d %zu %zu\n", m.size(), m.size(), m.contains(5), m.contains(99), m.count(7), m.count(99));
    std::printf("%ld %ld %ld\n", m.at(7), m.at(14), m[21]);
    m[21] = 5;
    m[300] += 7;
    m[300] += 7;
    int a1 = m.insert_or_assign(7, 77).second, a2 = m.insert_or_assign(400, 4).second;
    std::printf("%d %d %ld %ld\n", a1, a2, m.at(7), m[300]);
    m.insert_or_assign(8, 88);
    auto p = m.find(9);
    p->second = 99;
    std::printf("%d %ld %d %d %d\n", p->first, p->second, std::next(p)->first, std::prev(p)->first,
                m.find(50) == m.end());
    std::printf("%d %d %d %d\n", m.lower_bound(10)->first, m.upper_bound(10)->first, m.lower_bound(23)->first,
                m.upper_bound(400) == m.end());
    size_t e1 = m.erase(5), e2 = m.erase(5);
    std::printf("%zu %zu %d\n", e1, e2, std::prev(m.end())->first);
    p = m.erase(m.find(9));
    std::printf("%d %ld\n", p->first, p->second);
    show("erase", &m);
    std::map<int, long> t = {{70, 7}, {3, 333}, {80, 8}};
    m.merge(t);
    show("merge", &m);
    show("merged", &t);
    std::map<int, long> c = m;
    c[0] = -1;
    std::printf("%d %d %d %d %d %d\n", m == c, m != c, m < c, m > c, m <= c, m >= c);
    std::swap(m, c);
    std::printf("%ld %ld\n", m.at(0), c.at(0));
    c.clear();
    std::printf("%d %zu\n", c.empty(), c.size());
    std::map<int, double, std::greater<int>> d = {{5, 0.5}, {3, 0.25}, {9, 1.5}};
    d[4] = 2;
    for (auto q = d.begin(); q != d.end(); ++q) std::printf("%d=%g ", q->first, q->second);
    std::printf("| %zu %d\n", d.size(), d.lower_bound(6)->first);
    std::map<int, point> ps;
    ps[3] = point{3, 30};
    ps[1] = point{1, 10};
    ps[3].y = 31;
    std::printf("%d %d %d %zu\n", ps.at(3).y, ps.at(1).x, ps.begin()->second.y, ps.size());
    std::map<int, double> e = {{1, 2.5}, {2, 0.5}};
    std::printf("%g %g %zu\n", e.at(1), e[2], e.size());
    std::multimap<int, long> mm;
    for (int i = 0; i < 12; i++) mm.insert({i * 5 % 4, (long)i});
    mm.emplace(2, 100);
    show_multi("multimap", &mm);
    std::printf("%zu %zu %d %ld %d\n", mm.count(2), mm.count(9), mm.contains(3), mm.lower_bound(1)->second,
                mm.upper_bound(1)->first);
    auto mp = mm.erase(std::next(mm.lower_bound(2)));
    int mk = mp->first; long mv = mp->second;
    size_t c2 = mm.count(2), e3 = mm.erase(3);
    std::printf("%d %ld %zu %zu %zu\n", mk, mv, c2, e3, mm.size());
    std::multimap<int, long> mt;
    mt.insert({2, 500});
    mt.insert({0, 600});
    mm.merge(mt);
    std::multimap<int, long> mc = mm;
    show_multi("multimap merge", &mm);
    std::printf("%zu %d %d\n", mt.size(), mm == mc, mm < mc);
    std::printf("%ld\n", total(std::move(m)));
    return 0;
}
