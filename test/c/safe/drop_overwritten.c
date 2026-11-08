/* AUTODROP (0.262): an object that may hold memory, given a new value: what it held would leak. push may fill the
   buffer that was null, so after it the buffer is live */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
static vector<int> make(int n) { vector<int> r; for (int i = 0; i < n; i++) push(r, i); return r; }
int main(void) {
    vector<int> a;
    push(a, 1);
    a = make(2);
    return (int)len(a);
}
