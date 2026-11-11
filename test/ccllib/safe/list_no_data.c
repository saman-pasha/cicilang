/* refused: a list has no data and no capacity -- its elements are not one run of memory (0.277) */
#include <stdio.h>
#include <list.pl>
int main(void) {
    list<int> l;
    push_back(l, 1);
    printf("%d\n", *data(l));
    return 0;
}
