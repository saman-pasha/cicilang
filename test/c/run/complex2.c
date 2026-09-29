/* the complex types' remainders (0.101): the imaginary literal in every spelling, Annex G's multiplication and
   division through the runtime's __muldc3 and __divdc3 (the infinities recovered where the textbook formulas give
   NaN), __real__ and __imag__ as places, and _Complex long double (lowered as a complex double) */
#include <complex.h>
#include <math.h>
#include <stdio.h>
double _Complex g = 1.0 + 2.0i;
double _Complex h = 3.0i;
static double _Complex sq(double _Complex z) { return z * z; }
int main(void) {
    double _Complex z = 1.0 + 2.0i, w = 3.0 - 1.0i;
    float _Complex f = 1.5if + 0.5fi;
    double _Complex k = 3i, m = 4.0I + 5.0J + 6e2i + 0x10i + 1.0li;
    printf("%.1f %.1f %.1f %.1f %.1f %.1f\n", creal(z), cimag(z), creal(w), cimag(w), crealf(f), cimagf(f));
    printf("%.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f\n", creal(k), cimag(k), creal(m), cimag(m), creal(g), cimag(g), creal(h), cimag(h));
    __real__ z = 5.0; __imag__ w = 7.0; __imag__ z += 1.0;
    printf("%.1f %.1f %.1f %.1f\n", creal(z), cimag(z), creal(w), cimag(w));
    double _Complex q = (1.0 + 2.0i) / (3.0 - 1.0i), s = sq(1.0 + 1.0i);
    printf("%.2f %.2f %.1f %.1f\n", creal(q), cimag(q), creal(s), cimag(s));
    double _Complex byzero = (1.0 + 1.0i) / (0.0 + 0.0i);
    double _Complex infmul = (INFINITY + 1.0i) * (2.0 + 0.0i);
    double _Complex infdiv = (1.0 + 1.0i) / (INFINITY + INFINITY * 1.0i);
    printf("%d %d %d %d %d %d\n", isinf(creal(byzero)), isinf(cimag(byzero)), isinf(creal(infmul)), isnan(cimag(infmul)), creal(infdiv) == 0.0, cimag(infdiv) == 0.0);
    float _Complex fq = (1.0f + 2.0if) / (3.0f - 1.0if), fm = f * f;
    printf("%.2f %.2f %.2f %.2f\n", crealf(fq), cimagf(fq), crealf(fm), cimagf(fm));
    long double _Complex L = 2.0L + 1.0i;
    L = L * L;
    printf("%.1f %.1f %d\n", (double) __real__ L, (double) __imag__ L, (int) sizeof(z));   /* the components, not creall: a complex long double is a complex double here, and the library's l functions take the x87 pair */
    return 0;
}
