// a plain struct bound to a base-clause type parameter (0.117): `template <class B> struct D : B' over `struct P { int x; }'. The base
// clause names the parameter, so the structs named as bases at the start (cpp_note_bases) did not include P and `D<P>' refused
// base_not_registered(P, D.P). One base, two, a base seen through a reference, a function taking the base, two instances, a namespace --
// and a base named through an ALIAS of a class (`using ZA = Z; struct Y : ZA', `D<PA>'), which was refused base_not_registered('ZA', 'Y')
#include <cstdio>
struct P { int x; };
struct Q { int z; long w; };
namespace ns { struct R { char c; int n; }; }
template <class B> struct D : B { int y; };
template <class T> int total(T &t) { return t.x + t.y; }
template <class A, class B> struct E : A, B { int y; };
template <class B> struct F : B { int get() { return this->c + this->n; } };
int readx(P &p) { return p.x * 2; }
using PA = P;
struct Z { int a; int get() { return a; } };
using ZA = Z;
typedef Z ZT;
struct Y : ZA { int b; };
struct X : ZT { int c; };
int main() {
  D<P> d;
  d.x = 3; d.y = 4;
  std::printf("%d %d\n", total(d), (int)sizeof(D<P>));
  E<P, Q> e;
  e.x = 3; e.z = 5; e.w = 6; e.y = 4;
  std::printf("%d %d %ld %d %d\n", e.x, e.z, e.w, e.y, (int)sizeof(E<P, Q>));
  P &p = d;
  p.x = 10;
  std::printf("%d %d\n", total(d), readx(d));
  D<Q> dq;
  dq.z = 7; dq.w = 8; dq.y = 9;
  std::printf("%d %ld %d %d\n", dq.z, dq.w, dq.y, (int)sizeof(D<Q>));
  F<ns::R> f;
  f.c = 'a'; f.n = 3;
  std::printf("%d\n", f.get());
  D<PA> da;
  da.x = 11; da.y = 12;
  Y y; y.a = 1; y.b = 2;
  X x; x.a = 3; x.c = 4;
  std::printf("%d %d %d %d %d %d %d\n", da.x, da.y, y.get(), y.b, x.get(), x.c, (int)sizeof(D<PA>));
  return 0;
}
