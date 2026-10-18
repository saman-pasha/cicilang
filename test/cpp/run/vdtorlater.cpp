// a destructor virtual by a base that is no primary, and a defaulted virtual one: std::has_virtual_destructor, typeid through the
// base, a delete through each base
#include <cstdio>
#include <type_traits>
#include <typeinfo>
struct P { int p = 1; virtual int f() { return 1; } };
struct Q { int q = 2; virtual ~Q() { std::printf("~Q\n"); } };
struct T : P, Q { int t = 3; };
struct U : T { ~U() { std::printf("~U\n"); } };
struct B { virtual ~B() = default; };
struct D : B { ~D() = default; int d = 4; };
struct E : D { ~E() { std::printf("~E\n"); } };
struct A { int a = 5; virtual ~A() { std::printf("~A\n"); } };
struct V : virtual A { int v = 6; virtual int g() { return 7; } };
struct W : V { ~W() { std::printf("~W\n"); } int g() override { return 8; } };
int main() {
  std::printf("%d %d %d %d %d %d %d\n", (int) std::has_virtual_destructor<P>::value, (int) std::has_virtual_destructor<T>::value,
              (int) std::has_virtual_destructor<U>::value, (int) std::has_virtual_destructor<B>::value, (int) std::has_virtual_destructor<D>::value,
              (int) std::has_virtual_destructor<V>::value, (int) std::has_virtual_destructor<W>::value);
  T *t = new U; std::printf("%s\n", typeid(*t).name()); delete t;
  D *d = new E; std::printf("%s\n", typeid(*d).name()); delete d;
  V *v = new W; std::printf("%s %d\n", typeid(*v).name(), v->g()); delete v;
  A *a = new W; delete a;
  return 0;
}
