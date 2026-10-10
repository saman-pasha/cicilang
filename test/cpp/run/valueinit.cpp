// VALUE-INITIALIZATION ZEROES a class whose default constructor is not user-provided, then runs that constructor
// ([dcl.init]/8; 0.127): `R()', `R r = R();', `T t{}' of a non-aggregate, a member's `r()', `new R()', `new (p) R()'
// and `new int()' were left as garbage where clang++ gives 0. `new T' and `new (p) T' with no initializer
// default-initialize: the constructor alone, the bytes as they are.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>
struct Q { int a; Q() : a(5) {} };
struct R { int a; Q q; };
struct S { int a = 3; int b; };
struct V { virtual int f() { return a; } int a; int b = 7; };
struct D : Q { int b; };
struct H { R r; S s; V v; D d; H() : r(), s(), v(), d() {} };
struct P { int a, b; };
__attribute__((noinline)) void dirty() { volatile unsigned char big[1024]; for (int i = 0; i < 1024; i++) big[i] = 0xAB; }
template <class T> T *fresh() { void *m = std::malloc(sizeof(T)); std::memset(m, 0xAB, sizeof(T)); std::free(m); return new T(); }
__attribute__((noinline)) void locals() {
  R loc{};
  R loc2 = R();
  S s{};
  S s2 = S();
  H h;
  std::printf("%d %d %d %d %d %d %d %d %d\n", loc.a, loc2.a, R().a, s.b, s2.b, S().b, h.r.a, h.s.a, h.s.b);
  V v{};
  V v2 = V();
  D d{};
  D d2 = D();
  std::printf("%d %d %d %d %d %d %d %d %d %d\n", v.f(), v.b, v2.f(), V().f(), h.v.a, h.v.b, d.a, d.b, d2.b, h.d.b);
  alignas(V) unsigned char buf[sizeof(V)];
  std::memset(buf, 0x11, sizeof buf);
  V *pv = new (buf) V();
  std::printf("%d %d\n", pv->a, pv->b);
  std::memset(buf, 0x11, sizeof buf);
  V *pv2 = new (buf) V;
  std::printf("%x %d\n", (unsigned)pv2->f(), pv2->b);
}
int main() {
  dirty();
  locals();
  int *x = fresh<int>();
  P *p = fresh<P>();
  R *r = fresh<R>();
  std::printf("%d %d %d %d %d\n", *x, p->a, p->b, r->a, r->q.a);
  delete x;
  delete p;
  delete r;
  return 0;
}
