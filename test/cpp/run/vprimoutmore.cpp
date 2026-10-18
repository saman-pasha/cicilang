// a nearly empty primary whose virtual bases lie outside it, beside other bases: a plain base with no table, another virtual base
// written first, and a primary whose own virtual bases lie partly at its address and partly outside it
#include <cstdio>
#include <typeinfo>
struct A { int a = 1; virtual int fa() { return 10 + a; } virtual ~A() {} };
struct I : virtual A { virtual int f() { return 2; } int fa() override { return 20 + a; } };
struct P0 { int p = 7; };
struct C3 : virtual I, P0 { int c = 3; int f() override { return 30 + c + p; } };
struct K { int k = 8; virtual int g() { return 40 + k; } virtual ~K() {} };
struct C4 : virtual K, virtual I { int c = 4; int f() override { return 50 + c; } int g() override { return 60 + c; } };
struct N { virtual int n() { return 9; } virtual ~N() {} };
struct J : virtual N, virtual A { virtual int j() { return 11; } int n() override { return 12; } };
struct C5 : virtual J { int c = 5; int j() override { return 70 + c; } int fa() override { return 80 + c + a; } };
struct D5 : C5 { int d = 6; int n() override { return 90 + d; } };
static long off(const void *p, const void *q) { return (const char *) p - (const char *) q; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu %zu\n", sizeof(C3), sizeof(C4), sizeof(J), sizeof(C5), sizeof(D5));
  C3 c3; C4 c4; C5 c5; D5 d5;
  std::printf("C3: I %ld A %ld P0 %ld c %ld f %d %d fa %d\n", off((I *) &c3, &c3), off((A *) &c3, &c3), off((P0 *) &c3, &c3), off(&c3.c, &c3), c3.f(), ((I *) &c3)->f(), ((A *) &c3)->fa());
  std::printf("C4: I %ld A %ld K %ld c %ld f %d g %d %d fa %d\n", off((I *) &c4, &c4), off((A *) &c4, &c4), off((K *) &c4, &c4), off(&c4.c, &c4), ((I *) &c4)->f(), c4.g(), ((K *) &c4)->g(), ((A *) &c4)->fa());
  std::printf("C5: J %ld N %ld A %ld c %ld j %d n %d fa %d %d\n", off((J *) &c5, &c5), off((N *) &c5, &c5), off((A *) &c5, &c5), off(&c5.c, &c5), ((J *) &c5)->j(), ((N *) &c5)->n(), ((A *) &c5)->fa(), c5.fa());
  std::printf("D5: J %ld N %ld A %ld C5 %ld d %ld n %d %d fa %d\n", off((J *) &d5, &d5), off((N *) &d5, &d5), off((A *) &d5, &d5), off((C5 *) &d5, &d5), off(&d5.d, &d5), ((N *) &d5)->n(), ((J *) &d5)->n(), ((A *) &d5)->fa());
  tab("C3", &c3, 6); tab("C4", &c4, 8); tab("C5", &c5, 8); tab("D5", &d5, 8);
  std::printf("%s %s %s %s\n", typeid(*(A *) &c3).name(), typeid(*(K *) &c4).name(), typeid(*(N *) &c5).name(), typeid(*(A *) &d5).name());
  A *p = new C4; std::printf("new C4 %d\n", p->fa()); delete p; N *q = new D5; std::printf("new D5 %d\n", q->n()); delete q;
  C5 cc = c5; std::printf("copy %d %d\n", ((J *) &cc)->j(), ((A *) &cc)->fa());
  return 0;
}
