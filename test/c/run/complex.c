/* C's complex types (C11 6.2.5, Annex G): the arithmetic, the components, the conversions, the C library's
   functions over them (the ABI: two components in registers), I and CMPLX from the compiler's <complex.h> */
#include <complex.h>
#include <stdio.h>
#ifndef CMPLX                       /* the C library defines it for GCC only; clang has the builtin */
#define CMPLX(x, y) __builtin_complex((double) (x), (double) (y))
#endif
double _Complex g = 2.0;
static double _Complex twice(double _Complex z) { return z * 2.0; }
int main(void) {
    double _Complex z = 1.0 + 2.0 * I;
    double _Complex w = CMPLX(3.0, -1.0);
    double _Complex s = z + w, d = z - w, p = z * w, q = z / w;
    printf("%.1f %.1f %.1f %.1f\n", creal(z), cimag(z), __real__ w, __imag__ w);
    printf("%.1f %.1f %.1f %.1f %.1f %.1f\n", creal(s), cimag(s), creal(d), cimag(d), creal(p), cimag(p));
    printf("%.2f %.2f %.1f %d %d %d\n", creal(q), cimag(q), cabs(__builtin_complex(3.0, 4.0)), z == w, z == 1.0 + 2.0 * I, z != w);
    float _Complex f = 1.5f + 0.5f * I;
    f = f * 2.0f;
    z = f;
    z = -z;
    printf("%.1f %.1f %.1f %.1f %.1f\n", crealf(f), cimagf(f), creal(z), cimag(z), creal(g) + cimag(g));
    double _Complex c = conj(twice(z));
    double r = z;
    printf("%.1f %.1f %.1f %d %d %.1f\n", creal(c), cimag(c), r, (int) sizeof(z), (int) sizeof(f), __imag__ r);
    return 0;
}
