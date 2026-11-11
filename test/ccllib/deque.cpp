// the twin of deque.c over std::deque (0.276): clang++ builds it over libc++, and what it prints is deque.expect
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <utility>
struct point { int x, y; };
static void show(const char *what, const std::deque<int> *d) {
    std::printf("%s:", what);
    for (size_t i = 0; i < d->size(); i++) std::printf(" %d", d->at(i));
    std::printf(" | %zu\n", d->size());
}
static long total(std::deque<int> d) {
    long s = 0;
    for (size_t i = 0; i < d.size(); i++) s += d[i];
    return s;
}
static int many(long n) {
    std::deque<int> q;
    unsigned x = 12345;
    long s = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        q.push_back((int)((x >> 8) % 1000));
        if (i % 4 == 3) { s += q.front(); q.pop_front(); }
        if (i % 16 == 5) q.push_front((int)(i % 100));
    }
    std::deque<int> w = q;
    size_t gone = std::erase(w, 7);
    w.insert(w.begin() + w.size() / 4, 4, -1);
    w.erase(w.begin() + (w.size() - 3));
    for (size_t i = 0; i < w.size(); i++) s += w[i];
    for (size_t i = 0; i < q.size(); i += 1 + q.size() / 16) s += q.at(i);
    std::printf("%zu %zu %zu %ld %d\n", q.size(), w.size(), gone, s, q < w);
    return 0;
}
static int walk(long n) {
    std::deque<int> d;
    unsigned x = 54321;
    unsigned long h = 0;
    int three[3] = {1, 2, 3};
    if (n > 300000) n = 300000;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned op = (x >> 16) % 16, r = (x >> 8) & 0xffff;
        size_t z = d.size();
        if (op < 3) d.push_back((int)r);
        else if (op < 6) d.push_front((int)r);
        else if (op == 6 && z) { h += (unsigned long)d.back(); d.pop_back(); }
        else if (op == 7 && z) { h += (unsigned long)d.front(); d.pop_front(); }
        else if (op == 8) d.insert(d.begin() + r % (z + 1), (int)i);
        else if (op == 9) d.insert(d.begin() + r % (z + 1), r % 5, (int)i);
        else if (op == 10 && z) d.erase(d.begin() + r % z);
        else if (op == 11 && z) {
            size_t a = r % z, b = a + (r >> 3) % (z - a + 1);
            d.erase(d.begin() + a, d.begin() + (b > a + 6 ? a + 6 : b));
        }
        else if (op == 12 && z) h = h * 31 + (unsigned long)d.at(r % z);
        else if (op == 13 && z) d[r % z] = (int)i;
        else if (op == 14 && r % 64 == 0) d.shrink_to_fit();
        else if (op == 14 && r % 64 == 1) d.resize(z / 2);
        else if (op == 14 && r % 64 == 2) d.resize(z + r % 7, -1);
        else if (op == 15 && r % 512 == 0) {
            d.insert(d.begin() + r % (z + 1), three, three + 3);
            d.insert(d.begin(), three, three + 2);
            d.insert(d.end(), three, three + 1);
        }
        h = h * 131 + d.size();
    }
    for (size_t i = 0; i < d.size(); i++) h = h * 31 + (unsigned long)d[i];
    std::printf("%lu %zu\n", h, d.size());
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1])) + walk(std::atol(argv[1]));
    std::deque<int> d;
    std::printf("%d %zu %d\n", d.empty(), d.size(), d.max_size() > 1000000);
    d.push_back(5); d.push_front(3); d.push_back(9); d.emplace_back(1); d.emplace_front(4);
    show("push", &d);
    std::printf("%d %d %d %d %zu %zu\n", d.at(2), d[1], d.front(), d.back(), d.size(), d.size());
    d[1] = 42;
    show("index", &d);
    for (int i = 0; i < 20; i++) { d.push_front(100 + i); d.push_back(200 + i); }
    show("round", &d);
    d.insert(d.begin() + 1, 11);
    d.insert(d.begin() + (d.size() - 1), 12);
    d.insert(d.begin(), 2, 8);
    d.emplace(d.end(), 6);
    show("insert", &d);
    int more[3] = {70, 71, 72};
    d.insert(d.begin() + 2, more, more + 3);
    d.insert(d.end(), more, more + 2);
    d.insert(d.begin(), more, more + 1);
    show("ranges", &d);
    d.erase(d.begin());
    d.erase(d.begin() + 1, d.begin() + 3);
    d.erase(d.begin() + (d.size() - 4), d.begin() + (d.size() - 2));
    show("erase", &d);
    int last = d.back(); d.pop_back();
    int before = d.back(); d.pop_back();
    int first = d.front(); d.pop_front();
    std::printf("%d %d %d\n", last, before, first);
    d.push_back(9); d.push_front(9);
    size_t gone = std::erase(d, 9);
    show("erase_value", &d);
    std::printf("%zu\n", gone);
    d.resize(3);
    show("resize", &d);
    d.resize(5);
    d.resize(7, -4);
    show("resize up", &d);
    d.shrink_to_fit();
    show("shrink", &d);
    std::deque<int> w = {1, 2, 3};
    std::deque<int> u = w;
    u.push_back(4);
    std::printf("%d %d %d %d %d %d\n", w == u, w != u, w < u, w > u, w <= u, w >= u);
    std::swap(w, u);
    show("swap", &w);
    show("swap", &u);
    w.assign(3, 6);
    u.assign(more, more + 3);
    show("assign", &w);
    show("assign", &u);
    w.clear();
    std::printf("%d %zu\n", w.empty(), w.size());
    std::deque<double> f = {2.5, -1, 0.25};
    f.push_front(4);
    double fs = 0;
    for (size_t i = 0; i < f.size(); i++) fs += f[i];
    std::printf("%g %g %g %zu\n", fs, f.front(), f.back(), f.size());
    std::deque<point> ps;
    ps.push_back(point{1, 2});
    ps.push_front(point{3, 4});
    ps[0].y = 20;
    std::printf("%d %d %d %zu\n", ps[0].x, ps[0].y, ps.at(1).y, ps.size());
    std::printf("%ld\n", total(std::move(d)));
    return 0;
}
