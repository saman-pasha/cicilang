/* LIST AND MAP LITERALS (0.263): the reader check k124 -- a map literal's types with a comma, where the owner's spelling is K:V */
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(void) {
    m := [int, double; 5: 1.25];
    return 0;
}
