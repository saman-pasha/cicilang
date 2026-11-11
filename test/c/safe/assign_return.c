/* THE VALUE OF AN ASSIGNMENT OVER AN OBJECT THAT ITS SCOPE DROPS IS NOT TAKEN (0.287): given back, the caller holds
   the buffer that the function's end frees */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
static vector<int> make(int n) { vector<int> r; for (int i = 0; i < n; i++) push(r, i); return r; }
static vector<int> twice(void) {
    vector<int> a;
    return a = make(3);
}
int main(void) {
    vector<int> b = twice();
    return (int)len(b);
}
