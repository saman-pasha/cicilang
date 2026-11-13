/* <variant.pl>: get_if gives a place in the variant, tied to it: its address does not leave the function that holds
   the variant (0.308) */
#include <variant.pl>
static int *first(void) {
    variant<int, double> v = 1;
    return get_if<int>(&v);
}
int main(void) {
    return *first();
}
