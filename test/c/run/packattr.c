#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
/* GCC's packed and aligned attributes, and where LLVM's offsets must be C's: a store through a member is read back at its
   offsetof, and an array's stride is its sizeof */
struct __attribute__((aligned(16))) A16 { char c; };
struct O1 { char x; struct A16 s; int y; };
struct M1 { int a; _Alignas(16) int b; char c; };
struct BF { int a : 3; int b : 5; };
struct O2 { char c; struct BF bf; char d; };
typedef int aint8 __attribute__((aligned(8)));
struct T8 { char c; aint8 v; };
struct Q2 { char c; int i __attribute__((aligned(8))); };
struct __attribute__((packed)) PB { char a; int b : 4; int c : 20; short d; };
union __attribute__((packed)) PU { char c[5]; int i; };
struct PUH { char x; union PU u; char y; };
enum __attribute__((packed)) PE { PE0, PE1, PE2 };
enum PE2 { N1 = -1, N2 = 100 } __attribute__((packed));
enum __attribute__((packed)) PE3 { BIG = 300 };
struct EH { char c; enum PE e; enum PE3 f; };
static int gv __attribute__((aligned(64))) = 5;
static char gbuf[3] __attribute__((aligned(32)));
#define CHECK(S, M, V) do { S s_; memset(&s_, 0, sizeof s_); s_.M = V; __typeof__(s_.M) v_ = V; \
    printf("%s.%s %zu %d\n", #S, #M, offsetof(S, M), memcmp((char *) &s_ + offsetof(S, M), &v_, sizeof v_) == 0); } while (0)
int main(void) {
  printf("%zu %zu %zu %zu\n", sizeof(struct A16), _Alignof(struct A16), sizeof(struct O1), offsetof(struct O1, y));
  CHECK(struct O1, y, 77);
  CHECK(struct M1, b, 5);
  CHECK(struct M1, c, 6);
  printf("%zu %zu %zu\n", sizeof(struct BF), sizeof(struct O2), offsetof(struct O2, d));
  CHECK(struct O2, d, 9);
  printf("%zu %zu %zu\n", sizeof(struct T8), offsetof(struct T8, v), _Alignof(aint8));
  CHECK(struct T8, v, 11);
  printf("%zu %zu\n", sizeof(struct Q2), offsetof(struct Q2, i));
  CHECK(struct Q2, i, 12);
  struct PB pb; memset(&pb, 0, sizeof pb); pb.a = 1; pb.b = -3; pb.c = 70000; pb.d = 7;
  printf("%zu %zu %d %d %d %d\n", sizeof(struct PB), offsetof(struct PB, d), pb.a, pb.b, pb.c, pb.d);
  unsigned char raw[sizeof pb]; memcpy(raw, &pb, sizeof pb);
  for (size_t i = 0; i < sizeof pb; i++) printf("%02x", raw[i]);
  printf("\n");
  printf("%zu %zu %zu\n", sizeof(union PU), sizeof(struct PUH), offsetof(struct PUH, y));
  CHECK(struct PUH, y, 13);
  printf("%zu %zu %zu %zu %zu %zu\n", sizeof(enum PE), sizeof(enum PE2), sizeof(enum PE3), sizeof(PE1), sizeof(struct EH), offsetof(struct EH, f));
  enum PE e = PE2; enum PE2 f = N1;
  printf("%d %d %d\n", e, f, f < 0);
  printf("%d %d %d\n", (int) ((uintptr_t) &gv % 64), (int) ((uintptr_t) gbuf % 32), gv);
  struct O1 arr[2];
  printf("%d\n", (int) ((char *) &arr[1] - (char *) &arr[0]));
  return 0;
}
