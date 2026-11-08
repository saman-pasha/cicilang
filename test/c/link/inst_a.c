#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
int fill(vector<int> *v, int n);
int main(void) {
    vector<int> v = { 0, 0, NULL };
    push(v, 7);
    int s = fill(&v, 4);
    printf("%zu %d %d\n", len(v), at(v, 0), s);
    free(v.data);
    return 0;
}
