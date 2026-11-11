/* refused: a set has no index -- its elements are found by their keys and walked by places (0.281) */
#include <stdio.h>
#include <set.pl>
int main(void) {
    set<int> s = [1, 2];
    printf("%d\n", s[1]);
    return 0;
}
