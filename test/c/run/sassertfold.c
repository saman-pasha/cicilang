/* A STATIC ASSERTION'S CONDITION FOLDS OR THE PROGRAM IS REFUSED (0.257): each form here is an integer constant expression
   clang takes, and each folds -- a member of a C23 constexpr structure, nested and designated, a block's enumerator,
   GCC's __builtin_constant_p, offsetof, a cast of a floating constant, _Generic -- where a condition that does not fold
   is refused in clang's words. Before 0.257 a condition that did not fold passed unasked. */
#include <stdio.h>
#include <stddef.h>
struct In { int a, b; };
struct P { int x; struct In in; int z; long w; };
constexpr struct P cp = { 1, { 2, 3 }, .w = 7 };
static_assert(cp.x == 1 && cp.in.a == 2 && cp.in.b == 3 && cp.z == 0 && cp.w == 7);
static_assert(__builtin_constant_p(5) && !__builtin_constant_p(cp.x + printf("")));
static_assert(offsetof(struct P, in) == 4 && (int)3.7 == 3 && _Generic(1L, long: 1, default: 0));
int g = cp.in.b * 10;
int main(void) {
  enum { K = 3, L };
  static_assert(K == 3 && L == 4, "a block's enumerators");
  constexpr struct In li = { .b = 40 };
  static_assert(li.a == 0 && li.b == 40);
  int arr[L];
  printf("%d %d %d %d\n", g, li.b, (int)(sizeof arr / sizeof arr[0]), cp.in.a + K);
  return 0;
}
