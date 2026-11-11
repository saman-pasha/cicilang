/* refused: what stands after a map's two types is the NAME of the function that orders two keys, where C++ writes the
   comparison's type (0.281) */
#include <map.pl>
int main(void) {
    map<int, int, 3> m;
    insert(m, 1, 2);
    return 0;
}
