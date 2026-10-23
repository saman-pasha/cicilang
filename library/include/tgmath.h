/* cicilang's own <tgmath.h> (C17 7.25; 0.194): the type-generic macros over the C library's <math.h> and <complex.h>,
   the set clang's own header defines, chosen by _Generic -- an integer argument counts as a double, several generic
   arguments by the type their sum has, a complex one by the complex function. glibc's own refuses a compiler with clang's
   macros, at its `#error "Unsupported combination of types for <tgmath.h>."' (__HAVE_FLOAT64X without __HAVE_FLOAT128),
   which stopped the header silently: `sqrt(z)' of a complex called the real sqrt over its real part. clang's own lives in
   a resource directory off the path, as with <stdatomic.h>. In C++ libc++'s <tgmath.h> comes first. */
#ifndef _CICILANG_TGMATH_H
#define _CICILANG_TGMATH_H
#include <math.h>
#include <complex.h>

/* an argument as the generic choice sees it: a floating or complex type as it is, any other a double */
#define __TG_P(x) _Generic((x), float: (x), long double: (x), float _Complex: (x), double _Complex: (x), \
    long double _Complex: (x), default: (double) (x))
#define __TG_R(E, F) _Generic((E), float: F##f, long double: F##l, default: F)
#define __TG_C(E, F, C) _Generic((E), float: F##f, long double: F##l, float _Complex: C##f, double _Complex: C, \
    long double _Complex: C##l, default: F)
#define __TG_X(E, C) _Generic((E), float: C##f, long double: C##l, float _Complex: C##f, long double _Complex: C##l, \
    default: C)

/* 7.25/4: a real and a complex function */
#define acos(x) __TG_C(__TG_P(x), acos, cacos)(x)
#define asin(x) __TG_C(__TG_P(x), asin, casin)(x)
#define atan(x) __TG_C(__TG_P(x), atan, catan)(x)
#define acosh(x) __TG_C(__TG_P(x), acosh, cacosh)(x)
#define asinh(x) __TG_C(__TG_P(x), asinh, casinh)(x)
#define atanh(x) __TG_C(__TG_P(x), atanh, catanh)(x)
#define cos(x) __TG_C(__TG_P(x), cos, ccos)(x)
#define sin(x) __TG_C(__TG_P(x), sin, csin)(x)
#define tan(x) __TG_C(__TG_P(x), tan, ctan)(x)
#define cosh(x) __TG_C(__TG_P(x), cosh, ccosh)(x)
#define sinh(x) __TG_C(__TG_P(x), sinh, csinh)(x)
#define tanh(x) __TG_C(__TG_P(x), tanh, ctanh)(x)
#define exp(x) __TG_C(__TG_P(x), exp, cexp)(x)
#define log(x) __TG_C(__TG_P(x), log, clog)(x)
#define pow(x, y) __TG_C(__TG_P(x) + __TG_P(y), pow, cpow)((x), (y))
#define sqrt(x) __TG_C(__TG_P(x), sqrt, csqrt)(x)
#define fabs(x) __TG_C(__TG_P(x), fabs, cabs)(x)

/* 7.25/5: a real function alone; frexp, ldexp, scalbn, scalbln and nexttoward generic in their first argument */
#define atan2(x, y) __TG_R(__TG_P(x) + __TG_P(y), atan2)((x), (y))
#define cbrt(x) __TG_R(__TG_P(x), cbrt)(x)
#define ceil(x) __TG_R(__TG_P(x), ceil)(x)
#define copysign(x, y) __TG_R(__TG_P(x) + __TG_P(y), copysign)((x), (y))
#define erf(x) __TG_R(__TG_P(x), erf)(x)
#define erfc(x) __TG_R(__TG_P(x), erfc)(x)
#define exp2(x) __TG_R(__TG_P(x), exp2)(x)
#define expm1(x) __TG_R(__TG_P(x), expm1)(x)
#define fdim(x, y) __TG_R(__TG_P(x) + __TG_P(y), fdim)((x), (y))
#define floor(x) __TG_R(__TG_P(x), floor)(x)
#define fma(x, y, z) __TG_R(__TG_P(x) + __TG_P(y) + __TG_P(z), fma)((x), (y), (z))
#define fmax(x, y) __TG_R(__TG_P(x) + __TG_P(y), fmax)((x), (y))
#define fmin(x, y) __TG_R(__TG_P(x) + __TG_P(y), fmin)((x), (y))
#define fmod(x, y) __TG_R(__TG_P(x) + __TG_P(y), fmod)((x), (y))
#define frexp(x, e) __TG_R(__TG_P(x), frexp)((x), (e))
#define hypot(x, y) __TG_R(__TG_P(x) + __TG_P(y), hypot)((x), (y))
#define ilogb(x) __TG_R(__TG_P(x), ilogb)(x)
#define ldexp(x, e) __TG_R(__TG_P(x), ldexp)((x), (e))
#define lgamma(x) __TG_R(__TG_P(x), lgamma)(x)
#define llrint(x) __TG_R(__TG_P(x), llrint)(x)
#define llround(x) __TG_R(__TG_P(x), llround)(x)
#define log10(x) __TG_R(__TG_P(x), log10)(x)
#define log1p(x) __TG_R(__TG_P(x), log1p)(x)
#define log2(x) __TG_R(__TG_P(x), log2)(x)
#define logb(x) __TG_R(__TG_P(x), logb)(x)
#define lrint(x) __TG_R(__TG_P(x), lrint)(x)
#define lround(x) __TG_R(__TG_P(x), lround)(x)
#define nearbyint(x) __TG_R(__TG_P(x), nearbyint)(x)
#define nextafter(x, y) __TG_R(__TG_P(x) + __TG_P(y), nextafter)((x), (y))
#define nexttoward(x, y) __TG_R(__TG_P(x), nexttoward)((x), (y))
#define remainder(x, y) __TG_R(__TG_P(x) + __TG_P(y), remainder)((x), (y))
#define remquo(x, y, q) __TG_R(__TG_P(x) + __TG_P(y), remquo)((x), (y), (q))
#define rint(x) __TG_R(__TG_P(x), rint)(x)
#define round(x) __TG_R(__TG_P(x), round)(x)
#define scalbn(x, n) __TG_R(__TG_P(x), scalbn)((x), (n))
#define scalbln(x, n) __TG_R(__TG_P(x), scalbln)((x), (n))
#define tgamma(x) __TG_R(__TG_P(x), tgamma)(x)
#define trunc(x) __TG_R(__TG_P(x), trunc)(x)

/* 7.25/6: a complex function alone, for a real argument too */
#define carg(x) __TG_X(__TG_P(x), carg)(x)
#define cimag(x) __TG_X(__TG_P(x), cimag)(x)
#define conj(x) __TG_X(__TG_P(x), conj)(x)
#define cproj(x) __TG_X(__TG_P(x), cproj)(x)
#define creal(x) __TG_X(__TG_P(x), creal)(x)
#endif
