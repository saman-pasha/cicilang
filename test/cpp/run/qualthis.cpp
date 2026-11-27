// qualthis.cpp (1.6.26): a member function named with its class, called in a lambda that captured this -- by [this],
// by [&] and by [=], one inside another --, beside a static one in a lambda of no capture: the call went out with a null
// this, where the closure keeps the object, and crashed
#include <cstdio>
struct B { int v = 5; int m(int a) { return a + v; } static int s(int a) { return a * 2; } };
struct S : B {
  int w = 1;
  int m(int a) { return a * 10 + w; }
  int k() { return [this] { return S::m(1) + B::m(2); }(); }
  int j() { auto f = [&](int x) { return S::m(x) + B::s(x); }; return f(3); }
  int i() { return B::m(4) + S::m(5); }
  int h() { auto f = [=](int x) { return B::m(x); }; return f(6); }
  int g() { auto f = [](int x) { return B::s(x); }; return f(7); }
  int e() { return [this] { return [this] { return S::m(8); }(); }(); }
};
int main() { S s; std::printf("%d %d %d %d %d %d\n", s.k(), s.j(), s.i(), s.h(), s.g(), s.e()); return 0; }
