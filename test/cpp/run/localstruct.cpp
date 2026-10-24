// a plain local struct is its function's own: two functions' and two instances' `struct X' have their own layouts, and
// one with a class member is a local class
#include <cstdio>
#include <string>
int f() { struct X { int a; char b; }; X x{1, 2}; return (int) sizeof(X) * 10 + x.b; }
int g() { struct X { double a; char b; }; X x{1.5, 3}; return (int) sizeof(X) * 10 + x.b; }
template <class T> int h() {
  struct X { T a; char b; };
  X x{};
  x.b = 3;
  return (int) sizeof(X) * 10 + x.b;
}
template <class T> constexpr int k() {
  struct Y { T a; char b; };
  return (int) sizeof(Y);
}
int s() {
  struct S { std::string s; int n; };
  S v{"abc", 4};
  return (int) v.s.size() * 10 + v.n;
}
int u() {
  union U { int i; char c[8]; };
  U v;
  v.i = 0x41;
  return (int) sizeof(U) * 100 + v.c[0];
}
int main() {
  std::printf("%d %d %d %d %d %d\n", f(), g(), h<int>(), h<double>(), k<char>(), k<long>());
  constexpr int c = k<short>();
  std::printf("%d %d %d\n", c, s(), u());
  return 0;
}
