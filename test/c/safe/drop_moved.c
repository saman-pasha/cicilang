/* AUTODROP (0.262): an object used after it moved -- its address handed to a function -- is refused: the move left it
   empty, and the safe part takes it as gone until it is given a value again */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
int main(void) {
    vector<int> a;
    push(a, 1);
    vector<int> c = a;
    push(a, 3);
    return (int)len(c);
}
