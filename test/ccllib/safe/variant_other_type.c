/* <variant.pl>: the relations compare two variants of one type: one of int and char is no operand of one of int and
   double, as in C++ (0.308) */
#include <variant.pl>
int main(void) {
    variant<int, double> a = 1;
    variant<int, char> b = 1;
    return a == b;
}
