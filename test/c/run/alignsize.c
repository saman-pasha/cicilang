#include <stdio.h>
#include <stddef.h>
#include <stdalign.h>
/* an alignment specifier moves where an object or a member lies and never how big it is (0.112): sizeof of an
   _Alignas object, an aligned array and its element, and the members around an aligned member, as C lays them out */
struct T { _Alignas(16) int x; int y; char z; };
struct U { char a; _Alignas(8) char b[3]; short c; };
_Alignas(16) char g[24];
int main(void) {
  _Alignas(8) unsigned char b[24];
  alignas(struct T) unsigned char c[sizeof(struct T)];
  _Alignas(16) int x = 5;
  printf("%zu %zu %zu %zu %zu\n", sizeof b, sizeof c, sizeof g, sizeof x, sizeof(b[0]));
  printf("%d %d %d\n", (int) ((unsigned long) b % 8), (int) ((unsigned long) g % 16), (int) ((unsigned long) &x % 16));
  struct T t = {1, 2, 3}; struct U u = {4, {5, 6, 7}, 8};
  printf("%zu %zu %zu %zu %zu\n", sizeof(struct T), alignof(struct T), offsetof(struct T, y), offsetof(struct T, z), sizeof t.x);
  printf("%zu %zu %zu %zu %zu\n", sizeof(struct U), alignof(struct U), offsetof(struct U, b), offsetof(struct U, c), sizeof u.b);
  printf("%d %d %d %d %d %d\n", t.x, t.y, t.z, u.a, u.b[2], u.c);
  return 0;
}
