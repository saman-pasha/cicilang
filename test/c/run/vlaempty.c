/* C23 6.7.10: an array of variable length takes one initializer, the empty one, and every element is zero. */
#include <stdio.h>
#include <string.h>

/* leaves 0x55 on the stack below its caller, where the next frames' arrays will lie */
static void dirty(int n) {
    volatile unsigned char b[512];
    memset((void *)b, 0x55, sizeof b);
    (void)n;
}
static long total(int n) {
    int a[n] = {};
    long s = 0;
    for (int i = 0; i < n; i++) s += a[i] + i;
    return s;
}
static long grid(int r, int c) {
    long g[r][c] = {};
    long s = 0;
    for (int i = 0; i < r; i++)
        for (int j = 0; j < c; j++) s += g[i][j] + 1;
    return s;
}
static double reals(int n) {
    double d[n] = {};
    double s = 0;
    for (int i = 0; i < n; i++) s += d[i];
    return s + sizeof d;
}
int main(int argc, char **argv) {
    (void)argv;
    dirty(argc);
    printf("%ld\n", total(argc + 5));
    dirty(argc);
    printf("%ld\n", grid(argc + 1, 3));
    dirty(argc);
    printf("%g\n", reals(argc + 2));
    return 0;
}
