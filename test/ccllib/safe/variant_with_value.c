/* <variant.pl>: a variant is compared with a variant: an int is no operand of a variant of int and double, as C++
   has no such relation (0.308) */
#include <variant.pl>
int main(void) {
    variant<int, double> a = 1;
    return a == 1;
}
