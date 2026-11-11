/* AUTODROP (0.262, 0.287): an object that may hold memory, given a new value where no scope drops it -- a member of a
   plain struct: what it held would leak. push may fill the buffer that was null, so after it the buffer is live. An
   object that its scope drops, named by its name, is dropped first by its assignment since 0.287
   (test/c/run/dropassign.c) */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
struct two { vector<int> v; int n; };
static vector<int> make(int n) { vector<int> r; for (int i = 0; i < n; i++) push(r, i); return r; }
int main(void) {
    struct two s = { 0 };
    push(s.v, 1);
    s.v = make(2);
    int n = (int)len(s.v);
    vector_int_drop(&s.v);
    return n;
}
