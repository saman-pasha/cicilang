/* A BITSET HAS NO to_string YET (0.286): ccllib's string comes later, and the call is refused by name */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<8> b = 3;
    printf("%zu\n", to_string(b));
    return 0;
}
