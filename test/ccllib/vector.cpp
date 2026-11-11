// the twin of vector.c over std::vector (0.274): clang++ builds it over libc++, and what it prints is vector.expect
#include <cstdio>
#include <cstdlib>
#include <utility>
#include <vector>
struct point { int x, y; };
static void show(const char *what, const std::vector<int> *v) {
    std::printf("%s:", what);
    for (size_t i = 0; i < v->size(); i++) std::printf(" %d", v->at(i));
    std::printf(" | %zu\n", v->size());
}
static long total(std::vector<int> v) {
    long s = 0;
    for (const int *p = v.data(); p != v.data() + v.size(); p++) s += *p;
    return s;
}
static int many(long n) {
    std::vector<int> v;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) { x = x * 1103515245u + 12345u; v.push_back((int)((x >> 8) % 1000)); }
    std::vector<int> w = v;
    size_t gone = std::erase(w, 7);
    w.insert(w.begin() + w.size() / 2, 4, -1);
    w.resize(w.size() + 3, 5);
    long s = 0;
    for (const int *p = w.data(); p != w.data() + w.size(); p++) s += *p;
    for (size_t i = 0; i < v.size(); i += 1 + v.size() / 16) s += v[i];
    std::printf("%zu %zu %zu %ld %d\n", v.size(), w.size(), gone, s, v < w);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::vector<int> v;
    std::printf("%d %zu %d\n", v.empty(), v.size(), v.max_size() > 1000000);
    v.push_back(5); v.push_back(3); v.push_back(9); v.emplace_back(1);
    show("push_back", &v);
    std::printf("%d %d %d %d %zu %zu\n", v.at(2), v[1], v.front(), v.back(), v.size(), v.size());
    v[1] = 42;
    *v.data() = 7;
    show("index", &v);
    v.reserve(100);
    std::printf("%zu %d\n", v.capacity(), v.capacity() >= v.size());
    v.shrink_to_fit();
    std::printf("%zu\n", v.capacity());
    v.insert(v.begin() + 1, 11);
    v.insert(v.begin(), 2, 8);
    v.emplace(v.end(), 6);
    show("insert", &v);
    int more[3] = {70, 71, 72};
    v.insert(v.begin() + 2, more, more + 3);
    v.insert(v.end(), more, more + 2);
    show("ranges", &v);
    v.erase(v.begin());
    v.erase(v.begin() + 1, v.begin() + 3);
    show("erase", &v);
    int last = v.back(); v.pop_back();
    int before = v.back(); v.pop_back();
    std::printf("%d %d\n", last, before);
    v.push_back(9); v.push_back(9);
    size_t gone = std::erase(v, 9);
    show("erase_value", &v);
    std::printf("%zu\n", gone);
    v.resize(3);
    show("resize", &v);
    v.resize(5);
    v.resize(7, -4);
    show("resize up", &v);
    std::vector<int> w = {1, 2, 3};
    std::vector<int> u = w;
    u.push_back(4);
    std::printf("%d %d %d %d %d %d\n", w == u, w != u, w < u, w > u, w <= u, w >= u);
    w.swap(u);
    show("swap", &w);
    show("swap", &u);
    w.assign(3, 6);
    u.assign(more, more + 3);
    show("assign", &w);
    show("assign", &u);
    w.clear();
    std::printf("%d %zu\n", w.empty(), w.size());
    std::vector<double> d = {2.5, -1, 0.25};
    d.push_back(4);
    double ds = 0;
    for (const double *p = d.data(); p != d.data() + d.size(); p++) ds += *p;
    std::printf("%g %g %zu\n", ds, d.back(), d.size());
    std::vector<point> ps;
    ps.push_back(point{1, 2});
    ps.push_back(point{3, 4});
    ps[0].y = 20;
    std::printf("%d %d %d %zu\n", ps[0].x, ps[0].y, ps.at(1).y, ps.size());
    std::vector<bool> bs;
    bs.push_back(1); bs.push_back(0); bs.push_back(1);
    std::printf("%d %d %d %zu\n", (int)bs.at(0), (int)bs.at(1), (int)bs[2], bs.size());
    d = {9.5, 8.5};
    std::printf("%g %zu\n", d.back(), d.size());
    w = u;
    w = {4, 5};
    u = std::move(w);
    u = u;
    show("assigned", &u);
    std::printf("%ld\n", total(std::move(v)));
    return 0;
}
