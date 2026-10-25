#include <stdio.h>
#include <stddef.h>
enum __attribute__((aligned(8))) E { E0, E1 };
enum __attribute__((packed, aligned(4))) P { P0, P1 };
enum __attribute__((aligned(16))) N { N0 = -2, N1 = 70000 };
struct H { char c; enum E e; };
struct Q { char c; enum P p; };
struct M { char c; _Alignas(16) int x; double d; };
enum E ge = E1;
int main(void) {
  double d = 1.5; char c = 2; struct M m; enum E e = E1; enum N n = N0;
  _Alignas(32) int a32 = 1;
  printf("%d %d %d %d\n", (int) __alignof__(d), (int) __alignof__(c), (int) _Alignof(double), (int) __alignof(d));
  printf("%d %d %d %d\n", (int) sizeof(enum E), (int) _Alignof(enum E), (int) sizeof(struct H), (int) offsetof(struct H, e));
  printf("%d %d %d\n", (int) sizeof(enum P), (int) _Alignof(enum P), (int) sizeof(struct Q));
  printf("%d %d %d\n", (int) sizeof(enum N), (int) _Alignof(enum N), n < 0);
  printf("%d %d %d\n", (int) __alignof__(m.x), (int) __alignof__(m), (int) __alignof__(a32));
  printf("%d %d %d %d\n", (int) (((size_t) &e) % 8), (int) (((size_t) &ge) % 8), e + 1, -e);
  m.x = a32 + c * 0 + (int) d * 0;
  return m.x - 1;
}
