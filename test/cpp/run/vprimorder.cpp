// the order the virtual bases are built and destroyed in, a nearly empty primary among them, and the virtual calls in each
#include <cstdio>
#include <typeinfo>
struct I { int t = 1; virtual int f() { return 1; } I() { std::printf("I %d %s\n", f(), typeid(*this).name()); } virtual ~I() { std::printf("~I %d\n", f()); } };
struct I0 { virtual int f() { return 10; } I0() { std::printf("I0 %d\n", f()); } virtual ~I0() { std::printf("~I0 %d\n", f()); } };
struct K { int k = 3; virtual int h() { return 4; } K() { std::printf("K %d %s\n", h(), typeid(*this).name()); } virtual ~K() { std::printf("~K %d\n", h()); } };
struct XJ2 : virtual K, virtual I0 { int v2 = 6; int f() override { return 60 + v2; } int h() override { return 61; } XJ2() { std::printf("XJ2 %d %d\n", f(), h()); } ~XJ2() { std::printf("~XJ2\n"); } };
struct V { virtual int v() { return 1; } V() { std::printf("V %d\n", v()); } virtual ~V() { std::printf("~V %d\n", v()); } };
struct N : virtual V { int v() override { return 10; } N() { std::printf("N %d\n", v()); } ~N() { std::printf("~N %d\n", v()); } };
struct C : virtual N { int c = 3; int v() override { return 30 + c; } C() { std::printf("C %d\n", v()); } ~C() { std::printf("~C %d\n", v()); } };
struct C3 : virtual K, virtual N { int c3 = 5; C3() { std::printf("C3 %d %d\n", v(), h()); } ~C3() { std::printf("~C3\n"); } };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
int main() {
  std::printf("sizes %zu %zu %zu\n", sizeof(XJ2), sizeof(C), sizeof(C3));
  { XJ2 x; std::printf("XJ2: I0 %ld K %ld\n", off((I0 *) &x, &x), off((K *) &x, &x)); }
  { C c; std::printf("C: N %ld V %ld\n", off((N *) &c, &c), off((V *) &c, &c)); }
  { C3 c; std::printf("C3: N %ld V %ld K %ld c3 %ld\n", off((N *) &c, &c), off((V *) &c, &c), off((K *) &c, &c), off(&c.c3, &c)); }
  return 0;
}
