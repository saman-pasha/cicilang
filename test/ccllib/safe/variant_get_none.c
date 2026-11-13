/* <variant.pl>: get<T> of a type that the variant does not hold names no alternative, as in C++ (0.308) */
#include <variant.pl>
int main(void) {
    variant<int, double> v = 1;
    return get<char>(v);
}
