// later virtual bases (0.172): two direct ones, X : virtual A, virtual W, and one after a plain base, Y : B, virtual A
// -- sizes, offsets and members as clang lays them; Z : virtual A, B with its table pointer first; a class derived from X
#include <cstdio>
struct A { int a = 1; };
struct W { int w = 2; };
struct B { int b = 3; };
struct X : virtual A, virtual W { int x = 4; };
struct Y : B, virtual A { int y = 5; };
struct Z : virtual A, B { int z = 6; };
struct XX : X { int xx = 7; };
static long off(const void *p, const void *b) { return (const char *) p - (const char *) b; }
int main() {
  X x; Y y; Z z; XX xx;
  std::printf("%zu %zu %zu %zu\n", sizeof(X), sizeof(Y), sizeof(Z), sizeof(XX));
  std::printf("%d %d %d | %d %d %d | %d %d %d\n", x.a, x.w, x.x, y.a, y.b, y.y, z.a, z.b, z.z);
  std::printf("%ld %ld %ld | %ld %ld %ld | %ld %ld %ld\n", off((A *) &x, &x), off((W *) &x, &x), off(&x.x, &x),
              off((A *) &y, &y), off((B *) &y, &y), off(&y.y, &y), off((A *) &z, &z), off((B *) &z, &z), off(&z.z, &z));
  A *pa = &xx; W *pw = &xx; X *px = &xx;
  pa->a = 31; pw->w = 32;
  std::printf("%d %d %d %d %ld %ld %ld\n", xx.a, xx.w, px->a, px->w, off(pa, &xx), off(pw, &xx), off(&xx.xx, &xx));
  XX c = xx;
  std::printf("%d %d %d %d\n", c.a, c.w, c.x, c.xx);
  return 0;
}
