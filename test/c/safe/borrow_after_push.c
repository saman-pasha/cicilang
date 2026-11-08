/* A CALL THAT MAY REPLACE A STRUCT'S OWN FIELDS ENDS THE BORROWS OF THEM (0.265): push over a vector<int> is
   vector_int_push(&v, 1), which may realloc the buffer, so p is not read after it -- iterator invalidation */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
int main(void) {
    vector<int> v = [int; 5, 3, 9];
    int *p = v.data;
    push(v, 1);
    printf("%d\n", *p);
    return 0;
}
