/* The generic bit builtins over any integer width: an unsigned __int128 and an unsigned _BitInt(N) are counted in
   their own width, LLVM's intrinsics of that width, the value for a zero given or the width. */
#include <stdio.h>
int main(void) {
  unsigned __int128 x = (unsigned __int128) 1 << 100;
  unsigned __int128 z = 0;
  unsigned _BitInt(37) y = 5;
  unsigned _BitInt(100) w = (unsigned _BitInt(100)) 3 << 70;
  printf("%d %d %d\n", __builtin_clzg(x), __builtin_ctzg(x), __builtin_popcountg(x));
  printf("%d %d %d\n", __builtin_clzg(y), __builtin_ctzg(y), __builtin_popcountg(y));
  printf("%d %d %d\n", __builtin_clzg(w), __builtin_ctzg(w), __builtin_popcountg(w));
  printf("%d %d %d\n", __builtin_clzg(z, -1), __builtin_ctzg(z, 128), __builtin_popcountg(z));
  return 0;
}
