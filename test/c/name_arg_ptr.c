/* A CALL BY NAME'S ARGUMENT (0.288): the reader check k161 -- a pointer to another type where the function takes a
   pointer to the instance is refused by name */
#include <stdlib.h>
#include <string.h>
#include "run/tnames.pl"
int main(void) {
    text<char> a = "ab";
    long n = 5;
    append(a, &n);
    return 0;
}
