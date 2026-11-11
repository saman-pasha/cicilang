/* refused: &m[1] is a borrow of the map's table, and a write to another key may make the table again (0.283) */
#include <stdio.h>
#include <unordered_map.pl>
int main(void) {
    unordered_map<int, long> m;
    m[1] = 10;
    long *v = &m[1];
    m[2] = 20;
    printf("%ld\n", *v);
    return 0;
}
