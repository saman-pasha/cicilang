// Pointers to members as the ABI holds them (0.161): a data member's null is -1, never 0 (offset 0 is the first member's), so
// `&C::a' tests true; a base's member pointer converted to the derived class's grows by the base's offset, null kept null; two
// are compared as integers, a member function's by its { ptr, adj } rule; and zero-initialization -- a global without an
// initializer, `H h{}', an array's rest, `new H()', a value-initialized class -- gives the -1. A member function a base
// declares, named through the derived class (`&D::f'), is the base's member pointer converted.
#include <cstdio>
#include <cstring>
#include <string>
struct A { int a = 1; int f() { return 10 + a; } virtual int g() { return 20 + a; } };
struct B { int b = 2; int h() { return 30 + b; } };
struct C : A, B { int c = 3; int g() override { return 40 + c; } };
struct H { int C::*m; int k; };
struct G { H h[2]; int C::*n; };
struct K { int C::*m; std::string s; K() = default; };
struct V { virtual ~V() {} int C::*m; };
typedef int (C::*CM)();
int C::*g1;
H g2;
H g3 = { &C::c };
int C::*g4[2];
int C::*g5 = nullptr;
CM g6;
static long bits(const void *p) { long b; std::memcpy(&b, p, 8); return b; }
static int pick(int C::*m) { return m ? 1 : 0; }
int main() {
  int C::*p = nullptr, C::*q = &C::c, C::*r = &C::a;
  int B::*s = &B::b, B::*sn = nullptr;
  int C::*t = s, C::*tn = sn, C::*z{};
  C c;
  std::printf("%ld %ld %ld %ld %ld %ld\n", bits(&p), bits(&q), bits(&r), bits(&t), bits(&tn), bits(&z));
  std::printf("%d %d %d %d | %d %d | %d %d %d %d %d | %d %d %d\n", p ? 1 : 0, q ? 1 : 0, r ? 1 : 0, tn ? 1 : 0, c.*q, c.*t,
              p == nullptr, r == nullptr, q != r, r == &C::a, !p, pick(nullptr), pick(&C::a), pick(z));
  H h{}, h2 = {}, h3 = { &C::c };
  G gg{};
  int C::*arr[2] = {};
  int C::*one[3] = { &C::c };
  H *hp = new H();
  K *kp = new K();
  V v{};
  std::printf("%ld %ld %ld %ld %ld %ld %ld\n", bits(&g1), bits(&g2.m), bits(&g3.m), bits(&g4[1]), bits(&g5), bits(&h.m), bits(&h2.m));
  std::printf("%ld %ld %ld %ld %ld %ld %ld %ld %ld\n", bits(&h3.m), bits(&gg.h[1].m), bits(&gg.n), bits(&arr[1]), bits(&one[0]), bits(&one[2]), bits(&hp->m), bits(&kp->m), bits(&v.m));
  CM f = &C::f, gv = &C::g, hb = &C::h, none = nullptr;
  std::printf("%d %d %d | %d %d %d %d %d %d | %d\n", (c.*f)(), (c.*gv)(), (c.*hb)(), f == nullptr, none == nullptr, f == &C::f, f != gv, gv == &C::g, hb == &C::h, g6 ? 1 : 0);
  delete hp; delete kp;
  return 0;
}
