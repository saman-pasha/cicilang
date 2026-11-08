/* AUTODROP (0.262): an owner inside an object that its scope drops, freed by hand: the drop would free it again */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
int main(void) {
    vector<int> a;
    push(a, 1);
    free(a.data);
    return 0;
}
