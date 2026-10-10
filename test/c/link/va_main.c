#include <stdio.h>
#include "va.h"
int main(void) {
    vd2 p = { 1.5, 2.5 };
    vf3 f = { 0.5f, 1.5f, 2.5f };
    vl3 s = { 10, 20, 30 };
    vic c = { 7, 'x' };
    vq q = { ((__int128)3 << 64) + 5 };
    printf("%.2f\n", va_mix("idLpfsc", 1, 2.0, (long double)3.25, p, f, s, c));
    printf("%.2f\n", va_mix("iiiiiiiiidddddddddd", 1, 2, 3, 4, 5, 6, 7, 8, 9, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0));
    printf("%.2f\n", va_mix("pppppc", p, p, p, p, p, c));
    printf("%.2f\n", va_mix("iqiqlll", 1, q, 2, q, 3L, 4L, 5L));
    printf("%.2f\n", va_mix("LLLLLLLLLd", (long double)1, (long double)2, (long double)3, (long double)4, (long double)5,
                            (long double)6, (long double)7, (long double)8, (long double)9.5, 0.25));
    printf("%.2f\n", va_mix("ffffs", f, f, f, f, s));
    return 0;
}
