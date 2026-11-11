/* TWO BITSETS OF TWO COUNTS ARE TWO TYPES (0.286): `a & b' over them is refused, as C++ refuses it */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<8> a = 3;
    bitset<12> b = 5;
    bitset<8> c = a & b;
    printf("%zu\n", count(c));
    return 0;
}
