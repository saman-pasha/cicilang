/* <variant.pl>: a variant is made of a value whose type is one alternative's: a long is none of int and double,
   where C++ converts it to the alternative that its overload resolution picks (0.308) */
#include <variant.pl>
int main(void) {
    long x = 5;
    variant<int, double> v = x;
    return (int)index(v);
}
