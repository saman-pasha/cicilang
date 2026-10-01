/* A hex, octal or binary literal past 2^60 is big('0x...') in both lexers (0.94), and the constant evaluator reads it
   AS HEX: read as decimal digits, `0xF000000000000000ull >> 60' folded to 0 where C says 15 (0.112). */
#include <stdio.h>
enum { A = (int) (0xF000000000000000ull >> 60), B = (int) (0x8000000000000000 >> 63) };
int main(void) {
  char a[(0xF000000000000000ull >> 60)];
  printf("%d %d %d %d\n", A, B, (int) sizeof a, (int) (0xFFFFFFFFFFFFFFFFull % 1000));
  return 0;
}
