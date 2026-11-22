/* loop_pass_three.c (1.6.19): a loop whose third pass writes over an owner that the second pass gave memory -- b takes
   a's memory and a takes new memory in each pass, so in the third b still holds the first pass's memory, which nothing
   frees: refused there, where the walk's state settles */
#include <stdlib.h>
int main(void) {
    own char *a = NULL;
    own char *b = NULL;
    for (int i = 0; i < 3; i++) {
        b = a;
        a = malloc(4);
    }
    free(a);
    free(b);
    return 0;
}
