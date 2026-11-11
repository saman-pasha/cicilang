/* A BIT HAS NO ADDRESS (0.286): `&b[i]' is refused */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<8> b = 3;
    int *p = &b[1];
    printf("%d\n", *p);
    return 0;
}
