/* _Complex int, GNU's integer complex (0.103): the integer imaginary literal `3i' is a _Complex int, the usual
   arithmetic conversions give a _Complex unsigned and a _Complex long, the arithmetic runs on integer components
   (the textbook multiplication and division, as clang has them), the comparisons, the negation, the components as
   values and as places, the conversions to and from a complex double, and the globals' constants */
#include <stdio.h>
int _Complex a = 1 + 2i, b = 3i;
static int _Complex twice(int _Complex z) { return z + z; }
int main(void) {
    int _Complex z = 3 + 4i, w = 1 - 2i;
    int _Complex s = z + w, d = z - w, m = z * w, q = z / w;
    printf("%d %d %d %d %d %d %d %d\n", __real__ s, __imag__ s, __real__ d, __imag__ d, __real__ m, __imag__ m, __real__ q, __imag__ q);
    printf("%d %d %d %d %d %d\n", __real__ a, __imag__ a, __real__ b, __imag__ b, z == w, z != z);
    double _Complex dz = z;
    int _Complex back = 2.5 + 1.5i;
    printf("%.1f %.1f %d %d %d %d\n", __real__ dz, __imag__ dz, __real__ back, __imag__ back, (int) sizeof(z), (int) z);
    int _Complex n = -z;
    unsigned _Complex u = 7u + 3i;
    u = u / (2 + 0i);
    long _Complex L = 5l + 6li;
    L = L * L;
    printf("%d %d %u %u %ld %ld %d\n", __real__ n, __imag__ n, __real__ u, __imag__ u, __real__ L, __imag__ L, (int) sizeof(L));
    int _Complex t = twice(z);
    __real__ t = 10; __imag__ t += 1;
    printf("%d %d %d\n", __real__ t, __imag__ t, (int) (t == (10 + 9i)));
    return 0;
}
