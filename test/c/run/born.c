/* AN INSTANCE'S BIRTH (0.285): an object of an instance's type declared with no initializer is given zero -- a mask,
   which has no drop, over a stack that held other bytes, and a for's object; a box, which has a drop, is the empty
   one --, and an object is made of a value of another type by its type macro's `_of': `mask<12> b = 0x0f0;' of a
   number, `mask<12> c = "1010";' of a text, `box<int> q = 42;', and `a = 0x00f' in an assignment. A value of the
   instance's own type is copied as C copies it. cicilang++ builds this file too */
#include <stdio.h>
#include <stdlib.h>
#include "tborn.pl"
static void dirty(void) {
    volatile unsigned char junk[256];
    for (int i = 0; i < 256; i++) junk[i] = 0xff;
}
static unsigned long long born(void) {
    mask<12> a;
    return a.w;
}
static int twice(mask<12> m) { return (int)(m.w * 2); }
int main(void) {
    dirty();
    printf("%llx\n", born());
    mask<12> a;
    mask<12> b = 0x0f0;
    mask<12> c = "1010";
    mask<12> d = b;
    mask<12> e = 0xfffff;
    printf("%llx %llx %llx %llx %llx\n", a.w, b.w, c.w, d.w, e.w);
    a = 0x00f;
    d = "11";
    printf("%llx %llx %d\n", a.w, d.w, twice(a));
    for (mask<12> m; m.w < 3; m.w++) printf("%llx", m.w);
    printf("\n");
    box<int> p;
    box<int> q = 42;
    box<double> r = 2.5, s = 3;
    printf("%d %d %d %g %g\n", full(p), full(q), get(q), get(r), get(s));
    return 0;
}
