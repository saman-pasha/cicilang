/* A CALL BY NAME'S ARGUMENT (0.288): the reader check k161 -- a C text where the function takes a pointer to the
   instance, and the type macro has no form for a text, is refused by name; the function read the text's bytes as its
   object's */
#include "run/lazy.pl"
int main(void) {
    stack<int> s;
    return eq(s, "x");
}
