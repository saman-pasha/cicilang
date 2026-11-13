/* AN OWN ARRAY'S STORE FREES WITH THE C LIBRARY'S FREE, WHICH THE LOWERING DECLARES WHERE THE PROGRAM DECLARES NONE
   (0.307): a file of <stdio.h> and <string.h> alone, its own array of strings from strdup, each store freeing the old
   one -- an own array of FILE pointers in such a file was `not lowered yet: undeclared(free)', with no line. The last
   strings stay in the array, which lives to the end of the run: valgrind finds nothing lost */
#include <stdio.h>
#include <string.h>
static own char *names[2];
int main(void) {
    names[0] = strdup("first");
    names[0] = strdup("second");
    names[1] = strdup("third");
    printf("%s %s\n", names[0] ? names[0] : "-", names[1] ? names[1] : "-");
    return 0;
}
