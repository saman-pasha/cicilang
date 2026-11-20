#include <stdio.h>
static int seven(void) { return 7; }
int main(void) {
    int k = 3, a[3] = { 1, 2, 3 };
    char c = 2;
    int *p = &a[0], *q = &a[2];
    long x = q - p;
    printf("%ld\n", x);
    printf("%d %d %d\n", *(p + 1), *(1 + p), *(q - 1));
    printf("%d\n", k << c);
    printf("%d %d %d\n", !p, p && q, p < q);
    int *r = p;
    r += 2;
    r -= 1;
    printf("%d\n", *r);
    k <<= 2;
    k %= 5;
    k |= 8;
    k ^= 1;
    k &= 13;
    printf("%d\n", k);
    double d = 2.5;
    d *= 2;
    d /= 4;
    printf("%g\n", d);
    printf("%d %d %d\n", +c, -c, ~c);
    printf("%zu %zu %zu\n", sizeof(+c), sizeof(-c), sizeof(~c));
    int (*fp)(void) = seven;
    printf("%d\n", fp());
    return 0;
}
