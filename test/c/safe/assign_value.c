/* THE VALUE OF AN ASSIGNMENT OVER AN OBJECT THAT ITS SCOPE DROPS IS NOT TAKEN (0.287): `b = a = make(3)' copies a
   whole, so two objects hold one buffer and each scope's end frees it. Until 0.287 the check said nothing, and the
   program freed the buffer twice */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
static vector<int> make(int n) { vector<int> r; for (int i = 0; i < n; i++) push(r, i); return r; }
int main(void) {
    vector<int> a;
    vector<int> b;
    b = a = make(3);
    return (int)(len(a) + len(b));
}
