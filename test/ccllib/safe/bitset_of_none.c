/* A BITSET HAS ONE BIT AT LEAST (0.286): C++'s bitset<0> is an empty class; C has no struct of no member */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<0> b;
    printf("%zu\n", count(b));
    return 0;
}
