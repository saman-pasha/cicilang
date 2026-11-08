/* LIST AND MAP LITERALS (0.263): the reader check k124 -- a floating element in an int literal narrows */
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(void) {
    vector<int> a = [int; 1, 1.5];
    return 0;
}
