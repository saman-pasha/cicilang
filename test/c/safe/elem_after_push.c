/* AN ELEMENT'S ADDRESS IS A BORROW OF THE BUFFER (0.265): &v.data[1] borrows v.data, so it dangles after push too */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
int main(void) {
    vector<int> v = [int; 5, 3, 9];
    int *p = &v.data[1];
    push(v, 1);
    printf("%d\n", *p);
    return 0;
}
