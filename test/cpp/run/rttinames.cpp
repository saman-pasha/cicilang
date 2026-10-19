// the type information's names of the program's own types, as clang spells them (0.180): a class in a namespace and in
// a nested one, a namespace's class whose name a class at file scope has too, a plain struct and a union in a
// namespace, a nested class and enum, a template's instances, pointers, pointers to members, arrays and functions over
// them; compared, thrown and caught
#include <cstdio>
#include <typeinfo>
namespace ns { struct A { int a; virtual ~A() {} }; struct P { int x; }; namespace in { struct Q { int q; }; } }
struct Outer { struct Inner { int i; }; enum Color { R, G }; };
template <class T> struct Box { T v; };
template <class T, int N> struct Arr { T a[N]; };
struct A { int f(int) { return a; } int a; };
union U { int i; float f; };
namespace ns { union V { int i; char c; }; }
int main() {
  std::printf("%s %s %s %s %s\n", typeid(ns::A).name(), typeid(ns::P).name(), typeid(ns::in::Q).name(),
              typeid(Outer::Inner).name(), typeid(Outer::Color).name());
  std::printf("%s %s %s %s\n", typeid(Box<int>).name(), typeid(Box<ns::P>).name(), typeid(Arr<char, 3>).name(),
              typeid(Box<Box<int>>).name());
  std::printf("%s %s %s %s\n", typeid(ns::A *).name(), typeid(Outer::Inner **).name(),
              typeid(int Outer::Inner::*).name(),
              typeid(A **).name());
  std::printf("%s %s %s\n", typeid(A[2]).name(), typeid(void (*)(A, Box<int>)).name(), typeid(int A::*).name());
  std::printf("%s %s %s %s\n", typeid(U).name(), typeid(ns::V).name(), typeid(U *).name(),
              typeid(const ns::P *).name());
  ns::A a; Outer::Inner oi; Box<int> bi;
  std::printf("%d %d %d\n", typeid(a) == typeid(ns::A), typeid(oi) == typeid(Outer::Inner),
              typeid(bi) == typeid(Box<int>));
  try { throw Box<ns::P>{{5}}; } catch (Box<ns::P> &e) { std::printf("caught %d\n", e.v.x); }
  try { throw &oi; } catch (Outer::Inner *p) { std::printf("caught a pointer %d\n", p == &oi); }
  return 0;
}
