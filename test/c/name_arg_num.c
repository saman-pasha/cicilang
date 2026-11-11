/* A CALL BY NAME'S ARGUMENT (0.288): the reader check k161 -- a number where the function takes a pointer to the
   instance is refused by name; it was made a pointer with no message */
#include <stdlib.h>
#include <string.h>
#include "run/tnames.pl"
int main(void) {
    text<char> a = "ab";
    append(a, 5);
    return 0;
}
