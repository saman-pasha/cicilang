/* A CALL BY NAME'S ARGUMENT WHERE THE FUNCTION TAKES A POINTER TO THE INSTANCE (0.288): the reader check k161 -- what
   goes on as it is written: an object of the instance by its address, a pointer to the instance, the address of an
   object, a pointer to void, a null pointer constant, a conditional of two pointers */
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "run/tnames.pl"
int main(void) {
    text<char> a = "ab";
    text<char> b = "cd";
    text<char> *pb = &b;
    void *vp = &b;
    append(a, b);
    append(a, pb);
    append(a, &b);
    append(a, vp);
    insert(a, 1, a.len ? pb : &b);
    return find(a, pb) < 0;
}
