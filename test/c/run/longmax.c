#include <stdio.h>
#include <limits.h>
int main(void) {
    long a = LONG_MAX; long b = LONG_MIN;
    unsigned long c = ULONG_MAX;
    long long d = LLONG_MAX;
    printf("%ld %ld %lu %lld\n", a, b, c, d);
    printf("%ld\n", LONG_MAX - 1);
    return 0;
}
