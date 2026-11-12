/* <tuple.pl>: the relations compare two tuples of one type: a tuple of int and double is no operand of a tuple of two
   ints, where C++ compares the elements (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<int, int> a = {1, 2};
    tuple<int, double> b = {1, 2.0};
    return a == b;
}
