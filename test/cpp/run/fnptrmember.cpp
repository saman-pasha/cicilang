// A data member of pointer-to-function type, named bare in a member function and called, is a call through the
// pointer. libc++ 18's __output_buffer::__flush() writes `__flush_(__ptr_, __size_, __obj_)'.
#include <cstdio>
struct Counter {
  int n = 0;
  int (*step_)(int);
  Counter(int (*s)(int)) : step_(s) {}
  void tick() { n = step_(n); }
};
struct Base { int (*twice_)(int) = nullptr; };
struct Derived : Base { int run(int x) { return twice_(x) + 1; } };
template <class T> struct G {
  T v{};
  T (*f_)(T);
  G() : f_([](T x) { return x * 2 + 1; }) {}
  T go() { v = f_(v); return v; }
};
int add3(int x) { return x + 3; }
int dbl(int x) { return 2 * x; }
int main() {
  Counter c(add3);
  c.tick();
  c.tick();
  Derived d;
  d.twice_ = dbl;
  G<int> g;
  g.go();
  std::printf("%d %d %d\n", c.n, d.run(20), g.go());
  return 0;
}
