// a nearly empty base with a virtual base of its own: a virtual base, two of them, a plain one
#include <cstdio>
#include <typeinfo>
struct V { virtual int v() { return 1; } virtual ~V() {} };
struct N : virtual V { int v() override { return 10; } virtual int n() { return 11; } };
struct C : virtual N { int c = 3; int n() override { return 30 + c; } };
struct C3 : virtual N, virtual V { int c3 = 5; int v() override { return 50 + c3; } };
struct C2 : N { int c2 = 4; };
static long off(const void *a, const void *b) { return (const char *) a - (const char *) b; }
static void tab(const char *n, const void *o, int k) { const long *vp = *(const long *const *) o; std::printf("%s:", n); for (int i = 2; i <= k; i++) std::printf(" %ld", vp[-i]); std::printf("\n"); }
int main() {
  std::printf("sizes %zu %zu %zu %zu\n", sizeof(N), sizeof(C), sizeof(C3), sizeof(C2));
  C c; C3 c3; C2 c2;
  std::printf("C: N %ld V %ld c %ld v %d n %d %d\n", off((N *) &c, &c), off((V *) &c, &c), off(&c.c, &c), ((V *) &c)->v(), ((N *) &c)->n(), c.n());
  std::printf("C3: N %ld V %ld c3 %ld v %d %d n %d\n", off((N *) &c3, &c3), off((V *) &c3, &c3), off(&c3.c3, &c3), ((V *) &c3)->v(), ((N *) &c3)->v(), c3.n());
  std::printf("C2: N %ld V %ld c2 %ld v %d n %d\n", off((N *) &c2, &c2), off((V *) &c2, &c2), off(&c2.c2, &c2), ((V *) &c2)->v(), c2.n());
  tab("C", &c, 7); tab("C3", &c3, 7); tab("C2", &c2, 5);
  std::printf("%s %s %s\n", typeid(*(V *) &c).name(), typeid(*(N *) &c3).name(), typeid(*(V *) &c2).name());
  std::printf("dc %d %d\n", dynamic_cast<C *>((V *) &c) == &c, dynamic_cast<C3 *>((V *) &c3) == &c3);
  V *p = new C; std::printf("new C %d\n", p->v()); delete p;
  C cc = c; std::printf("copy %d\n", cc.n());
  return 0;
}
