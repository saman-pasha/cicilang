/* A CALL BY NAME'S COUNT OF ARGUMENTS (0.288): the reader check k161 -- a call with another count of arguments than
   its function takes is refused by name; it was made with the arguments that it had */
#include <stdlib.h>
#include <string.h>
#include "run/tnames.pl"
int main(void) {
    text<char> a = "ab";
    text<char> b = "cd";
    insert(a, b);
    return 0;
}
