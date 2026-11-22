/* lj_incomplete.c (1.6.17): a longjmp out of a function that freed its borrowed struct's own field: the caller's struct is
   left with a freed field -- refused at the jump, as at a return */
#include <setjmp.h>
#include <stdlib.h>
static jmp_buf env;
struct box { own char *data; };
static void drop_and_jump(struct box *b) { free(b->data); longjmp(env, 1); }
int main(void) {
    struct box b;
    b.data = malloc(4);
    if (setjmp(env)) { free(b.data); return 1; }
    drop_and_jump(&b);
    free(b.data);
    return 0;
}
