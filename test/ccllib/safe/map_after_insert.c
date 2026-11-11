/* refused: &m[1] is a borrow of the map's arena, and a write to another key may replace the arena (0.281) */
#include <stdio.h>
#include <map.pl>
int main(void) {
    map<int, long> m;
    m[1] = 10;
    long *v = &m[1];
    m[2] = 20;
    printf("%ld\n", *v);
    return 0;
}
