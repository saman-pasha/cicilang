/* LIST AND MAP LITERALS (0.263): the reader check k124 -- two equal constant keys */
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(void) {
    m := [1: 2, 1: 3];
    return 0;
}
