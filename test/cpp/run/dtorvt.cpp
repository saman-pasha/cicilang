// a virtual call inside a constructor or a destructor reaches that class's override, never a more derived one's
// ([class.cdtor]/4): a destructor stores its own class's tables first, as a constructor does, through single
// inheritance, a second polymorphic base, and a virtual base
#include <cstdio>
struct A { virtual int f() { return 1; } A() { std::printf("A %d\n", f()); } virtual ~A() { std::printf("~A %d\n", f()); } };
struct S : A { int f() override { return 5; } S() { std::printf("S %d\n", f()); } ~S() override { std::printf("~S %d\n", f()); } };
struct T : S { int f() override { return 6; } T() { std::printf("T %d\n", f()); } ~T() override { std::printf("~T %d\n", f()); } };
struct G { virtual int g() { return 10; } virtual ~G() { std::printf("~G %d\n", g()); } };
struct M : A, G { int f() override { return 7; } int g() override { return 20; } ~M() override { std::printf("~M %d %d\n", f(), g()); } };
struct V : virtual A { int f() override { return 8; } V() { std::printf("V %d\n", f()); } ~V() override { std::printf("~V %d\n", f()); } };
int main() {
  { T t; }
  { M m; }
  { V v; }
  A *p = new T; delete p;
  return 0;
}
