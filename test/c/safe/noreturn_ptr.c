/* noreturn_ptr.c (1.6.15): a call through a pointer to a function that does not return goes on: the pointer's type is
   its declaration's, and `void (*f)(int)' names no such mark, as clang has it -- new memory still live after the call
   is refused at main's return */
#include <stdlib.h>
int main(void) {
    void (*f)(int) = exit;
    char *p = malloc(4);
    if (!p) return 1;
    p[0] = 1;
    f(3);
    return 0;
}
