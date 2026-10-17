// the Itanium layout of every class over a virtual base (0.163): a diamond whose paths hold the virtual base FURTHER IN --
// P1 and P2 reach A through Q1 and Q2 -- built with every class's virtual base at the end of the complete object, and the
// single paths laid as clang lays them: sizes, offsets, a member's place through each path, virtual calls and casts
#include <cstdio>
#include <cstddef>
struct A { int a = 1; virtual int f() { return a; } virtual ~A() {} };
struct Q1 : virtual A { int q1 = 2; int f() override { return a + q1; } };
struct Q2 : virtual A { int q2 = 3; };
struct P1 : Q1 { int p1 = 4; int f() override { return a + q1 + p1; } };
struct P2 : Q2 { int p2 = 5; };
struct D : P1, P2 { int d = 6; int f() override { return a + q1 + p1 + q2 + p2 + d; } };
struct E : P1 { int e = 7; E() { a = 10; } };
static long off(const void *o, const void *m) { return (const char *) m - (const char *) o; }
static int via1(P1 &p) { return p.a * 100 + p.p1; }
static int via2(P2 &p) { return p.a * 100 + p.p2; }
int main() {
  D d; E e; P1 p;
  std::printf("sizes %zu %zu %zu %zu %zu %zu\n", sizeof(A), sizeof(Q1), sizeof(P1), sizeof(P2), sizeof(D), sizeof(E));
  std::printf("P1 %ld %ld %ld\n", off(&p, &p.a), off(&p, &p.q1), off(&p, &p.p1));
  std::printf("D %ld %ld %ld %ld %ld %ld\n", off(&d, &d.a), off(&d, &d.q1), off(&d, &d.p1), off(&d, &d.q2), off(&d, &d.p2), off(&d, &d.d));
  std::printf("E %ld %ld %ld\n", off(&e, &e.a), off(&e, &e.p1), off(&e, &e.e));
  d.a = 9;
  std::printf("paths %d %d %d %d\n", via1(d), via2(d), via1(e), (int) (static_cast<A *>(static_cast<P1 *>(&d)) == static_cast<A *>(static_cast<P2 *>(&d))));
  A *pa = &d, *pe = &e; Q1 *pq = &d;
  std::printf("calls %d %d %d %d\n", pa->f(), pq->f(), pe->f(), p.f());
  std::printf("casts %d %d %d\n", (int) (dynamic_cast<D *>(pa) == &d), (int) (dynamic_cast<P2 *>(pa) == static_cast<P2 *>(&d)), (int) (dynamic_cast<E *>(pe) == &e));
  return d.a + d.p1 + d.p2 - 18;
}
