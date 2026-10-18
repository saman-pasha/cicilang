// the slots of a class's primary table, read off pointers to its virtual functions (1 + the slot's byte offset): an override of a
// virtual base's function that is no primary has a slot of its own in the class's table, as the Itanium ABI lays it
#include <cstdio>
#include <cstring>
struct A { int a = 1; virtual int f() { return 1; } virtual int g() { return 2; } virtual ~A() {} };
struct C : virtual A { int c = 3; int g() override { return 30; } virtual int h() { return 4; } };
struct D : virtual A { int d = 4; virtual int k() { return 5; } int f() override { return 50; } };
struct P { int p = 5; virtual int q() { return 6; } virtual ~P() {} };
struct E : P, virtual A { int e = 6; int g() override { return 60; } int q() override { return 61; } virtual int m() { return 7; } };
template <class T> static long slot(int (T::*pm)()) { long w[2]; std::memcpy(w, &pm, sizeof w); return (w[0] - 1) / 8; }
int main() {
  std::printf("C: g %ld h %ld\n", slot(&C::g), slot(&C::h));
  std::printf("D: k %ld f %ld\n", slot(&D::k), slot(&D::f));
  std::printf("E: q %ld g %ld m %ld\n", slot(&E::q), slot(&E::g), slot(&E::m));
  C c; D d; E e; C *pc = &c; D *pd = &d; E *pe = &e;
  std::printf("%d %d %d %d %d %d %d %d\n", pc->g(), pc->h(), pc->f(), pd->k(), pd->f(), pe->q(), pe->g(), pe->m());
  return 0;
}
