// a path that does not take the shared nearly empty base as its primary: its table's slots of the base that it leaves to the
// base move `this' there; the order of the claim; virtual calls and typeid while each base is built
#include <cstdio>
#include <typeinfo>
struct I { virtual int f() { return 1; } virtual int k() { return 2; } virtual ~I() { std::printf("~I %s\n", typeid(*this).name()); } };
struct X1 : virtual I { int a = 3; X1() { std::printf("X1 %d %d %s\n", f(), k(), typeid(*this).name()); } int f() override { return 30 + a; } ~X1() { std::printf("~X1 %d %d\n", f(), k()); } };
struct X2 : virtual I { int b = 4; X2() { std::printf("X2 %d %d %d %s\n", f(), k(), m(), typeid(*this).name()); } virtual int m() { return 40 + b; } ~X2() { std::printf("~X2 %d %d\n", f(), k()); } };
struct Z : X1, X2 { int c = 5; Z() { std::printf("Z %d %d %d\n", f(), k(), m()); } };
struct Z2 : X2, X1 { int d = 6; Z2() { std::printf("Z2 %d %d %d\n", f(), k(), m()); } };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
int main() {
  std::printf("sizes %zu %zu %zu %zu\n", sizeof(X1), sizeof(X2), sizeof(Z), sizeof(Z2));
  {
    Z z; I *pi = (X1 *) &z; X2 *p2 = &z;
    std::printf("Z: I %ld X2 %ld c %ld\n", off(pi, &z), off(p2, &z), off(&z.c, &z));
    std::printf("Z calls %d %d %d %d %d %d\n", pi->f(), pi->k(), p2->f(), p2->k(), p2->m(), z.k());
  }
  {
    Z2 z; I *pi = (X2 *) &z; X1 *p1 = &z;
    std::printf("Z2: I %ld X1 %ld d %ld\n", off(pi, &z), off(p1, &z), off(&z.d, &z));
    std::printf("Z2 calls %d %d %d %d %d\n", pi->f(), pi->k(), p1->f(), p1->k(), z.m());
  }
  return 0;
}
