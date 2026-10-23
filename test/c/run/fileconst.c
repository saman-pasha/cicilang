/* A file-scope `const' integer with a constant initializer is a constant where C17 folds one, as clang folds it (GNU's
   folding): an array's bound at file scope and in a block, an enumerator, a bit-field's width, `_Static_assert', a case
   label; its value converted to its type; one of the program's own header; a local or a parameter of its name shadows
   it; its address is the object's (0.195) */
#include <stdio.h>
#include "fileconst.h"
const int K = 8;
const int M = K * 4 + 1;
const unsigned char C = 300;
enum { E = K + 1, F, EH = H * 2 };
struct S { unsigned b : K; int a[K]; };
_Static_assert(M == 33, "M");
int arr[K];
char cb[C];
int harr[H];
static int twice_of(const int K) { int a[K]; return (int) sizeof a; }
static int shadowed(void) { const int K = 3; int a[K]; return (int) sizeof a; }
static int after(void) { int a[K]; return (int) sizeof a; }
int main(void) {
    int loc[M];
    const int *p = &K;
    switch (8) { case K: puts("case"); break; default: break; }
    printf("%zu %zu %zu %zu %d %d\n", sizeof arr, sizeof cb, sizeof loc, sizeof(struct S), E, F);
    printf("%d %d %d %d %d\n", twice_of(2), shadowed(), after(), *p, (int) C);
    printf("%zu %d\n", sizeof harr, EH);
    return 0;
}
