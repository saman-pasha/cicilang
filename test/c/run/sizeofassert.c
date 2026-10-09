/* A static assertion over the size and the alignment of a struct, which the reader folds where it stands: the answer is
   one, the first, and not the alternatives behind it (0.117; a test that backtracks met a zero after the sixteen). */
#include <stddef.h>
#include <stdio.h>

typedef struct { char c; long v; } T;
_Static_assert(sizeof(T) == 16, "typedef struct");
_Static_assert(_Alignof(T) == 8, "its alignment");
struct U { char c; long v; };
_Static_assert(sizeof(struct U) == 16 && offsetof(struct U, v) == 8, "tag");
struct S { int a; int b; short c; };
_Static_assert(sizeof(struct S) == 12, "padding");
union V { char c[5]; int i; };
_Static_assert(sizeof(union V) == 8 && _Alignof(union V) == 4, "union");
struct X { char c; long double ld; };
_Static_assert(sizeof(struct X) == 32 && _Alignof(struct X) == 16, "long double");
struct B { unsigned a : 3; unsigned b : 5; short s; int c; };
_Static_assert(sizeof(struct B) == 8, "bitfields");
struct F { int n; int d[]; };
_Static_assert(sizeof(struct F) == 4, "flexible");
_Static_assert(sizeof(T[3]) == 48, "array of structs");
_Static_assert(sizeof(T *) == 8, "pointer");
_Static_assert(sizeof(T) > 0 && sizeof(T) != 0 && sizeof(T) >= 16 && sizeof(T) < 17, "comparisons");
char buf[sizeof(struct S)];
_Static_assert(sizeof(buf) == 12, "array bound from sizeof");

int main(void) {
    printf("%d %d %d %d %d\n", (int)sizeof(T), (int)sizeof(struct S), (int)sizeof(union V), (int)sizeof(struct X), (int)sizeof(buf));
    return 0;
}
