/* blockenums.c (1.6.30): a block's enumerators are its block's (C17 6.2.1/4) -- one of a block shadows the file's of its
   name and another block's, and the file's is the one after the block; they were the unit's, and the last of a name gave
   every block the wrong value */
#include <stdio.h>
enum { B = 5 };
static int f(void) { enum { A = 1, B = 2 }; return A + B; }
static int g(void) { { enum { B = 7 }; if (B != 7) return -1; } return B; }
static int h(int x) { enum { K = 3, L = K + 1 }; switch (x) { case K: return 30; case L: return 40; default: return 0; } }
static int later(void) { enum { C = 9 }; return C; }
enum { C = 11 };
int main(void) {
  enum { B = 4 };
  int arr[sizeof(int)];
  printf("%d %d %d %d %d %d %d %d\n", f(), g(), h(3), h(4), B, later(), C, (int)(sizeof arr / sizeof arr[0]));
  return 0;
}
