/* THE VALUE OF AN ASSIGNMENT OVER AN OBJECT THAT ITS SCOPE DROPS IS NOT TAKEN (0.287): handed to a parameter by value,
   the callee drops it and the scope drops it again */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
static vector<int> make(int n) { vector<int> r; for (int i = 0; i < n; i++) push(r, i); return r; }
static size_t eat(vector<int> v) { return len(v); }
int main(void) {
    vector<int> a;
    return (int)eat(a = make(3));
}
