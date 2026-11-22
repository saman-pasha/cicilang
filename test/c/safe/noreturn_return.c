/* noreturn_return.c (1.6.17): a return of a function declared not to return, refused at its line in clang's words */
#include <stdlib.h>
_Noreturn static void stop(int x) {
    if (x) {
        return;
    }
    exit(0);
}
int main(void) { stop(0); }
