/* GNU's 128-bit integers: `__int128', `unsigned __int128', `__int128_t' and `__uint128_t' are LLVM's i128, sixteen bytes
   aligned sixteen -- arithmetic, shifts, division, conversions, structs, globals, variable arguments. */
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

typedef __int128 i128;
typedef unsigned __int128 u128;

struct W { char c; __int128 v; };
i128 g1 = 5;
u128 g2 = (u128)1 << 100;
u128 g3 = ((u128)0xFFFFFFFFFFFFFFFFULL << 64) | 0x0123456789ABCDEFULL;
_Static_assert(sizeof(__int128) == 16, "size");
_Static_assert(_Alignof(__int128) == 16, "align");
_Static_assert(sizeof(struct W) == 32, "struct");
_Static_assert(sizeof(__uint128_t) == 16 && sizeof(__int128_t) == 16, "typedefs");

static void show(u128 v) {
    char b[48];
    int n = 0;
    if (!v) b[n++] = '0';
    while (v) { b[n++] = (char)('0' + (int)(v % 10)); v /= 10; }
    while (n) putchar(b[--n]);
    putchar('\n');
}
static void hex(u128 v) { printf("%016llx%016llx\n", (unsigned long long)(v >> 64), (unsigned long long)v); }
static i128 mul(i128 a, i128 b) { return a * b; }
static u128 fact(int n) { return n <= 1 ? 1 : (u128)n * fact(n - 1); }
static i128 sum(int n, ...) {
    va_list ap;
    va_start(ap, n);
    i128 s = 0;
    for (int i = 0; i < n; i++) s += va_arg(ap, i128);
    va_end(ap);
    return s;
}
/* six integer arguments and then an __int128: it needs two registers, one is free, so it goes on the stack */
static long mixed(long a, long b, long c, long d, long e, i128 x, long f) { return a + b + c + d + e + f + (long)(x >> 70); }

int main(int argc, char **argv) {
    (void)argv;
    u128 x = 1;
    for (int i = 0; i < 100; i++) x *= 3;
    show(x);
    show(fact(30));
    show(g2);
    hex(g3);
    i128 y = -(i128)1 << 100;
    printf("%d %d %d\n", (int)sizeof(i128), (int)(y < 0), (int)(y >> 120));
    printf("%lld\n", (long long)(mul(1000000007LL, 998244353LL) >> 3));
    __uint128_t z = (__uint128_t)0xFFFFFFFFFFFFFFFFULL * 0xFFFFFFFFFFFFFFFFULL;
    hex(z);
    struct W w = { 1, g1 };
    printf("%d %d %d\n", (int)sizeof(w), (int)(sizeof(w) - sizeof(w.v)), (int)w.v);
    i128 a = sum(3, (i128)1 << 90, (i128)-5, (i128)(argc + 7));
    printf("%d %llx %d\n", (int)(a < 0), (unsigned long long)(a >> 64), (int)(a & 0xFFFF));
    printf("%.6g %.6g\n", (double)a, (double)(u128)a);
    i128 e = (i128)1e30;
    show((u128)e);
    printf("%g\n", (double)(e / 1000000007));
    uint64_t lo = 3, hi = 5;
    u128 q = ((u128)hi << 64) | lo;
    printf("%llu %llu %d\n", (unsigned long long)(q >> 64), (unsigned long long)q, (int)(q > (u128)hi));
    printf("%ld\n", mixed(1, 2, 3, 4, 5, (i128)1 << 72, 6));
    printf("%d %d\n", (int)(q % 7), (int)((i128)-q % 7));
#ifdef __SIZEOF_INT128__
    printf("have %d\n", __SIZEOF_INT128__);
#endif
    return 0;
}
