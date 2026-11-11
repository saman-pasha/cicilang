/* refused: a multimap has no at and no index, as C++'s has none -- a key may have several values (0.281) */
#include <stdio.h>
#include <map.pl>
int main(void) {
    multimap<int, int> m;
    insert(m, 1, 2);
    printf("%d\n", at(m, 1));
    return 0;
}
