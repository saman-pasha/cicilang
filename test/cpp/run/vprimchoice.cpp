// two virtual bases, a nearly empty one the primary (the Itanium ABI 2.4 II.1b): written first, written second, beside a non-empty one
#include <cstdio>
#include <typeinfo>
struct I { virtual int f() { return 1; } virtual ~I() {} };
struct J { virtual int g() { return 2; } virtual ~J() {} };
struct K { int k = 3; virtual int h() { return 4; } virtual ~K() {} };
struct XJ : virtual I, virtual J { int v = 5; int g() override { return 50 + v; } };
struct XJ2 : virtual K, virtual I { int v2 = 6; int f() override { return 60 + v2; } };
struct XJ3 : virtual I, virtual K { int v3 = 7; int h() override { return 70 + v3; } };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu\n", sizeof(XJ), sizeof(XJ2), sizeof(XJ3));
  XJ a; XJ2 b; XJ3 c;
  std::printf("XJ: I %ld J %ld v %ld f %d g %d %d\n", off((I *) &a, &a), off((J *) &a, &a), off(&a.v, &a), ((I *) &a)->f(), ((J *) &a)->g(), a.g());
  std::printf("XJ2: K %ld I %ld v2 %ld f %d h %d\n", off((K *) &b, &b), off((I *) &b, &b), off(&b.v2, &b), ((I *) &b)->f(), ((K *) &b)->h());
  std::printf("XJ3: I %ld K %ld v3 %ld h %d %d\n", off((I *) &c, &c), off((K *) &c, &c), off(&c.v3, &c), ((K *) &c)->h(), c.h());
  tab("XJ", &a, 6); tab("XJ2", &b, 6); tab("XJ3", &c, 6);
  std::printf("%s %s %s\n", typeid(*(J *) &a).name(), typeid(*(I *) &b).name(), typeid(*(K *) &c).name());
  std::printf("dc %d %d %d\n", dynamic_cast<XJ *>((J *) &a) == &a, dynamic_cast<XJ2 *>((I *) &b) == &b, dynamic_cast<I *>((K *) &c) == (I *) &c);
  I *p = new XJ; delete p; J *q = new XJ; std::printf("del %d\n", q->g()); delete q; K *r = new XJ2; std::printf("del %d\n", r->h()); delete r;
  XJ ac = a; XJ2 bc = b; XJ3 cc = c; std::printf("copies %d %d %d\n", ac.g(), bc.f(), cc.h());
  return 0;
}
