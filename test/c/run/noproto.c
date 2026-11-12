/* Calls that C17 takes without a prototype, and the null pointer constants (0.302): an empty list `()' declares no
   prototype before C23, so a call of such a function or through such a pointer may take any arguments, and a K&R
   definition takes its own count; an integer constant expression of 0 is a null pointer constant wherever a pointer is
   wanted, and a pointer converts to _Bool. Each was accepted before and stays so, where a prototype's count and an
   integer for a pointer are refused now. clang -std=c17 builds it with four warnings of deprecation, and one of the
   null pointer constant `1 - 1', and both print the same lines */
#include <stdio.h>
#include <stddef.h>
extern int legacy();
static int twice(a) int a; { return a * 2; }
static int none() { return 4; }
static int is_null(const char *p) { return p == 0; }
static int truth(_Bool b) { return b; }
static int add(int a, int b) { return a + b; }
int main(void) {
    int (*loose)() = add;
    int (*fixed)(int, int) = add;
    const char *text = "x";
    printf("%d %d %d %d %d\n", legacy(1, 2), twice(21), none(), loose(3, 4), fixed(5, 6));
    printf("%d %d %d %d %d %d\n", is_null(0), is_null(1 - 1), is_null((void *)0), is_null(NULL), is_null(0L), is_null(text));
    printf("%d %d\n", truth(text), truth(0));
    printf("%d %d %d\n", __builtin_types_compatible_p(int (*)(), int (*)(int)), __builtin_types_compatible_p(int (*)(), int (*)(void)),
           __builtin_types_compatible_p(int (*)(), int (*)(char)));
    return 0;
}
int legacy(int a, int b) { return a * 10 + b; }
