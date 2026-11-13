/* <memory.pl> (0.309; CCLLIB.md's phase 1b): the whole surface of ccllib's unique_ptr -- born empty, make_unique of a
   value and of none, made of an own pointer, *p and p->m as values and as places, get, release, reset of none and of an
   own pointer, swap, each relation, a move by an assignment, into a function and out of one, and a unique_ptr of an
   int, of a struct, of a pair and of an optional. cicilang builds this file as C and cicilang++ as C++; unique_ptr.cpp
   is its twin over std::unique_ptr, which clang++ builds over libc++: the three print the same lines,
   unique_ptr.expect. With a count, `unique_ptr 1000000', it makes, moves, releases and frees a block that many times:
   the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <memory.pl>
#include <pair.pl>
#include <optional.pl>
typedef struct point { int x, y; } point;
static void show(const char *what, const unique_ptr<point> *u) {
    const point *b = get(*u);
    if (b) printf("%s: %d %d\n", what, b->x, b->y);
    else printf("%s: empty\n", what);
}
static unique_ptr<point> made(int x, int y) {
    point pt = {x, y};
    unique_ptr<point> u = make_unique<point>(pt);
    return u;
}
static int taken(unique_ptr<point> u) { return u->x + u->y; }
static int many(long n) {
    unsigned x = 12345;
    long s = 0;
    unique_ptr<int> keep = make_unique<int>(0);
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unique_ptr<int> u = make_unique<int>((int)(x >> 16 & 255));
        if (x >> 30 & 1) {
            s += *u;
            keep = u;
        } else {
            own int *r = release(u);
            s += *r * 2;
            free(r);
        }
        s += *keep;
    }
    printf("%ld\n", s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    unique_ptr<point> p;
    show("born", &p);
    point pt = {1, 2};
    unique_ptr<point> q = make_unique<point>(pt);
    show("made of a value", &q);
    unique_ptr<point> z = make_unique<point>();
    show("made of none", &z);
    q->x = 3;
    (*q).y += 2;
    show("places", &q);
    printf("values: %d %d\n", q->x, (*q).y);
    own point *r = release(q);
    reset(p, r);
    show("released", &q);
    show("reset to the released", &p);
    swap(p, z);
    show("swap p", &p);
    show("swap z", &z);
    printf("relations: %d %d %d %d %d %d\n", p == p, p != p, p < p, p <= p, p > p, p >= p);
    printf("unequal: %d %d\n", p == z, p != z);
    reset(p);
    show("reset", &p);
    p = z;
    show("moved by an assignment", &p);
    unique_ptr<point> m = made(5, 6);
    show("moved out of a function", &m);
    printf("moved into a function: %d\n", taken(m));
    own point *s = malloc(sizeof *s);
    if (!s) return 1;
    s->x = 7;
    s->y = 8;
    unique_ptr<point> t = s;
    show("made of an own pointer", &t);
    unique_ptr<int> n = make_unique<int>(5);
    *n += 1;
    printf("int: %d\n", *n);
    pair<int, double> pr = {1, 2.5};
    unique_ptr<pair<int, double>> up = make_unique<pair<int, double>>(pr);
    up->second *= 2;
    printf("pair: %d %g\n", up->first, (*up).second);
    optional<int> o = 4;
    unique_ptr<optional<int>> uo = make_unique<optional<int>>(o);
    printf("optional: %d %d\n", has_value(*uo), value(*uo));
    return 0;
}
