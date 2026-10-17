/* the buffer Apple's arm64 lays the variadic arguments of va_darwin.c out in, and the two walks over it (0.160): clang's
   must read the values put there (this layout is Apple's), and cicilang's must read what clang's reads */
#include <stdio.h>
#include <string.h>
struct big { long a, b, c; };
void walk_clang(long *o, char *ap);
void walk_cicilang(long *o, char *ap);
static void put(unsigned char *b, int at, const void *p, int n) { memcpy(b + at, p, n); }
int main(void) {
    _Alignas(16) unsigned char buf[128];
    static struct big B = {21, 22, 23};
    long v; double d; float f; short s = 300; void *p = &B; __int128 q = ((__int128) 52 << 64) | 51;
    memset(buf, 0, sizeof buf);
    buf[0] = 5; put(buf, 2, &s, 2);                                                   /* small, one slot */
    v = 11; put(buf, 8, &v, 8); v = 12; put(buf, 16, &v, 8);                          /* two, two slots */
    put(buf, 24, &p, 8);                                                              /* big, by its pointer */
    d = 31; put(buf, 32, &d, 8); d = 32; put(buf, 40, &d, 8); d = 33; put(buf, 48, &d, 8);   /* hfa3, by value */
    f = 41; put(buf, 56, &f, 4); f = 42; put(buf, 60, &f, 4);                         /* hfa2f */
    put(buf, 64, &q, 16);                                                             /* al16, at 16 */
    v = 61; put(buf, 80, &v, 8);                                                      /* the union */
    d = 71; put(buf, 88, &d, 8); d = 72; put(buf, 96, &d, 8);                         /* the complex */
    v = 81; put(buf, 104, &v, 8); v = 82; put(buf, 112, &v, 8);                       /* two again */
    long want[19] = {5, 300, 11, 12, 21, 22, 23, 31, 32, 33, 41, 42, 51, 52, 61, 71, 72, 81, 82}, a[19] = {0}, b[19] = {0};
    walk_clang(a, (char *) buf);
    walk_cicilang(b, (char *) buf);
    int bad = 0;
    for (int i = 0; i < 19; i++) {
        if (a[i] != want[i]) { printf("clang read %ld at %d, the layout says %ld\n", a[i], i, want[i]); bad = 1; }
        if (b[i] != a[i]) { printf("cicilang read %ld at %d, clang %ld\n", b[i], i, a[i]); bad = 1; }
    }
    printf(bad ? "differ\n" : "same\n");
    return bad;
}
