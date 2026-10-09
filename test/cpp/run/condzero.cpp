// a conditional with the literal zero for one arm and a pointer for the other (0.117, [expr.cond]/7): the zero is a null pointer constant and the
// result is the pointer's type, so the overload taking an `int *' is chosen -- libc++'s `deque::begin()' passes `__map_.empty() ? 0 : *__mp + ...' to an
// iterator constructor taking a pointer
#include <cstdio>
int f(int *p) { return p ? 10 : 11; }
int f(long x) { return 20 + (int)x; }
int g(int *a, bool e) { return f(e ? 0 : a + 3); }
int h(int *a, bool e) { return f(e ? a + 1 : 0); }
int main() {
  int a[8] = {0};
  std::printf("%d %d %d %d\n", g(a, false), g(a, true), h(a, false), h(a, true));
  return 0;
}
