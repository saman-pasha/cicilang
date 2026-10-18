// a lambda as an aggregate's function-pointer item, and a call through a plain struct's function-pointer member
// (0.168): the item converts to its member's type through the closure's conversion ([dcl.init.aggr]/4.2) -- in a
// local, a nested list, an array, a global, a braced return and a braced argument -- a braced argument to a plain
// struct or union parameter is a compound literal of it, and `h.fp(k)' over a plain struct calls through its member
#include <cstdio>
struct H { void (*fp)(int &); int n; };
struct G { H h; int m; };
struct T { int (*f)(int); };
struct P { int a; int b; };
union U { int i; float f; };
int twice(int x) { return 2 * x; }
H g{[](int &x) { x = 11; }, 5};
H mk() { return {[](int &x) { x = 12; }, 6}; }
int use(H h) { int k = 0; h.fp(k); return k + h.n; }
int sum(P p) { return p.a + p.b; }
int sumr(const P &p) { return p.a * p.b; }
int first(U u) { return u.i; }
int run(T t, int v) { return t.f(v); }
int main() {
    H h{[](int &x) { x = 9; }, 4};
    int k = 0;
    h.fp(k);
    H *p = &h;
    int j = 1;
    p->fp(j);
    G gg{{[](int &x) { x += 5; }, 1}, 2};
    int i = 3;
    gg.h.fp(i);
    void (*fs[2])(int &) = {[](int &x) { x *= 3; }, [](int &x) { x -= 1; }};
    int a = 4;
    fs[0](a);
    fs[1](a);
    T t{twice};
    T u{[](int x) { return x + 100; }};
    std::printf("%d %d %d %d %d %d %d %d\n", k, j, h.n, i, gg.m, a, t.f(21), u.f(1));
    int ga = 0;
    g.fp(ga);
    H m = mk();
    int b = 0;
    m.fp(b);
    std::printf("%d %d %d %d %d\n", ga, g.n, b, m.n, use({[](int &x) { x = 13; }, 7}));
    std::printf("%d %d %d %d %d\n", sum({3, 4}), sumr({5, 6}), first({42}), run({twice}, 8), run({[](int x) { return x - 1; }}, 8));
    return 0;
}
