// The Itanium layout (0.135): the table pointer first where the class introduces it, a base's tail padding reused where the
// base is no POD for the purpose of layout, a [[no_unique_address]] member likewise; offsets, sizes, a constant, an exception
// caught through a base behind the table pointer, a downcast, type information, and stores through a base that keep the
// members in its tail.
#include <cstdio>
#include <typeinfo>
template <class T> long off(const T *p, const void *q) { return (const char *) q - (const char *) p; }
struct B { virtual int f() { return 1; } int x; };
struct D : B { int y; int f() override { return 2; } };
struct P { int b; ~P() { std::printf("~P %d\n", b); } };
struct V : P { V(int b0, int x0) { b = b0; x = x0; } virtual int g() { return 3; } int x; };
struct W : V { W() : V(40, 41) {} int g() override { return 4; } };
struct NP { constexpr NP(int a0, char c0) : a(a0), c(c0) {} int a; char c; };
struct ND : NP { constexpr ND() : NP(7, 'x'), d('y') {} char d; };
struct ND2 : ND { char e = 'e'; };
struct Pod { int a; char c; };
struct PD : Pod { char d; };
struct A1 { int a; };
struct A2 { int b; };
struct M2 : A1, A2 { virtual void h() {} int m; };
struct Inner { Inner() {} int a; char c; };
struct H { [[no_unique_address]] Inner in; char t; };
constexpr ND gnd;
const ND *pgnd = &gnd;
int main() {
  D d; d.x = 10; d.y = 20;
  std::printf("D %d y@%ld f=%d\n", (int) sizeof(D), off(&d, &d.y), static_cast<B &>(d).f());
  W w; P *pp = &w;
  std::printf("W %d P@%ld x@%ld b=%d g=%d\n", (int) sizeof(W), off(&w, pp), off(&w, &w.x), pp->b, w.g());
  ND2 n2;
  std::printf("ND %d d@%ld ND2 %d e@%ld %d %c %c %c\n", (int) sizeof(ND), off(&n2, &n2.d), (int) sizeof(ND2), off(&n2, &n2.e), n2.a, n2.c, n2.d, n2.e);
  PD pd; std::printf("PD %d d@%ld\n", (int) sizeof(PD), off(&pd, &pd.d));
  M2 m; m.a = 1; m.b = 2; m.m = 3; A1 *a1 = &m; A2 *a2 = &m;
  std::printf("M2 %d A1@%ld A2@%ld m@%ld %d %d %d back %d\n", (int) sizeof(M2), off(&m, a1), off(&m, a2), off(&m, &m.m), a1->a, a2->b, m.m, (int) (static_cast<M2 *>(a2) == &m));
  H h; h.in.a = 9; h.in.c = 'q'; h.t = 'T'; Inner &ri = h.in; Inner other; other.a = 1; other.c = 'o'; ri = other;
  std::printf("H %d t@%ld %d %c %c\n", (int) sizeof(H), off(&h, &h.t), h.in.a, h.in.c, h.t);
  NP &rn = n2; rn = NP(5, 'z'); std::printf("after %d %c %c %c\n", n2.a, n2.c, n2.d, n2.e);
  std::printf("gnd %d %c %c\n", pgnd->a, pgnd->c, pgnd->d);
  std::printf("ds %d %d %d %d\n", (int) __datasizeof(B), (int) __datasizeof(NP), (int) __datasizeof(ND), (int) __datasizeof(Pod));
  try { throw V(5, 6); } catch (P &p) { std::printf("caught P b=%d\n", p.b); }
  V &rv = w; std::printf("typeid %s %d\n", typeid(rv) == typeid(W) ? "W" : "other", (int) (dynamic_cast<W *>(&rv) == &w));
  ND arr[3]; std::printf("arr %d %c\n", (int) sizeof(arr), arr[2].d);
  return 0;
}
