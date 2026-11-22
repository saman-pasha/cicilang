/* loop_pass_after.c (1.6.19): the path after a loop leaves from each pass's end -- b first holds memory at the second
   pass's end, and nothing frees it after the loop: refused at the return */
#include <stdlib.h>
int main(void) {
    own char *a = NULL;
    own char *b = NULL;
    for (int i = 0; i < 3; i++) {
        free(b);
        b = a;
        a = malloc(4);
    }
    free(a);
    return 0;
}
