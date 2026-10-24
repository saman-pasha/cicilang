#include <stddef.h>
#include <stdio.h>
#include <string.h>
/* packed and aligned unions: their sizes, a member read and written where its place is below its alignment, a bitfield in one,
   a constant of one, and an aligned union's size in a struct */
union __attribute__((packed)) U1 { char c; int i; long long l; };
union __attribute__((packed)) U2 { int a : 3; char c; };
union __attribute__((packed)) U3 { short s; int i __attribute__((aligned(4))); };
union __attribute__((aligned(16))) U4 { char c; };
union U5 { char c; int i; } __attribute__((packed));
struct __attribute__((packed)) S1 { char x; union U1 u; char y; };
struct S2 { char x; union U4 u; char y; };
struct S3 { char x; union U5 u; short z; };
static union U1 gu = { .i = 0x01020304 };
static struct S1 gs = { 7, { .l = 0x1122334455667788LL }, 9 };
int main(void) {
  printf("%zu %zu %zu %zu\n", sizeof(union U1), _Alignof(union U1), sizeof(union U2), _Alignof(union U2));
  printf("%zu %zu %zu %zu\n", sizeof(union U3), _Alignof(union U3), sizeof(union U4), _Alignof(union U4));
  printf("%zu %zu\n", sizeof(union U5), _Alignof(union U5));
  printf("%zu %zu %zu\n", sizeof(struct S1), offsetof(struct S1, u), offsetof(struct S1, y));
  printf("%zu %zu %zu\n", sizeof(struct S2), offsetof(struct S2, u), offsetof(struct S2, y));
  printf("%zu %zu %zu\n", sizeof(struct S3), offsetof(struct S3, u), offsetof(struct S3, z));
  struct S1 s; memset(&s, 0, sizeof s); s.x = 1; s.u.i = 0x0a0b0c0d; s.y = 2;
  unsigned char raw[sizeof s]; memcpy(raw, &s, sizeof s);
  for (size_t k = 0; k < sizeof s; k++) printf("%02x", raw[k]);
  printf(" %x %d %d\n", s.u.i, s.x, s.y);
  s.u.l = -5; printf("%lld %d\n", s.u.l, s.y);
  union U2 b; memset(&b, 0, sizeof b); b.a = -2; printf("%d %d\n", b.a, b.c);
  b.c = 5; printf("%d %d\n", b.a, b.c);
  printf("%x %x\n", gu.i, gu.c);
  printf("%d %llx %d\n", gs.x, gs.u.l, gs.y);
  struct S2 t; memset(&t, 0, sizeof t); t.y = 3; t.u.c = 4; printf("%d %d\n", t.y, t.u.c);
  struct S3 w; memset(&w, 0, sizeof w); w.u.i = 77; w.z = 8; printf("%d %d\n", w.u.i, w.z);
  return 0;
}
