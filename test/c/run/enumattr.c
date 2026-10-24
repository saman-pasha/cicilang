#include <stdio.h>
/* an attribute after `enum' (C23 6.7.2.2/1; GCC's __attribute__ in every C) */
enum __attribute__((__deprecated__)) G { d = 2, e = 300 };
enum [[deprecated]] H { f = 5 };
int main(void) {
  enum G z = e;
  enum H y = f;
  printf("%d %d %zu\n", (int) z, (int) y, sizeof(enum G));
  return 0;
}
