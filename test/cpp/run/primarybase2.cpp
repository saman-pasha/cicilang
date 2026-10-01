// a polymorphic base after plain ones (the Itanium ABI's primary base, laid out first): the bases are still built in
// the order written and destroyed in the reverse, a base with no constructor or no destructor among them; a call
// through each base, a dynamic_cast and the sizes and offsets as clang lays them out
#include <cstdio>
struct P { int x = 7; P() { std::printf("P\n"); } };
struct Q { int q = 9; ~Q() { std::printf("~Q\n"); } };
struct V { virtual int f() { return 1; } virtual ~V() { std::printf("~V\n"); } int v = 2; int pad = 0; };
struct W { virtual int g() { return 3; } virtual ~W() { std::printf("~W\n"); } };
struct D : P, Q, V, W {
  int y = 3;
  D() { std::printf("D\n"); }
  int f() override { return x * 10 + y; }
  int g() override { return q + v; }
  ~D() override { std::printf("~D\n"); }
};
int main() {
  {
    D d; V *v = &d; W *w = &d; P *p = &d; Q *q = &d;
    std::printf("%d %d %d %d\n", v->f(), w->g(), p->x, q->q);
    std::printf("%d %d %d %d %d\n", (int) ((char *) p - (char *) &d), (int) ((char *) q - (char *) &d), (int) ((char *) v - (char *) &d),
                (int) ((char *) w - (char *) &d), (int) sizeof(D));
    D *back = dynamic_cast<D *>(w);
    std::printf("%d\n", back == &d);
  }
  W *h = new D; std::printf("%d\n", h->g()); delete h;
  return 0;
}
