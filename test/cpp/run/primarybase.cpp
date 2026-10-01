// a polymorphic base after a plain first base: the Itanium ABI puts the PRIMARY base (the first dynamic one) at
// offset 0 and the others after it, constructed in declaration order all the same
#include <cstdio>
#include <cstddef>
struct P { int x = 7; P() { std::printf("P\n"); } };
struct V { virtual int f() { return 1; } V() { std::printf("V\n"); } virtual ~V() { std::printf("~V\n"); } };
struct D : P, V { int y = 3; D() { std::printf("D\n"); } int f() override { return x * 10 + y; } ~D() { std::printf("~D\n"); } };
int main() {
  {
    D d; V *v = &d; P *p = &d;
    std::printf("%d %d %d %d\n", v->f(), p->x, (int) ((char *) p - (char *) &d), (int) ((char *) v - (char *) &d));
    std::printf("%d\n", (int) sizeof(D));
  }
  V *h = new D; std::printf("%d\n", h->f()); delete h;
  return 0;
}
