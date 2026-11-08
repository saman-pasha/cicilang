/* AUTODROP (0.262): an object that its scope drops, copied whole where the reader does not move it -- a statement
   expression's value -- would be dropped twice, the copy and the object */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
int main(void) {
    vector<int> a;
    push(a, 1);
    vector<int> c = ({ a; });
    return (int)len(c);
}
