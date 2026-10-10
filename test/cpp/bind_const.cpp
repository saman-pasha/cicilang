/* a non-const lvalue reference binds no const lvalue ([dcl.init.ref]/5): a const object, and a by-value capture of a lambda that is not
   mutable, are refused by name (0.127) */
#include <cstdio>
int main() {
  int x = 3;
  auto f = [x]() { int &r = x; return r; };
  std::printf("%d\n", f());
  return 0;
}
