/* LIST AND MAP LITERALS (0.263): the reader check k124 -- a long variable in an int literal narrows */
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(void) {
    long n = 5; vector<int> a = [n];
    return 0;
}
