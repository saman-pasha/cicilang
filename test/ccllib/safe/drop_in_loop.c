// A vector that a for declares, dropped at the end of each pass and pushed to again in the next (1.6.19): the drop
// frees its buffer, and the next pass pushes into it -- refused in the second pass, which the check walks since 1.6.19
#include <vector.pl>
typedef struct holder { vector<int> items; int n; } holder;
int main(void) {
    int t = 0;
    for (holder h; t < 3; t++) { push_back(h.items, t); t += (int)len(h.items); vector_int_drop(&h.items); }
    return t;
}
