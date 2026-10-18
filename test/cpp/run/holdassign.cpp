// a holder assigned through a reference to it inside a larger object (0.172): the bytes past the holder's own part
// are the derived class's, and its virtual bases lie where the complete object put them
#include <cstdio>
struct A { int a = 1; };
struct W { int w = 2; };
struct Q1 : virtual A { int q1 = 3; };
struct R1 : virtual W { int r1 = 4; };
struct H1 : Q1, R1 { int h1 = 7; };
struct H2 : Q1 { int h2 = 8; };
struct D : H1 { int d = 9; };
struct E : H2 { int e = 10; };
int main() {
    D d;
    H1 h;
    h.a = 21; h.w = 22; h.q1 = 23; h.r1 = 24; h.h1 = 27;
    H1 &r = d;
    r = h;
    std::printf("%d %d %d %d %d %d\n", d.a, d.w, d.q1, d.r1, d.h1, d.d);
    E e;
    H2 g;
    g.a = 31; g.q1 = 33; g.h2 = 38;
    H2 &s = e;
    s = g;
    std::printf("%d %d %d %d\n", e.a, e.q1, e.h2, e.e);
    return 0;
}
