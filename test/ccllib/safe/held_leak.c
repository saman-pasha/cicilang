// A struct born zero that holds a vector, filled and never dropped (0.297): its own field leaks -- it was built over
// the struct's garbage, and the run faulted in the push
#include <vector.pl>
typedef struct holder { vector<int> items; int n; } holder;
int main(void) { holder h; push_back(h.items, 1); return (int)len(h.items); }
