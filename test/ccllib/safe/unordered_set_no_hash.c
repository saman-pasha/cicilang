/* refused: a struct has no hash and no `==' of its own, so its type names the two functions (0.283) */
#include <unordered_set.pl>
typedef struct point { int x, y; } point;
int main(void) {
    unordered_set<point> s;
    insert(s, (point){1, 2});
    return 0;
}
