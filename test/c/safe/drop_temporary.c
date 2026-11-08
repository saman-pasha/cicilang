/* AUTODROP (0.262): a call's value whose type has a drop, thrown away: nothing drops a temporary yet, so it would leak */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
static vector<int> make(int n) { vector<int> r; for (int i = 0; i < n; i++) push(r, i); return r; }
int main(void) {
    make(4);
    return 0;
}
