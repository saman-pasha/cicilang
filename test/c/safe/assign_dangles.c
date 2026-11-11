/* AN ASSIGNMENT OVER AN OBJECT THAT ITS SCOPE DROPS (0.287) drops the old value: a borrow of the old buffer, used
   after the assignment, reads freed memory */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
static vector<int> make(int n) { vector<int> r; for (int i = 0; i < n; i++) push(r, i); return r; }
int main(void) {
    vector<int> a = make(3);
    const int *p = &a.data[1];
    a = make(2);
    return *p;
}
