/* <tuple.pl>: get<T> of a type that the tuple does not hold names no element, as in C++ (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<int, double> t = {1, 2.5};
    return get<char>(t);
}
