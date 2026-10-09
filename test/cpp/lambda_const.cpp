/* a by-value capture of a lambda that is not mutable is const: the write is refused by name (0.117) */
#include <cstdio>
int main() {
  int n = 1;
  auto bad = [n]() { n++; return n; };
  return bad();
}
