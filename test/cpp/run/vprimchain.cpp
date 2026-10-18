// nearly empty bases inside nearly empty bases: a chain of three, a plain path over it, two paths over one
#include <cstdio>
#include <typeinfo>
struct V { virtual int v() { return 1; } virtual ~V() {} };
struct N : virtual V { int v() override { return 2; } virtual int n() { return 3; } };
struct M : virtual N { virtual int m() { return 4; } int n() override { return 5; } };
struct C : virtual M { int c = 6; int m() override { return 60 + c; } };
struct Y : M { int y = 7; int v() override { return 70 + y; } };
struct X1 : virtual N { int x1 = 8; int n() override { return 80 + x1; } };
struct X2 : virtual N { int x2 = 9; };
struct Z : X1, X2 { int z = 10; int v() override { return 100 + z; } };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu %zu %zu %zu\n", sizeof(N), sizeof(M), sizeof(C), sizeof(Y), sizeof(X1), sizeof(X2), sizeof(Z));
  C c; Y y; Z z;
  std::printf("C: M %ld N %ld V %ld c %ld v %d n %d m %d %d\n", off((M *) &c, &c), off((N *) &c, &c), off((V *) &c, &c), off(&c.c, &c), ((V *) &c)->v(), ((N *) &c)->n(), ((M *) &c)->m(), c.m());
  std::printf("Y: M %ld N %ld V %ld y %ld v %d %d n %d\n", off((M *) &y, &y), off((N *) &y, &y), off((V *) &y, &y), off(&y.y, &y), ((V *) &y)->v(), y.v(), ((N *) &y)->n());
  std::printf("Z: X1 %ld X2 %ld N %ld V %ld z %ld v %d n %d %d %d\n", off((X1 *) &z, &z), off((X2 *) &z, &z), off((N *) &z, &z), off((V *) &z, &z), off(&z.z, &z), ((V *) &z)->v(), ((N *) &z)->n(), ((X2 *) &z)->n(), ((X1 *) &z)->n());
  tab("C", &c, 9); tab("Y", &y, 7); tab("Z", &z, 7); tab("Z.X2", (X2 *) &z, 7);
  std::printf("%s %s %s\n", typeid(*(V *) &c).name(), typeid(*(N *) &y).name(), typeid(*(V *) &z).name());
  std::printf("dc %d %d %d\n", dynamic_cast<C *>((V *) &c) == &c, dynamic_cast<Y *>((N *) &y) == &y, dynamic_cast<X2 *>((V *) &z) == (X2 *) &z);
  V *p = new C; std::printf("new C %d\n", p->v()); delete p; p = new Z; std::printf("new Z %d\n", p->v()); delete p;
  C cc = c; Z zc = z; std::printf("copies %d %d\n", cc.m(), zc.v());
  return 0;
}
