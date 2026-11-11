/* refused: a walk of an unordered_set goes one way, as C++'s forward iterator does (0.283) */
#include <stdio.h>
#include <unordered_set.pl>
int main(void) {
    unordered_set<int> s = [1, 2];
    printf("%zu\n", prev(s, 0));
    return 0;
}
