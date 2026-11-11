/* <vector.pl>: an element with an owner in it -- a vector of vectors -- waits for the owner's rule on containers of
   owners (CCLLIB.md's open decision 2): the push_back of one is refused by the safe part, not taken and leaked (0.274) */
#include <stdio.h>
#include <vector.pl>
int main(void) {
    vector<vector<int>> vv;
    row := [int; 1, 2];
    push_back(vv, row);
    printf("%zu\n", size(vv));
    return 0;
}
