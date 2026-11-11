/* A NULL TEST REFINES A PLAIN POINTER THAT HOLDS NEW MEMORY, AND THE OTHER PATH STILL OWES IT (0.290): where the test's
   two paths join, null on one and loose on the other is loose, so the block that is never freed is still refused */
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    char *p = malloc(8);
    if (!p) puts("none");
    return 0;
}
