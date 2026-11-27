/* GNU's extern inline with gnu_inline (1.6.39): its body is for inlining alone, no definition of the function, so the
   external definition after it is the one that a call calls, as clang has it; a static inline and a plain inline with
   the attribute are definitions as before */
#include <stdio.h>
extern __inline int k2(int x) __attribute__((__gnu_inline__));
extern __inline __attribute__((__gnu_inline__)) int k2(int x) { return x + 10; }
int k2(int x) { return x + 20; }
extern inline __attribute__((gnu_inline)) int k(int x) { return x + 1; }
int k(int x) { return x + 2; }
static inline __attribute__((gnu_inline)) int s(int x) { return x * 2; }
inline __attribute__((gnu_inline)) int p(int x) { return x * 3; }
extern __attribute__((gnu_inline)) int e(int x) { return x + 4; }   /* no inline: clang ignores the attribute */
int main(void) {
  int (*fk)(int) = k;
  printf("%d %d %d %d %d %d\n", k2(1), k(1), fk(5), s(2), p(3), e(1));
  return 0;
}
