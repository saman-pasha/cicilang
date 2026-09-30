/* the floating literals: hex floats, a leading dot, and the suffixes as the types they name (0.108) */
#include <stdio.h>
#define KIND(x) _Generic((x), float: "float", double: "double", long double: "long double", default: "other")
float fg = 1.5f;
float fh = 2;
double dg = .125;
double hx = 0x1.8p1;
int main(void) {
    printf("%.4f %.4f %.4f %.4f\n", 0x1.8p1, 0x.8p-2, 0X1P3, 0x1.fffffffffffffp1023 / 1e308);
    printf("%.4f %.4f %.4Lf\n", .25e1f, .5, .5L);
    printf("%s %s %s %s\n", KIND(1.5f), KIND(1.5), KIND(1.5L), KIND(0x1p+2f));
    printf("%zu %zu %zu\n", sizeof(1.0f), sizeof(1.0), sizeof(0xA.Bp-1L));
    printf("%.3f %.3f %.3f %.3f\n", fg, fh, dg, hx);
    float f = 1.0f / 3;
    printf("%.9f\n", f);
    return 0;
}
