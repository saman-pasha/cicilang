/* <array.pl>: an element that is a pointer is refused where the type is written, as a vector's is (0.275) */
#include <array.pl>
int main(void) {
    array<const char *, 2> names;
    return (int)size(names);
}
