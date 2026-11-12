/* C23's parameter with no name in a definition (6.9.1) beside one named p0, whose register was the unnamed one's
   (0.293). clang's build of this file at C23 prints what cicilang's prints */
#include <stdio.h>
static int f_anon(int, int p0) { return p0 + 1; }
static int f_two(int p0, int, int p1) { return p0 * 10 + p1; }
int main(void) {
    printf("%d %d\n", f_anon(5, 6), f_two(1, 2, 3));
    return 0;
}
