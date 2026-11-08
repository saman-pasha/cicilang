/* AUTODROP (0.262): an object that its scope drops, dropped by hand, would be dropped twice */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
int main(void) {
    vector<int> a;
    push(a, 1);
    vector_int_drop(&a);
    return 0;
}
