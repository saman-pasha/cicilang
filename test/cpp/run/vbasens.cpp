// vbasens.cpp: a virtual base is named in its namespace and substituted for a template parameter (0.235): the reader writes
// its access `virtual(Access)', which the namespace pass and the substitution did not take for an access -- `b::D : virtual
// B' took `a::B', the first class of that name, and `D<T> : virtual T' kept `T'. Two namespaces of the same class names
// over virtual bases, as a program of several parts has them.
extern "C" int printf(const char *, ...);
namespace a { struct B { int x = 1; }; struct D : virtual B { int d = 2; }; }
namespace b { struct B { int x = 3; int y = 4; long z = 5; }; struct D : virtual B { int d = 6; }; }
struct A { int a = 1; long b = 2; };
template <class T> struct D : virtual T { int d = 3; };
template <class T> struct E : D<T>, virtual T { int e = 4; };
namespace n1 { struct C0 { int m = 1; virtual int f() { return 10; } }; struct C1 : virtual C0 { int k = 2; }; struct C2 : C1 { int j = 3; }; }
namespace n2 { struct C0 { long m = 5; }; struct C1 : virtual C0 { int k = 6; }; struct C2 : C1, virtual C0 { int j = 7; }; }
int main() {
  a::D *p = new a::D; b::D *q = new b::D;
  printf("%d %d %d %d\n", (int) sizeof(a::D), (int) sizeof(b::D), p->x + p->d, q->x + q->y + (int) q->z + q->d);
  E<A> *e = new E<A>;
  A *ea = e;
  printf("%d %d %d %d %d\n", (int) sizeof(E<A>), (int)((char *)ea - (char *)e), e->a + (int) e->b, e->d, e->e);
  n1::C2 *r = new n1::C2; n2::C2 *s = new n2::C2;
  n1::C0 *r0 = r; n2::C0 *s0 = s;
  printf("%d %d %d %d %d %d\n", (int) sizeof(n1::C2), (int) sizeof(n2::C2), (int)((char *)r0 - (char *)r), (int)((char *)s0 - (char *)s), r0->f(), (int) s0->m + r->k + s->k + r->j + s->j);
  delete p; delete q; delete e; delete r; delete s;
  return 0;
}
