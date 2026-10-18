// a stolen primary with a nearly empty base of its own inside it: `D : virtual X' over `X : virtual N', `N : virtual V'
#include <cstdio>
#include <typeinfo>
struct V { virtual int v() { return 1; } virtual ~V() {} };
struct N : virtual V { virtual int n() { return 2; } };
struct X : virtual N {
  int x = 3; int v() override { return 10 + x; }
  X() { std::printf("X() %d %d %s\n", ((V *) this)->v(), ((N *) this)->n(), typeid(*(V *) this).name()); }
  ~X() override { std::printf("~X %d %d %s\n", ((V *) this)->v(), ((N *) this)->n(), typeid(*(N *) this).name()); }
};
struct D : virtual X { int d = 4; int n() override { return 20 + d; } D() { std::printf("D() %d %d\n", ((V *) this)->v(), ((N *) this)->n()); } };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu\n", sizeof(N), sizeof(X), sizeof(D));
  {
    D d;
    std::printf("D: V %ld N %ld X %ld d %ld v %d n %d\n", off((V *) &d, &d), off((N *) &d, &d), off((X *) &d, &d), off(&d.d, &d), ((V *) &d)->v(), ((N *) &d)->n());
    tab("D", &d, 8); tab("D.X", (X *) &d, 7);
    std::printf("%s %s dc %d %d\n", typeid(*(V *) &d).name(), typeid(*(X *) &d).name(), dynamic_cast<D *>((V *) &d) == &d, dynamic_cast<X *>((N *) &d) == (X *) &d);
    D dc = d; std::printf("copy %d %d\n", ((V *) &dc)->v(), ((N *) &dc)->n());
  }
  V *p = new D; std::printf("new D %d\n", p->v()); delete p;
  return 0;
}
