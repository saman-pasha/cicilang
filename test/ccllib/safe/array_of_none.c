/* <array.pl>: C has no array of no element (0.275) */
#include <array.pl>
int main(void) {
    array<int, 0> z;
    return (int)size(z);
}
