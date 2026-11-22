/* loop_unsettled.c (1.6.19): a loop whose walk does not settle in eight passes -- each pass gives each of eight own
   pointers what the one before it held, so the eighth first holds memory in the eighth pass, and the state changes in
   each of them: refused by name, where C runs it right */
#include <stdlib.h>
int main(void) {
    own char *a1 = NULL; own char *a2 = NULL; own char *a3 = NULL; own char *a4 = NULL;
    own char *a5 = NULL; own char *a6 = NULL; own char *a7 = NULL; own char *a8 = NULL;
    for (int i = 0; i < 20; i++) {
        free(a8); a8 = a7; a7 = a6; a6 = a5; a5 = a4; a4 = a3; a3 = a2; a2 = a1; a1 = malloc(4);
    }
    free(a1); free(a2); free(a3); free(a4); free(a5); free(a6); free(a7); free(a8);
    return 0;
}
