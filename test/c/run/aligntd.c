#include <pthread.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
/* GCC's `aligned' on a typedef lowers or raises the type's alignment and keeps its size; `_Alignas' on a pointer object aligns
   the pointer; an aligned array, global and local, lies at its alignment; a read through a pointer to a typedef aligned at one */
struct S { int a; char b; };
typedef struct S T16 __attribute__((aligned(16)));
typedef int I16 __attribute__((aligned(16)));
typedef int I2 __attribute__((aligned(2)));
typedef uint32_t u32u __attribute__((aligned(1)));
typedef char *CP2 __attribute__((aligned(2)));
struct H { char c; T16 t; char d; };
struct K { char c; I2 i; };
struct __attribute__((packed)) PK { char c; I16 i; };
struct PA { char c; _Alignas(16) char *p; char d; };
struct Q { char c; CP2 p; };
_Alignas(32) static char g[24];
static I16 gi = 3;
static uint32_t rd(const unsigned char *b, int k) { return *(const u32u *) (b + k); }
int main(void) {
  printf("%zu %zu %zu %zu\n", sizeof(T16), _Alignof(T16), sizeof(I16), _Alignof(I16));
  printf("%zu %zu %zu\n", sizeof(struct H), offsetof(struct H, t), offsetof(struct H, d));
  printf("%zu %zu %zu %zu\n", sizeof(I2), _Alignof(I2), sizeof(struct K), offsetof(struct K, i));
  printf("%zu %zu %zu\n", sizeof(struct PK), offsetof(struct PK, i), _Alignof(struct PK));
  printf("%zu %zu %zu %zu\n", sizeof(struct PA), offsetof(struct PA, p), offsetof(struct PA, d), _Alignof(struct PA));
  printf("%zu %zu %zu\n", sizeof(struct Q), offsetof(struct Q, p), _Alignof(CP2));
#ifdef __GLIBC__
  printf("%zu %zu\n", sizeof(__pthread_unwind_buf_t), _Alignof(__pthread_unwind_buf_t));   /* glibc's own aligned typedef */
#else
  printf("%zu %zu\n", sizeof(pthread_mutex_t), _Alignof(pthread_mutex_t));   /* elsewhere (0.225): a Mac's C library has no such type */
#endif
  _Alignas(64) char loc[10]; I16 li = 4; I2 l2 = 5;
  printf("%d %d %d %d\n", (int) ((uintptr_t) g % 32), (int) ((uintptr_t) loc % 64), (int) ((uintptr_t) &gi % 16), (int) ((uintptr_t) &li % 16));
  unsigned char buf[12]; for (int k = 0; k < 12; k++) buf[k] = (unsigned char) (k + 1);
  printf("%x %x %d %d\n", rd(buf, 1), rd(buf, 3), gi + li, l2);
  struct K kk; memset(&kk, 0, sizeof kk); kk.i = 0x1234; unsigned char raw[sizeof kk]; memcpy(raw, &kk, sizeof kk);
  for (size_t k = 0; k < sizeof kk; k++) printf("%02x", raw[k]);
  printf(" %x\n", kk.i);
  struct PA pa; memset(&pa, 0, sizeof pa); pa.p = loc; pa.d = 9; printf("%d %d\n", pa.p == loc, pa.d);
  return 0;
}
