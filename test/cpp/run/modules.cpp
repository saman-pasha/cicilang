import mathm;
#include <cstdio>
int main() {
  Acc a;
  a.add(square(3));
  a.add(bump(4));
  hello();
  printf("%d %d %d %d %g\n", square(7), a.total, cube(3), biggest(4, 9), biggest(2.5, 1.5));
  return 0;
}
