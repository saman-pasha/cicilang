#include <stdio.h>
#include <stddef.h>
struct [[gnu::packed]] S { char c; int i; };
struct T { char c; [[gnu::aligned(16)]] int i; };
[[gnu::aligned(64)]] int g = 1;
int main(void) {
  printf("%d %d %d %d\n", (int) sizeof(struct S), (int) offsetof(struct S, i), (int) sizeof(struct T), (int) offsetof(struct T, i));
  printf("%d %d %d\n", (int) (((size_t) &g) % 64), __has_c_attribute(gnu::packed), __has_c_attribute(gnu::aligned));
  return 0;
}
