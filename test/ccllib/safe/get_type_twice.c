/* <tuple.pl>: get<T> of a type that the tuple holds twice names no element, as in C++ (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<int, int> t = {1, 2};
    return get<int>(t);
}
