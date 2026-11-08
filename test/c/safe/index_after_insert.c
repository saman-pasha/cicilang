/* A RESULT TIED TO A STRUCT WITH OWN FIELDS IS A BORROW OF THEM (0.266): &m[3] over a dictionary is
   &*dict_int_int_index(&m, 3), tied to m, a place in m's buffer -- which the insertions' realloc may free, so p is not
   read after them */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../run/topers.pl"
int main(void) {
    dict<int, int> m = { 0 };
    m[3] = 30;
    int *p = &m[3];
    for (int i = 10; i < 20; i++) m[i] = i;
    printf("%d\n", *p);
    return 0;
}
