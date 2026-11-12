/* <tuple.pl>: a tuple's element is a value with no pointer in it, as a container's element is (CCLLIB.md's open
   decision 2): a tuple of a pointer is refused where its type is written (0.305) */
#include <tuple.pl>
int main(void) {
    int x = 1;
    tuple<int, int *> t = {1, &x};
    return get<0>(t) == 1 ? 0 : 1;
}
