/* OPERATORS ON INSTANCES, PART 2 (0.284): the reader check k153 -- b[1] is a value, so |= has nothing to change */
#include <stddef.h>
#include "run/topers2.pl"
int main(void) {
    bits<12> b = { 0 };
    b[1] |= 1;
    return 0;
}
