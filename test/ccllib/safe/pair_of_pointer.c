/* <pair.pl>: a pair's member is a value with no pointer in it, as a container's element is (CCLLIB.md's open
   decision 2): a pair of a pointer is refused where its type is written (0.301) */
#include <pair.pl>
int main(void) {
    int x = 1;
    pair<int *, int> p = {&x, 2};
    return p.second == 2 ? 0 : 1;
}
