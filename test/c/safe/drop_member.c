/* AUTODROP (0.262): a vector held as a member of a plain struct is not dropped with it (not done), and push filled its
   buffer: the buffer leaks at the scope's end, where the member is not dropped by hand */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
struct holder { vector<int> v; int k; };
int main(void) {
    struct holder s = { 0 };
    push(s.v, 1);
    printf("%zu\n", len(s.v));
    return 0;
}
