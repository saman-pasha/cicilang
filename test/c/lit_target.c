/* LIST AND MAP LITERALS (0.263): the reader check k124 -- a literal that initializes an int */
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(void) {
    int x = [1]; (void)x;
    return 0;
}
