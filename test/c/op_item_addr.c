/* OPERATORS ON INSTANCES (0.286): the reader check k158 -- b[1] is a value, with no place of its own: its address is
   refused */
#include <stddef.h>
#include "run/topers2.pl"
int main(void) {
    bits<12> b = { 0 };
    int *p = &b[1];
    return *p;
}
