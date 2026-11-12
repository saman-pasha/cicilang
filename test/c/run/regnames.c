/* A FUNCTION'S PARAMETERS BESIDE THE NAMES THAT THE LOWERING MAKES (0.293): a parameter's register was its name, so a
   parameter named entry met the entry block (`unable to create block named 'entry''), one named t1 a temporary and one
   named L2 a block; a struct that comes in pieces beside a local of its name in an inner block; a label and a local
   named entry. clang's build of this file prints what cicilang's prints */
#include <stdio.h>
struct pair { long a, b; };
static int f_entry(int entry) { return entry + 1; }
static int f_temps(int t1, int t2) {
    int s = 0;
    for (int i = 0; i < t2; i++) s += t1 * i;
    return s;
}
static int f_labels(int L1, int L2, int L3) {
    int k = 0;
    while (k < L1) { if (k == L2) break; k++; }
    return k + L3;
}
static long f_pieces(struct pair x) {
    long r = x.a;
    { long x = 5; r += x; }
    return r + x.b;
}
static int f_label(int n) {
    int k = 0;
entry:
    k++;
    if (k < n) goto entry;
    return k;
}
int main(void) {
    struct pair p = {3, 4};
    int entry = 7;
    printf("%d %d %d %ld %d %d\n", f_entry(1), f_temps(2, 4), f_labels(9, 3, 100), f_pieces(p), f_label(5), entry);
    return 0;
}
