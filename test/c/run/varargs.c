#include <stdio.h>
#include <stdarg.h>
static int sum(int n, ...) {
    va_list ap; va_start(ap, n);
    int s = 0;
    for (int i = 0; i < n; i++) s += va_arg(ap, int);
    va_end(ap);
    return s;
}
static double dsum(int n, ...) {
    va_list ap, aq; va_start(ap, n); va_copy(aq, ap);
    double s = 0;
    for (int i = 0; i < n; i++) s += va_arg(ap, double);
    for (int i = 0; i < n; i++) s += va_arg(aq, double);
    va_end(aq); va_end(ap);
    return s;
}
static void say(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
}
static long mix(int n, ...) {
    va_list ap; va_start(ap, n);
    long s = 0;
    for (int i = 0; i < n; i++) { char *p = va_arg(ap, char *); long v = va_arg(ap, long); s += v * (p[0] - 'a' + 1); }
    va_end(ap);
    return s;
}
int main(void) {
    printf("%d\n", sum(4, 1, 2, 3, 4));
    printf("%d\n", sum(10, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10));
    printf("%.2f\n", dsum(3, 1.5, 2.5, 3.0));
    printf("%.2f\n", dsum(10, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0));
    say("%s-%d-%.1f\n", "x", 7, 2.5);
    printf("%ld\n", mix(3, "a", 10L, "b", 20L, "c", 30L));
    printf("%zu\n", sizeof(va_list));
    return 0;
}
