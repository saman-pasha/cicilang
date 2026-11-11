/* A NUMBER IS NO OPERAND OF A BITSET'S OPERATORS (0.286): `b == 5', which C++ takes through its constructor, is
   refused by name; `bitset<12> five = 5;' makes the set first */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<12> b = 5;
    printf("%d\n", b == 5);
    return 0;
}
