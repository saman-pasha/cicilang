/* A BIT HAS NO ADDRESS (0.286): b[i] is the bit's value and b[i] = x writes it; a compound assignment of it is
   refused, where C++ makes it over a reference to the bit. set(b, i, x) and flip(b, i) are the calls */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<8> b = 3;
    b[1] |= 1;
    printf("%zu\n", count(b));
    return 0;
}
