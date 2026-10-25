// A by-value parameter of a class with a destructor is the caller's object: built where the callee reads it, destroyed by
// the caller at the end of its full-expression, on unwinding too -- the Itanium C++ ABI's 3.1.2.3, as clang and gcc have it
// (0.207). The callee destroyed it before, at its return.
#include <cstdio>
#include <string>
#include <utility>
struct D {
  int v;
  D(int x) : v(x) { std::printf("D(%d)\n", v); }
  D(const D &o) : v(o.v + 10) { std::printf("copy %d\n", v); }
  D(D &&o) noexcept : v(o.v + 100) { std::printf("move %d\n", v); }
  ~D() { std::printf("~D(%d)\n", v); }
};
int f(D d) { std::printf("f %d\n", d.v); return d.v; }
D make(int v) { return D(v); }
int g(D a, D b) { return a.v + b.v; }
int thrower(D d) { if (d.v > 50) throw d.v; return d.v; }
struct S {
  int k;
  int m(D d) const { return d.v + k; }
};
int main() {
  std::printf("[1] %d\n", f(D(1)));
  D x(2);
  std::printf("[2] %d\n", f(x));
  std::printf("[3] %d\n", f(std::move(x)));
  std::printf("[4] %d\n", f(make(4)));
  bool c = x.v > 0;
  std::printf("[5] %d\n", f(c ? D(5) : D(6)));
  std::printf("[6] %d\n", g(D(7), make(8)));
  try { thrower(D(99)); } catch (int e) { std::printf("caught %d\n", e); }
  S s{1000};
  std::printf("[7] %d\n", s.m(D(9)));
  int t = f(D(11)) + f(D(12));
  std::printf("[8] %d\n", t);
  std::string str = "abc";
  auto h = [](std::string u) { return u.size(); };
  std::printf("[9] %zu %zu\n", h(str), h(std::string("hello")));
  std::printf("end\n");
}
