/* refused: an unordered_multimap has no at and no index, as C++'s has none -- a key may have several values (0.283) */
#include <stdio.h>
#include <unordered_map.pl>
int main(void) {
    unordered_multimap<int, int> m;
    insert(m, 1, 2);
    printf("%d\n", at(m, 1));
    return 0;
}
