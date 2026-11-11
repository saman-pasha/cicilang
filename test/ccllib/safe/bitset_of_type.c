/* A BITSET TAKES THE COUNT OF ITS BITS (0.286), a number: a type in its place is refused by name */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<int> b;
    printf("%zu\n", count(b));
    return 0;
}
