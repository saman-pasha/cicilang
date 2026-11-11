/* A BITSET HAS NO ORDER (0.286): `==' and `!=' compare two, and `<' is refused, as C++ refuses it */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<8> a = 3, b = 5;
    printf("%d\n", a < b);
    return 0;
}
