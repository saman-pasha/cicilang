/* <array.pl>: &a[0] is a borrow of the array, tied to it; it does not leave the function that holds the array (0.275) */
#include <array.pl>
static int *first(void) {
    array<int, 2> a = [1, 2];
    return &a[0];
}
int main(void) { return *first(); }
