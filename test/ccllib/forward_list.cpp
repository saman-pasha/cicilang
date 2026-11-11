// the twin of forward_list.c over std::forward_list (0.278): clang++ builds it over libc++, and what it prints is
// forward_list.expect
#include <cstdio>
#include <cstdlib>
#include <forward_list>
#include <iterator>
#include <utility>
struct point { int x, y; };
static void show(const char *what, const std::forward_list<int> *l) {
    size_t n = 0;
    std::printf("%s:", what);
    for (auto p = l->begin(); p != l->end(); ++p) { std::printf(" %d", *p); n++; }
    std::printf(" | %zu\n", n);
}
static int odd(int x) { return x & 1; }
static int greater(int a, int b) { return a > b; }
static int same_tens(int a, int b) { return a / 10 == b / 10; }
static long total(std::forward_list<int> l) {
    long s = 0;
    for (auto p = l.begin(); p != l.end(); ++p) s += *p;
    return s;
}
static int many(long n) {
    std::forward_list<int> l;
    unsigned x = 12345;
    long s = 0;
    size_t count = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        l.push_front((int)((x >> 8) % 100000));
    }
    size_t gone = l.remove(7);
    auto p = l.before_begin();
    for (long i = 0; i < n / 2 && std::next(p) != l.end(); i++) {
        if (i % 3 == 0) l.erase_after(p);
        else ++p;
    }
    l.sort();
    size_t doubles = l.unique();
    l.reverse();
    for (auto q = l.begin(); q != l.end(); ++q) { s += *q % 7; count++; }
    std::printf("%zu %zu %zu %ld %d\n", count, gone, doubles, s, l.front());
    return 0;
}
// std::forward_list has no size: the walk counts its elements in z, as a program that needs the count does
static int walk(long n) {
    std::forward_list<int> l;
    std::forward_list<int> o;
    unsigned x = 54321;
    unsigned long h = 0;
    size_t z = 0;
    auto c = l.before_begin();
    int three[3] = {1, 2, 3};
    if (n > 300000) n = 300000;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned op = (x >> 16) % 16, r = (x >> 8) & 0xffff;
        if (op < 4) { l.push_front((int)(r % 512)); z++; }
        else if (op == 4 && !l.empty()) {
            if (c == l.begin()) c = l.before_begin();
            h += (unsigned long)l.front();
            l.pop_front();
            z--;
        }
        else if (op < 7) { l.insert_after(c, (int)(i % 512)); z++; }
        else if (op == 7) { l.insert_after(c, r % 4, (int)(i % 512)); z += r % 4; }
        else if (op < 10 && std::next(c) != l.end()) { l.erase_after(c); z--; }
        else if (op == 10 || op == 11) c = std::next(c) == l.end() ? l.before_begin() : std::next(c);
        else if (op == 12 && c != l.before_begin()) h = h * 31 + (unsigned long)*c;
        else if (op == 13 && c != l.before_begin()) *c = (int)(i % 512);
        else if (op == 14 && r % 64 == 0) l.reverse();
        else if (op == 14 && r % 64 == 1) l.sort();
        else if (op == 14 && r % 64 == 2) { c = l.before_begin(); size_t g = l.unique(); h += g; z -= g; }
        else if (op == 14 && r % 64 == 3) { c = l.before_begin(); size_t g = l.remove((int)(r % 512)); h += g; z -= g; }
        else if (op == 14 && r % 64 == 4) { c = l.before_begin(); z /= 2; l.resize(z); }
        else if (op == 14 && r % 64 == 5) { z += r % 7; l.resize(z, -1); }
        else if (op == 15 && r % 256 == 0) {
            l.insert_after(c, three, three + 3);
            l.insert_after(l.before_begin(), three, three + 2);
            z += 5;
        }
        else if (op == 15 && r % 256 == 1) { o.assign(three, three + 3); l.splice_after(c, o); z += 3; }
        else if (op == 15 && r % 256 == 2) { o.assign(2, 7); l.sort(); l.merge(o); z += 2; }
        h = h * 131 + z + (c != l.before_begin() ? (unsigned long)*c : 7u);
    }
    for (auto p = l.begin(); p != l.end(); ++p) h = h * 31 + (unsigned long)*p;
    std::printf("%lu %zu\n", h, z);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1])) + walk(std::atol(argv[1]));
    std::forward_list<int> l;
    std::printf("%d %d\n", l.empty(), l.max_size() > 1000000);
    l.push_front(5); l.push_front(3); l.emplace_front(4);
    show("push", &l);
    size_t count = (size_t)std::distance(l.begin(), l.end());
    std::printf("%d %zu %zu\n", l.front(), count, count);
    auto p = std::next(l.begin());
    *p = 42;
    std::printf("%d %d\n", *p, *std::next(l.before_begin()));
    show("index", &l);
    auto q = l.insert_after(p, 11);
    l.insert_after(l.before_begin(), 2, 8);
    l.emplace_after(q, 6);
    show("insert", &l);
    std::printf("%d %d\n", *p, *q);
    int more[3] = {70, 71, 72};
    auto r = l.insert_after(q, more, more + 3);
    l.insert_after(l.before_begin(), more, more + 2);
    show("ranges", &l);
    std::printf("%d\n", *r);
    r = l.erase_after(l.before_begin());
    std::printf("%d\n", *r);
    l.erase_after(l.begin(), q);
    show("erase", &l);
    l.erase_after(l.begin(), std::next(l.begin()));
    show("erase none", &l);
    int first = l.front(); l.pop_front();
    std::printf("%d\n", first);
    l.push_front(9); l.insert_after(q, 9);
    size_t gone = l.remove(9);
    show("remove", &l);
    size_t gone72 = std::erase(l, 72);
    std::printf("%zu %zu\n", gone, gone72);
    for (int i = 0; i < 12; i++) l.push_front(i * 7 % 5 + i % 2 * 10);
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
    l.resize(2);
    show("resize", &l);
    l.resize(4);
    l.resize(6, -4);
    show("resize up", &l);
    std::forward_list<int> w = {1, 5, 9};
    std::forward_list<int> u = {2, 5, 6, 10};
    w.merge(u);
    show("merge", &w);
    show("merged", &u);
    std::forward_list<int> g = {9, 4};
    std::forward_list<int> h = {7, 5, 1};
    g.merge(h, greater);
    show("merge by", &g);
    std::forward_list<int> c = w;
    c.push_front(0);
    std::printf("%d %d %d %d %d %d\n", w == c, w != c, w < c, w > c, w <= c, w >= c);
    std::swap(w, c);
    show("swap", &w);
    show("swap", &c);
    c.splice_after(c.begin(), g);
    show("splice", &c);
    show("spliced", &g);
    c.splice_after(c.before_begin(), w, w.begin());
    show("splice one", &c);
    show("spliced one", &w);
    c.splice_after(c.begin(), w, w.begin(), w.end());
    show("splice some", &c);
    show("spliced some", &w);
    w.assign(3, 6);
    c.assign(more, more + 3);
    show("assign", &w);
    show("assign", &c);
    w.clear();
    std::printf("%d\n", w.empty());
    std::forward_list<double> f = {2.5, -1, 0.25};
    f.push_front(4);
    double fs = 0;
    for (auto i = f.begin(); i != f.end(); ++i) fs += *i;
    std::printf("%g %g\n", fs, f.front());
    std::forward_list<point> ps;
    ps.push_front(point{1, 2});
    ps.push_front(point{3, 4});
    ps.begin()->y = 20;
    std::printf("%d %d %d\n", ps.front().x, ps.front().y, std::next(ps.begin())->y);
    std::printf("%ld\n", total(std::move(l)));
    return 0;
}
