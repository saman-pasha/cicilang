/* C23's `constexpr' objects are named constants (6.6/7): at file scope an array's bound at file scope, in a block and in a
   struct, an enumerator, a bit-field's width, `static_assert', a case label, one constant over another, a `const' one
   beside them; in a block they are its own -- an array's bound, a static array's, `static_assert', an enumerator, a case
   label -- and leave with it, another block's of the name its own, a plain local of an inner block shadowing it (0.195) */
#include <stdio.h>
constexpr int K = 8;
constexpr long M = K * 4L;
constexpr unsigned char U = 255;
const int N = K + 2;
int arr[K];
struct S { int a[K]; unsigned b : K; };
static_assert(M == 32);
enum { E = K + 1 };
static int blk(int x) {
    constexpr int N = 4;
    int a[N];
    static int s[N];
    static_assert(N == 4);
    enum { EB = N + 1 };
    switch (x) { case N: return (int) (sizeof a + sizeof s) + EB; default: return -1; }
}
static int blk2(void) {
    constexpr int N = 7;
    int a[N];
    { int N = 2; int b[N]; return (int) (sizeof a * 100 + sizeof b); }
}
int main(void) {
    int loc[N];
    switch (8) { case K: puts("case"); break; default: break; }
    printf("%zu %zu %zu %d %ld %d\n", sizeof arr, sizeof loc, sizeof(struct S), E, M, U);
    printf("%d %d %zu\n", blk(4), blk2(), sizeof loc);
    return 0;
}
