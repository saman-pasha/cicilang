/* OPERATORS ON INSTANCES (0.266): the reader check k139 -- + over a pointer to a point is C's pointer arithmetic, and ==
   and > over two pointers C's comparisons; + over ints stays C's */
#include <stdio.h>
#include "run/topers.pl"
int main(void) {
    pt<double> arr[2] = { { 1, 2 }, { 3, 4 } };
    pt<double> *pp = arr;
    pt<double> *pq = pp + 1;
    int k = 2 + 3;
    printf("%g %d %d %d\n", pq->x, pq == pp + 1, pq > pp, k);
    return 0;
}
