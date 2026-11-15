/* <memory.pl> (1.1.3; CCLLIB.md's phase 1b): the whole surface of ccllib's shared_ptr -- born empty, make_shared of a
   value and of none, make_shared_for_overwrite, *p and p->m as values and as places, get, use_count, unique, clone as a
   second owner, reset of none and of a value, swap, each relation, a move by an assignment, into a function and out of
   one, and a shared_ptr of an int, of a struct, of a pair and of an optional. cicilang builds this file as C and
   cicilang++ as C++; shared_ptr.cpp is its twin over std::shared_ptr, which clang++ builds over libc++: the three print
   the same lines, shared_ptr.expect. With a count, `shared_ptr 1000000', it makes, shares, releases and frees a block
   that many times: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <memory.pl>
#include <pair.pl>
#include <optional.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const shared_ptr<point> *u) {
    const point *b = get(*u);
    if (b) printf("%s: %d %d %zu %d\n", what, b->x, b->y, use_count(*u), unique(*u));
    else printf("%s: empty %zu\n", what, use_count(*u));
}
static shared_ptr<point> made(int x, int y) {
    point pt = {x, y};
    shared_ptr<point> u = make_shared<point>(pt);
    return u;
}
static int taken(shared_ptr<point> u) { return u->x + u->y; }
static int many(long n) {
    unsigned x = 12345;
    long s = 0;
    shared_ptr<int> keep = make_shared<int>(0);
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        shared_ptr<int> u = make_shared<int>((int)(x >> 16 & 255));
        if (x >> 30 & 1) {
            s += *u;
            shared_ptr<int> c = clone(u);
            s += *c * 2;
        } else {
            s += *u;
            keep = u;
        }
        s += *keep;
    }
    printf("%ld\n", s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    shared_ptr<point> p;
    show("born", &p);
    point pt = {1, 2};
    shared_ptr<point> q = make_shared<point>(pt);
    show("made of a value", &q);
    shared_ptr<point> z = make_shared<point>();
    show("made of none", &z);
    q->x = 3;
    (*q).y += 2;
    show("places", &q);
    printf("values: %d %d\n", q->x, (*q).y);
    shared_ptr<point> c = clone(q);
    show("cloned q", &q);
    show("cloned c", &c);
    reset(c);
    show("reset c", &c);
    reset(q, pt);
    show("reset to a value", &q);
    swap(q, z);
    show("swap q", &q);
    show("swap z", &z);
    printf("relations: %d %d %d %d %d %d\n", q == q, q != q, q < q, q <= q, q > q, q >= q);
    printf("unequal: %d %d\n", q == z, q != z);
    reset(q);
    show("reset", &q);
    z = q;
    show("moved by an assignment", &z);
    shared_ptr<point> m = made(5, 6);
    show("moved out of a function", &m);
    printf("moved into a function: %d\n", taken(m));
    shared_ptr<int> n = make_shared<int>(5);
    *n += 1;
    printf("int: %d\n", *n);
    shared_ptr<int> w = make_shared_for_overwrite<int>();
    *w = 11;
    printf("for overwrite: %d\n", *w);
    pair<int, double> pr = {1, 2.5};
    shared_ptr<pair<int, double>> up = make_shared<pair<int, double>>(pr);
    up->second *= 2;
    printf("pair: %d %g\n", up->first, (*up).second);
    optional<int> o = 4;
    shared_ptr<optional<int>> uo = make_shared<optional<int>>(o);
    printf("optional: %d %d\n", has_value(*uo), value(*uo));
    return 0;
}
