/* loop_pass_leak.c (1.6.19): a loop that gives a pointer new memory in each pass -- the second pass leaves the first
   pass's memory, which nothing frees: refused in the second pass, where the first walk saw a null */
#include <stdlib.h>
int main(void) {
    char *p = NULL;
    for (int i = 0; i < 3; i++) p = malloc(4);
    free(p);
    return 0;
}
