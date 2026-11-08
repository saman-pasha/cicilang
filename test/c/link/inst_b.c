#include <stdlib.h>
#include "../run/tvector.pl"
int fill(vector<int> *v, int n) {
    int s = 0;
    for (int i = 0; i < n; i++) { push(*v, i); s += at(*v, len(*v) - 1); }
    return s;
}
