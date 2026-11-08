/* LIST AND MAP LITERALS (0.263): the reader check k124 -- the literal names other types than the declared type */
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(void) {
    vector<int> a = [double; 1.5];
    return 0;
}
