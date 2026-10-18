// a nearly empty virtual base is the primary (the Itanium ABI 2.4 II.1b): sizes, places, calls, tables, type information
#include <cstdio>
#include <typeinfo>
struct I { virtual int f() { return 1; } virtual ~I() {} };
struct X : virtual I { int x = 2; int f() override { return 20 + x; } virtual int g() { return 3; } };
struct Y : X { int y = 5; int g() override { return 50 + y; } };
struct X1 : virtual I { int x1 = 6; };
struct X2 : virtual I { int x2 = 7; int f() override { return 70 + x2; } };
struct Z : X1, X2 { int z = 8; };
struct B { int b = 9; virtual int h() { return 90; } virtual ~B() {} };
struct W : B, X { int w = 10; };
struct P { int p = 11; };
struct Q : P, virtual I { int q = 12; };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu %zu %zu\n", sizeof(I), sizeof(X), sizeof(Y), sizeof(Z), sizeof(W), sizeof(Q));
  X x; Y y; Z z; W w; Q q;
  std::printf("X: I at %ld, f %d g %d\n", off((I *) &x, &x), x.f(), x.g());
  I *pi = &x; std::printf("via I: %d\n", pi->f());
  std::printf("Y: I at %ld X at %ld y at %ld f %d g %d\n", off((I *) &y, &y), off((X *) &y, &y), off(&y.y, &y), y.f(), y.g());
  pi = &y; std::printf("via I: %d\n", pi->f());
  std::printf("Z: I %ld X1 %ld X2 %ld z %ld f %d\n", off((I *) (X1 *) &z, &z), off((X1 *) &z, &z), off((X2 *) &z, &z), off(&z.z, &z), z.f());
  pi = (X1 *) &z; std::printf("via I: %d via X1: %d via X2: %d\n", pi->f(), ((X1 *) &z)->f(), ((X2 *) &z)->f());
  std::printf("W: B %ld X %ld I %ld w %ld f %d h %d\n", off((B *) &w, &w), off((X *) &w, &w), off((I *) &w, &w), off(&w.w, &w), w.f(), w.h());
  pi = &w; std::printf("via I: %d\n", pi->f());
  std::printf("Q: I %ld P %ld q %ld f %d\n", off((I *) &q, &q), off((P *) &q, &q), off(&q.q, &q), q.f());
  tab("X", &x, 5); tab("Y", &y, 5); tab("Z", &z, 5); tab("Z.X2", (X2 *) &z, 5); tab("W", &w, 3); tab("W.X", (X *) &w, 5); tab("Q", &q, 5);
  std::printf("%s %s %s\n", typeid(*pi).name(), typeid(*(I *) (X1 *) &z).name(), typeid(*(I *) &q).name());
  std::printf("dc %d %d %d\n", dynamic_cast<X *>(pi) == (X *) &w, dynamic_cast<W *>(pi) == &w, dynamic_cast<X2 *>((I *) (X1 *) &z) == (X2 *) &z);
  I *pd = new X; delete pd; pd = new Z; std::printf("new Z: %d\n", pd->f()); delete pd;
  X xc = x; Z zc = z; std::printf("copies %d %d %d\n", xc.f(), zc.f(), ((I *) (X1 *) &zc)->f());
  return 0;
}
