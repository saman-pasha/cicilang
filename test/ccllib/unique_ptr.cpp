// the twin of unique_ptr.c over std::unique_ptr (0.309): clang++ builds it over libc++, and it prints unique_ptr.expect,
// the lines that the C build and the C++ build of unique_ptr.c print. A move is std::move, where unique_ptr.c moves
// every object of an instance's type; the object of an own pointer is made by new, which the deleter's delete frees
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <optional>
#include <utility>
struct point { int x, y; };
static void show(const char *what, const std::unique_ptr<point> *u) {
    const point *b = u->get();
    if (b) std::printf("%s: %d %d\n", what, b->x, b->y);
    else std::printf("%s: empty\n", what);
}
static std::unique_ptr<point> made(int x, int y) {
    point pt = {x, y};
    std::unique_ptr<point> u = std::make_unique<point>(pt);
    return u;
}
static int taken(std::unique_ptr<point> u) { return u->x + u->y; }
static int many(long n) {
    unsigned x = 12345;
    long s = 0;
    std::unique_ptr<int> keep = std::make_unique<int>(0);
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        std::unique_ptr<int> u = std::make_unique<int>((int)(x >> 16 & 255));
        if (x >> 30 & 1) {
            s += *u;
            keep = std::move(u);
        } else {
            int *r = u.release();
            s += *r * 2;
            delete r;
        }
        s += *keep;
    }
    std::printf("%ld\n", s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::unique_ptr<point> p;
    show("born", &p);
    point pt = {1, 2};
    std::unique_ptr<point> q = std::make_unique<point>(pt);
    show("made of a value", &q);
    std::unique_ptr<point> z = std::make_unique<point>();
    show("made of none", &z);
    q->x = 3;
    (*q).y += 2;
    show("places", &q);
    std::printf("values: %d %d\n", q->x, (*q).y);
    point *r = q.release();
    p.reset(r);
    show("released", &q);
    show("reset to the released", &p);
    std::swap(p, z);
    show("swap p", &p);
    show("swap z", &z);
    std::printf("relations: %d %d %d %d %d %d\n", p == p, p != p, p < p, p <= p, p > p, p >= p);
    std::printf("unequal: %d %d\n", p == z, p != z);
    p.reset();
    show("reset", &p);
    p = std::move(z);
    show("moved by an assignment", &p);
    std::unique_ptr<point> m = made(5, 6);
    show("moved out of a function", &m);
    std::printf("moved into a function: %d\n", taken(std::move(m)));
    point *s = new point;
    s->x = 7;
    s->y = 8;
    std::unique_ptr<point> t(s);
    show("made of an own pointer", &t);
    std::unique_ptr<int> n = std::make_unique<int>(5);
    *n += 1;
    std::printf("int: %d\n", *n);
    std::pair<int, double> pr = {1, 2.5};
    std::unique_ptr<std::pair<int, double>> up = std::make_unique<std::pair<int, double>>(pr);
    up->second *= 2;
    std::printf("pair: %d %g\n", up->first, (*up).second);
    std::optional<int> o = 4;
    std::unique_ptr<std::optional<int>> uo = std::make_unique<std::optional<int>>(o);
    std::printf("optional: %d %d\n", uo->has_value(), uo->value());
    return 0;
}
