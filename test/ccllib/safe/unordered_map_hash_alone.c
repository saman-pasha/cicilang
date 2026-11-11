/* refused: a struct key with a hash's name and no equality's: C has no `==' of two structs (0.283) */
#include <unordered_map.pl>
typedef struct point { int x, y; } point;
static unsigned long point_hash(point p) { return (unsigned long)p.x * 31u + (unsigned long)p.y; }
int main(void) {
    unordered_map<point, int, point_hash> m;
    insert(m, (point){1, 2}, 3);
    return 0;
}
