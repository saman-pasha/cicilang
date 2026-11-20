// ownnames.cpp: the twin of ownnames.c over std::, where the program's own names are the global namespace's
#include <cstdio>
#include <functional>
#include <algorithm>
#include "ownhdr.h"
static unsigned hash(const char *s) { unsigned h = 0; while (*s) h = h * 31 + (unsigned char)*s++; return h; }
static int less(const char *a, const char *b) { return a[0] < b[0]; }
static int count_if(int a, int b, int c) { return a + b + c; }
static int sub(int a, int b) { return a - b; }
static int apply(int (*plus)(int, int), int x) { return plus(x, 1); }
int main() {
    const char *x = "abc";
    const char *p = "b", *q = "a";
    std::printf("%u %d\n", hash(x), less(p, q));
    std::printf("%d %d\n", greater(7, 3), count_if(1, 2, 3));
    std::printf("%d\n", apply(sub, 5));
    int (*minus)(int, int) = sub;
    std::printf("%d\n", minus(4, 9));
    { int (*modulus)(int, int) = sub; std::printf("%d\n", modulus(3, 1)); }
    std::printf("%d\n", std::modulus<int>()(7, 4));
    std::printf("%d %d %d\n", std::equal_to<int>()(2, 2), std::multiplies<int>()(6, 7), std::logical_not<int>()(0));
    return 0;
}
