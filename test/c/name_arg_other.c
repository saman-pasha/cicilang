/* A CALL BY NAME'S ARGUMENT (0.288): the reader check k161 -- an object of another instance where the function takes a
   pointer to the instance is refused by name */
#include <stdlib.h>
#include <string.h>
#include "run/tnames.pl"
#include "run/lazy.pl"
int main(void) {
    text<char> a = "ab";
    stack<int> s;
    append(a, s);
    return 0;
}
