/* loop_settled7.c (1.6.19): the same loop over seven own pointers settles in eight passes, and is taken */
#include <stdlib.h>
int main(void) {
    own char *a1 = NULL; own char *a2 = NULL; own char *a3 = NULL; own char *a4 = NULL;
    own char *a5 = NULL; own char *a6 = NULL; own char *a7 = NULL;
    for (int i = 0; i < 20; i++) {
        free(a7); a7 = a6; a6 = a5; a5 = a4; a4 = a3; a3 = a2; a2 = a1; a1 = malloc(4);
    }
    free(a1); free(a2); free(a3); free(a4); free(a5); free(a6); free(a7);
    return 0;
}
