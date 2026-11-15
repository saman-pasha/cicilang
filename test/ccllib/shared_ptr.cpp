// the twin of shared_ptr.c over std::shared_ptr (1.1.3): clang++ builds it over libc++, and it prints shared_ptr.expect,
// the lines that the C build and the C++ build of shared_ptr.c print. A copy is a copy here, where shared_ptr.c writes
// clone(t); a move is std::move, where shared_ptr.c moves every object of an instance's type. A block is made by
// std::make_shared and freed by the last owner
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <optional>
#include <utility>
struct point { int x, y; };
static void show(const char *what, const std::shared_ptr<point> *u) {
    const point *b = u->get();
    if (b) std::printf("%s: %d %d %zu %d\n", what, b->x, b->y, u->use_count(), u->use_count() == 1);
    else std::printf("%s: empty %zu\n", what, u->use_count());
}
static std::shared_ptr<point> made(int x, int y) {
    point pt = {x, y};
    std::shared_ptr<point> u = std::make_shared<point>(pt);
    return u;
}
static int taken(std::shared_ptr<point> u) { return u->x + u->y; }
static int many(long n) {
    unsigned x = 12345;
    long s = 0;
    std::shared_ptr<int> keep = std::make_shared<int>(0);
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        std::shared_ptr<int> u = std::make_shared<int>((int)(x >> 16 & 255));
        if (x >> 30 & 1) {
            s += *u;
            std::shared_ptr<int> c = u;
            s += *c * 2;
        } else {
            s += *u;
            keep = std::move(u);
        }
        s += *keep;
    }
    std::printf("%ld\n", s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::shared_ptr<point> p;
    show("born", &p);
    point pt = {1, 2};
    std::shared_ptr<point> q = std::make_shared<point>(pt);
    show("made of a value", &q);
    std::shared_ptr<point> z = std::make_shared<point>();
    show("made of none", &z);
    q->x = 3;
    (*q).y += 2;
    show("places", &q);
    std::printf("values: %d %d\n", q->x, (*q).y);
    std::shared_ptr<point> c = q;
    show("cloned q", &q);
    show("cloned c", &c);
    c.reset();
    show("reset c", &c);
    q.reset(new point(pt));
    show("reset to a value", &q);
    std::swap(q, z);
    show("swap q", &q);
    show("swap z", &z);
    std::printf("relations: %d %d %d %d %d %d\n", q == q, q != q, q < q, q <= q, q > q, q >= q);
    std::printf("unequal: %d %d\n", q == z, q != z);
    q.reset();
    show("reset", &q);
    z = std::move(q);
    show("moved by an assignment", &z);
    std::shared_ptr<point> m = made(5, 6);
    show("moved out of a function", &m);
    std::printf("moved into a function: %d\n", taken(std::move(m)));
    std::shared_ptr<int> n = std::make_shared<int>(5);
    *n += 1;
    std::printf("int: %d\n", *n);
    std::shared_ptr<int> w = std::make_shared_for_overwrite<int>();
    *w = 11;
    std::printf("for overwrite: %d\n", *w);
    std::pair<int, double> pr = {1, 2.5};
    std::shared_ptr<std::pair<int, double>> up = std::make_shared<std::pair<int, double>>(pr);
    up->second *= 2;
    std::printf("pair: %d %g\n", up->first, (*up).second);
    std::optional<int> o = 4;
    std::shared_ptr<std::optional<int>> uo = std::make_shared<std::optional<int>>(o);
    std::printf("optional: %d %d\n", uo->has_value(), uo->value());
    return 0;
}
