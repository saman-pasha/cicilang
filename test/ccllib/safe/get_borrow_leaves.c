/* <tuple.pl>: get<I>(t) is a place in t, tied to it: its address does not leave the function that holds t (0.305) */
#include <tuple.pl>
static int *first(void) {
    tuple<int, int> t = {1, 2};
    return &get<0>(t);
}
int main(void) {
    return *first();
}
