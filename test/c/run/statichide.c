/* NAMES THAT A LOCAL SHARES WITH AN OWN ARRAY (0.307): a local array of another type under the name of an own array at
   file scope, or of a local own array, is the local's -- its elements plain slots --, and a function whose local hides
   the name writes no element of the file's array: a local int array, a local array of pointers that holds a local's
   address, a block's array of pointers under the file's array's name, a function whose local hides the name called
   while a borrow of the file's array is kept, an int result read through the file's array, and a block's array under
   a local own array's name. Valgrind finds no error and nothing lost */
#include <stdio.h>
#include <stdlib.h>
typedef struct thing { int v; } thing;
static own thing *make(int v) {
    own thing *t = malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
static int sum(void) { int slot[2]; slot[0] = 1; slot[1] = 2; return slot[0] + slot[1]; }
static int first(void) { thing x = { 5 }; thing *slot[1]; slot[0] = &x; return slot[0]->v; }
static int fill(void) { int slot[2]; slot[0] = 3; return slot[0]; }
static int firstv(void) { return slot[0] ? slot[0]->v : 0; }
static int local_own(void) {
    own thing *C[2] = {0};
    C[0] = make(8);
    {
        thing x = { 6 };
        thing *C[1];
        C[0] = &x;
        printf("inner %d\n", C[0]->v);
    }
    return C[0] ? C[0]->v : 0;
}
int main(void) {
    slot[0] = make(4);
    {
        thing x = { 7 };
        thing *slot[1];
        slot[0] = &x;
        printf("block %d\n", slot[0]->v);
    }
    thing *b = slot[0];
    printf("sum %d, first %d\n", sum(), first());
    int n = fill();
    printf("fill %d, kept %d, first value %d\n", n, b ? b->v : 0, firstv());
    printf("local own %d\n", local_own());
    free(slot[0]);
    return 0;
}
