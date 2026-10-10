// A virtual call that leaves a defaulted argument out dispatches to the override.
#include <cstdio>
struct B { virtual int f(int a, int b = 2) { return a + b; } virtual ~B() { } };
struct D : B { int f(int a, int b) override { return a * b * 10; } };
int main() {
  D d; B *p = &d;
  std::printf("%d %d\n", p->f(3), p->f(3, 4));
  return 0;
}
