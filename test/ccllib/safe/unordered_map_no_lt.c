/* refused: two unordered maps have `==' and no `<', as C++'s have none: a table has no order (0.283) */
#include <stdio.h>
#include <unordered_map.pl>
int main(void) {
    unordered_map<int, int> a = [1: 2];
    unordered_map<int, int> b = [1: 3];
    printf("%d\n", a < b);
    return 0;
}
