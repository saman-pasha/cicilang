/* complitblocks.c -- compound literals whose block is still running where they are used (1.6.37), built as C alone, since
   C++ takes no compound literal's address: a function's own, read at its end, an inner block's read in it, and each
   pass's read in its pass */
#include <stdio.h>
int main(void) {
    int *p = &(int){ 4 };
    int s = 0;
    { int *q = &(int){ 5 }; s += *q; }
    for (int i = 0; i < 3; i++) { int *r = &(int){ i * 10 }; s += *r; }
    s += *p;
    printf("%d\n", s);
    return 0;
}
