/* refused: a deque has no begin, end or data -- a ring is not one run of memory; a loop goes by the index (0.276) */
#include <stdio.h>
#include <deque.pl>
int main(void) {
    deque<int> d;
    push_back(d, 1);
    printf("%d\n", *begin(d));
    return 0;
}
