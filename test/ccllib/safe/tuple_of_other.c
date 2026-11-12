/* <tuple.pl>: a tuple is made by braces or of a tuple of its own type: one of int and double is not made of one of
   two ints, where C++ converts each element (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<int, int> a = {1, 2};
    tuple<int, double> b = a;
    return get<0>(b);
}
