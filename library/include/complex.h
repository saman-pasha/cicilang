/* cocolang's <complex.h> (0.100): the C library's own declarations first, then C11's I and CMPLX written over the
   compiler's __builtin_complex -- the C library spells them with the imaginary literal (`1.0iF', a GNU extension),
   which this compiler does not read; the complex types themselves are the language's (_Complex float, _Complex double). */
#ifndef _COCOLANG_COMPLEX_H
#define _COCOLANG_COMPLEX_H
#include_next <complex.h>
#undef _Complex_I
#define _Complex_I (__builtin_complex(0.0f, 1.0f))
#undef I
#define I _Complex_I
#undef CMPLX
#undef CMPLXF
#undef CMPLXL
#define CMPLX(x, y) __builtin_complex((double) (x), (double) (y))
#define CMPLXF(x, y) __builtin_complex((float) (x), (float) (y))
#define CMPLXL(x, y) __builtin_complex((double) (x), (double) (y))
#endif
