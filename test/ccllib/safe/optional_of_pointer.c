/* <optional.pl>: an optional's value is a value with no pointer in it, as a container's element is (CCLLIB.md's open
   decision 2): an optional of a pointer is refused where its type is written (0.300) */
#include <optional.pl>
int main(void) {
    int x = 1;
    optional<int *> o = &x;
    return has_value(o) ? 0 : 1;
}
