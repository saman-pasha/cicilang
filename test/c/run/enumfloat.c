/* A floating constant under a cast to an integer type is an integer constant expression (C 6.6/6), and an enumerator
   that does not fold is no enumerator (0.160): `(int) 2.5L' and `(int) 9.5f' took the value after the one before them */
#include <stdio.h>

enum fl { A = 7, B = (int) 2.5L, C, D = (int) 9.5f, E = (int) -3.75L, F = (int) (2.5 + 1.0), G = (int) (1.5L * 4) };
enum : unsigned long long { W = 0xFFFFFFFFFFFFFFF0ULL, X, Y };   /* the next value past 2^60 is wide */
_Static_assert((int) 2.5L == 2, "a long double truncates toward zero");
_Static_assert((int) 9.5f == 9, "so does a float");
_Static_assert((long) 1e18L == 1000000000000000000L, "a long double holds 10^18 exactly");
static char bound[(int) 3.5L];

static const char *pick(int v) {
    switch (v) {
    case (int) 4.75L: return "four";
    case (int) 5.5f: return "five";
    default: return "other";
    }
}

int main(void) {
    printf("%d %d %d %d %d %d %d\n", A, B, C, D, E, F, G);
    printf("%llx %llx %llx\n", (unsigned long long) W, (unsigned long long) X, (unsigned long long) Y);
    printf("%zu %s %s %s\n", sizeof bound, pick(4), pick(5), pick(6));
    return 0;
}
