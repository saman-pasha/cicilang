/* A macro's C text whose first function calls the second (1.1.2): it builds, where the program's own file may not call
   a function before a declaration of it */
#include <stdio.h>
#include "textorder.pl"
scaled_pair(2);
int main(void) {
    printf("%d %d\n", textorder_first(3), textorder_second(5));
    return 0;
}
