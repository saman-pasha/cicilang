/* A LIST LITERAL MAKES NO BITSET (0.286): a literal's slots have the type of the instance's first argument, and a
   bitset's is the count of its bits, no type. A number or a text of 0 and 1 makes one */
#include <stdio.h>
#include <bitset.pl>
int main(void) {
    bitset<8> b = [1, 0, 1];
    printf("%zu\n", count(b));
    return 0;
}
