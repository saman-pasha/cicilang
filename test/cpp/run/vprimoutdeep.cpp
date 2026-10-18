// a nearly empty primary whose virtual bases lie outside it, in deeper shapes: one further in that no base takes (F1), a chain of
// nearly empty primaries at one address over an outside base (G), a class derived from that (H), and one stolen from a base (K2)
#include <cstdio>
#include <typeinfo>
struct A { int a = 1; virtual int fa() { return 10 + a; } virtual ~A() {} };
struct I : virtual A { virtual int f() { return 2; } int fa() override { return 20 + a; } };
struct P1 { int p = 3; virtual int fp() { return 30 + p; } virtual ~P1() {} };
struct X1 : P1, virtual I { int x = 4; int f() override { return 40 + x; } };
struct F1 : virtual X1 { int g = 5; int fa() override { return 50 + g + a; } };
struct M { virtual int m() { return 6; } virtual ~M() {} };
struct N2 : virtual M { virtual int n() { return 7; } int m() override { return 60 + n(); } };
struct J2 : virtual N2, virtual A { virtual int j() { return 8; } int n() override { return 70 + j(); } };
struct G : virtual J2 { int g = 9; int j() override { return 80 + g; } int fa() override { return 90 + g + a; } };
struct H : G { int h = 2; int m() override { return 100 + h; } };
struct W : virtual I { int w = 3; int f() override { return 110 + w; } };
struct K2 : virtual W { int k = 4; int fa() override { return 120 + k + a; } };
static long off(const void *p, const void *q) { return (const char *) p - (const char *) q; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu %zu %zu %zu %zu\n", sizeof(X1), sizeof(F1), sizeof(N2), sizeof(J2), sizeof(G), sizeof(H), sizeof(W), sizeof(K2));
  F1 f1; G g; H h; K2 k2;
  std::printf("F1: I %ld A %ld X1 %ld P1 %ld g %ld f %d %d fa %d %d fp %d\n", off((I *) &f1, &f1), off((A *) &f1, &f1), off((X1 *) &f1, &f1), off((P1 *) &f1, &f1), off(&f1.g, &f1), ((I *) &f1)->f(), ((X1 *) &f1)->f(), ((A *) &f1)->fa(), f1.fa(), ((P1 *) &f1)->fp());
  std::printf("G: J2 %ld N2 %ld M %ld A %ld g %ld j %d n %d m %d fa %d %d\n", off((J2 *) &g, &g), off((N2 *) &g, &g), off((M *) &g, &g), off((A *) &g, &g), off(&g.g, &g), ((J2 *) &g)->j(), ((N2 *) &g)->n(), ((M *) &g)->m(), ((A *) &g)->fa(), g.fa());
  std::printf("H: J2 %ld N2 %ld M %ld A %ld G %ld h %ld m %d %d n %d fa %d\n", off((J2 *) &h, &h), off((N2 *) &h, &h), off((M *) &h, &h), off((A *) &h, &h), off((G *) &h, &h), off(&h.h, &h), ((M *) &h)->m(), ((N2 *) &h)->m(), ((N2 *) &h)->n(), ((A *) &h)->fa());
  std::printf("K2: I %ld A %ld W %ld k %ld f %d %d fa %d %d\n", off((I *) &k2, &k2), off((A *) &k2, &k2), off((W *) &k2, &k2), off(&k2.k, &k2), ((I *) &k2)->f(), ((W *) &k2)->f(), ((A *) &k2)->fa(), ((I *) &k2)->fa());
  tab("F1", &f1, 8); tab("G", &g, 10); tab("H", &h, 10); tab("K2", &k2, 8);
  std::printf("%s %s %s %s %s\n", typeid(*(A *) &f1).name(), typeid(*(P1 *) &f1).name(), typeid(*(M *) &g).name(), typeid(*(A *) &h).name(), typeid(*(I *) &k2).name());
  std::printf("dc %d %d %d %d\n", dynamic_cast<F1 *>((A *) &f1) == &f1, dynamic_cast<G *>((M *) &g) == &g, dynamic_cast<H *>((A *) &h) == &h, dynamic_cast<K2 *>((I *) &k2) == &k2);
  A *p = new G; std::printf("new G %d\n", p->fa()); delete p; M *q = new H; std::printf("new H %d\n", q->m()); delete q; P1 *r = new F1; std::printf("new F1 %d\n", r->fp()); delete r;
  F1 cf = f1; G cg = g; H ch = h; K2 ck = k2;
  std::printf("copies %d %d %d %d %d\n", ((A *) &cf)->fa(), ((N2 *) &cg)->m(), ((M *) &ch)->m(), ((W *) &ck)->f(), ((A *) &ck)->fa());
  return 0;
}
