// a member named through an object by its qualified name ([expr.ref]/7): a base's data member the derived class
// hides, a base's virtual method called without dispatch, through an object, a pointer, a reference and `this',
// a static, a dependent base of a class template, and a member written through the qualified name
#include <cstdio>
struct A { int v = 1; static int made; virtual int f() const { return 10; } int g() const { return 100; } virtual ~A() {} };
int A::made = 5;
struct B : A {
  int v = 2;
  int f() const override { return 20; }
  int both() const { return this->A::f() + this->f() + A::v + v; }
};
template <class T> struct Base { T x; T get() const { return x; } };
template <class T> struct Derived : Base<T> {
  T twice() const { return this->Base<T>::get() * 2 + this->Base<T>::x; }
};
int main() {
  B b; const B *p = &b; const A &r = b;
  std::printf("%d %d %d %d\n", b.v, b.A::v, b.A::f(), b.f());
  std::printf("%d %d %d %d\n", p->A::f(), p->B::f(), p->A::g(), r.A::f());
  b.A::v = 7;
  std::printf("%d %d %d\n", b.A::v, b.both(), b.A::made);
  B *q = &b; q->A::v += 3;
  std::printf("%d %d\n", q->A::v, r.f());
  Derived<int> d; d.x = 4;
  std::printf("%d %d\n", d.twice(), d.Base<int>::get());
  return 0;
}
