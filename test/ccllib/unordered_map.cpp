// the twin of unordered_map.c over std::unordered_map and std::unordered_multimap (0.283): clang++ builds it over
// libc++, and what it prints is unordered_map.expect
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <unordered_map>
#include <utility>
#include <vector>
struct point { int x, y; };
struct point_hash { size_t operator()(point p) const { return (unsigned long)p.x * 31u + (unsigned long)p.y; } };
struct point_eq { bool operator()(point a, point b) const { return a.x == b.x && a.y == b.y; } };
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static void show(const char *what, const std::unordered_map<int, long> &m) {
    size_t walked = 0;
    printf("%s:", what);
    for (int k = -5; k <= 1000; k++) if (m.contains(k)) printf(" %d=%ld", k, m.at(k));
    for (auto p = m.begin(); p != m.end(); ++p) walked++;
    printf(" | %zu %zu\n", m.size(), walked);
}
static void show_multi(const char *what, const std::unordered_multimap<int, long> &m) {
    size_t walked = 0;
    printf("%s:", what);
    for (int k = -5; k <= 1000; k++) {
        std::vector<long> vals;
        auto r = m.equal_range(k);
        for (auto p = r.first; p != r.second; ++p) vals.push_back(p->second);
        std::sort(vals.begin(), vals.end());
        for (long v : vals) printf(" %d=%ld", k, v);
    }
    for (auto p = m.begin(); p != m.end(); ++p) walked++;
    printf(" | %zu %zu\n", m.size(), walked);
}
static long total(std::unordered_map<int, long> m) {
    long t = 0;
    for (auto &e : m) t += e.first * e.second;
    return t;
}
static int many(long n) {
    std::unordered_map<int, int> m;
    long hits = 0, sum = 0;
    if (n < 1) n = 1;
    seed = 12345;
    for (long i = 0; i < n; i++) m[(int)(rnd() % (unsigned)n)] += 1;
    for (long i = 0; i < n; i++) { int k = (int)(rnd() % (unsigned)n); if (m.contains(k)) hits += m.at(k); }
    for (long i = 0; i < n / 2; i++) hits += (long)m.erase((int)(rnd() % (unsigned)n));
    for (auto p = m.begin(); p != m.end(); ++p) sum += p->first % 5 + p->second;
    printf("%zu %ld %ld\n", m.size(), hits, sum);
    return 0;
}
static unsigned long walk_map(long n, int range) {
    std::unordered_map<int, long> m;
    unsigned long h = 0, sum = 0, x = 0;
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
                h = h * 5 + (unsigned long)p->second + (unsigned long)p->first;
            }
        }
        else if (op == 12) {
            auto p = m.find(k);
            if (p != m.end()) { h = h * 5 + (unsigned long)p->second; m.erase(p); }
        }
        else if (op == 13 && i % 64 == 0) {
            size_t met = 0, before = m.size();
            for (auto p = m.begin(); p != m.end(); ) {
                met++;
                if (p->first < k) p = m.erase(p); else ++p;
            }
            h = h * 7 + (unsigned long)(met == before) + m.size();
        }
        else if (i % 4096 == 0) { std::unordered_map<int, long> c = m; h = h * 3 + (unsigned long)(c == m) + c.size(); }
        h += m.size();
        if (!m.empty()) {
            auto p = m.begin();
            int first = p->first;
            long was = p->second;
            m[first] += 2;
            h += (unsigned long)m.insert({first, 0}).second;
            h += (unsigned long)m.insert_or_assign(first, was).second;
            h += m.erase(range);
            h += (unsigned long)(p->first == first && p->second == was);
        }
    }
    for (auto p = m.begin(); p != m.end(); ++p) {
        unsigned long e = (unsigned long)p->first * 2654435761u + (unsigned long)p->second * 40503u;
        sum += e;
        x ^= e + 7u;
    }
    return h * 31 + sum + x;
}
static unsigned long walk_multimap(long n, int range) {
    std::unordered_multimap<int, long> m;
    unsigned long h = 0, sum = 0, x = 0;
    for (long i = 0; i < n; i++) {
        unsigned op = rnd() % 16;
        int k = (int)(rnd() % (unsigned)range);
        if (i > n / 2 && op < 6) op += 6;
        if (op < 6) { m.insert({k, i}); h = h * 3 + 1u; }
        else if (op < 8) h = h * 3 + m.erase(k);
        else if (op < 10) {
            auto r = m.equal_range(k);
            auto best = r.first;
            for (auto p = r.first; p != r.second; ++p) if (p->second < best->second) best = p;
            if (r.first != r.second) {
                h = h * 5 + (unsigned long)best->second;
                m.erase(best);
                h = h * 5 + m.count(k);
            }
        }
        else if (op == 10) h = h * 3 + (unsigned long)m.contains(k) + m.count(k);
        else if (op == 11) {
            unsigned long vs = 0;
            auto r = m.equal_range(k);
            for (auto p = r.first; p != r.second; ++p) vs += (unsigned long)p->second;
            h = h * 5 + vs + 1u;
        }
        else if (op == 13 && i % 64 == 0) {
            size_t met = 0, before = m.size();
            for (auto p = m.begin(); p != m.end(); ) {
                met++;
                if (p->first < k) p = m.erase(p); else ++p;
            }
            h = h * 7 + (unsigned long)(met == before) + m.size();
        }
        else if (i % 4096 == 0) {
            std::unordered_multimap<int, long> c = m;
            h = h * 3 + (unsigned long)(c == m) + c.size();
        }
        h += m.size();
        if (!m.empty()) {
            auto p = m.begin();
            int first = p->first;
            long was = p->second;
            h += m.erase(range);
            p->second = was;
            h += (unsigned long)(p->first == first && p->second == was);
        }
    }
    for (auto p = m.begin(); p != m.end(); ++p) {
        unsigned long e = (unsigned long)p->first * 2654435761u + (unsigned long)p->second * 40503u;
        sum += e;
        x ^= e + 7u;
    }
    return h * 31 + sum + x;
}
static int walk(long n) {
    if (n > 100000) n = 100000;
    seed = 54321;
    unsigned long a = walk_map(n, 64), b = walk_map(n, 100000);
    printf("%lu %lu ", a, b);
    a = walk_multimap(n, 64); b = walk_multimap(n, 20000);
    printf("%lu %lu\n", a, b);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) { int r = many(atol(argv[1])); return r + walk(atol(argv[1])); }
    std::unordered_map<int, long> m;
    size_t met = 0;
    printf("%d %zu %d\n", (int)m.empty(), m.size(), (int)(m.max_size() > 1000000));
    for (int i = 0; i < 40; i++) printf("%d", (int)m.insert({i * 7 % 23, (long)i * 10}).second);
    printf(" %d", (int)m.emplace(100, 1).second);
    printf(" %d", (int)m.try_emplace(100, 2).second);
    printf(" %d\n", (int)m.try_emplace(101, 3).second);
    show("insert", m);
    printf("%zu %zu %d %d %zu %zu\n", m.size(), m.size(), (int)m.contains(5), (int)m.contains(99), m.count(7),
           m.count(99));
    long v7 = m.at(7), v14 = m.at(14), v21 = m[21];
    printf("%ld %ld %ld\n", v7, v14, v21);
    m[21] = 5;
    m[300] += 7;
    m[300] += 7;
    printf("%d", (int)m.insert_or_assign(7, 77).second);
    bool n400 = m.insert_or_assign(400, 4).second;
    printf(" %d %ld %ld\n", (int)n400, m.at(7), m[300]);
    m.insert_or_assign(8, 88);
    auto p = m.find(9);
    p->second = 99;
    printf("%d %ld %d\n", p->first, p->second, (int)(m.find(50) == m.end()));
    size_t gone = m.erase(5);
    printf("%zu %zu\n", gone, m.erase(5));
    m.erase(m.find(9));
    for (p = m.begin(); p != m.end(); ) {
        met++;
        if (p->second % 20 == 0) p = m.erase(p); else ++p;
    }
    printf("%zu\n", met);
    show("erase", m);
    std::unordered_map<int, long> t = {{70, 7}, {3, 333}, {80, 8}};
    m.merge(t);
    show("merge", m);
    show("merged", t);
    std::unordered_map<int, long> c = m;
    printf("%d %d", (int)(m == c), (int)(m != c));
    c[0] = -1;
    printf(" %d %d\n", (int)(m == c), (int)(m != c));
    m.swap(c);
    printf("%ld %d\n", m.at(0), (int)c.contains(0));
    c.clear();
    printf("%d %zu\n", (int)c.empty(), c.size());
    std::unordered_map<int, long> r;
    r.reserve(1000);
    size_t slots = r.bucket_count();
    for (int i = 0; i < 1000; i++) r[i * 3] = i;
    printf("%d %d %d\n", (int)(r.bucket_count() == slots), (int)(r.load_factor() <= r.max_load_factor()),
           (int)(r.load_factor() > 0));
    r.rehash(4096);
    printf("%d %zu %ld %d\n", (int)(r.bucket_count() >= 4096), r.size(), r.at(2997), (int)r.contains(2998));
    std::unordered_map<point, int, point_hash, point_eq> pm;
    pm[point{3, 30}] = 1;
    pm[point{1, 10}] = 2;
    pm[point{3, 30}] += 10;
    printf("%d %d %d %zu\n", pm.at(point{3, 30}), pm.at(point{1, 10}), (int)pm.contains(point{1, 11}), pm.size());
    std::unordered_map<int, point> ps;
    ps[3] = point{3, 30};
    ps[1] = point{1, 10};
    ps[3].y = 31;
    printf("%d %d %zu\n", ps.at(3).y, ps.at(1).x, ps.size());
    std::unordered_map<double, int> f = {{2.5, 1}, {0.0, 2}};
    f[-0.0] += 5;
    printf("%d %d %zu\n", f.at(0.0), f.at(2.5), f.size());
    std::unordered_multimap<int, long> mm;
    for (int i = 0; i < 12; i++) mm.insert({i * 5 % 4, (long)i});
    mm.emplace(2, 100);
    show_multi("multimap", mm);
    printf("%zu %zu %d %d\n", mm.count(2), mm.count(9), (int)mm.contains(3), (int)(mm.find(9) == mm.end()));
    long vs = 0;
    auto r1 = mm.equal_range(1);
    for (auto q = r1.first; q != r1.second; ++q) vs += q->second;
    printf("%ld %d\n", vs, (int)(mm.count(1) <= 3));
    auto r2 = mm.equal_range(2);
    for (auto q = r2.first; q != r2.second; ++q) {
        if (q->second == 6) { mm.erase(q); break; }
    }
    size_t held = mm.count(2);
    gone = mm.erase(3);
    printf("%zu %zu %zu\n", held, gone, mm.size());
    std::unordered_multimap<int, long> mt;
    mt.insert({2, 500});
    mt.insert({0, 600});
    mm.merge(mt);
    show_multi("multimap merge", mm);
    std::unordered_multimap<int, long> mc = mm;
    printf("%zu %d", mt.size(), (int)(mm == mc));
    mc.erase(2);
    mc.insert({2, 500});
    mc.insert({2, 100});
    mc.insert({2, 10});
    mc.insert({2, 2});
    printf(" %d", (int)(mm == mc));
    mc.find(0)->second = -1;
    printf(" %d\n", (int)(mm == mc));
    printf("%ld\n", total(m));
    return 0;
}
