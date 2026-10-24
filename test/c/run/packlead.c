/* where GCC's attributes stand: one before a struct's key is the declaration's, not the type's, and one among the declaration
   specifiers is every declarator's; `typeof' of a packed member or of an aligned object is the type alone, a typedef's own
   alignment kept */
#include <stddef.h>
#include <stdio.h>
__attribute__((packed)) struct B1 { char c; int i; };
__attribute__((aligned(8))) struct B2 { char c; int i; } v2;
struct O { char x; __attribute__((packed)) struct I { char c; int i; } m; char y; };
struct L { char c; __attribute__((aligned(16))) int a, b; char d; };
struct LP { char c; __attribute__((packed)) int a, b; };
struct Q { char c; int i __attribute__((packed)); char d; };
struct HT { char c; __typeof__(((struct Q *) 0)->i) t; };
typedef int I16 __attribute__((aligned(16)));
struct H16 { char c; __typeof__((I16) 0) t; };
I16 g16;
_Alignas(16) int a16;
struct HG { char c; __typeof__(g16) t; __typeof__(a16) u; };
int main(void) {
  printf("%zu %zu %zu\n", sizeof(struct B1), sizeof(struct B2), _Alignof(struct B2));
  printf("%zu %zu %zu %zu\n", sizeof(struct O), offsetof(struct O, m), offsetof(struct O, y), sizeof(struct I));
  printf("%zu %zu %zu %zu\n", sizeof(struct L), offsetof(struct L, a), offsetof(struct L, b), offsetof(struct L, d));
  printf("%zu %zu %zu\n", sizeof(struct LP), offsetof(struct LP, a), offsetof(struct LP, b));
  printf("%zu %zu %zu\n", sizeof(struct Q), offsetof(struct Q, i), offsetof(struct HT, t));
  printf("%zu %zu %zu\n", offsetof(struct H16, t), offsetof(struct HG, t), offsetof(struct HG, u));
  struct O o = { 1, { 2, 3 }, 4 };
  v2.i = 7;
  printf("%d %d %d %d %d\n", o.x, o.m.c, o.m.i, o.y, v2.i);
  return 0;
}
