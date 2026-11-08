/* LIST AND MAP LITERALS (0.263): the reader check k124 -- a literal as a variadic argument */
#include <stdio.h>
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(void) {
    printf("%d", [1, 2]);
    return 0;
}
