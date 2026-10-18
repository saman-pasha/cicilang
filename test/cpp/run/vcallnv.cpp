// the vcall offsets of a virtual base's table: its non-virtual primary's functions, its own new ones, a later non-virtual base's
#include <cstdio>
struct P { int p = 1; virtual int a() { return 1; } virtual int b() { return 2; } virtual ~P() {} };
struct Q { int q = 2; virtual int c() { return 3; } virtual int d() { return 4; } virtual ~Q() {} };
struct V : P, Q { int v = 3; int b() override { return 20; } virtual int e() { return 5; } int d() override { return 40; } };
struct D : virtual V { int dd = 4; int a() override { return 100; } int c() override { return 300; } int e() override { return 500; } };
struct R { int r = 5; virtual int g() { return 6; } virtual ~R() {} };
struct W : R { int w = 7; virtual int h() { return 8; } };
struct D2 : virtual W { int d2 = 9; int g() override { return 600; } };
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
int main() {
  D d; D2 d2;
  std::printf("sizes %zu %zu V %ld Q %ld W %ld\n", sizeof(D), sizeof(D2), off((V *) &d, &d), off((Q *) &d, &d), off((W *) &d2, &d2));
  tab("D", &d, 3); tab("D.V", (V *) &d, 8); tab("D.Q", (Q *) &d, 2); tab("D2", &d2, 3); tab("D2.W", (W *) &d2, 5);
  std::printf("%d %d %d %d %d %d %d\n", ((P *) &d)->a(), ((P *) &d)->b(), ((Q *) &d)->c(), ((Q *) &d)->d(), ((V *) &d)->e(), ((R *) &d2)->g(), ((W *) &d2)->h());
  V *pv = new D; delete pv; W *pw = new D2; delete pw;
  return 0;
}
