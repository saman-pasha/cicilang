// A memset over a struct whose vector holds memory (0.297): the fill writes over the owner, and what it held is lost --
// it was a call that read the struct, and the buffer leaked
#include <stdio.h>
#include <string.h>
#include <vector.pl>
typedef struct holder { vector<int> items; int n; } holder;
int main(void) {
    holder h;
    push_back(h.items, 1);
    memset(&h, 0, sizeof h);
    printf("%zu\n", len(h.items));
    vector_int_drop(&h.items);
    return 0;
}
