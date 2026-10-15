#include <stdarg.h>
#include <stdio.h>
#include "va.h"
double va_mix(const char *kinds, ...) {
    va_list ap;
    va_start(ap, kinds);
    double t = 0;
    for (int i = 0; kinds[i]; i++) {
        switch (kinds[i]) {
        case 'i': { int v = va_arg(ap, int); printf(" i%d", v); t += v; break; }
        case 'l': { long v = va_arg(ap, long); printf(" l%ld", v); t += v; break; }
        case 'd': { double v = va_arg(ap, double); printf(" d%.2f", v); t += v; break; }
        case 'L': { long double v = va_arg(ap, long double); printf(" L%.3Lf", v); t += (double)v; break; }
        case 'p': { vd2 v = va_arg(ap, vd2); printf(" p%.1f/%.1f", v.x, v.y); t += v.x + v.y; break; }
        case 'f': { vf3 v = va_arg(ap, vf3); printf(" f%.1f/%.1f/%.1f", v.a, v.b, v.c); t += v.a + v.b + v.c; break; }
        case 's': { vl3 v = va_arg(ap, vl3); printf(" s%ld/%ld/%ld", v.a, v.b, v.c); t += v.a + v.b + v.c; break; }
        case 'c': { vic v = va_arg(ap, vic); printf(" c%d/%c", v.a, v.b); t += v.a; break; }
        case 'q': { vq v = va_arg(ap, vq); printf(" q%ld/%ld", (long)(v.v >> 64), (long)v.v); t += (double)(long)v.v; break; }
        }
    }
    va_end(ap);
    printf("\n");
    return t;
}
