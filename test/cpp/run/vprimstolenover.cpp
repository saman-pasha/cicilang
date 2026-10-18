// a class over a class that stole its primary: derived from it, and over it as a virtual base; two bases that each take the same
// nearly empty base as their primary, both virtual
#include <cstdio>
#include <typeinfo>
struct I { virtual int f() { return 1; } virtual int h() { return 2; } virtual ~I() {} };
struct X : virtual I { int x = 3; int f() override { return 10 + x; } };
struct Y : virtual I { int y = 4; int h() override { return 20 + y; } };
struct D : virtual X { int d = 5; };
struct F : D { int fv = 6; int f() override { return 30 + fv; } };
struct G : virtual D { int g = 7; };
struct H : virtual X, virtual Y { int hv = 8; };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu\n", sizeof(D), sizeof(F), sizeof(G), sizeof(H));
  F f; G g; H h;
  std::printf("F: I %ld X %ld D %ld fv %ld f %d %d h %d\n", off((I *) &f, &f), off((X *) &f, &f), off((D *) &f, &f), off(&f.fv, &f), ((I *) &f)->f(), ((X *) &f)->f(), ((I *) &f)->h());
  std::printf("G: I %ld X %ld D %ld g %ld f %d h %d\n", off((I *) &g, &g), off((X *) &g, &g), off((D *) &g, &g), off(&g.g, &g), ((I *) &g)->f(), ((D *) &g)->h());
  std::printf("H: I %ld X %ld Y %ld hv %ld f %d h %d %d %d\n", off((I *) &h, &h), off((X *) &h, &h), off((Y *) &h, &h), off(&h.hv, &h), ((I *) &h)->f(), ((I *) &h)->h(), ((X *) &h)->h(), ((Y *) &h)->f());
  tab("F", &f, 6); tab("G", &g, 7); tab("H", &h, 8); tab("H.X", (X *) &h, 6); tab("H.Y", (Y *) &h, 6);
  std::printf("%s %s %s %s\n", typeid(*(I *) &f).name(), typeid(*(X *) &g).name(), typeid(*(Y *) &h).name(), typeid(*(I *) &h).name());
  std::printf("dc %d %d %d %d\n", dynamic_cast<F *>((I *) &f) == &f, dynamic_cast<G *>((X *) &g) == &g, dynamic_cast<Y *>((X *) &h) == (Y *) &h, dynamic_cast<H *>((I *) &h) == &h);
  I *p = new G; std::printf("new G %d\n", p->f()); delete p; p = new H; std::printf("new H %d %d\n", p->f(), p->h()); delete p;
  F fc = f; G gc = g; H hc = h; std::printf("copies %d %d %d\n", ((I *) &fc)->f(), ((I *) &gc)->f(), ((I *) &hc)->h());
  return 0;
}
