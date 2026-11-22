/* noreturn_end.c (1.6.17): the end of a function declared not to return, which a path reaches, refused in clang's words */
#include <stdlib.h>
__attribute__((noreturn)) static void stop(int x) {
    if (x)
        exit(1);
}
int main(void) { stop(1); }
