/* A BORROW OF AN OUTER OWN ARRAY STORED IN A BLOCK'S ARRAY OF ITS NAME (1.6.33): a block's plain array holds no
   borrow that the check follows, and the words name the outer array by its own name */
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    own int *arr[2] = { NULL, NULL };
    arr[0] = malloc(sizeof(int)); if (!arr[0]) return 1; *arr[0] = 5;
    int *e = arr[0];
    { int *arr[2] = { e, e }; printf("%d\n", *arr[1]); }
    return 0;
}
