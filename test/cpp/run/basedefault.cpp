// the same base given its initializer, and a base whose only constructor takes defaults: both well-formed
#include <cstdio>
struct B { int v; B(int x) : v(x) {} };
struct E { int v; E(int x = 7) : v(x) {} };
struct D : B { int w; D() : B(5), w(2) {} };
struct F : E { int w; F() : w(3) {} };
struct G { int v; G(const G &o) = default; G(int x) : v(x) {} };
struct H : E, G { H() : G(9) {} };
int main() { D d; F f; H h; std::printf("%d %d %d %d %d %d\n", d.v, d.w, f.v, f.w, ((E &) h).v, ((G &) h).v); return 0; }
