/* <pair.pl>: the relations compare two pairs of one type: a pair of int and double is no operand of a pair of two
   ints, where C++ compares the members (0.301) */
#include <pair.pl>
int main(void) {
    pair<int, int> a = {1, 2};
    pair<int, double> b = {1, 2.0};
    return a == b;
}
