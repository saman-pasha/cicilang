// the twin of list.c over std::list (0.277): clang++ builds it over libc++, and what it prints is list.expect
#include <cstdio>
#include <cstdlib>
#include <iterator>
#include <list>
#include <utility>
struct point { int x, y; };
static void show(const char *what, const std::list<int> *l) {
    std::printf("%s:", what);
    for (auto p = l->begin(); p != l->end(); ++p) std::printf(" %d", *p);
    std::printf(" | %zu\n", l->size());
}
static int odd(int x) { return x & 1; }
static int greater(int a, int b) { return a > b; }
static int same_tens(int a, int b) { return a / 10 == b / 10; }
static long total(std::list<int> l) {
    long s = 0;
    for (auto p = l.begin(); p != l.end(); ++p) s += *p;
    return s;
}
static int many(long n) {
    std::list<int> l;
    unsigned x = 12345;
    long s = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        if (i % 8 == 5) l.push_front((int)((x >> 8) % 100000));
        else l.push_back((int)((x >> 8) % 100000));
    }
    size_t gone = l.remove(7);
    auto p = l.begin();
    for (long i = 0; i < n / 2 && p != l.end(); i++) p = i % 3 == 0 ? l.erase(p) : std::next(p);
    l.sort();
    size_t doubles = l.unique();
    l.reverse();
    for (auto q = l.begin(); q != l.end(); ++q) s += *q % 7;
    std::printf("%zu %zu %zu %ld %d %d\n", l.size(), gone, doubles, s, l.front(), l.back());
    return 0;
}
static int walk(long n) {
    std::list<int> l;
    std::list<int> o;
    unsigned x = 54321;
    unsigned long h = 0;
    auto c = l.end();
    int three[3] = {1, 2, 3};
    if (n > 300000) n = 300000;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned op = (x >> 16) % 16, r = (x >> 8) & 0xffff;
        size_t z = l.size();
        if (op < 3) l.push_back((int)(r % 512));
        else if (op < 5) l.push_front((int)(r % 512));
        else if (op == 5 && z) { if (c == std::prev(l.end())) c = l.end(); h += (unsigned long)l.back(); l.pop_back(); }
        else if (op == 6 && z) { if (c == l.begin()) c = l.end(); h += (unsigned long)l.front(); l.pop_front(); }
        else if (op == 7) l.insert(c, (int)(i % 512));
        else if (op == 8) l.insert(c, r % 4, (int)(i % 512));
        else if (op == 9 && c != l.end()) c = l.erase(c);
        else if (op == 10) c = c == l.end() ? l.begin() : std::next(c);
        else if (op == 11) c = c == l.begin() ? l.end() : std::prev(c);
        else if (op == 12 && c != l.end()) h = h * 31 + (unsigned long)*c;
        else if (op == 13 && c != l.end()) *c = (int)(i % 512);
        else if (op == 14 && r % 64 == 0) l.reverse();
        else if (op == 14 && r % 64 == 1) l.sort();
        else if (op == 14 && r % 64 == 2) { c = l.end(); h += l.unique(); }
        else if (op == 14 && r % 64 == 3) { c = l.end(); h += l.remove((int)(r % 512)); }
        else if (op == 14 && r % 64 == 4) { c = l.end(); l.resize(z / 2); }
        else if (op == 14 && r % 64 == 5) l.resize(z + r % 7, -1);
        else if (op == 15 && r % 256 == 0) {
            l.insert(c, three, three + 3);
            l.insert(l.begin(), three, three + 2);
            l.insert(l.end(), three, three + 1);
        }
        else if (op == 15 && r % 256 == 1) { o.assign(three, three + 3); l.splice(c, o); }
        else if (op == 15 && r % 256 == 2) { o.assign(2, 7); l.sort(); l.merge(o); }
        h = h * 131 + l.size() + (c != l.end() ? (unsigned long)*c : 7u);
    }
    for (auto p = l.begin(); p != l.end(); ++p) h = h * 31 + (unsigned long)*p;
    std::printf("%lu %zu\n", h, l.size());
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1])) + walk(std::atol(argv[1]));
    std::list<int> l;
    std::printf("%d %zu %d\n", l.empty(), l.size(), l.max_size() > 1000000);
    l.push_back(5); l.push_front(3); l.push_back(9); l.emplace_back(1); l.emplace_front(4);
    show("push", &l);
    std::printf("%d %d %zu %zu\n", l.front(), l.back(), l.size(), l.size());
    auto p = std::next(l.begin());
    *p = 42;
    std::printf("%d %d %d\n", *p, *std::prev(p), *std::prev(l.end()));
    show("index", &l);
    auto q = l.insert(p, 11);
    l.insert(l.end(), 12);
    l.insert(l.begin(), 2, 8);
    l.emplace(q, 6);
    show("insert", &l);
    std::printf("%d %d\n", *p, *q);
    int more[3] = {70, 71, 72};
    auto r = l.insert(q, more, more + 3);
    l.insert(l.end(), more, more + 2);
    l.insert(l.begin(), more, more + 1);
    show("ranges", &l);
    std::printf("%d\n", *r);
    r = l.erase(l.begin());
    std::printf("%d\n", *r);
    l.erase(std::next(l.begin()), q);
    show("erase", &l);
    int last = l.back(); l.pop_back();
    int before = l.back(); l.pop_back();
    int first = l.front(); l.pop_front();
    std::printf("%d %d %d\n", last, before, first);
    l.push_back(9); l.push_front(9);
    size_t gone = l.remove(9);
    show("remove", &l);
    size_t gone12 = std::erase(l, 12);
    std::printf("%zu %zu\n", gone, gone12);
    for (int i = 0; i < 12; i++) l.push_back(i * 7 % 5 + i % 2 * 10);
    show("more", &l);
    std::printf("%zu\n", (size_t)l.remove_if(odd));
    show("remove_if", &l);
    l.sort();
    show("sort", &l);
    std::printf("%zu\n", (size_t)l.unique());
    show("unique", &l);
    std::printf("%zu\n", (size_t)l.unique(same_tens));
    show("unique by", &l);
    l.sort(greater);
    show("sort by", &l);
    l.reverse();
    show("reverse", &l);
    l.resize(3);
    show("resize", &l);
    l.resize(5);
    l.resize(7, -4);
    show("resize up", &l);
    std::list<int> w = {1, 5, 9};
    std::list<int> u = {2, 5, 6, 10};
    w.merge(u);
    show("merge", &w);
    show("merged", &u);
    std::list<int> g = {9, 4};
    std::list<int> h = {7, 5, 1};
    g.merge(h, greater);
    show("merge by", &g);
    std::list<int> c = w;
    c.push_back(4);
    std::printf("%d %d %d %d %d %d\n", w == c, w != c, w < c, w > c, w <= c, w >= c);
    std::swap(w, c);
    show("swap", &w);
    show("swap", &c);
    c.splice(std::next(c.begin()), g);
    show("splice", &c);
    show("spliced", &g);
    c.splice(c.begin(), w, std::prev(w.end()));
    show("splice one", &c);
    show("spliced one", &w);
    c.splice(c.end(), w, std::next(w.begin()), std::prev(w.end()));
    show("splice some", &c);
    show("spliced some", &w);
    w.assign(3, 6);
    c.assign(more, more + 3);
    show("assign", &w);
    show("assign", &c);
    w.clear();
    std::printf("%d %zu\n", w.empty(), w.size());
    std::list<double> f = {2.5, -1, 0.25};
    f.push_front(4);
    double fs = 0;
    for (auto i = f.begin(); i != f.end(); ++i) fs += *i;
    std::printf("%g %g %g %zu\n", fs, f.front(), f.back(), f.size());
    std::list<point> ps;
    ps.push_back(point{1, 2});
    ps.push_front(point{3, 4});
    ps.begin()->y = 20;
    std::printf("%d %d %d %zu\n", ps.front().x, ps.front().y, ps.back().y, ps.size());
    std::printf("%ld\n", total(std::move(l)));
    return 0;
}
