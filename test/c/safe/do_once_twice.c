/* do_once_twice.c (1.6.18): a do-while(0) runs its body once, so the path after it holds what the body left -- an own
   pointer freed in it and freed again after it: refused, the double free */
#include <stdlib.h>
int main(void) {
    own char *p = malloc(4);
    do { free(p); } while (0);
    free(p);
    return 0;
}
