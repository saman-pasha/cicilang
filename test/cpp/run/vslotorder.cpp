// the slots of a class's primary table, read off pointers to its virtual functions (1 + the slot's byte offset): a destructor that
// is virtual by inheritance at its place, an implicit one last, an override of a function of a base that is no primary a slot
#include <cstdio>
#include <cstring>
struct A { int a = 1; virtual int f() { return 1; } virtual int g() { return 2; } virtual ~A() {} };
struct W : virtual A { virtual int k() { return 3; } ~W() { std::printf("~W\n"); } virtual int m() { return 4; } int g() override { return 5; } };
struct W2 : W { int k() override { return 6; } int g() override { return 7; } virtual int n() { return 8; } ~W2() { std::printf("~W2\n"); } };
struct P2 { int p2 = 1; virtual int p() { return 9; } };
struct Q2 { int q2 = 2; virtual ~Q2() { std::printf("~Q2\n"); } virtual int q() { return 10; } };
struct R2 : P2, Q2 { ~R2() { std::printf("~R2\n"); } virtual int r() { return 11; } int q() override { return 12; } };
struct S2 : R2 { ~S2() { std::printf("~S2\n"); } int r() override { return 13; } };
struct T2 : P2, Q2 { virtual int t() { return 14; } };
struct U2 : T2 { ~U2() { std::printf("~U2\n"); } };
template <class T> static long slot(int (T::*pm)()) { long w[2]; std::memcpy(w, &pm, sizeof w); return w[0] & 1 ? (w[0] - 1) / 8 : -1; }
int main() {
  std::printf("W: k %ld m %ld g %ld\n", slot(&W::k), slot(&W::m), slot(&W::g));
  std::printf("W2: k %ld g %ld m %ld n %ld\n", slot(&W2::k), slot(&W2::g), slot(&W2::m), slot(&W2::n));
  std::printf("R2: p %ld r %ld q %ld\n", slot(&R2::p), slot(&R2::r), slot(&R2::q));
  std::printf("S2: r %ld q %ld\n", slot(&S2::r), slot(&S2::q));
  std::printf("T2: p %ld t %ld U2: t %ld\n", slot(&T2::p), slot(&T2::t), slot(&U2::t));
  W *w = new W2; std::printf("%d %d %d %d\n", w->k(), w->g(), w->m(), ((A *) w)->g()); delete w;
  A *a = new W2; delete a;
  R2 *r = new S2; std::printf("%d %d\n", r->r(), r->q()); delete r;
  Q2 *q = new S2; delete q;
  P2 *p0 = new S2; std::printf("%d\n", p0->p()); delete (S2 *) p0;
  T2 *t = new U2; delete t;
  Q2 *q2 = new U2; delete q2;
  return 0;
}
